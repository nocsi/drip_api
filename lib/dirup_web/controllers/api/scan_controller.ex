defmodule DirupWeb.API.ScanController do
  @moduledoc """
  SafeMD API endpoints for markdown security scanning.

  Provides synchronous, asynchronous, and streaming scanning capabilities
  for detecting threats, capabilities, and polyglot features in markdown content.
  """

  use DirupWeb, :controller

  alias Dirup.Markdown.Pipeline
  alias Dirup.Markdown.Pipeline.Result
  alias Dirup.Billing
  alias Dirup.Events

  action_fallback DirupWeb.FallbackController

  @doc """
  Synchronous markdown scanning (POST /api/v1/scan)

  Scans markdown content for security threats and capabilities.
  Suitable for content up to 10MB.
  """
  def scan(conn, %{"content" => content} = params) when is_binary(content) do
    with {:ok, user} <- authenticate_api_request(conn),
         {:ok, _usage} <- check_usage_limits(user),
         {:ok, result} <- scan_content(content, params) do
      # Track usage for billing
      track_scan_usage(user, result)

      # Emit event for monitoring
      Events.emit(:scan_completed, %{
        user_id: user.id,
        content_size: byte_size(content),
        threat_level: result.threat_level,
        processing_time_ms: Map.get(result.metrics, :processing_time_ms)
      })

      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        data: format_scan_result(result, params)
      })
    else
      {:error, :authentication_failed} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :usage_limit_exceeded} ->
        conn
        |> put_status(:payment_required)
        |> json(%{error: "Usage limit exceeded"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def scan(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required 'content' parameter"})
  end

  @doc """
  Asynchronous markdown scanning (POST /api/v1/ascan)

  Initiates scanning of large markdown documents and returns a job ID.
  Use for content larger than 10MB or when non-blocking operation is preferred.
  """
  def async_scan(conn, %{"content" => content} = params) when is_binary(content) do
    with {:ok, user} <- authenticate_api_request(conn),
         {:ok, _usage} <- check_usage_limits(user),
         {:ok, job} <- enqueue_scan_job(user, content, params) do
      conn
      |> put_status(:accepted)
      |> json(%{
        success: true,
        job_id: job.id,
        status: "queued",
        estimated_completion: estimate_completion_time(content)
      })
    else
      {:error, :authentication_failed} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :usage_limit_exceeded} ->
        conn
        |> put_status(:payment_required)
        |> json(%{error: "Usage limit exceeded"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def async_scan(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required 'content' parameter"})
  end

  @doc """
  Get async scan results (GET /api/v1/ascan/:job_id)
  """
  def async_scan_result(conn, %{"job_id" => job_id}) do
    with {:ok, user} <- authenticate_api_request(conn),
         {:ok, job} <- get_scan_job(job_id),
         :ok <- verify_job_ownership(job, user) do
      case job.status do
        "completed" ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            status: "completed",
            data: job.result
          })

        "failed" ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: false,
            status: "failed",
            error: job.error
          })

        status when status in ["queued", "processing"] ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            status: status,
            progress: Map.get(job, :progress, 0)
          })
      end
    else
      {:error, :authentication_failed} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Job not found"})

      {:error, :access_denied} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})
    end
  end

  # Private functions

  defp authenticate_api_request(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        # Verify API token
        case verify_api_token(token) do
          {:ok, user} -> {:ok, user}
          :error -> {:error, :authentication_failed}
        end

      _ ->
        {:error, :authentication_failed}
    end
  end

  defp verify_api_token(token) do
    # This would integrate with your actual token verification
    # For now, return a mock user
    case token do
      "test_token_123" ->
        {:ok, %{id: 1, email: "test@example.com", tier: "pro"}}

      _ ->
        :error
    end
  end

  defp check_usage_limits(user) do
    # Check if user has remaining scan credits
    case Billing.check_scan_quota(user) do
      {:ok, remaining} when remaining > 0 ->
        {:ok, %{remaining: remaining}}

      {:ok, 0} ->
        {:error, :usage_limit_exceeded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp scan_content(content, params) do
    mode = determine_scan_mode(params)
    options = build_scan_options(params)

    Pipeline.process(content, mode, options)
  end

  defp determine_scan_mode(params) do
    case Map.get(params, "mode", "sanitize") do
      "research" -> :detect
      "analyze" -> :analyze
      _ -> :sanitize
    end
  end

  defp build_scan_options(params) do
    %{}
    |> maybe_add_option(:strict_mode, params, "strict", true)
    |> maybe_add_option(:include_polyglot, params, "include_polyglot", false)
    |> maybe_add_option(:threat_level, params, "threat_level", :medium)
    |> maybe_add_option(:ai_optimization, params, "ai_optimization", false)
  end

  defp maybe_add_option(options, key, params, param_name, default) do
    case Map.get(params, param_name) do
      nil -> Map.put(options, key, default)
      value -> Map.put(options, key, value)
    end
  end

  defp format_scan_result(result, params) do
    case determine_scan_mode(params) do
      :sanitize ->
        Result.to_safemd_json(result)

      :detect ->
        Result.to_research_json(result)

      :analyze ->
        Result.to_json(result)
    end
  end

  defp track_scan_usage(user, result) do
    usage_data = %{
      user_id: user.id,
      operation: "scan",
      content_size_bytes: Map.get(result.metrics, :bytes_processed, 0),
      processing_time_ms: Map.get(result.metrics, :processing_time_ms, 0),
      threat_level: result.threat_level,
      timestamp: DateTime.utc_now()
    }

    # This would integrate with your billing system
    Billing.record_usage(usage_data)

    # Emit event for real-time monitoring
    Events.emit(:api_usage, usage_data)
  end

  defp enqueue_scan_job(user, content, params) do
    job_params = %{
      user_id: user.id,
      content: content,
      scan_mode: determine_scan_mode(params),
      scan_options: build_scan_options(params),
      priority: get_user_priority(user)
    }

    # This would use Oban or similar job queue
    case Dirup.Jobs.ScanWorker.enqueue(job_params) do
      {:ok, job} ->
        {:ok, %{id: job.id, status: "queued"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp estimate_completion_time(content) do
    # Rough estimation based on content size
    size_mb = byte_size(content) / (1024 * 1024)
    # seconds
    base_time = 30
    # 10 seconds per MB
    size_factor = Float.ceil(size_mb) * 10

    total_seconds = base_time + size_factor
    DateTime.add(DateTime.utc_now(), trunc(total_seconds), :second)
  end

  defp get_scan_job(job_id) do
    # This would fetch from your job storage
    case Dirup.Jobs.get_job(job_id) do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  defp verify_job_ownership(job, user) do
    if job.user_id == user.id do
      :ok
    else
      {:error, :access_denied}
    end
  end

  defp get_user_priority(%{tier: "enterprise"}), do: :high
  defp get_user_priority(%{tier: "pro"}), do: :medium
  defp get_user_priority(_), do: :low
end
