defmodule KyozoWeb.ScanChannel do
  @moduledoc """
  WebSocket channel for real-time streaming markdown scanning.

  Allows clients to stream large markdown documents and receive
  real-time security analysis, threat detection, and capability
  extraction as the content is processed.
  """

  use KyozoWeb, :channel

  alias Kyozo.Markdown.Pipeline
  alias Kyozo.Markdown.Pipeline.Result
  alias Kyozo.Billing
  alias Kyozo.Events

  @max_chunk_size 64_000
  @stream_timeout 300_000

  def join("scan:" <> scan_id, payload, socket) do
    with {:ok, user} <- authenticate_socket(socket),
         {:ok, _usage} <- check_usage_limits(user),
         {:ok, scan_config} <- validate_scan_config(payload) do
      # Initialize scan session
      socket =
        socket
        |> assign(:user, user)
        |> assign(:scan_id, scan_id)
        |> assign(:scan_config, scan_config)
        |> assign(:content_buffer, "")
        |> assign(:bytes_received, 0)
        |> assign(:started_at, DateTime.utc_now())

      # Set up stream timeout
      Process.send_after(self(), :stream_timeout, @stream_timeout)

      {:ok, %{scan_id: scan_id, status: "ready"}, socket}
    else
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def handle_in("stream_chunk", %{"chunk" => chunk, "sequence" => seq}, socket) do
    with {:ok, _} <- validate_chunk(chunk, socket),
         {:ok, updated_socket} <- process_chunk(chunk, seq, socket) do
      # Send acknowledgment
      push(socket, "chunk_ack", %{sequence: seq, status: "processed"})

      {:noreply, updated_socket}
    else
      {:error, reason} ->
        push(socket, "chunk_error", %{sequence: seq, error: reason})
        {:noreply, socket}
    end
  end

  def handle_in("stream_complete", %{"final_sequence" => final_seq}, socket) do
    with {:ok, result} <- finalize_scan(socket) do
      # Track usage for billing
      track_stream_usage(socket.assigns.user, result, socket)

      # Send final result
      formatted_result = format_stream_result(result, socket.assigns.scan_config)

      push(socket, "scan_complete", %{
        sequence: final_seq,
        result: formatted_result,
        summary: Result.summary(result)
      })

      # Emit completion event
      Events.emit(:stream_scan_completed, %{
        user_id: socket.assigns.user.id,
        scan_id: socket.assigns.scan_id,
        content_size: socket.assigns.bytes_received,
        threat_level: result.threat_level,
        processing_time_ms: calculate_processing_time(socket)
      })

      {:noreply, socket}
    else
      {:error, reason} ->
        push(socket, "scan_error", %{error: reason})
        {:noreply, socket}
    end
  end

  def handle_in("cancel_scan", _payload, socket) do
    # Clean up any resources
    cleanup_scan_session(socket)

    push(socket, "scan_cancelled", %{scan_id: socket.assigns.scan_id})

    {:stop, :normal, socket}
  end

  def handle_info(:stream_timeout, socket) do
    push(socket, "stream_timeout", %{
      message: "Stream timeout - no activity for #{@stream_timeout / 1000} seconds"
    })

    {:stop, :normal, socket}
  end

  def handle_info({:scan_progress, progress}, socket) do
    push(socket, "scan_progress", progress)
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    cleanup_scan_session(socket)
    :ok
  end

  # Private functions

  defp authenticate_socket(socket) do
    case socket.assigns[:user] do
      nil ->
        case socket.assigns[:token] do
          nil -> {:error, "Authentication required"}
          token -> verify_stream_token(token)
        end

      user ->
        {:ok, user}
    end
  end

  defp verify_stream_token(token) do
    # This would integrate with your actual token verification
    case token do
      "stream_token_" <> _rest ->
        {:ok, %{id: 1, email: "test@example.com", tier: "pro"}}

      _ ->
        {:error, "Invalid stream token"}
    end
  end

  defp check_usage_limits(user) do
    case Billing.check_stream_quota(user) do
      {:ok, remaining} when remaining > 0 ->
        {:ok, %{remaining: remaining}}

      {:ok, 0} ->
        {:error, "Stream quota exceeded"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_scan_config(payload) do
    config = %{
      mode: Map.get(payload, "mode", "sanitize"),
      options: Map.get(payload, "options", %{}),
      chunk_processing: Map.get(payload, "chunk_processing", true),
      real_time_alerts: Map.get(payload, "real_time_alerts", false)
    }

    case config.mode do
      mode when mode in ["sanitize", "detect", "analyze"] ->
        {:ok, config}

      _ ->
        {:error, "Invalid scan mode"}
    end
  end

  defp validate_chunk(chunk, socket) do
    cond do
      byte_size(chunk) > @max_chunk_size ->
        {:error, "Chunk too large (max #{@max_chunk_size} bytes)"}

      socket.assigns.bytes_received + byte_size(chunk) > 100_000_000 ->
        {:error, "Total content too large (max 100MB)"}

      not String.valid?(chunk) ->
        {:error, "Invalid UTF-8 encoding in chunk"}

      true ->
        {:ok, :valid}
    end
  end

  defp process_chunk(chunk, sequence, socket) do
    # Update content buffer
    new_buffer = socket.assigns.content_buffer <> chunk
    new_bytes = socket.assigns.bytes_received + byte_size(chunk)

    updated_socket =
      socket
      |> assign(:content_buffer, new_buffer)
      |> assign(:bytes_received, new_bytes)

    # Process chunk if chunk processing is enabled
    if socket.assigns.scan_config.chunk_processing do
      case process_chunk_content(chunk, socket.assigns.scan_config) do
        {:ok, chunk_result} ->
          # Send real-time results if enabled
          if socket.assigns.scan_config.real_time_alerts and has_alerts?(chunk_result) do
            push(socket, "real_time_alert", %{
              sequence: sequence,
              alerts: extract_alerts(chunk_result)
            })
          end

          # Send chunk analysis
          push(socket, "chunk_analysis", %{
            sequence: sequence,
            threats_found: length(chunk_result.threats),
            capabilities_found: length(chunk_result.capabilities),
            safe: chunk_result.safe
          })

          {:ok, updated_socket}

        {:error, reason} ->
          {:error, "Chunk processing failed: #{reason}"}
      end
    else
      {:ok, updated_socket}
    end
  end

  defp process_chunk_content(chunk, config) do
    mode = string_to_mode(config.mode)
    options = config.options || %{}

    Pipeline.process(chunk, mode, options)
  end

  defp finalize_scan(socket) do
    final_content = socket.assigns.content_buffer
    scan_config = socket.assigns.scan_config

    mode = string_to_mode(scan_config.mode)

    options =
      Map.merge(scan_config.options || %{}, %{
        stream_processing: true,
        total_size: socket.assigns.bytes_received
      })

    Pipeline.process(final_content, mode, options)
  end

  defp string_to_mode("sanitize"), do: :sanitize
  defp string_to_mode("detect"), do: :detect
  defp string_to_mode("analyze"), do: :analyze
  defp string_to_mode(_), do: :sanitize

  defp format_stream_result(result, config) do
    case config.mode do
      "sanitize" ->
        Result.to_safemd_json(result)

      "detect" ->
        Result.to_research_json(result)

      "analyze" ->
        Result.to_json(result)

      _ ->
        Result.to_safemd_json(result)
    end
  end

  defp has_alerts?(result) do
    result.threat_level != :none or length(result.errors) > 0
  end

  defp extract_alerts(result) do
    %{
      threat_level: result.threat_level,
      # Top 3 threats
      threats: Enum.take(result.threats, 3),
      # Top 2 errors
      errors: Enum.take(result.errors, 2)
    }
  end

  defp track_stream_usage(user, result, socket) do
    usage_data = %{
      user_id: user.id,
      operation: "stream_scan",
      content_size_bytes: socket.assigns.bytes_received,
      processing_time_ms: calculate_processing_time(socket),
      threat_level: result.threat_level,
      scan_mode: socket.assigns.scan_config.mode,
      timestamp: DateTime.utc_now()
    }

    # Record usage for billing at $0.03 per scan
    Billing.record_usage(usage_data)

    # Emit usage event
    Events.emit(:stream_api_usage, usage_data)
  end

  defp calculate_processing_time(socket) do
    DateTime.diff(DateTime.utc_now(), socket.assigns.started_at, :millisecond)
  end

  defp cleanup_scan_session(socket) do
    # Clean up any temporary resources
    # Log session summary
    if socket.assigns[:scan_id] do
      Events.emit(:stream_session_ended, %{
        scan_id: socket.assigns.scan_id,
        user_id: socket.assigns[:user][:id],
        bytes_processed: socket.assigns[:bytes_received] || 0,
        duration_ms: calculate_processing_time(socket)
      })
    end
  end
end
