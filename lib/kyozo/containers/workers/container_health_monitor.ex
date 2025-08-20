defmodule Kyozo.Containers.Workers.ContainerHealthMonitor do
  @moduledoc """
  Background worker for monitoring container health and updating service status.

  This worker:
  - Periodically checks the health of running containers
  - Updates health status in the database
  - Triggers alerts for unhealthy services
  - Implements circuit breaker patterns for Docker API resilience
  - Collects health metrics for analysis
  """

  use Oban.Worker,
    queue: :health_monitoring,
    max_attempts: 5,
    tags: ["health", "monitoring", "containers"]

  require Logger
  alias Kyozo.{Containers, Events}
  alias Kyozo.Containers.{ServiceInstance, HealthCheck}

  # Circuit breaker state
  @circuit_breaker_key "docker_api_circuit_breaker"
  # 1 minute
  @circuit_breaker_timeout 60_000
  # failures before opening
  @circuit_breaker_threshold 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"service_instance_id" => service_id} = args}) do
    Logger.debug("Starting health check for service", service_instance_id: service_id)

    with {:ok, service} <- get_service_instance(service_id),
         {:ok, health_status} <- check_service_health(service, args),
         {:ok, updated_service} <- update_service_health(service, health_status),
         {:ok, _health_record} <- record_health_check(updated_service, health_status) do
      Logger.debug("Health check completed",
        service_instance_id: service_id,
        status: health_status.status
      )

      # Trigger alerts if unhealthy
      if health_status.status != "healthy" do
        maybe_trigger_alert(updated_service, health_status)
      end

      {:ok, health_status}
    else
      {:error, reason} = error ->
        Logger.error("Health check failed",
          service_instance_id: service_id,
          reason: reason
        )

        # Record failed health check
        record_failed_health_check(service_id, reason)
        error
    end
  end

  def perform(%Oban.Job{args: %{"batch_check" => true} = args}) do
    Logger.info("Starting batch health check")

    limit = args["limit"] || 50

    with {:ok, services} <- get_active_services(limit),
         :ok <- process_batch_health_checks(services, args) do
      Logger.info("Batch health check completed", services_checked: length(services))
      {:ok, %{services_checked: length(services)}}
    else
      error -> error
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("ContainerHealthMonitor received invalid arguments", args: args)
    {:error, :invalid_arguments}
  end

  @doc """
  Enqueue a health check for a specific service instance.
  """
  def enqueue_single_check(service_instance_id, opts \\ []) do
    priority = Keyword.get(opts, :priority, 0)

    args = %{
      "service_instance_id" => service_instance_id,
      "check_type" => Keyword.get(opts, :check_type, "standard"),
      "timeout" => Keyword.get(opts, :timeout, 30),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %{args: args}
    |> new(priority: priority)
    |> Oban.insert()
  end

  @doc """
  Enqueue a batch health check for all active services.
  """
  def enqueue_batch_check(opts \\ []) do
    # Lower priority for batch jobs
    priority = Keyword.get(opts, :priority, 5)

    args = %{
      "batch_check" => true,
      "limit" => Keyword.get(opts, :limit, 100),
      "check_type" => Keyword.get(opts, :check_type, "standard"),
      "timeout" => Keyword.get(opts, :timeout, 30),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %{args: args}
    |> new(priority: priority)
    |> Oban.insert()
  end

  @doc """
  Schedule periodic health checks using Oban cron.
  Add this to your application's Oban config:

  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"*/2 * * * *", Kyozo.Containers.Workers.ContainerHealthMonitor,
        args: %{"batch_check" => true}}
     ]}
  ]
  """
  def schedule_periodic_checks do
    enqueue_batch_check(priority: 5)
  end

  # Private Functions

  defp get_service_instance(service_id) do
    case Containers.get_service_instance(service_id) do
      nil -> {:error, :service_not_found}
      service -> {:ok, service}
    end
  end

  defp get_active_services(limit) do
    # Get services that are running or deploying
    services =
      Containers.list_service_instances(
        filters: %{
          container_status: ["running", "deploying", "starting"]
        },
        limit: limit
      )

    {:ok, services}
  end

  defp check_service_health(service, args) do
    check_type = args["check_type"] || "standard"
    timeout = args["timeout"] || 30

    Logger.debug("Performing health check",
      service_id: service.id,
      check_type: check_type,
      timeout: timeout
    )

    with {:ok, _circuit_status} <- check_circuit_breaker(),
         {:ok, container_status} <- check_container_status(service),
         {:ok, health_endpoint} <- check_health_endpoint(service, timeout),
         {:ok, resource_usage} <- check_resource_usage(service) do
      overall_status =
        determine_overall_health_status(container_status, health_endpoint, resource_usage)

      health_status = %{
        status: overall_status,
        container_status: container_status,
        health_endpoint_status: health_endpoint.status,
        health_endpoint_response_time: health_endpoint.response_time,
        cpu_usage_percent: resource_usage.cpu_percent,
        memory_usage_mb: resource_usage.memory_mb,
        disk_usage_percent: resource_usage.disk_percent,
        network_status: resource_usage.network_status,
        checked_at: DateTime.utc_now(),
        # Will be calculated
        check_duration_ms: 0,
        alerts: []
      }

      {:ok, health_status}
    else
      {:error, :circuit_breaker_open} = error ->
        Logger.warn("Docker API circuit breaker is open, skipping health check",
          service_id: service.id
        )

        error

      {:error, reason} = error ->
        record_circuit_breaker_failure()

        Logger.error("Health check failed",
          service_id: service.id,
          reason: reason
        )

        error
    end
  end

  defp check_circuit_breaker do
    case get_circuit_breaker_state() do
      {:open, last_failure} ->
        if DateTime.diff(DateTime.utc_now(), last_failure, :millisecond) >
             @circuit_breaker_timeout do
          reset_circuit_breaker()
          {:ok, :half_open}
        else
          {:error, :circuit_breaker_open}
        end

      {:closed, _} ->
        {:ok, :closed}

      {:half_open, _} ->
        {:ok, :half_open}
    end
  end

  defp check_container_status(service) do
    # In a real implementation, this would use Docker API
    # For now, simulate based on service attributes
    case service.container_status do
      "running" ->
        # Simulate occasional failures
        if :rand.uniform(100) > 95 do
          {:error, :container_not_responding}
        else
          {:ok, "running"}
        end

      status ->
        {:ok, status}
    end
  rescue
    error ->
      Logger.error("Container status check failed",
        service_id: service.id,
        error: Exception.message(error)
      )

      {:error, :docker_api_error}
  end

  defp check_health_endpoint(service, timeout) do
    # Extract health check configuration
    health_config = service.health_check_config || %{}
    path = health_config["path"] || "/health"
    port = health_config["port"] || get_primary_port(service)

    if should_check_health_endpoint?(service, health_config) do
      perform_health_endpoint_check(service, path, port, timeout)
    else
      {:ok, %{status: "not_configured", response_time: 0}}
    end
  end

  defp perform_health_endpoint_check(service, path, port, timeout) do
    start_time = System.monotonic_time(:millisecond)

    # Simulate HTTP health check
    # In production, this would make actual HTTP requests
    result = simulate_health_endpoint_check(service, path)

    end_time = System.monotonic_time(:millisecond)
    response_time = end_time - start_time

    case result do
      :ok ->
        {:ok, %{status: "healthy", response_time: response_time}}

      :unhealthy ->
        {:ok, %{status: "unhealthy", response_time: response_time}}

      :timeout ->
        {:ok, %{status: "timeout", response_time: timeout * 1000}}

      :error ->
        {:error, :health_endpoint_error}
    end
  rescue
    error ->
      Logger.error("Health endpoint check failed",
        service_id: service.id,
        error: Exception.message(error)
      )

      {:error, :health_endpoint_error}
  end

  defp check_resource_usage(service) do
    # In production, this would query Docker stats API
    # Simulate resource usage data
    cpu_percent = :rand.uniform(100)
    memory_mb = :rand.uniform(1024) + 256
    disk_percent = :rand.uniform(80) + 10

    network_status = if :rand.uniform(100) > 98, do: "degraded", else: "healthy"

    {:ok,
     %{
       cpu_percent: cpu_percent,
       memory_mb: memory_mb,
       disk_percent: disk_percent,
       network_status: network_status
     }}
  rescue
    error ->
      Logger.error("Resource usage check failed",
        service_id: service.id,
        error: Exception.message(error)
      )

      {:error, :resource_check_error}
  end

  defp determine_overall_health_status(container_status, health_endpoint, resource_usage) do
    cond do
      container_status != "running" ->
        "unhealthy"

      health_endpoint.status in ["unhealthy", "timeout"] ->
        "unhealthy"

      resource_usage.cpu_percent > 90 or resource_usage.memory_mb > 2048 ->
        "degraded"

      resource_usage.network_status == "degraded" ->
        "degraded"

      true ->
        "healthy"
    end
  end

  defp update_service_health(service, health_status) do
    updates = %{
      health_status: health_status.status,
      last_health_check_at: health_status.checked_at,
      cpu_usage_percent: health_status.cpu_usage_percent,
      memory_usage_mb: health_status.memory_usage_mb
    }

    case Containers.update_service_instance(service, updates) do
      {:ok, updated_service} ->
        # Successful operation
        reset_circuit_breaker()
        {:ok, updated_service}

      error ->
        error
    end
  end

  defp record_health_check(service, health_status) do
    attrs = %{
      service_instance_id: service.id,
      status: health_status.status,
      response_time_ms: health_status.health_endpoint_response_time,
      cpu_usage_percent: health_status.cpu_usage_percent,
      memory_usage_mb: health_status.memory_usage_mb,
      disk_usage_percent: health_status.disk_usage_percent,
      details: %{
        container_status: health_status.container_status,
        health_endpoint_status: health_status.health_endpoint_status,
        network_status: health_status.network_status,
        check_duration_ms: health_status.check_duration_ms
      },
      checked_at: health_status.checked_at
    }

    Containers.create_health_check(attrs)
  end

  defp record_failed_health_check(service_id, reason) do
    attrs = %{
      service_instance_id: service_id,
      status: "failed",
      error_message: to_string(reason),
      checked_at: DateTime.utc_now(),
      details: %{
        failure_reason: reason,
        worker_error: true
      }
    }

    Containers.create_health_check(attrs)
  end

  defp process_batch_health_checks(services, args) do
    # Process in smaller batches to avoid overwhelming the system
    batch_size = 10

    services
    |> Enum.chunk_every(batch_size)
    |> Enum.each(fn batch ->
      # Process batch with slight delay between checks
      Enum.each(batch, fn service ->
        case check_service_health(service, args) do
          {:ok, health_status} ->
            update_service_health(service, health_status)
            record_health_check(service, health_status)

            if health_status.status != "healthy" do
              maybe_trigger_alert(service, health_status)
            end

          {:error, reason} ->
            record_failed_health_check(service.id, reason)
        end

        # Small delay between checks
        Process.sleep(100)
      end)

      # Longer delay between batches
      Process.sleep(500)
    end)

    :ok
  end

  defp maybe_trigger_alert(service, health_status) do
    # Check if we should send an alert based on:
    # - Service hasn't been healthy for X minutes
    # - Alert frequency limits
    # - Alert escalation rules

    if should_send_alert?(service, health_status) do
      Events.publish_event("service_health_alert", %{
        service_instance_id: service.id,
        service_name: service.name,
        health_status: health_status.status,
        details: %{
          container_status: health_status.container_status,
          cpu_usage: health_status.cpu_usage_percent,
          memory_usage: health_status.memory_usage_mb,
          response_time: health_status.health_endpoint_response_time
        },
        workspace_id: service.workspace_id,
        alert_level: determine_alert_level(health_status),
        timestamp: DateTime.utc_now()
      })

      Logger.warn("Service health alert triggered",
        service_id: service.id,
        status: health_status.status
      )
    end
  end

  # Circuit Breaker Implementation

  defp get_circuit_breaker_state do
    case :ets.lookup(:kyozo_circuit_breakers, @circuit_breaker_key) do
      [{_, state, timestamp, failure_count}] ->
        {state, timestamp, failure_count}

      [] ->
        {:closed, DateTime.utc_now(), 0}
    end
  end

  defp record_circuit_breaker_failure do
    {state, timestamp, failure_count} = get_circuit_breaker_state()
    new_failure_count = failure_count + 1

    if new_failure_count >= @circuit_breaker_threshold do
      :ets.insert(
        :kyozo_circuit_breakers,
        {@circuit_breaker_key, :open, DateTime.utc_now(), new_failure_count}
      )

      Logger.warn("Docker API circuit breaker opened", failures: new_failure_count)
    else
      :ets.insert(
        :kyozo_circuit_breakers,
        {@circuit_breaker_key, state, timestamp, new_failure_count}
      )
    end
  end

  defp reset_circuit_breaker do
    :ets.insert(
      :kyozo_circuit_breakers,
      {@circuit_breaker_key, :closed, DateTime.utc_now(), 0}
    )
  end

  # Helper Functions

  defp should_check_health_endpoint?(service, health_config) do
    service.container_status == "running" and
      health_config["enabled"] != false and
      service.service_type in ["web_app", "api_service"]
  end

  defp get_primary_port(service) do
    case service.port_mappings do
      %{} = mappings when map_size(mappings) > 0 ->
        mappings |> Map.values() |> List.first()

      # default
      _ ->
        "8080"
    end
  end

  defp simulate_health_endpoint_check(_service, _path) do
    # Simulate different health check outcomes
    case :rand.uniform(100) do
      n when n <= 85 -> :ok
      n when n <= 95 -> :unhealthy
      n when n <= 98 -> :timeout
      _ -> :error
    end
  end

  defp should_send_alert?(service, health_status) do
    # Implement alert frequency limiting and escalation logic
    # For now, simple implementation
    health_status.status in ["unhealthy", "degraded"] and
      consecutive_unhealthy_checks(service.id) >= 3
  end

  defp consecutive_unhealthy_checks(service_id) do
    # Query recent health checks to determine consecutive failures
    # Simplified implementation
    recent_checks = Containers.list_health_checks(service_id, limit: 5)

    recent_checks
    |> Enum.take_while(fn check -> check.status != "healthy" end)
    |> length()
  end

  defp determine_alert_level(health_status) do
    case health_status.status do
      "unhealthy" -> "critical"
      "degraded" -> "warning"
      _ -> "info"
    end
  end
end
