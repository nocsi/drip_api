defmodule DirupWeb.API.ServicesJSON do
  alias Dirup.Containers.ServiceInstance
  alias Dirup.Containers.DeploymentEvent
  alias Dirup.Containers.HealthCheck
  alias Dirup.Containers.ServiceMetric
  alias Dirup.Workspaces.Workspace
  alias Dirup.Accounts.Team

  @doc """
  Renders a list of services.
  """
  def index(%{services: services}) do
    %{data: for(service <- services, do: data(service))}
  end

  @doc """
  Renders a single service.
  """
  def show(%{service: service}) do
    %{data: data(service)}
  end

  @doc """
  Renders service status information.
  """
  def status(%{status: status}) do
    %{data: status}
  end

  @doc """
  Renders service logs.
  """
  def logs(%{logs: logs}) do
    %{data: %{logs: logs, timestamp: DateTime.utc_now()}}
  end

  @doc """
  Renders service metrics.
  """
  def metrics(%{metrics: metrics}) do
    %{data: metrics}
  end

  @doc """
  Renders service health status.
  """
  def health(%{health: health}) do
    %{data: health}
  end

  defp data(%ServiceInstance{} = service) do
    %{
      id: service.id,
      name: service.name,
      folder_path: service.folder_path,
      service_type: service.service_type,
      detection_confidence: service.detection_confidence,
      status: service.status,
      container_id: service.container_id,
      image_id: service.image_id,
      deployment_config: service.deployment_config || %{},
      port_mappings: service.port_mappings || %{},
      environment_variables: service.environment_variables || %{},
      volume_mounts: service.volume_mounts || %{},
      resource_limits: service.resource_limits,
      scaling_config: service.scaling_config,
      health_check_config: service.health_check_config,
      labels: service.labels || %{},
      network_config: service.network_config || %{},
      created_at: service.created_at,
      updated_at: service.updated_at,
      deployed_at: service.deployed_at,
      last_health_check_at: service.last_health_check_at,
      stopped_at: service.stopped_at,
      workspace_id: service.workspace_id,
      team_id: service.team_id,
      created_by_id: service.created_by_id,
      topology_detection_id: service.topology_detection_id,
      workspace: render_if_loaded(service.workspace, &workspace_data/1),
      team: render_if_loaded(service.team, &team_data/1),
      deployment_events: render_if_loaded(service.deployment_events, &deployment_event_data/1),
      health_checks: render_if_loaded(service.health_checks, &health_check_data/1),
      service_metrics: render_if_loaded(service.service_metrics, &metric_data/1)
    }
  end

  defp workspace_data(%Workspace{} = workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      description: workspace.description,
      status: workspace.status,
      storage_backend: workspace.storage_backend,
      storage_path: workspace.storage_path
    }
  end

  defp team_data(%Team{} = team) do
    %{
      id: team.id,
      name: team.name,
      created_at: team.created_at,
      updated_at: team.updated_at
    }
  end

  defp deployment_event_data(%DeploymentEvent{} = event) do
    %{
      id: event.id,
      event_type: event.event_type,
      event_data: event.event_data || %{},
      error_message: event.error_message,
      error_details: event.error_details || %{},
      duration_ms: event.duration_ms,
      sequence_number: event.sequence_number,
      occurred_at: event.occurred_at,
      service_instance_id: event.service_instance_id,
      team_id: event.team_id,
      triggered_by_id: event.triggered_by_id
    }
  end

  defp health_check_data(%HealthCheck{} = check) do
    %{
      id: check.id,
      check_type: check.check_type,
      endpoint: check.endpoint,
      status: check.status,
      response_time_ms: check.response_time_ms,
      status_code: check.status_code,
      response_body: check.response_body,
      error_message: check.error_message,
      checked_at: check.checked_at,
      service_instance_id: check.service_instance_id
    }
  end

  defp metric_data(%ServiceMetric{} = metric) do
    %{
      id: metric.id,
      metric_type: metric.metric_type,
      value: metric.value,
      unit: metric.unit,
      metadata: metric.metadata || %{},
      collected_at: metric.collected_at,
      service_instance_id: metric.service_instance_id
    }
  end

  defp render_if_loaded(%Ash.NotLoaded{}, _fun), do: nil
  defp render_if_loaded(nil, _fun), do: nil
  defp render_if_loaded(data, fun) when is_list(data), do: Enum.map(data, fun)
  defp render_if_loaded(data, fun), do: fun.(data)
end
