defmodule KyozoWeb.API.ServicesController do
  use KyozoWeb, :controller

  alias Kyozo.Containers

  action_fallback KyozoWeb.FallbackController

  def index(conn, params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, services} <-
           Containers.list_service_instances(
             query: build_query(params),
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :index, services: services)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team,
             load: [:workspace, :team, :deployment_events, :health_checks]
           ) do
      render(conn, :show, service: service)
    end
  end

  def create(conn, %{"service" => service_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    service_params = Map.put(service_params, "team_id", current_team.id)

    with {:ok, service} <-
           Containers.create_service_instance(
             service_params,
             actor: current_user,
             tenant: current_team
           ) do
      conn
      |> put_status(:created)
      |> render(:show, service: service)
    end
  end

  def update(conn, %{"id" => id, "service" => service_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ),
         {:ok, updated_service} <-
           Containers.update_service_instance(
             service,
             service_params,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :show, service: updated_service)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ),
         {:ok, _service} <-
           Containers.destroy_service_instance(
             service,
             actor: current_user,
             tenant: current_team
           ) do
      send_resp(conn, :no_content, "")
    end
  end

  def status(conn, %{"service_id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ) do
      status = %{
        id: service.id,
        name: service.name,
        status: service.status,
        container_id: service.container_id,
        image_id: service.image_id,
        deployed_at: service.deployed_at,
        last_health_check_at: service.last_health_check_at,
        uptime: Containers.ServiceInstance.uptime(service),
        deployment_status: Containers.ServiceInstance.deployment_status(service)
      }

      render(conn, :status, status: status)
    end
  end

  def start(conn, %{"service_id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ),
         {:ok, updated_service} <-
           Containers.start_container(
             service,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :show, service: updated_service)
    end
  end

  def stop(conn, %{"service_id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ),
         {:ok, updated_service} <-
           Containers.stop_container(
             service,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :show, service: updated_service)
    end
  end

  def restart(conn, %{"service_id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ) do
      # Stop then start
      with {:ok, _stopped_service} <-
             Containers.stop_container(
               service,
               actor: current_user,
               tenant: current_team
             ),
           {:ok, restarted_service} <-
             Containers.start_container(
               service,
               actor: current_user,
               tenant: current_team
             ) do
        render(conn, :show, service: restarted_service)
      end
    end
  end

  def scale(conn, %{"service_id" => id} = params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    replica_count = Map.get(params, "replica_count", 1)

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ),
         {:ok, scaled_service} <-
           Containers.scale_service(
             service,
             replica_count,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :show, service: scaled_service)
    end
  end

  def logs(conn, %{"service_id" => id} = params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    lines = Map.get(params, "lines", "100")
    follow = Map.get(params, "follow", "false") == "true"

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team
           ),
         {:ok, logs} <- get_container_logs(service, lines, follow) do
      render(conn, :logs, logs: logs)
    end
  end

  def metrics(conn, %{"service_id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team,
             load: [:service_metrics]
           ) do
      # Calculate resource utilization
      utilization = Containers.ServiceInstance.resource_utilization(service)

      metrics = %{
        service_id: service.id,
        resource_utilization: utilization,
        recent_metrics: service.service_metrics |> Enum.take(50),
        updated_at: DateTime.utc_now()
      }

      render(conn, :metrics, metrics: metrics)
    end
  end

  def health_check(conn, %{"service_id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(id,
             actor: current_user,
             tenant: current_team,
             load: [:health_checks]
           ) do
      latest_health = service.health_checks |> Enum.take(1) |> List.first()

      health_status = %{
        service_id: service.id,
        overall_status: service.status,
        last_health_check: latest_health,
        last_check_at: service.last_health_check_at,
        recent_checks: service.health_checks |> Enum.take(10)
      }

      render(conn, :health, health: health_status)
    end
  end

  # Private helper functions

  defp build_query(params) do
    filters = []

    filters =
      if status = params["status"] do
        [{:status, status} | filters]
      else
        filters
      end

    filters =
      if service_type = params["service_type"] do
        [{:service_type, service_type} | filters]
      else
        filters
      end

    filters =
      if workspace_id = params["workspace_id"] do
        [{:workspace_id, workspace_id} | filters]
      else
        filters
      end

    if filters == [] do
      []
    else
      [filter: filters]
    end
  end

  defp get_container_logs(service, lines, _follow) do
    case service.container_id do
      nil ->
        {:ok, "Service not deployed yet"}

      container_id ->
        case Kyozo.Containers.ContainerManager.get_service_status(service) do
          {:ok, _status} ->
            # In a real implementation, you'd get logs from Docker
            # For now, return mock logs
            {:ok, "Mock logs for container #{container_id} (#{lines} lines)"}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end
end
