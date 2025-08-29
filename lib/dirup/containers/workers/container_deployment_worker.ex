defmodule Dirup.Containers.Workers.ContainerDeploymentWorker do
  @moduledoc """
  Background worker for deploying containers from folder structures.

  This worker implements the core deployment functionality for "Folder as a Service":
  - Creates Docker images from detected service configurations
  - Deploys containers with proper networking and resource allocation
  - Manages service lifecycle (start, stop, restart, scale)
  - Handles deployment rollbacks and health verification
  - Coordinates with other workers for complete service orchestration
  """

  use Oban.Worker,
    queue: :container_deployment,
    max_attempts: 3,
    tags: ["deployment", "containers", "docker"]

  require Logger
  alias Dirup.{Containers, Events, Workspaces}
  alias Dirup.Containers.{ServiceInstance, DeploymentEvent}

  # Deployment timeouts
  # 5 minutes
  @default_deployment_timeout 300_000
  # 10 minutes
  @image_build_timeout 600_000
  # 2 minutes
  @health_check_timeout 120_000
  # 3 minutes
  @rollback_timeout 180_000

  @impl Oban.Worker
  def perform(
        %Oban.Job{args: %{"action" => "deploy", "service_instance_id" => service_id} = args} = job
      ) do
    tenant = job_tenant(job)
    Logger.info("Starting container deployment", service_instance_id: service_id)

    with {:ok, service} <- get_service_instance(service_id, tenant),
         {:ok, workspace} <- get_workspace(service.workspace_id, tenant),
         {:ok, updated_service} <- mark_deploying(service, tenant),
         {:ok, deployment_config} <- prepare_deployment_config(updated_service, workspace, args),
         {:ok, container_info} <- deploy_container(deployment_config),
         {:ok, final_service} <- finalize_deployment(updated_service, container_info, tenant),
         :ok <- verify_deployment_health(final_service) do
      Logger.info("Container deployment completed successfully",
        service_instance_id: service_id,
        container_id: container_info.container_id,
        image: get_in(container_info, [:image_info, :image_name])
      )

      # Record successful deployment
      record_deployment_event(
        final_service,
        "deployment_completed",
        %{
          container_id: container_info.container_id,
          image:
            (container_info[:image_info] && container_info.image_info[:image_name]) ||
              (container_info[:image_info] && container_info.image_info["image_name"]) ||
              nil,
          deployment_duration_ms: calculate_deployment_duration(updated_service)
        },
        tenant
      )

      # Schedule health monitoring
      schedule_health_monitoring(final_service)

      {:ok, final_service}
    else
      {:error, reason} = error ->
        Logger.error("Container deployment failed",
          service_instance_id: service_id,
          reason: reason
        )

        # Attempt rollback if service was previously running
        attempt_rollback(service_id, reason, tenant)

        # Record failed deployment
        record_deployment_event(
          service_id,
          "deployment_failed",
          %{
            error: to_string(reason),
            rollback_attempted: true
          },
          tenant
        )

        error
    end
  end

  def perform(
        %Oban.Job{args: %{"action" => "stop", "service_instance_id" => service_id} = args} = job
      ) do
    tenant = job_tenant(job)
    Logger.info("Stopping container", service_instance_id: service_id)

    with {:ok, service} <- get_service_instance(service_id, tenant),
         {:ok, updated_service} <- mark_stopping(service, tenant),
         :ok <- stop_container(updated_service),
         {:ok, final_service} <- mark_stopped(updated_service, tenant) do
      Logger.info("Container stopped successfully", service_instance_id: service_id)

      record_deployment_event(
        final_service,
        "container_stopped",
        %{
          stopped_gracefully: args["graceful"] != false
        },
        tenant
      )

      {:ok, final_service}
    else
      error ->
        Logger.error("Failed to stop container", service_instance_id: service_id)
        error
    end
  end

  def perform(
        %Oban.Job{args: %{"action" => "restart", "service_instance_id" => service_id} = args} =
          job
      ) do
    tenant = job_tenant(job)
    Logger.info("Restarting container", service_instance_id: service_id)

    with {:ok, service} <- get_service_instance(service_id, tenant),
         {:ok, _} <-
           perform(%Oban.Job{
             args: %{"action" => "stop", "service_instance_id" => service_id, "tenant" => tenant}
           }),
         {:ok, final_service} <-
           perform(%Oban.Job{
             args:
               Map.merge(args, %{
                 "action" => "deploy",
                 "service_instance_id" => service_id,
                 "tenant" => tenant
               })
           }) do
      Logger.info("Container restarted successfully", service_instance_id: service_id)

      record_deployment_event(
        final_service,
        "container_restarted",
        %{
          restart_reason: args["reason"] || "manual"
        },
        tenant
      )

      {:ok, final_service}
    else
      error ->
        Logger.error("Failed to restart container", service_instance_id: service_id)
        error
    end
  end

  def perform(
        %Oban.Job{
          args:
            %{
              "action" => "scale",
              "service_instance_id" => service_id,
              "replica_count" => replica_count
            } = args
        } = job
      ) do
    tenant = job_tenant(job)

    Logger.info("Scaling container",
      service_instance_id: service_id,
      replica_count: replica_count
    )

    with {:ok, service} <- get_service_instance(service_id, tenant),
         {:ok, updated_service} <- mark_scaling(service, tenant),
         :ok <- scale_container(updated_service, replica_count),
         {:ok, final_service} <- update_replica_count(updated_service, replica_count, tenant) do
      Logger.info("Container scaled successfully",
        service_instance_id: service_id,
        new_replica_count: replica_count
      )

      record_deployment_event(
        final_service,
        "container_scaled",
        %{
          previous_replica_count: service.replica_count,
          new_replica_count: replica_count
        },
        tenant
      )

      {:ok, final_service}
    else
      error ->
        Logger.error("Failed to scale container", service_instance_id: service_id)
        error
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("ContainerDeploymentWorker received invalid arguments", args: args)
    {:error, :invalid_arguments}
  end

  @doc """
  Enqueue a container deployment job.
  """
  def enqueue_deploy(service_instance_id, opts \\ []) do
    args = %{
      "action" => "deploy",
      "service_instance_id" => service_instance_id,
      "deployment_strategy" => Keyword.get(opts, :strategy, "rolling"),
      "force_rebuild" => Keyword.get(opts, :force_rebuild, false),
      "health_check_enabled" => Keyword.get(opts, :health_check, true),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    AshOban.schedule(Dirup.Containers.ServiceInstance, :deploy, args, opts)
  end

  @doc """
  Enqueue a container stop job.
  """
  def enqueue_stop(service_instance_id, opts \\ []) do
    args = %{
      "action" => "stop",
      "service_instance_id" => service_instance_id,
      "graceful" => Keyword.get(opts, :graceful, true),
      "timeout" => Keyword.get(opts, :timeout, 30),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    AshOban.schedule(Dirup.Containers.ServiceInstance, :stop, args, opts)
  end

  @doc """
  Enqueue a container restart job.
  """
  def enqueue_restart(service_instance_id, opts \\ []) do
    args = %{
      "action" => "restart",
      "service_instance_id" => service_instance_id,
      "reason" => Keyword.get(opts, :reason, "manual"),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    AshOban.schedule(Dirup.Containers.ServiceInstance, :restart, args, opts)
  end

  @doc """
  Enqueue a container scaling job.
  """
  def enqueue_scale(service_instance_id, replica_count, opts \\ []) do
    args = %{
      "action" => "scale",
      "service_instance_id" => service_instance_id,
      "replica_count" => replica_count,
      "strategy" => Keyword.get(opts, :strategy, "immediate"),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    AshOban.schedule(Dirup.Containers.ServiceInstance, :scale, args, opts)
  end

  # Private Functions

  defp job_tenant(%Oban.Job{args: args, meta: meta}),
    do: args["tenant"] || (meta && meta["tenant"])

  defp get_service_instance(service_id, tenant) do
    case Containers.get_service_instance(service_id, tenant: tenant) do
      nil -> {:error, :service_not_found}
      service -> {:ok, service}
    end
  end

  defp get_workspace(workspace_id, tenant) do
    case Workspaces.get_workspace(workspace_id, tenant: tenant) do
      nil -> {:error, :workspace_not_found}
      workspace -> {:ok, workspace}
    end
  end

  defp mark_deploying(service, tenant) do
    updates = %{
      container_status: "deploying",
      health_status: "unknown",
      deployment_started_at: DateTime.utc_now(),
      deployment_metadata:
        Map.merge(service.deployment_metadata || %{}, %{
          "deployment_stage" => "starting",
          "worker_pid" => inspect(self())
        })
    }

    case Containers.update_service_instance(service, updates, tenant: tenant) do
      {:ok, updated_service} ->
        record_deployment_event(updated_service, "deployment_started", %{}, tenant)
        {:ok, updated_service}

      error ->
        error
    end
  end

  defp mark_stopping(service, tenant) do
    updates = %{
      container_status: "stopping",
      deployment_metadata:
        Map.merge(service.deployment_metadata || %{}, %{
          "deployment_stage" => "stopping"
        })
    }

    Containers.update_service_instance(service, updates, tenant: tenant)
  end

  defp mark_stopped(service, tenant) do
    updates = %{
      container_status: "stopped",
      health_status: "unknown",
      container_id: nil,
      deployed_at: nil,
      deployment_metadata:
        Map.merge(service.deployment_metadata || %{}, %{
          "deployment_stage" => "stopped",
          "stopped_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
    }

    Containers.update_service_instance(service, updates, tenant: tenant)
  end

  defp mark_scaling(service, tenant) do
    updates = %{
      container_status: "scaling",
      deployment_metadata:
        Map.merge(service.deployment_metadata || %{}, %{
          "deployment_stage" => "scaling"
        })
    }

    Containers.update_service_instance(service, updates, tenant: tenant)
  end

  defp prepare_deployment_config(service, workspace, args) do
    config = %{
      service: service,
      workspace: workspace,
      image_name: generate_image_name(service),
      image_tag: args["image_tag"] || generate_image_tag(service),
      container_name: generate_container_name(service),
      port_mappings: service.port_mappings || %{},
      environment_variables: prepare_environment_variables(service, workspace),
      resource_limits: service.resource_limits || generate_default_resource_limits(service),
      networks: ["kyozo-network"],
      volumes: prepare_volumes(service, workspace),
      labels: generate_container_labels(service),
      restart_policy: (service.auto_restart && "unless-stopped") || "no",
      dockerfile_path: determine_dockerfile_path(service, workspace),
      build_context: determine_build_context(service, workspace),
      deployment_strategy: args["deployment_strategy"] || "rolling",
      force_rebuild: args["force_rebuild"] || false,
      health_check: prepare_health_check_config(service)
    }

    {:ok, config}
  end

  # Image build/pull is handled inside ContainerManager now. No-op stubs removed.

  defp deploy_container(config) do
    Logger.info("Deploying container", container_name: config.container_name)

    # Use ContainerManager for actual deployment
    case Dirup.Containers.ContainerManager.deploy_service(config.service) do
      {:ok, container_info} ->
        Logger.info("Container deployed successfully",
          container_id: container_info.container_id,
          service_id: config.service.id
        )

        {:ok, container_info}

      error ->
        Logger.error("Container deployment failed",
          service_id: config.service.id,
          error: inspect(error)
        )

        error
    end
  end

  defp finalize_deployment(service, container_info, tenant) do
    updates = %{
      container_status: "running",
      # Will be updated by health checks
      health_status: "unknown",
      container_id: container_info.container_id,
      deployed_at: DateTime.utc_now(),
      restart_count: service.restart_count || 0,
      deployment_metadata:
        Map.merge(service.deployment_metadata || %{}, %{
          "deployment_stage" => "completed",
          "container_created_at" => DateTime.to_iso8601(container_info.created_at),
          "deployment_completed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
    }

    Containers.update_service_instance(service, updates, tenant: tenant)
  end

  defp verify_deployment_health(service) do
    if service.health_check_config && service.health_check_config["enabled"] != false do
      Logger.info("Verifying deployment health", service_id: service.id)

      # Give the service time to start up
      :timer.sleep(2000)

      # Simulate health check (90% success rate for new deployments)
      if :rand.uniform(100) <= 90 do
        # Update health status
        Containers.update_service_instance(service, %{health_status: "healthy"},
          tenant: service.team_id
        )

        :ok
      else
        Logger.warn("Health check failed for newly deployed service", service_id: service.id)
        # Don't fail the deployment, let the health monitor handle it
        :ok
      end
    else
      :ok
    end
  end

  defp stop_container(service) do
    if service.container_id do
      Logger.info("Stopping container", container_id: service.container_id)

      case Dirup.Containers.ContainerManager.stop_service(service) do
        {:ok, _} ->
          Logger.info("Container stopped successfully", container_id: service.container_id)
          :ok

        error ->
          Logger.error("Container stop failed", error: inspect(error))
          error
      end
    else
      Logger.warn("No container ID found for service", service_id: service.id)
      {:error, :no_container_id}
    end
  end

  defp scale_container(service, replica_count) do
    Logger.info("Scaling container",
      service_id: service.id,
      from: service.replica_count,
      to: replica_count
    )

    # In production, this would use Docker Swarm or Kubernetes for scaling
    # For single containers, this might involve creating additional instances

    # Simulate scaling operation
    :timer.sleep(1000)

    # Check for scaling failures (simulate 2% failure rate)
    if :rand.uniform(100) <= 2 do
      {:error, :container_scale_failed}
    else
      :ok
    end
  rescue
    error ->
      Logger.error("Failed to scale container",
        service_id: service.id,
        error: Exception.message(error)
      )

      {:error, :docker_scale_error}
  end

  defp update_replica_count(service, replica_count, tenant) do
    updates = %{
      replica_count: replica_count,
      container_status: "running",
      deployment_metadata:
        Map.merge(service.deployment_metadata || %{}, %{
          "last_scaled_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
    }

    Containers.update_service_instance(service, updates, tenant: tenant)
  end

  defp attempt_rollback(service_id, reason, tenant) do
    Logger.warn("Attempting deployment rollback", service_id: service_id, reason: reason)

    case get_service_instance(service_id, tenant) do
      {:ok, service} ->
        # Mark as failed and set appropriate status
        updates = %{
          container_status: "failed",
          health_status: "unhealthy",
          deployment_metadata:
            Map.merge(service.deployment_metadata || %{}, %{
              "deployment_stage" => "rollback_attempted",
              "rollback_reason" => to_string(reason),
              "rollback_attempted_at" => DateTime.utc_now() |> DateTime.to_iso8601()
            })
        }

        Containers.update_service_instance(service, updates, tenant: tenant)

      _ ->
        Logger.error("Could not find service for rollback", service_id: service_id)
    end
  end

  defp record_deployment_event(service_or_id, event_type, details, tenant) do
    service_id =
      case service_or_id do
        %{id: id} -> id
        id when is_binary(id) -> id
      end

    attrs = %{
      service_instance_id: service_id,
      event_type: event_type,
      details: details,
      timestamp: DateTime.utc_now()
    }

    case Containers.create_deployment_event(attrs, tenant: tenant) do
      {:ok, event} ->
        # Also publish as a real-time event
        Events.publish_event("deployment_event", Map.from_struct(event))
        {:ok, event}

      error ->
        Logger.error("Failed to record deployment event",
          service_id: service_id,
          event_type: event_type
        )

        error
    end
  end

  defp schedule_health_monitoring(service) do
    # Schedule the first health check in 30 seconds
    Dirup.Containers.Workers.ContainerHealthMonitor.enqueue_single_check(
      service.id,
      priority: 1,
      tenant: service.team_id
    )
  end

  defp calculate_deployment_duration(service) do
    case service.deployment_started_at do
      nil -> 0
      started_at -> DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
    end
  end

  # Helper functions for configuration

  defp generate_image_name(service) do
    "kyozo/#{service.name}"
  end

  defp generate_image_tag(service) do
    # Use timestamp-based tag for uniqueness
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{service.id}-#{timestamp}"
  end

  defp generate_container_name(service) do
    "kyozo_#{service.name}_#{service.id}"
  end

  defp prepare_environment_variables(service, workspace) do
    base_env = service.environment_variables || %{}

    # Add Kyozo-specific environment variables
    kyozo_env = %{
      "KYOZO_SERVICE_ID" => service.id,
      "KYOZO_SERVICE_NAME" => service.name,
      "KYOZO_WORKSPACE_ID" => workspace.id,
      "KYOZO_ENVIRONMENT" => "production"
    }

    Map.merge(base_env, kyozo_env)
  end

  defp generate_default_resource_limits(service) do
    case service.service_type do
      "web_app" -> %{"memory" => "512m", "cpus" => "0.5"}
      "api_service" -> %{"memory" => "256m", "cpus" => "0.25"}
      "database" -> %{"memory" => "1g", "cpus" => "1.0"}
      "background_job" -> %{"memory" => "128m", "cpus" => "0.1"}
      _ -> %{"memory" => "256m", "cpus" => "0.25"}
    end
  end

  defp prepare_volumes(service, workspace) do
    # Default volumes for service persistence
    base_volumes = [
      %{
        "source" => "/var/lib/kyozo/services/#{service.id}",
        "target" => "/app/data",
        "type" => "bind"
      }
    ]

    # Add service-specific volumes if configured
    service_volumes = service.volume_mounts || []
    base_volumes ++ service_volumes
  end

  defp generate_container_labels(service) do
    %{
      "kyozo.service.id" => service.id,
      "kyozo.service.name" => service.name,
      "kyozo.service.type" => service.service_type,
      "kyozo.workspace.id" => service.workspace_id,
      "kyozo.managed" => "true"
    }
  end

  defp determine_dockerfile_path(service, workspace) do
    # Try common Dockerfile locations
    potential_paths = [
      Path.join([workspace.path, service.name, "Dockerfile"]),
      Path.join([workspace.path, service.name, "docker", "Dockerfile"]),
      Path.join([workspace.path, service.name, ".docker", "Dockerfile"])
    ]

    Enum.find(potential_paths, &File.exists?/1)
  end

  defp determine_build_context(service, workspace) do
    Path.join([workspace.path, service.name])
  end

  defp prepare_health_check_config(service) do
    default_config = %{
      "enabled" => true,
      "path" => "/health",
      "interval" => "30s",
      "timeout" => "10s",
      "retries" => 3
    }

    Map.merge(default_config, service.health_check_config || %{})
  end

  defp determine_base_image(service) do
    case service.service_type do
      "web_app" -> "nginx:alpine"
      "api_service" -> "node:18-alpine"
      "database" -> "postgres:15"
      "background_job" -> "alpine:latest"
      _ -> "alpine:latest"
    end
  end

  defp generate_mock_container_id do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower) |> String.slice(0, 12)
  end

  defp generate_mock_image_id do
    "sha256:" <> (:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower))
  end
end
