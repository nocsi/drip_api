defmodule Kyozo.Containers do
  use Ash.Domain,
    otp_app: :kyozo

  # GraphQL configuration removed during GraphQL cleanup

  resources do
    # Core container orchestration resources
    resource Kyozo.Containers.ServiceInstance do
      define :create_service_instance, action: :create
      define :list_service_instances, action: :read
      define :list_running_services, action: :list_running
      define :list_workspace_services, action: :list_by_workspace, args: [:workspace_id]
      define :get_service_instance, action: :read, get_by: :id
      define :update_service_instance, action: :update
      define :deploy_service, action: :deploy
      define :start_service, action: :start
      define :stop_service, action: :stop
      define :scale_service, action: :scale, args: [:replica_count]
      define :delete_service_instance, action: :destroy
    end

    resource Kyozo.Containers.TopologyDetection do
      define :analyze_folder_topology,
        action: :analyze_folder,
        args: [:workspace_id, :folder_path]

      define :list_topology_detections, action: :read
      define :list_workspace_detections, action: :by_workspace, args: [:workspace_id]
      define :get_topology_detection, action: :read, get_by: :id
      define :reanalyze_topology, action: :reanalyze
      define :delete_topology_detection, action: :destroy
    end

    resource Kyozo.Containers.DeploymentEvent do
      define :list_deployment_events, action: :read
      define :get_deployment_event, action: :read, get_by: :id
    end

    resource Kyozo.Containers.ServiceDependency do
      define :list_service_dependencies, action: :read
      define :create_service_dependency, action: :create
      define :delete_service_dependency, action: :destroy
    end

    resource Kyozo.Containers.HealthCheck do
      define :list_health_checks, action: :read
      define :get_health_check, action: :read, get_by: :id
    end

    resource Kyozo.Containers.ServiceMetric do
      define :list_service_metrics, action: :read
      define :get_service_metric, action: :read, get_by: :id
    end

    resource Kyozo.Containers.ServicePermission do
      define :list_service_permissions, action: :read
      define :grant_permission, action: :create
      define :revoke_permission, action: :destroy
    end
  end

  @doc """
  Subscribe to container events for real-time updates.
  """
  def subscribe(topic) when is_binary(topic) do
    Phoenix.PubSub.subscribe(Kyozo.PubSub, "containers:#{topic}")
  end

  def subscribe(service_instance_id) do
    Phoenix.PubSub.subscribe(Kyozo.PubSub, "containers:#{service_instance_id}")
  end

  @doc """
  Subscribe to deployment events for a specific service.
  """
  def subscribe_to_deployments(service_instance_id) do
    Phoenix.PubSub.subscribe(Kyozo.PubSub, "deployments:#{service_instance_id}")
  end

  @doc """
  Subscribe to health check events for monitoring.
  """
  def subscribe_to_health_checks(service_instance_id) do
    Phoenix.PubSub.subscribe(Kyozo.PubSub, "health:#{service_instance_id}")
  end

  # Alias functions for controller compatibility
  @doc """
  Destroy a service instance (alias for delete_service_instance).
  """
  def destroy_service_instance(service_instance, opts \\ []) do
    delete_service_instance(service_instance, opts)
  end

  @doc """
  Start a container (alias for start_service).
  """
  def start_container(service_instance, opts \\ []) do
    start_service(service_instance, opts)
  end

  @doc """
  Stop a container (alias for stop_service).
  """
  def stop_container(service_instance, opts \\ []) do
    stop_service(service_instance, opts)
  end

  @doc """
  Broadcast container event to subscribers.
  """
  def broadcast(topic, event, payload) do
    Phoenix.PubSub.broadcast(Kyozo.PubSub, "containers:#{topic}", {event, payload})
  end

  @doc """
  Broadcast deployment event to subscribers.
  """
  def broadcast_deployment(service_instance_id, event, payload) do
    Phoenix.PubSub.broadcast(Kyozo.PubSub, "deployments:#{service_instance_id}", {event, payload})
  end

  @doc """
  Broadcast health check event to subscribers.
  """
  def broadcast_health_check(service_instance_id, status, payload) do
    Phoenix.PubSub.broadcast(Kyozo.PubSub, "health:#{service_instance_id}", {status, payload})
  end
end
