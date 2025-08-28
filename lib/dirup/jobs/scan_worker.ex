defmodule Dirup.Jobs.ScanWorker do
  @moduledoc """
  Oban worker for processing asynchronous markdown scanning jobs.

  Handles large document processing with progress tracking,
  error handling, and result storage.
  """

  use Oban.Worker, queue: :scan, max_attempts: 3

  alias Dirup.Markdown.Pipeline
  alias Dirup.Markdown.Pipeline.Result
  alias Dirup.Billing
  alias Dirup.Events
  alias Dirup.Jobs

  @impl Oban.Worker
  def perform(%Oban.Job{args: args} = job) do
    %{
      "user_id" => user_id,
      "content" => content,
      "scan_mode" => scan_mode,
      "scan_options" => scan_options
    } = args

    with {:ok, user} <- get_user(user_id),
         {:ok, _usage} <- check_usage_limits(user),
         {:ok, result} <- process_scan(content, scan_mode, scan_options, job) do
      # Store result
      store_scan_result(job.id, result)

      # Track usage for billing
      track_async_usage(user, result, content)

      # Emit completion event
      Events.emit(:async_scan_completed, %{
        job_id: job.id,
        user_id: user_id,
        content_size: byte_size(content),
        threat_level: result.threat_level,
        processing_time_ms: Map.get(result.metrics, :processing_time_ms)
      })

      :ok
    else
      {:error, :usage_limit_exceeded} ->
        # Mark job as failed due to quota
        store_scan_error(job.id, "Usage limit exceeded")
        {:error, "Usage limit exceeded"}

      {:error, reason} ->
        # Store error for retrieval
        store_scan_error(job.id, reason)
        {:error, reason}
    end
  end

  @doc """
  Enqueue a new scan job.
  """
  def enqueue(params) do
    %{
      user_id: user_id,
      content: content,
      scan_mode: scan_mode,
      scan_options: scan_options,
      priority: priority
    } = params

    job_args = %{
      "user_id" => user_id,
      "content" => content,
      "scan_mode" => Atom.to_string(scan_mode),
      "scan_options" => scan_options
    }

    opts = [
      priority: priority_to_int(priority),
      max_attempts: 3,
      tags: ["scan", "user:#{user_id}"]
    ]

    case new(job_args, opts) |> Oban.insert() do
      {:ok, job} ->
        # Initialize job status
        store_job_status(job.id, "queued", 0)
        {:ok, job}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp get_user(user_id) do
    # This would fetch from your user system
    case Dirup.Accounts.get_user(user_id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  rescue
    _ ->
      # Mock user for development
      {:ok, %{id: user_id, email: "user@example.com", tier: "pro"}}
  end

  defp check_usage_limits(user) do
    case Billing.check_async_scan_quota(user) do
      {:ok, remaining} when remaining > 0 ->
        {:ok, %{remaining: remaining}}

      {:ok, 0} ->
        {:error, :usage_limit_exceeded}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ ->
      # Allow in development
      {:ok, %{remaining: 100}}
  end

  defp process_scan(content, scan_mode_string, scan_options, job) do
    scan_mode = String.to_existing_atom(scan_mode_string)

    # Update job status
    update_job_progress(job.id, 10, "Starting scan")

    # Process in chunks for large content
    content_size = byte_size(content)

    if content_size > 10_000_000 do
      # Process large files in streaming mode
      process_large_scan(content, scan_mode, scan_options, job)
    else
      # Process normally
      update_job_progress(job.id, 50, "Processing content")

      case Pipeline.process(content, scan_mode, scan_options) do
        {:ok, result} ->
          update_job_progress(job.id, 100, "Completed")
          {:ok, result}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp process_large_scan(content, scan_mode, scan_options, job) do
    # Split content into chunks for progress tracking
    # 1MB chunks
    chunk_size = 1_000_000
    chunks = split_content(content, chunk_size)
    total_chunks = length(chunks)

    update_job_progress(job.id, 20, "Processing #{total_chunks} chunks")

    # Process with streaming pipeline
    _stream_config = Pipeline.build_config(scan_mode, scan_options)

    try do
      result_stream =
        chunks
        |> Stream.with_index()
        |> Stream.map(fn {chunk, index} ->
          progress = 20 + trunc(index / total_chunks * 70)
          update_job_progress(job.id, progress, "Processing chunk #{index + 1}/#{total_chunks}")

          case Pipeline.process(chunk, scan_mode, scan_options) do
            {:ok, chunk_result} -> chunk_result
            {:error, reason} -> throw({:chunk_error, reason, index})
          end
        end)
        |> Enum.to_list()

      # Combine results
      combined_result = combine_chunk_results(result_stream, content)
      update_job_progress(job.id, 100, "Completed")

      {:ok, combined_result}
    catch
      {:chunk_error, reason, chunk_index} ->
        {:error, "Failed processing chunk #{chunk_index}: #{reason}"}
    end
  end

  defp split_content(content, chunk_size) do
    content
    |> String.codepoints()
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(&Enum.join/1)
  end

  defp combine_chunk_results(chunk_results, original_content) do
    # Combine all threats, capabilities, etc. from chunks
    all_threats = Enum.flat_map(chunk_results, & &1.threats)
    all_capabilities = Enum.flat_map(chunk_results, & &1.capabilities)
    all_transformations = Enum.flat_map(chunk_results, & &1.transformations)
    all_errors = Enum.flat_map(chunk_results, & &1.errors)
    all_warnings = Enum.flat_map(chunk_results, & &1.warnings)

    # Determine overall safety and threat level
    max_threat_level =
      chunk_results
      |> Enum.map(& &1.threat_level)
      |> Enum.max_by(&threat_level_to_int/1, fn -> :none end)

    overall_safe = Enum.all?(chunk_results, & &1.safe)

    # Calculate combined metrics
    total_processing_time =
      chunk_results
      |> Enum.map(&Map.get(&1.metrics, :processing_time_ms))
      |> Enum.filter(&is_integer/1)
      |> Enum.sum()

    %Result{
      content: original_content,
      safe: overall_safe,
      threat_level: max_threat_level,
      threats: all_threats |> Enum.uniq_by(&{&1.type, &1.location}),
      capabilities: all_capabilities |> Enum.uniq_by(&{&1.type, &1.language}),
      transformations: all_transformations,
      metadata: %{
        processing_mode: :async,
        chunk_count: length(chunk_results),
        combined_at: DateTime.utc_now()
      },
      metrics: %{
        processing_time_ms: total_processing_time,
        bytes_processed: byte_size(original_content),
        chunks_processed: length(chunk_results)
      },
      errors: all_errors,
      warnings: all_warnings
    }
  end

  defp threat_level_to_int(:none), do: 0
  defp threat_level_to_int(:low), do: 1
  defp threat_level_to_int(:medium), do: 2
  defp threat_level_to_int(:high), do: 3
  defp threat_level_to_int(:critical), do: 4

  defp store_scan_result(job_id, result) do
    formatted_result = Result.to_json(result)

    Jobs.store_result(job_id, %{
      status: "completed",
      result: formatted_result,
      completed_at: DateTime.utc_now()
    })
  end

  defp store_scan_error(job_id, reason) do
    Jobs.store_result(job_id, %{
      status: "failed",
      error: reason,
      failed_at: DateTime.utc_now()
    })
  end

  defp store_job_status(job_id, status, progress) do
    Jobs.update_status(job_id, %{
      status: status,
      progress: progress,
      updated_at: DateTime.utc_now()
    })
  end

  defp update_job_progress(job_id, progress, message) do
    Jobs.update_status(job_id, %{
      status: "processing",
      progress: progress,
      message: message,
      updated_at: DateTime.utc_now()
    })
  end

  defp track_async_usage(user, result, content) do
    usage_data = %{
      user_id: user.id,
      operation: "async_scan",
      content_size_bytes: byte_size(content),
      processing_time_ms: Map.get(result.metrics, :processing_time_ms, 0),
      threat_level: result.threat_level,
      timestamp: DateTime.utc_now()
    }

    # Record usage at $0.03 per scan
    Billing.record_usage(usage_data)

    # Emit usage event
    Events.emit(:async_api_usage, usage_data)
  rescue
    error ->
      # Log but don't fail the job
      require Logger
      Logger.warning("Failed to track async usage: #{inspect(error)}")
  end

  defp priority_to_int(:high), do: 3
  defp priority_to_int(:medium), do: 2
  defp priority_to_int(:low), do: 1
  defp priority_to_int(_), do: 1
end
