defmodule Kyozo.Containers.Workers.ContainerHealthMonitor do
  @moduledoc """
  Oban worker for monitoring container health status.

  This worker performs batch health checks on all running containers
  and can also handle individual container health monitoring tasks.
  """

  use Oban.Worker,
    queue: :health_monitoring,
    priority: 2,
    max_attempts: 3,
    tags: ["containers", "health"]

  alias Kyozo.Containers
  alias Kyozo.Containers.ContainerManager

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"batch_check" => true}} = job) do
    Logger.info("Starting batch container health check")

    case perform_batch_health_check() do
      {:ok, results} ->
        Logger.info("Batch health check completed successfully",
          checked: length(results.checked),
          healthy: length(results.healthy),
          unhealthy: length(results.unhealthy)
        )

        :ok

      {:error, reason} ->
        Logger.error("Batch health check failed", error: inspect(reason))
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"service_id" => service_id, "tenant" => tenant}} = job) do
    Logger.debug("Performing health check for service", service_id: service_id)

    case perform_single_health_check(service_id, tenant) do
      {:ok, status} ->
        Logger.debug("Health check completed",
          service_id: service_id,
          status: status
        )

        :ok

      {:error, reason} ->
        Logger.warning("Health check failed for service",
          service_id: service_id,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: args} = job) do
    Logger.warning("Unknown health monitor job args", args: inspect(args))
    :ok
  end

  @doc """
  Enqueue a single health check for a specific service.
  """
  def enqueue_single_check(service_id, opts \\ []) do
    priority = Keyword.get(opts, :priority, 2)
    tenant = Keyword.get(opts, :tenant)

    args = %{
      "service_id" => service_id,
      "tenant" => tenant
    }

    %{args: args, priority: priority}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @doc """
  Enqueue a batch health check job.
  """
  def enqueue_batch_check(opts \\ []) do
    priority = Keyword.get(opts, :priority, 3)

    args = %{"batch_check" => true}

    %{args: args, priority: priority}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  # Private functions

  defp perform_batch_health_check do
    try do
      # Get all running service instances
      {:ok, services} = Containers.list_service_instances()

      running_services =
        Enum.filter(services, fn service ->
          service.status in [:running, :deployed, :starting]
        end)

      # Perform health checks in parallel with limited concurrency
      task_results =
        running_services
        |> Task.async_stream(&check_service_health/1,
          max_concurrency: 10,
          timeout: 30_000,
          on_timeout: :kill_task
        )
        |> Enum.to_list()

      # Process results
      {healthy, unhealthy} =
        task_results
        |> Enum.reduce({[], []}, fn
          {:ok, {:ok, service_id}} = result, {healthy, unhealthy} ->
            {[service_id | healthy], unhealthy}

          {:ok, {:error, service_id}} = result, {healthy, unhealthy} ->
            {healthy, [service_id | unhealthy]}

          {:exit, reason}, {healthy, unhealthy} ->
            Logger.warning("Health check task crashed", reason: inspect(reason))
            {healthy, unhealthy}
        end)

      results = %{
        checked: running_services |> Enum.map(& &1.id),
        healthy: healthy,
        unhealthy: unhealthy
      }

      {:ok, results}
    rescue
      exception ->
        Logger.error("Batch health check exception",
          exception: inspect(exception),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        {:error, exception}
    end
  end

  defp perform_single_health_check(service_id, tenant) do
    try do
      # Get service details
      case Containers.get_service_instance(service_id, tenant: tenant) do
        {:ok, service} ->
          check_service_health(service)

        {:error, reason} = error ->
          Logger.warning("Service not found for health check",
            service_id: service_id,
            error: inspect(reason)
          )

          error
      end
    rescue
      exception ->
        Logger.error("Single health check exception",
          service_id: service_id,
          exception: inspect(exception),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        {:error, exception}
    end
  end

  defp check_service_health(service) do
    case ContainerManager.check_container_health(service.container_id, service.team_id) do
      {:ok, :healthy} ->
        # Update service status if needed
        maybe_update_service_status(service, :healthy)
        {:ok, service.id}

      {:ok, :unhealthy} ->
        Logger.warning("Container reported unhealthy",
          service_id: service.id,
          container_id: service.container_id
        )

        maybe_update_service_status(service, :unhealthy)
        {:error, service.id}

      {:error, :not_found} ->
        Logger.warning("Container not found during health check",
          service_id: service.id,
          container_id: service.container_id
        )

        maybe_update_service_status(service, :stopped)
        {:error, service.id}

      {:error, reason} ->
        Logger.warning("Health check failed",
          service_id: service.id,
          container_id: service.container_id,
          error: inspect(reason)
        )

        {:error, service.id}
    end
  rescue
    exception ->
      Logger.error("Health check crashed for service",
        service_id: service.id,
        exception: inspect(exception)
      )

      {:error, service.id}
  end

  defp maybe_update_service_status(service, health_status) do
    # Map health status to service status
    new_status =
      case {service.status, health_status} do
        # No change needed
        {:running, :healthy} -> nil
        # No change needed
        {:deployed, :healthy} -> nil
        # Starting -> Running
        {:starting, :healthy} -> :running
        {_, :unhealthy} -> :unhealthy
        {_, :stopped} -> :stopped
        _ -> nil
      end

    if new_status && new_status != service.status do
      case Containers.update_service_instance(service, %{status: new_status},
             tenant: service.team_id
           ) do
        {:ok, _updated_service} ->
          Logger.info("Updated service status after health check",
            service_id: service.id,
            old_status: service.status,
            new_status: new_status
          )

          :ok

        {:error, reason} ->
          Logger.warning("Failed to update service status after health check",
            service_id: service.id,
            new_status: new_status,
            error: inspect(reason)
          )

          :error
      end
    else
      :ok
    end
  end
end
