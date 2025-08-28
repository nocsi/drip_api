defmodule Dirup.Containers.Workers.CleanupWorker do
  @moduledoc """
  Background worker for cleaning up old metrics, deployment events, health checks,
  and orphaned container resources. Runs periodically to maintain database performance
  and disk space usage.
  """

  use Oban.Worker,
    queue: :cleanup,
    max_attempts: 2,
    tags: ["cleanup", "maintenance"]

  import Ecto.Query

  alias Dirup.Containers.{ServiceMetric, DeploymentEvent, HealthCheck}
  alias Dirup.Containers.{ServiceInstance, ContainerManager}
  alias Dirup.Repo

  require Logger

  # Retention periods (configurable via application config)
  @default_retention_periods %{
    metrics: [days: 7],
    deployment_events: [days: 90],
    health_checks: [days: 30],
    stopped_services: [days: 30]
  }

  # Minimal retention safeguards to prevent accidental mass deletion
  @min_retention_days %{
    metrics: 1,
    deployment_events: 7,
    health_checks: 1,
    stopped_services: 7
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "metrics"}}) do
    Logger.info("Starting metrics cleanup")

    retention_period = get_retention_period(:metrics)
    cutoff_date = DateTime.add(DateTime.utc_now(), -retention_period[:days], :day)

    query = from(m in ServiceMetric, where: m.recorded_at < ^cutoff_date)

    case Repo.delete_all(query) do
      {count, _} ->
        Logger.info("Cleaned up old metrics", deleted_count: count, cutoff_date: cutoff_date)

        telemetry_cleanup(:metrics, %{deleted: count}, %{
          cutoff_date: cutoff_date,
          days: retention_period[:days]
        })

        :ok

      error ->
        Logger.error("Failed to cleanup metrics", error: inspect(error))
        {:error, error}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "deployment_events"}}) do
    Logger.info("Starting deployment events cleanup")

    retention_period = get_retention_period(:deployment_events)
    cutoff_date = DateTime.add(DateTime.utc_now(), -retention_period[:days], :day)

    # Keep critical events longer (deployment_completed, deployment_failed)
    critical_events = [:deployment_completed, :deployment_failed, :service_started]

    query =
      from(e in DeploymentEvent,
        where: e.occurred_at < ^cutoff_date and e.event_type not in ^critical_events
      )

    case Repo.delete_all(query) do
      {count, _} ->
        Logger.info("Cleaned up deployment events",
          deleted_count: count,
          cutoff_date: cutoff_date
        )

        telemetry_cleanup(:deployment_events, %{deleted: count}, %{
          cutoff_date: cutoff_date,
          days: retention_period[:days]
        })

        :ok

      error ->
        Logger.error("Failed to cleanup deployment events", error: inspect(error))
        {:error, error}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "health_checks"}}) do
    Logger.info("Starting health checks cleanup")

    retention_period = get_retention_period(:health_checks)
    cutoff_date = DateTime.add(DateTime.utc_now(), -retention_period[:days], :day)

    # Keep recent failed health checks longer for debugging
    query =
      from(h in HealthCheck,
        where: h.checked_at < ^cutoff_date and h.status != :unhealthy
      )

    case Repo.delete_all(query) do
      {count, _} ->
        Logger.info("Cleaned up health checks", deleted_count: count, cutoff_date: cutoff_date)

        telemetry_cleanup(:health_checks, %{deleted: count}, %{
          cutoff_date: cutoff_date,
          days: retention_period[:days]
        })

        :ok

      error ->
        Logger.error("Failed to cleanup health checks", error: inspect(error))
        {:error, error}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "orphaned_containers"}}) do
    Logger.info("Starting orphaned containers cleanup")

    case ContainerManager.list_all_containers() do
      {:ok, running_containers} ->
        # Get all service instances with container IDs
        service_containers =
          ServiceInstance
          |> select([s], s.container_id)
          |> where([s], not is_nil(s.container_id))
          |> Repo.all()
          |> MapSet.new()

        # Find orphaned containers
        orphaned =
          Enum.reject(running_containers, fn container ->
            MapSet.member?(service_containers, container.id)
          end)

        # Clean up orphaned containers
        cleanup_results =
          Enum.map(orphaned, fn container ->
            case ContainerManager.remove_container(container.id) do
              :ok ->
                Logger.info("Removed orphaned container", container_id: container.id)
                {:ok, container.id}

              error ->
                Logger.warn("Failed to remove orphaned container",
                  container_id: container.id,
                  error: inspect(error)
                )

                {:error, container.id}
            end
          end)

        success_count = Enum.count(cleanup_results, &match?({:ok, _}, &1))

        Logger.info("Orphaned containers cleanup completed",
          total: length(orphaned),
          cleaned: success_count
        )

        telemetry_cleanup(
          :orphaned_containers,
          %{total: length(orphaned), cleaned: success_count},
          %{}
        )

        :ok

      {:error, error} ->
        Logger.error("Failed to list containers for cleanup", error: inspect(error))
        {:error, error}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "stopped_services"}}) do
    Logger.info("Starting stopped services cleanup")

    retention_period = get_retention_period(:stopped_services)
    cutoff_date = DateTime.add(DateTime.utc_now(), -retention_period[:days], :day)

    # Find services that have been stopped for longer than retention period
    stopped_services_query =
      from(s in ServiceInstance,
        where: s.status == :stopped and s.stopped_at < ^cutoff_date
      )

    stopped_services = Repo.all(stopped_services_query)

    cleanup_results =
      Enum.map(stopped_services, fn service ->
        case cleanup_stopped_service(service) do
          :ok ->
            Logger.info("Cleaned up stopped service", service_id: service.id, name: service.name)
            {:ok, service.id}

          error ->
            Logger.warn("Failed to cleanup stopped service",
              service_id: service.id,
              error: inspect(error)
            )

            {:error, service.id}
        end
      end)

    success_count = Enum.count(cleanup_results, &match?({:ok, _}, &1))

    Logger.info("Stopped services cleanup completed",
      total: length(stopped_services),
      cleaned: success_count
    )

    telemetry_cleanup(
      :stopped_services,
      %{total: length(stopped_services), cleaned: success_count},
      %{cutoff_date: cutoff_date}
    )

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "docker_images"}}) do
    Logger.info("Starting Docker images cleanup")

    case ContainerManager.cleanup_unused_images() do
      {:ok, cleanup_result} ->
        Logger.info("Docker images cleanup completed",
          images_removed: cleanup_result.images_removed,
          space_freed: cleanup_result.space_freed_bytes
        )

        telemetry_cleanup(
          :docker_images,
          %{
            images_removed: cleanup_result.images_removed,
            space_freed_bytes: cleanup_result.space_freed_bytes
          },
          %{}
        )

        :ok

      {:error, error} ->
        Logger.error("Failed to cleanup Docker images", error: inspect(error))
        {:error, error}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "full_cleanup"}}) do
    Logger.info("Starting full system cleanup")

    # Schedule all cleanup types
    cleanup_types = [
      "metrics",
      "deployment_events",
      "health_checks",
      "orphaned_containers",
      "stopped_services",
      "docker_images"
    ]

    Enum.each(cleanup_types, fn type ->
      %{"type" => type}
      # Spread over 5 minutes
      |> __MODULE__.new(schedule_in: :rand.uniform(300))
      |> Oban.insert()
    end)

    Logger.info("Scheduled full cleanup tasks", types: cleanup_types)
    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "vacuum_analyze"}}) do
    Logger.info("Starting database vacuum analyze")

    tables_to_vacuum = [
      "service_metrics",
      "deployment_events",
      "health_checks",
      "service_instances"
    ]

    Enum.each(tables_to_vacuum, fn table ->
      started = System.monotonic_time()

      case Repo.query("VACUUM ANALYZE #{table}") do
        {:ok, _} ->
          duration_ms =
            System.convert_time_unit(System.monotonic_time() - started, :native, :millisecond)

          Logger.debug("Vacuumed table", table: table, duration_ms: duration_ms)
          telemetry_cleanup(:vacuum, %{duration_ms: duration_ms}, %{table: table})

        {:error, error} ->
          Logger.warn("Failed to vacuum table", table: table, error: inspect(error))
      end
    end)

    Logger.info("Database vacuum analyze completed")
    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error("CleanupWorker received invalid arguments", args: args)
    {:error, :invalid_arguments}
  end

  # Schedule cleanup jobs
  def schedule_cleanup(type, opts \\ [])
      when type in ~w(metrics deployment_events health_checks orphaned_containers stopped_services docker_images full_cleanup vacuum_analyze)a do
    schedule_in = Keyword.get(opts, :schedule_in, 0)

    %{"type" => to_string(type)}
    |> __MODULE__.new(schedule_in: schedule_in)
    |> Oban.insert()
  end

  def schedule_daily_cleanup do
    # Schedule full cleanup daily at 2 AM
    schedule_cleanup(:full_cleanup, schedule_in: seconds_until_2am())
  end

  def schedule_weekly_vacuum do
    # Schedule vacuum analyze weekly on Sunday at 3 AM
    schedule_cleanup(:vacuum_analyze, schedule_in: seconds_until_sunday_3am())
  end

  # Private helper functions

  defp cleanup_stopped_service(service_instance) do
    Repo.transaction(fn ->
      # Remove container if it still exists
      if service_instance.container_id do
        ContainerManager.remove_container(service_instance.container_id)
      end

      # Remove old metrics for this service
      metrics_query =
        from(m in ServiceMetric,
          where: m.service_instance_id == ^service_instance.id
        )

      Repo.delete_all(metrics_query)

      # Remove old health checks
      health_query =
        from(h in HealthCheck,
          where: h.service_instance_id == ^service_instance.id
        )

      Repo.delete_all(health_query)

      # Keep deployment events for audit purposes
      # Update service status to cleaned
      case ServiceInstance.read(service_instance.id) do
        {:ok, service} ->
          ServiceInstance.update(service, %{
            status: :cleaned,
            container_id: nil,
            cleaned_at: DateTime.utc_now()
          })

        error ->
          Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp get_retention_period(type) do
    config =
      Application.get_env(:dirup, :container_cleanup_retention, @default_retention_periods)[type] ||
        @default_retention_periods[type]

    days =
      case config do
        %{days: d} -> d
        [days: d] -> d
        _ -> 0
      end

    min_days = Map.get(@min_retention_days, type, 1)
    effective_days = max(days, min_days)
    [days: effective_days]
  end

  defp telemetry_cleanup(event, measurements, metadata) when is_atom(event) do
    :telemetry.execute([:dirup, :containers, :cleanup, event], measurements, metadata)
  end

  defp seconds_until_2am do
    now = DateTime.utc_now()

    tomorrow_2am =
      now
      |> DateTime.to_date()
      |> Date.add(1)
      |> DateTime.new!(~T[02:00:00], "Etc/UTC")

    DateTime.diff(tomorrow_2am, now)
  end

  defp seconds_until_sunday_3am do
    now = DateTime.utc_now()
    days_until_sunday = 7 - Date.day_of_week(DateTime.to_date(now)) + 7

    next_sunday_3am =
      now
      |> DateTime.to_date()
      |> Date.add(days_until_sunday)
      |> DateTime.new!(~T[03:00:00], "Etc/UTC")

    DateTime.diff(next_sunday_3am, now)
  end
end
