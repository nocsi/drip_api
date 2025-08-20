defmodule Kyozo.Containers.Workers.MetricsCollector do
  @moduledoc """
  Background worker for collecting container performance metrics and system statistics.

  This worker:
  - Collects CPU, memory, disk, and network metrics from running containers
  - Aggregates metrics for workspace-level and system-level reporting
  - Stores time-series data for performance analysis
  - Triggers alerts for resource threshold violations
  - Provides data for the metrics dashboard and capacity planning
  """

  use Oban.Worker,
    queue: :metrics_collection,
    max_attempts: 3,
    tags: ["metrics", "monitoring", "performance"]

  require Logger
  alias Kyozo.{Containers, Events}
  alias Kyozo.Containers.ServiceMetric

  # Metric collection intervals
  @default_collection_interval 30_000  # 30 seconds
  @high_frequency_interval 10_000      # 10 seconds for critical services
  @batch_size 20                       # Process metrics in batches

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"service_instance_id" => service_id} = args}) do
    Logger.debug("Collecting metrics for service", service_instance_id: service_id)

    with {:ok, service} <- get_service_instance(service_id),
         {:ok, metrics} <- collect_service_metrics(service, args),
         {:ok, _metric_record} <- store_metrics(service, metrics),
         :ok <- check_metric_thresholds(service, metrics) do

      Logger.debug("Metrics collected successfully",
        service_instance_id: service_id,
        cpu_usage: metrics.cpu_usage_percent,
        memory_usage: metrics.memory_usage_mb
      )

      {:ok, metrics}
    else
      {:error, reason} = error ->
        Logger.error("Metrics collection failed",
          service_instance_id: service_id,
          reason: reason
        )
        error
    end
  end

  def perform(%Oban.Job{args: %{"batch_collection" => true} = args}) do
    Logger.info("Starting batch metrics collection")

    limit = args["limit"] || @batch_size
    collection_type = args["collection_type"] || "standard"

    with {:ok, services} <- get_services_for_metrics_collection(limit, collection_type),
         :ok <- process_batch_metrics_collection(services, args),
         {:ok, aggregated} <- aggregate_system_metrics(services) do

      Logger.info("Batch metrics collection completed",
        services_processed: length(services),
        system_cpu_avg: aggregated.avg_cpu_usage,
        system_memory_total: aggregated.total_memory_usage
      )

      {:ok, %{services_processed: length(services), aggregated_metrics: aggregated}}
    else
      error -> error
    end
  end

  def perform(%Oban.Job{args: %{"cleanup_old_metrics" => true} = args}) do
    Logger.info("Starting metrics cleanup")

    retention_days = args["retention_days"] || 30
    batch_size = args["batch_size"] || 1000

    with {:ok, cleanup_result} <- cleanup_old_metrics(retention_days, batch_size) do
      Logger.info("Metrics cleanup completed",
        records_deleted: cleanup_result.deleted_count,
        retention_days: retention_days
      )

      {:ok, cleanup_result}
    else
      error -> error
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("MetricsCollector received invalid arguments", args: args)
    {:error, :invalid_arguments}
  end

  @doc """
  Enqueue metrics collection for a specific service instance.
  """
  def enqueue_service_metrics(service_instance_id, opts \\ []) do
    priority = Keyword.get(opts, :priority, 3)
    collection_type = Keyword.get(opts, :collection_type, "standard")

    args = %{
      "service_instance_id" => service_instance_id,
      "collection_type" => collection_type,
      "include_detailed_stats" => Keyword.get(opts, :detailed, false),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %{args: args}
    |> new(priority: priority)
    |> Oban.insert()
  end

  @doc """
  Enqueue batch metrics collection for all active services.
  """
  def enqueue_batch_collection(opts \\ []) do
    priority = Keyword.get(opts, :priority, 5)
    collection_type = Keyword.get(opts, :collection_type, "standard")

    args = %{
      "batch_collection" => true,
      "limit" => Keyword.get(opts, :limit, @batch_size),
      "collection_type" => collection_type,
      "include_system_metrics" => Keyword.get(opts, :system_metrics, true),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %{args: args}
    |> new(priority: priority)
    |> Oban.insert()
  end

  @doc """
  Schedule periodic metrics cleanup.
  """
  def enqueue_metrics_cleanup(opts \\ []) do
    priority = Keyword.get(opts, :priority, 8)

    args = %{
      "cleanup_old_metrics" => true,
      "retention_days" => Keyword.get(opts, :retention_days, 30),
      "batch_size" => Keyword.get(opts, :batch_size, 1000),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %{args: args}
    |> new(priority: priority)
    |> Oban.insert()
  end

  # Private Functions

  defp get_service_instance(service_id) do
    case Containers.get_service_instance(service_id) do
      nil -> {:error, :service_not_found}
      service -> {:ok, service}
    end
  end

  defp get_services_for_metrics_collection(limit, collection_type) do
    filters = case collection_type do
      "high_frequency" ->
        %{container_status: ["running"], service_type: ["web_app", "api_service"]}
      "critical_only" ->
        %{container_status: ["running"], health_status: ["unhealthy", "degraded"]}
      _ ->
        %{container_status: ["running"]}
    end

    services = Containers.list_service_instances(filters: filters, limit: limit)
    {:ok, services}
  end

  defp collect_service_metrics(service, args) do
    collection_type = args["collection_type"] || "standard"
    include_detailed = args["include_detailed_stats"] || false

    Logger.debug("Collecting metrics",
      service_id: service.id,
      type: collection_type,
      detailed: include_detailed
    )

    with {:ok, container_stats} <- get_container_stats(service),
         {:ok, resource_metrics} <- calculate_resource_metrics(container_stats),
         {:ok, performance_metrics} <- collect_performance_metrics(service, include_detailed),
         {:ok, network_metrics} <- collect_network_metrics(service) do

      metrics = %{
        service_instance_id: service.id,
        collected_at: DateTime.utc_now(),
        cpu_usage_percent: resource_metrics.cpu_usage_percent,
        memory_usage_mb: resource_metrics.memory_usage_mb,
        memory_limit_mb: resource_metrics.memory_limit_mb,
        disk_usage_mb: resource_metrics.disk_usage_mb,
        disk_io_read_mb: resource_metrics.disk_io_read_mb,
        disk_io_write_mb: resource_metrics.disk_io_write_mb,
        network_rx_mb: network_metrics.rx_mb,
        network_tx_mb: network_metrics.tx_mb,
        network_connections: network_metrics.connections,
        requests_per_second: performance_metrics.requests_per_second,
        response_time_avg_ms: performance_metrics.response_time_avg_ms,
        error_rate_percent: performance_metrics.error_rate_percent,
        uptime_seconds: performance_metrics.uptime_seconds,
        restart_count: performance_metrics.restart_count,
        health_score: calculate_health_score(resource_metrics, performance_metrics),
        collection_metadata: %{
          collection_type: collection_type,
          detailed: include_detailed,
          collection_duration_ms: 0  # Will be calculated
        }
      }

      {:ok, metrics}
    else
      {:error, :container_not_found} ->
        # Service might have been stopped
        create_offline_metrics(service)

      error -> error
    end
  end

  defp get_container_stats(service) do
    # In production, this would call Docker stats API
    # For now, simulate realistic container statistics

    case service.container_status do
      "running" ->
        simulate_container_stats(service)

      _ ->
        {:error, :container_not_found}
    end
  rescue
    error ->
      Logger.error("Failed to get container stats",
        service_id: service.id,
        error: Exception.message(error)
      )
      {:error, :docker_api_error}
  end

  defp simulate_container_stats(service) do
    # Simulate realistic Docker stats based on service type
    base_cpu = case service.service_type do
      "web_app" -> 15 + :rand.uniform(30)
      "api_service" -> 25 + :rand.uniform(40)
      "database" -> 20 + :rand.uniform(50)
      "background_job" -> 10 + :rand.uniform(20)
      _ -> 5 + :rand.uniform(25)
    end

    base_memory = case service.service_type do
      "web_app" -> 128 + :rand.uniform(256)
      "api_service" -> 256 + :rand.uniform(512)
      "database" -> 512 + :rand.uniform(1024)
      "background_job" -> 64 + :rand.uniform(128)
      _ -> 32 + :rand.uniform(128)
    end

    stats = %{
      cpu_usage_percent: Float.round(base_cpu + (:rand.uniform() - 0.5) * 10, 2),
      memory_usage_bytes: trunc(base_memory * 1024 * 1024),
      memory_limit_bytes: trunc(base_memory * 2 * 1024 * 1024),
      disk_read_bytes: :rand.uniform(100) * 1024 * 1024,
      disk_write_bytes: :rand.uniform(50) * 1024 * 1024,
      network_rx_bytes: :rand.uniform(200) * 1024,
      network_tx_bytes: :rand.uniform(150) * 1024,
      network_connections: :rand.uniform(100) + 5
    }

    {:ok, stats}
  end

  defp calculate_resource_metrics(stats) do
    metrics = %{
      cpu_usage_percent: stats.cpu_usage_percent,
      memory_usage_mb: Float.round(stats.memory_usage_bytes / (1024 * 1024), 2),
      memory_limit_mb: Float.round(stats.memory_limit_bytes / (1024 * 1024), 2),
      disk_usage_mb: Float.round((stats.disk_read_bytes + stats.disk_write_bytes) / (1024 * 1024), 2),
      disk_io_read_mb: Float.round(stats.disk_read_bytes / (1024 * 1024), 2),
      disk_io_write_mb: Float.round(stats.disk_write_bytes / (1024 * 1024), 2)
    }

    {:ok, metrics}
  end

  defp collect_performance_metrics(service, include_detailed) do
    # Simulate application-level performance metrics
    base_rps = case service.service_type do
      "web_app" -> 50 + :rand.uniform(200)
      "api_service" -> 100 + :rand.uniform(500)
      _ -> 0
    end

    base_response_time = case service.service_type do
      "web_app" -> 100 + :rand.uniform(200)
      "api_service" -> 50 + :rand.uniform(150)
      _ -> 0
    end

    metrics = %{
      requests_per_second: if(base_rps > 0, do: Float.round(base_rps * :rand.uniform(), 2), else: 0),
      response_time_avg_ms: if(base_response_time > 0, do: Float.round(base_response_time * (0.8 + :rand.uniform() * 0.4), 2), else: 0),
      error_rate_percent: Float.round(:rand.uniform() * 2, 3),
      uptime_seconds: calculate_uptime_seconds(service),
      restart_count: service.restart_count || 0
    }

    enhanced_metrics = if include_detailed do
      Map.merge(metrics, %{
        p95_response_time_ms: metrics.response_time_avg_ms * 1.5,
        p99_response_time_ms: metrics.response_time_avg_ms * 2.2,
        concurrent_connections: :rand.uniform(50) + 10,
        queue_length: :rand.uniform(10),
        cache_hit_rate_percent: 85 + :rand.uniform(10)
      })
    else
      metrics
    end

    {:ok, enhanced_metrics}
  end

  defp collect_network_metrics(service) do
    # Get network statistics from container
    stats = %{
      rx_mb: Float.round(:rand.uniform(100) * 0.1, 3),
      tx_mb: Float.round(:rand.uniform(80) * 0.1, 3),
      connections: :rand.uniform(50) + 5
    }

    {:ok, stats}
  end

  defp calculate_health_score(resource_metrics, performance_metrics) do
    # Calculate composite health score based on various factors
    cpu_score = max(0, 100 - resource_metrics.cpu_usage_percent)
    memory_score = max(0, 100 - (resource_metrics.memory_usage_mb / resource_metrics.memory_limit_mb * 100))
    error_score = max(0, 100 - performance_metrics.error_rate_percent * 10)

    # Response time penalty (assuming 200ms is baseline good)
    response_penalty = if performance_metrics.response_time_avg_ms > 200 do
      min(30, (performance_metrics.response_time_avg_ms - 200) / 10)
    else
      0
    end

    response_score = max(0, 100 - response_penalty)

    # Weighted average
    overall_score = (cpu_score * 0.3 + memory_score * 0.3 + error_score * 0.2 + response_score * 0.2)
    Float.round(overall_score, 2)
  end

  defp store_metrics(service, metrics) do
    attrs = %{
      service_instance_id: service.id,
      workspace_id: service.workspace_id,
      collected_at: metrics.collected_at,
      cpu_usage_percent: metrics.cpu_usage_percent,
      memory_usage_mb: metrics.memory_usage_mb,
      memory_limit_mb: metrics.memory_limit_mb,
      disk_usage_mb: metrics.disk_usage_mb,
      disk_io_read_mb: metrics.disk_io_read_mb,
      disk_io_write_mb: metrics.disk_io_write_mb,
      network_rx_mb: metrics.network_rx_mb,
      network_tx_mb: metrics.network_tx_mb,
      network_connections: metrics.network_connections,
      requests_per_second: metrics.requests_per_second,
      response_time_avg_ms: metrics.response_time_avg_ms,
      error_rate_percent: metrics.error_rate_percent,
      health_score: metrics.health_score,
      metadata: metrics.collection_metadata
    }

    Containers.create_service_metric(attrs)
  end

  defp check_metric_thresholds(service, metrics) do
    alerts = []

    # CPU threshold check
    alerts = if metrics.cpu_usage_percent > 90 do
      [create_threshold_alert("cpu_high", service, metrics.cpu_usage_percent, 90) | alerts]
    else
      alerts
    end

    # Memory threshold check
    memory_usage_percent = (metrics.memory_usage_mb / metrics.memory_limit_mb) * 100
    alerts = if memory_usage_percent > 85 do
      [create_threshold_alert("memory_high", service, memory_usage_percent, 85) | alerts]
    else
      alerts
    end

    # Error rate threshold check
    alerts = if metrics.error_rate_percent > 5 do
      [create_threshold_alert("error_rate_high", service, metrics.error_rate_percent, 5) | alerts]
    else
      alerts
    end

    # Response time threshold check
    alerts = if metrics.response_time_avg_ms > 1000 do
      [create_threshold_alert("response_time_high", service, metrics.response_time_avg_ms, 1000) | alerts]
    else
      alerts
    end

    # Publish alerts if any
    Enum.each(alerts, fn alert ->
      Events.publish_event("metric_threshold_violation", alert)
    end)

    :ok
  end

  defp create_threshold_alert(type, service, current_value, threshold) do
    %{
      alert_type: type,
      service_instance_id: service.id,
      service_name: service.name,
      workspace_id: service.workspace_id,
      current_value: current_value,
      threshold_value: threshold,
      severity: determine_alert_severity(type, current_value, threshold),
      timestamp: DateTime.utc_now(),
      message: format_alert_message(type, service.name, current_value, threshold)
    }
  end

  defp process_batch_metrics_collection(services, args) do
    # Process in smaller chunks to avoid overwhelming the system
    chunk_size = 5

    services
    |> Enum.chunk_every(chunk_size)
    |> Enum.each(fn chunk ->
      # Process chunk with concurrent tasks
      chunk
      |> Enum.map(fn service ->
        Task.async(fn ->
          case collect_service_metrics(service, args) do
            {:ok, metrics} ->
              store_metrics(service, metrics)
              check_metric_thresholds(service, metrics)
              {:ok, service.id}

            {:error, reason} ->
              Logger.warn("Failed to collect metrics for service",
                service_id: service.id,
                reason: reason
              )
              {:error, reason}
          end
        end)
      end)
      |> Enum.map(&Task.await(&1, 10_000))

      # Brief pause between chunks
      Process.sleep(200)
    end)

    :ok
  end

  defp aggregate_system_metrics(services) do
    # Calculate system-wide aggregations
    total_services = length(services)
    running_services = Enum.count(services, &(&1.container_status == "running"))

    # Get recent metrics for aggregation
    recent_metrics = get_recent_metrics_for_aggregation(services)

    aggregated = %{
      total_services: total_services,
      running_services: running_services,
      avg_cpu_usage: calculate_average_metric(recent_metrics, :cpu_usage_percent),
      total_memory_usage: calculate_total_metric(recent_metrics, :memory_usage_mb),
      avg_response_time: calculate_average_metric(recent_metrics, :response_time_avg_ms),
      total_requests_per_second: calculate_total_metric(recent_metrics, :requests_per_second),
      avg_health_score: calculate_average_metric(recent_metrics, :health_score),
      aggregated_at: DateTime.utc_now()
    }

    # Store system-level metrics
    store_system_metrics(aggregated)

    {:ok, aggregated}
  end

  defp cleanup_old_metrics(retention_days, batch_size) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-retention_days, :day)

    deleted_count = Containers.delete_old_service_metrics(cutoff_date, batch_size)

    {:ok, %{deleted_count: deleted_count, cutoff_date: cutoff_date}}
  end

  defp create_offline_metrics(service) do
    metrics = %{
      service_instance_id: service.id,
      collected_at: DateTime.utc_now(),
      cpu_usage_percent: 0,
      memory_usage_mb: 0,
      memory_limit_mb: 0,
      disk_usage_mb: 0,
      disk_io_read_mb: 0,
      disk_io_write_mb: 0,
      network_rx_mb: 0,
      network_tx_mb: 0,
      network_connections: 0,
      requests_per_second: 0,
      response_time_avg_ms: 0,
      error_rate_percent: 0,
      uptime_seconds: 0,
      restart_count: service.restart_count || 0,
      health_score: 0,
      collection_metadata: %{
        collection_type: "offline",
        reason: "container_not_running"
      }
    }

    {:ok, metrics}
  end

  # Helper functions

  defp calculate_uptime_seconds(service) do
    case service.deployed_at do
      nil -> 0
      deployed_at -> DateTime.diff(DateTime.utc_now(), deployed_at, :second)
    end
  end

  defp determine_alert_severity(type, current_value, threshold) do
    ratio = current_value / threshold

    cond do
      ratio >= 2.0 -> "critical"
      ratio >= 1.5 -> "high"
      ratio >= 1.2 -> "medium"
      true -> "low"
    end
  end

  defp format_alert_message(type, service_name, current_value, threshold) do
    case type do
      "cpu_high" ->
        "Service #{service_name} CPU usage is #{current_value}% (threshold: #{threshold}%)"
      "memory_high" ->
        "Service #{service_name} memory usage is #{current_value}% (threshold: #{threshold}%)"
      "error_rate_high" ->
        "Service #{service_name} error rate is #{current_value}% (threshold: #{threshold}%)"
      "response_time_high" ->
        "Service #{service_name} response time is #{current_value}ms (threshold: #{threshold}ms)"
      _ ->
        "Service #{service_name} metric threshold violated: #{current_value} > #{threshold}"
    end
  end

  defp get_recent_metrics_for_aggregation(services) do
    # Get most recent metrics for each service
    service_ids = Enum.map(services, & &1.id)
    Containers.get_latest_metrics_for_services(service_ids)
  end

  defp calculate_average_metric(metrics, field) do
    if length(metrics) > 0 do
      total = Enum.reduce(metrics, 0, fn metric, acc ->
        Map.get(metric, field, 0) + acc
      end)
      Float.round(total / length(metrics), 2)
    else
      0
    end
  end

  defp calculate_total_metric(metrics, field) do
    Enum.reduce(metrics, 0, fn metric, acc ->
      Map.get(metric, field, 0) + acc
    end)
  end

  defp store_system_metrics(aggregated) do
    # Store system-wide metrics for capacity planning and dashboards
    # This could be in a separate table or time-series database
    Events.publish_event("system_metrics_collected", aggregated)
  end
end
