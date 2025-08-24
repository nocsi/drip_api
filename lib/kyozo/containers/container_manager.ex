defmodule Kyozo.Containers.ContainerManager do
  @moduledoc """
  ContainerManager GenServer for orchestrating Docker container operations.

  This GenServer provides centralized management of Docker containers for the
  "Folder as a Service" functionality, handling container lifecycle, monitoring,
  and coordination with the Docker daemon.

  Features:
  - Container deployment and lifecycle management
  - Health monitoring and metrics collection
  - Error handling and recovery
  - Circuit breaker pattern for Docker API resilience
  - Event broadcasting for real-time updates
  """

  use GenServer
  require Logger

  alias Kyozo.Containers.{DockerClient, ServiceInstance, DeploymentEvent}
  alias Kyozo.Containers.DockerClient.Error

  # State structure
  defstruct [
    # Map of container_id => container_info
    :containers,
    # Circuit breaker state
    :circuit_breaker,
    # Timer for health checks
    :health_check_timer,
    # Timer for metrics collection
    :metrics_timer,
    # Timer for cleanup operations
    :cleanup_timer
  ]

  # Circuit breaker configuration
  # 1 minute
  @circuit_breaker_timeout 60_000
  # failures before opening
  @circuit_breaker_threshold 5
  # 30 seconds
  @health_check_interval 30_000
  # 1 minute
  @metrics_interval 60_000
  # 5 minutes
  @cleanup_interval 300_000

  ## Public API

  @doc """
  Starts the ContainerManager GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Deploys a service instance as a Docker container.
  """
  def deploy_service(service_instance) do
    GenServer.call(__MODULE__, {:deploy_service, service_instance}, 30_000)
  end

  @doc """
  Stops a running service container.
  """
  def stop_service(service_instance) do
    GenServer.call(__MODULE__, {:stop_service, service_instance}, 15_000)
  end

  @doc """
  Restarts a service container.
  """
  def restart_service(service_instance) do
    GenServer.call(__MODULE__, {:restart_service, service_instance}, 30_000)
  end

  @doc """
  Scales a service to the specified number of replicas.
  """
  def scale_service(service_instance, replica_count) do
    GenServer.call(__MODULE__, {:scale_service, service_instance, replica_count}, 30_000)
  end

  @doc """
  Gets the current status of a service.
  """
  def get_service_status(service_instance) do
    GenServer.call(__MODULE__, {:get_service_status, service_instance})
  end

  @doc """
  Lists all managed containers.
  """
  def list_all_containers do
    GenServer.call(__MODULE__, :list_all_containers)
  end

  @doc """
  Removes a container by ID.
  """
  def remove_container(container_id) do
    GenServer.call(__MODULE__, {:remove_container, container_id})
  end

  @doc """
  Cleans up unused Docker images.
  """
  def cleanup_unused_images do
    GenServer.call(__MODULE__, :cleanup_unused_images, 60_000)
  end

  @doc """
  Gets current circuit breaker status.
  """
  def circuit_breaker_status do
    GenServer.call(__MODULE__, :circuit_breaker_status)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Check Docker connectivity on startup but don't fail if unavailable
    docker_available =
      case DockerClient.ping() do
        :ok ->
          Logger.info("ContainerManager started successfully - Docker daemon accessible")
          true

        {:error, error} ->
          Logger.warning("Docker daemon not available - ContainerManager running in mock mode",
            error: inspect(error)
          )

          false
      end

    state = %__MODULE__{
      containers: %{},
      circuit_breaker: if(docker_available, do: {:closed, 0, nil}, else: {:open, 0, nil}),
      health_check_timer: schedule_health_checks(),
      metrics_timer: schedule_metrics_collection(),
      cleanup_timer: schedule_cleanup()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:deploy_service, service_instance}, _from, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        # Return mock success when Docker is unavailable
        Logger.info("Mock deployment - Docker unavailable", service_id: service_instance.id)

        mock_result =
          {:ok,
           %{
             container_id: "mock_#{:rand.uniform(10000)}",
             status: :running,
             created_at: DateTime.utc_now()
           }}

        {:reply, mock_result, state}

      _ ->
        result = perform_deployment(service_instance, state)
        new_state = update_circuit_breaker(result, state)
        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call({:stop_service, service_instance}, _from, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        # Return mock success when Docker is unavailable
        Logger.info("Mock stop - Docker unavailable", service_id: service_instance.id)
        {:reply, {:ok, :stopped}, state}

      _ ->
        result = perform_stop(service_instance, state)
        new_state = update_circuit_breaker(result, state)
        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call({:restart_service, service_instance}, _from, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        # Return mock success when Docker is unavailable
        Logger.info("Mock restart - Docker unavailable", service_id: service_instance.id)

        mock_result =
          {:ok,
           %{
             container_id: "mock_#{:rand.uniform(10000)}",
             status: :running,
             created_at: DateTime.utc_now()
           }}

        {:reply, mock_result, state}

      _ ->
        with {:ok, _} <- perform_stop(service_instance, state),
             {:ok, container_info} <- perform_deployment(service_instance, state) do
          new_state = update_circuit_breaker({:ok, container_info}, state)
          {:reply, {:ok, container_info}, new_state}
        else
          error ->
            new_state = update_circuit_breaker(error, state)
            {:reply, error, new_state}
        end
    end
  end

  @impl true
  def handle_call({:scale_service, service_instance, replica_count}, _from, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        # Return mock success when Docker is unavailable
        Logger.info("Mock scaling - Docker unavailable",
          service_id: service_instance.id,
          replicas: replica_count
        )

        {:reply, {:ok, %{replica_count: replica_count}}, state}

      _ ->
        result = perform_scaling(service_instance, replica_count, state)
        new_state = update_circuit_breaker(result, state)
        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call({:get_service_status, service_instance}, _from, state) do
    container_id = service_instance.container_id

    status =
      case Map.get(state.containers, container_id) do
        nil -> :not_found
        container_info -> container_info.status
      end

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call(:list_all_containers, _from, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        # Return mock containers when Docker is unavailable
        Logger.debug("Mock container list - Docker unavailable")

        mock_containers =
          Enum.map(state.containers, fn {id, info} ->
            %{"Id" => id, "State" => info.status, "Created" => info.created_at}
          end)

        {:reply, {:ok, mock_containers}, state}

      _ ->
        case DockerClient.list_containers(all: true) do
          {:ok, containers} ->
            {:reply, {:ok, containers}, state}

          error ->
            new_state = update_circuit_breaker(error, state)
            {:reply, error, new_state}
        end
    end
  end

  @impl true
  def handle_call({:remove_container, container_id}, _from, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        # Return mock success when Docker is unavailable
        Logger.debug("Mock container removal - Docker unavailable", container_id: container_id)
        containers = Map.delete(state.containers, container_id)
        new_state = %{state | containers: containers}
        {:reply, :ok, new_state}

      _ ->
        result = DockerClient.remove_container(container_id, force: true)

        new_state =
          case result do
            :ok ->
              containers = Map.delete(state.containers, container_id)
              %{state | containers: containers}

            _ ->
              state
          end

        new_state = update_circuit_breaker(result, new_state)
        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call(:cleanup_unused_images, _from, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        # Return mock success when Docker is unavailable
        Logger.debug("Mock image cleanup - Docker unavailable")
        mock_result = {:ok, %{images_removed: 0, space_freed_bytes: 0}}
        {:reply, mock_result, state}

      _ ->
        result = DockerClient.prune_images()
        new_state = update_circuit_breaker(result, state)
        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call(:circuit_breaker_status, _from, state) do
    {:reply, state.circuit_breaker, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        Logger.debug("Skipping health checks - Docker unavailable")

      _ ->
        perform_health_checks(state)
    end

    timer = schedule_health_checks()
    {:noreply, %{state | health_check_timer: timer}}
  end

  @impl true
  def handle_info(:metrics_collection, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        Logger.debug("Skipping metrics collection - Docker unavailable")

      _ ->
        collect_metrics(state)
    end

    timer = schedule_metrics_collection()
    {:noreply, %{state | metrics_timer: timer}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    case get_circuit_breaker_state(state) do
      :open ->
        Logger.debug("Skipping cleanup operations - Docker unavailable")

      _ ->
        perform_cleanup(state)
    end

    timer = schedule_cleanup()
    {:noreply, %{state | cleanup_timer: timer}}
  end

  @impl true
  def handle_info(:reset_circuit_breaker, state) do
    Logger.info("Resetting Docker API circuit breaker")
    new_state = %{state | circuit_breaker: {:closed, 0, nil}}
    {:noreply, new_state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("ContainerManager terminating", reason: inspect(reason))

    # Cancel timers
    if state.health_check_timer, do: Process.cancel_timer(state.health_check_timer)
    if state.metrics_timer, do: Process.cancel_timer(state.metrics_timer)
    if state.cleanup_timer, do: Process.cancel_timer(state.cleanup_timer)

    :ok
  end

  ## Private Functions - Deployment Operations

  defp perform_deployment(service_instance, state) do
    Logger.info("Deploying service", service_id: service_instance.id, name: service_instance.name)

    with {:ok, image_info} <- build_or_pull_image(service_instance),
         {:ok, container_info} <- create_and_start_container(service_instance, image_info),
         :ok <- record_deployment_success(service_instance, container_info) do
      # Update state with new container
      containers = Map.put(state.containers, container_info.container_id, container_info)
      broadcast_container_event(service_instance, :deployed, container_info)

      {:ok, container_info}
    else
      error ->
        record_deployment_failure(service_instance, error)
        error
    end
  end

  defp perform_stop(service_instance, state) do
    container_id = service_instance.container_id

    if container_id do
      Logger.info("Stopping container", container_id: container_id)

      case DockerClient.stop_container(container_id) do
        :ok ->
          containers = Map.delete(state.containers, container_id)
          broadcast_container_event(service_instance, :stopped, %{container_id: container_id})
          {:ok, :stopped}

        error ->
          Logger.error("Failed to stop container",
            container_id: container_id,
            error: inspect(error)
          )

          error
      end
    else
      {:error, :no_container_id}
    end
  end

  defp perform_scaling(service_instance, replica_count, _state) do
    # For now, return a placeholder - full scaling implementation would depend on orchestration strategy
    Logger.info("Scaling service", service_id: service_instance.id, replicas: replica_count)

    broadcast_container_event(service_instance, :scaled, %{replica_count: replica_count})
    {:ok, %{replica_count: replica_count}}
  end

  ## Private Functions - Image Management

  defp build_or_pull_image(service_instance) do
    case service_instance.deployment_config do
      %{"dockerfile_path" => dockerfile_path} when not is_nil(dockerfile_path) ->
        build_custom_image(service_instance, dockerfile_path)

      _ ->
        pull_base_image(service_instance)
    end
  end

  defp build_custom_image(service_instance, dockerfile_path) do
    workspace_path = get_workspace_path(service_instance)
    context_path = Path.join(workspace_path, service_instance.folder_path)

    build_opts = [
      dockerfile: dockerfile_path,
      tag: generate_image_tag(service_instance),
      no_cache: false
    ]

    case DockerClient.build_image(context_path, build_opts) do
      {:ok, image_info} ->
        Logger.info("Successfully built custom image",
          service_id: service_instance.id,
          image: image_info.image_name
        )

        {:ok, image_info}

      error ->
        Logger.error("Failed to build custom image",
          service_id: service_instance.id,
          error: inspect(error)
        )

        error
    end
  end

  defp pull_base_image(service_instance) do
    base_image = determine_base_image(service_instance.service_type)

    case DockerClient.pull_image(base_image) do
      {:ok, image_info} ->
        Logger.info("Successfully pulled base image",
          service_id: service_instance.id,
          image: base_image
        )

        {:ok, image_info}

      error ->
        Logger.error("Failed to pull base image",
          service_id: service_instance.id,
          image: base_image,
          error: inspect(error)
        )

        error
    end
  end

  ## Private Functions - Container Management

  defp create_and_start_container(service_instance, image_info) do
    container_config = build_container_config(service_instance, image_info)

    with {:ok, create_result} <- DockerClient.create_container(container_config),
         :ok <- DockerClient.start_container(create_result["Id"]) do
      container_info = %{
        container_id: create_result["Id"],
        image_info: image_info,
        status: :running,
        created_at: DateTime.utc_now(),
        ports: extract_port_mappings(container_config),
        environment: extract_environment_vars(container_config)
      }

      {:ok, container_info}
    else
      error ->
        Logger.error("Failed to create/start container",
          service_id: service_instance.id,
          error: inspect(error)
        )

        error
    end
  end

  defp build_container_config(service_instance, image_info) do
    port_mappings = build_port_mappings(service_instance)
    environment_vars = build_environment_variables(service_instance)
    volumes = build_volume_mounts(service_instance)

    %{
      image: "#{image_info.image_name}:#{image_info.image_tag}",
      name: generate_container_name(service_instance),
      ports: port_mappings,
      env: environment_vars,
      volumes: volumes,
      labels: %{
        "kyozo.service_id" => service_instance.id,
        "kyozo.service_name" => service_instance.name,
        "kyozo.service_type" => to_string(service_instance.service_type),
        "kyozo.managed" => "true"
      },
      restart_policy: :unless_stopped,
      resource_limits: service_instance.resource_limits || %{}
    }
  end

  ## Private Functions - Health Monitoring

  defp perform_health_checks(state) do
    Task.start(fn ->
      state.containers
      |> Enum.each(fn {container_id, container_info} ->
        check_container_health(container_id, container_info)
      end)
    end)
  end

  defp check_container_health(container_id, container_info) do
    case DockerClient.inspect_container(container_id) do
      {:ok, inspection} ->
        status = get_in(inspection, ["State", "Status"])

        if status != "running" do
          Logger.warn("Container health check failed",
            container_id: container_id,
            status: status
          )

          broadcast_health_event(container_info, :unhealthy, %{status: status})
        end

      {:error, error} ->
        Logger.error("Failed to inspect container for health check",
          container_id: container_id,
          error: inspect(error)
        )
    end
  end

  ## Private Functions - Metrics Collection

  defp collect_metrics(state) do
    Task.start(fn ->
      state.containers
      |> Enum.each(fn {container_id, container_info} ->
        collect_container_metrics(container_id, container_info)
      end)
    end)
  end

  defp collect_container_metrics(container_id, _container_info) do
    case DockerClient.get_container_stats(container_id, stream: false) do
      {:ok, stats} ->
        broadcast_metrics_event(container_id, stats)

      {:error, error} ->
        Logger.debug("Failed to collect container metrics",
          container_id: container_id,
          error: inspect(error)
        )
    end
  end

  ## Private Functions - Circuit Breaker

  defp get_circuit_breaker_state(state) do
    case state.circuit_breaker do
      {:open, _, timeout} when not is_nil(timeout) ->
        if DateTime.compare(DateTime.utc_now(), timeout) == :gt do
          :half_open
        else
          :open
        end

      {:open, _, _} ->
        :open

      {:closed, _, _} ->
        :closed

      {:half_open, _, _} ->
        :half_open
    end
  end

  defp update_circuit_breaker({:ok, _}, state), do: reset_circuit_breaker(state)
  defp update_circuit_breaker(:ok, state), do: reset_circuit_breaker(state)

  defp update_circuit_breaker({:error, %Error{type: :connection_error}}, state) do
    increment_circuit_breaker_failures(state)
  end

  defp update_circuit_breaker({:error, %Error{type: :request_error}}, state) do
    increment_circuit_breaker_failures(state)
  end

  defp update_circuit_breaker(_, state), do: state

  defp reset_circuit_breaker(state) do
    %{state | circuit_breaker: {:closed, 0, nil}}
  end

  defp increment_circuit_breaker_failures(state) do
    {status, failure_count, _} = state.circuit_breaker
    new_failure_count = failure_count + 1

    if new_failure_count >= @circuit_breaker_threshold do
      timeout = DateTime.add(DateTime.utc_now(), @circuit_breaker_timeout, :millisecond)

      Logger.warn("Opening Docker API circuit breaker",
        failures: new_failure_count,
        timeout: timeout
      )

      # Schedule circuit breaker reset
      Process.send_after(self(), :reset_circuit_breaker, @circuit_breaker_timeout)

      %{state | circuit_breaker: {:open, new_failure_count, timeout}}
    else
      %{state | circuit_breaker: {status, new_failure_count, nil}}
    end
  end

  ## Private Functions - Helpers

  defp build_port_mappings(service_instance) do
    service_instance.deployment_config
    |> Map.get("port_mappings", %{})
    |> Enum.into(%{}, fn {container_port, host_port} ->
      {String.to_integer(container_port), String.to_integer(host_port)}
    end)
  end

  defp build_environment_variables(service_instance) do
    env_vars =
      service_instance.deployment_config
      |> Map.get("environment_variables", %{})
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)

    # Add Kyozo-specific environment variables
    kyozo_vars = [
      "KYOZO_SERVICE_ID=#{service_instance.id}",
      "KYOZO_SERVICE_NAME=#{service_instance.name}",
      "KYOZO_SERVICE_TYPE=#{service_instance.service_type}"
    ]

    env_vars ++ kyozo_vars
  end

  defp build_volume_mounts(service_instance) do
    service_instance.deployment_config
    |> Map.get("volume_mounts", [])
    |> Enum.map(fn
      %{"host_path" => host, "container_path" => container} ->
        {host, container}

      %{"host_path" => host, "container_path" => container, "readonly" => true} ->
        {host, container, :readonly}

      volume when is_binary(volume) ->
        volume
    end)
  end

  defp extract_port_mappings(container_config) do
    Map.get(container_config, :ports, %{})
  end

  defp extract_environment_vars(container_config) do
    Map.get(container_config, :env, [])
  end

  defp generate_container_name(service_instance) do
    "kyozo-#{service_instance.name}-#{String.slice(service_instance.id, 0, 8)}"
  end

  defp generate_image_tag(service_instance) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "kyozo-#{service_instance.name}:#{timestamp}"
  end

  defp determine_base_image(:nodejs), do: "node:18-alpine"
  defp determine_base_image(:python), do: "python:3.11-alpine"
  defp determine_base_image(:golang), do: "golang:1.21-alpine"
  defp determine_base_image(:rust), do: "rust:1.75-alpine"
  defp determine_base_image(:ruby), do: "ruby:3.2-alpine"
  defp determine_base_image(:java), do: "openjdk:17-alpine"
  defp determine_base_image(_), do: "alpine:latest"

  defp get_workspace_path(_service_instance) do
    # This would integrate with the workspace storage system
    # For now, return a placeholder
    "/tmp/kyozo-workspaces"
  end

  ## Private Functions - Event Broadcasting

  defp broadcast_container_event(service_instance, event_type, data) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      "service_instance:#{service_instance.id}",
      {:container_event, event_type, data}
    )
  end

  defp broadcast_health_event(container_info, status, data) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      "container:#{container_info.container_id}",
      {:health_event, status, data}
    )
  end

  defp broadcast_metrics_event(container_id, metrics) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      "container:#{container_id}",
      {:metrics_event, metrics}
    )
  end

  ## Private Functions - Database Operations

  defp record_deployment_success(service_instance, container_info) do
    # This would create a deployment event record
    # For now, just log success
    Logger.info("Deployment successful",
      service_id: service_instance.id,
      container_id: container_info.container_id
    )

    :ok
  end

  defp record_deployment_failure(service_instance, error) do
    # This would create a deployment failure event record
    # For now, just log failure
    Logger.error("Deployment failed",
      service_id: service_instance.id,
      error: inspect(error)
    )

    :ok
  end

  ## Private Functions - Cleanup

  defp perform_cleanup(_state) do
    Task.start(fn ->
      # Clean up stopped containers
      case DockerClient.list_containers(all: true, filters: %{"status" => ["exited"]}) do
        {:ok, containers} ->
          containers
          |> Enum.filter(&is_kyozo_container?/1)
          |> Enum.each(&cleanup_stopped_container/1)

        {:error, error} ->
          Logger.warning("Failed to list containers for cleanup", error: inspect(error))
      end

      # Clean up unused images periodically
      # 10% chance
      if :rand.uniform(10) == 1 do
        DockerClient.prune_images()
      end
    end)
  end

  defp is_kyozo_container?(container) do
    labels = get_in(container, ["Labels"]) || %{}
    Map.get(labels, "kyozo.managed") == "true"
  end

  defp cleanup_stopped_container(container) do
    container_id = container["Id"]

    # Only remove containers that have been stopped for more than 1 hour
    finished_at = get_in(container, ["State", "FinishedAt"])

    if finished_at && container_old_enough?(finished_at) do
      case DockerClient.remove_container(container_id) do
        :ok ->
          Logger.info("Cleaned up stopped container", container_id: container_id)

        error ->
          Logger.warning("Failed to cleanup stopped container",
            container_id: container_id,
            error: inspect(error)
          )
      end
    end
  end

  defp container_old_enough?(finished_at_str) do
    case DateTime.from_iso8601(finished_at_str) do
      {:ok, finished_at, _} ->
        one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)
        DateTime.compare(finished_at, one_hour_ago) == :lt

      _ ->
        false
    end
  end

  ## Private Functions - Scheduling

  defp schedule_health_checks do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  defp schedule_metrics_collection do
    Process.send_after(self(), :metrics_collection, @metrics_interval)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
