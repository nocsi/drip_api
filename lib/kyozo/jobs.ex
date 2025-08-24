defmodule Kyozo.Jobs do
  @moduledoc """
  Job storage and management system for async scan operations.

  Provides storage, retrieval, and status tracking for background
  processing jobs, particularly async markdown scanning.
  """

  @doc """
  Get a job by ID with its current status and results.
  """
  @spec get_job(String.t()) :: map() | nil
  def get_job(job_id) do
    # In a real implementation, this would query a jobs table
    # For now, we'll use ETS or a simple GenServer-based storage
    case :ets.lookup(:scan_jobs, job_id) do
      [{^job_id, job_data}] -> job_data
      [] -> nil
    end
  rescue
    _ ->
      # ETS table doesn't exist, create it and return nil
      ensure_jobs_table_exists()
      nil
  end

  @doc """
  Store job result and update status.
  """
  @spec store_result(String.t(), map()) :: :ok
  def store_result(job_id, result_data) do
    ensure_jobs_table_exists()

    existing_job = get_job(job_id) || %{id: job_id}
    updated_job = Map.merge(existing_job, result_data)

    :ets.insert(:scan_jobs, {job_id, updated_job})
    :ok
  end

  @doc """
  Update job status and progress.
  """
  @spec update_status(String.t(), map()) :: :ok
  def update_status(job_id, status_data) do
    ensure_jobs_table_exists()

    existing_job = get_job(job_id) || %{id: job_id}
    updated_job = Map.merge(existing_job, status_data)

    :ets.insert(:scan_jobs, {job_id, updated_job})

    # Broadcast status update if there are listeners
    Phoenix.PubSub.broadcast(Kyozo.PubSub, "job:#{job_id}", {
      :job_status_update,
      %{
        job_id: job_id,
        status: Map.get(status_data, :status),
        progress: Map.get(status_data, :progress),
        message: Map.get(status_data, :message)
      }
    })

    :ok
  end

  @doc """
  List jobs for a specific user.
  """
  @spec list_user_jobs(integer(), keyword()) :: [map()]
  def list_user_jobs(user_id, opts \\ []) do
    ensure_jobs_table_exists()
    limit = Keyword.get(opts, :limit, 50)

    :ets.tab2list(:scan_jobs)
    |> Enum.map(fn {_id, job} -> job end)
    |> Enum.filter(&(&1.user_id == user_id))
    |> Enum.sort_by(&Map.get(&1, :created_at, DateTime.utc_now()), {:desc, DateTime})
    |> Enum.take(limit)
  end

  @doc """
  Clean up old completed jobs (older than 7 days).
  """
  @spec cleanup_old_jobs() :: {:ok, integer()}
  def cleanup_old_jobs do
    ensure_jobs_table_exists()
    cutoff_date = DateTime.add(DateTime.utc_now(), -7, :day)

    old_jobs =
      :ets.tab2list(:scan_jobs)
      |> Enum.filter(fn {_id, job} ->
        completed_at = Map.get(job, :completed_at) || Map.get(job, :failed_at)

        case completed_at do
          nil ->
            false

          date when is_binary(date) ->
            case DateTime.from_iso8601(date) do
              {:ok, dt, _} -> DateTime.compare(dt, cutoff_date) == :lt
              _ -> false
            end

          %DateTime{} = dt ->
            DateTime.compare(dt, cutoff_date) == :lt

          _ ->
            false
        end
      end)

    count = length(old_jobs)

    Enum.each(old_jobs, fn {job_id, _job} ->
      :ets.delete(:scan_jobs, job_id)
    end)

    {:ok, count}
  end

  @doc """
  Get job statistics for monitoring.
  """
  @spec get_stats() :: map()
  def get_stats do
    ensure_jobs_table_exists()

    all_jobs =
      :ets.tab2list(:scan_jobs)
      |> Enum.map(fn {_id, job} -> job end)

    total_count = length(all_jobs)

    status_counts =
      all_jobs
      |> Enum.group_by(&Map.get(&1, :status, "unknown"))
      |> Enum.map(fn {status, jobs} -> {status, length(jobs)} end)
      |> Enum.into(%{})

    # Calculate average processing time for completed jobs
    completed_jobs =
      all_jobs
      |> Enum.filter(&(Map.get(&1, :status) == "completed"))

    avg_processing_time =
      if length(completed_jobs) > 0 do
        total_time =
          completed_jobs
          |> Enum.map(fn job ->
            case job do
              %{result: %{metrics: %{processing_time_ms: time}}} -> time
              _ -> nil
            end
          end)
          |> Enum.filter(&is_integer/1)
          |> Enum.sum()

        if total_time > 0, do: div(total_time, length(completed_jobs)), else: 0
      else
        0
      end

    %{
      total_jobs: total_count,
      status_counts: status_counts,
      average_processing_time_ms: avg_processing_time,
      jobs_last_24h: count_recent_jobs(all_jobs, 1),
      jobs_last_7d: count_recent_jobs(all_jobs, 7)
    }
  end

  @doc """
  Initialize job with basic metadata.
  """
  @spec initialize_job(String.t(), integer(), map()) :: :ok
  def initialize_job(job_id, user_id, metadata \\ %{}) do
    job_data =
      Map.merge(
        %{
          id: job_id,
          user_id: user_id,
          status: "queued",
          progress: 0,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        },
        metadata
      )

    store_result(job_id, job_data)
  end

  @doc """
  Cancel a job if it's still in queue or processing.
  """
  @spec cancel_job(String.t()) :: :ok | {:error, String.t()}
  def cancel_job(job_id) do
    case get_job(job_id) do
      nil ->
        {:error, "Job not found"}

      %{status: status} when status in ["completed", "failed", "cancelled"] ->
        {:error, "Job already finished"}

      job ->
        cancelled_job =
          Map.merge(job, %{
            status: "cancelled",
            cancelled_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          })

        store_result(job_id, cancelled_job)

        # Try to cancel the actual Oban job
        try do
          Oban.cancel_job(job_id)
        rescue
          # Job might not be in Oban anymore
          _ -> :ok
        end

        :ok
    end
  end

  @doc """
  Subscribe to job status updates via PubSub.
  """
  @spec subscribe_to_job(String.t()) :: :ok
  def subscribe_to_job(job_id) do
    Phoenix.PubSub.subscribe(Kyozo.PubSub, "job:#{job_id}")
  end

  @doc """
  Unsubscribe from job status updates.
  """
  @spec unsubscribe_from_job(String.t()) :: :ok
  def unsubscribe_from_job(job_id) do
    Phoenix.PubSub.unsubscribe(Kyozo.PubSub, "job:#{job_id}")
  end

  # Private functions

  defp ensure_jobs_table_exists do
    case :ets.whereis(:scan_jobs) do
      :undefined ->
        :ets.new(:scan_jobs, [:set, :public, :named_table])
        :ok

      _ ->
        :ok
    end
  end

  defp count_recent_jobs(jobs, days) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days, :day)

    jobs
    |> Enum.count(fn job ->
      created_at = Map.get(job, :created_at)

      case created_at do
        %DateTime{} = dt ->
          DateTime.compare(dt, cutoff_date) == :gt

        date when is_binary(date) ->
          case DateTime.from_iso8601(date) do
            {:ok, dt, _} -> DateTime.compare(dt, cutoff_date) == :gt
            _ -> false
          end

        _ ->
          false
      end
    end)
  end
end
