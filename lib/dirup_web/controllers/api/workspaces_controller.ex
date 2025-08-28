defmodule DirupWeb.API.WorkspacesController do
  use DirupWeb, :controller

  alias Dirup.Workspaces

  action_fallback DirupWeb.FallbackController

  def index(conn, params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspaces} <-
           Workspaces.list_workspaces(
             query: build_query(params),
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :index, workspaces: workspaces)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id,
             actor: current_user,
             tenant: current_team,
             load: [:documents, :notebooks, :team]
           ) do
      render(conn, :show, workspace: workspace)
    end
  end

  def create(conn, %{"workspace" => workspace_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    workspace_params = Map.put(workspace_params, "team_id", current_team.id)

    with {:ok, workspace} <-
           Workspaces.create_workspace(
             workspace_params,
             actor: current_user,
             tenant: current_team
           ) do
      conn
      |> put_status(:created)
      |> render(:show, workspace: workspace)
    end
  end

  def update(conn, %{"id" => id, "workspace" => workspace_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, updated_workspace} <-
           Workspaces.update_workspace(
             workspace,
             workspace_params,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :show, workspace: updated_workspace)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, _workspace} <-
           Workspaces.delete_workspace(workspace, actor: current_user, tenant: current_team) do
      send_resp(conn, :no_content, "")
    end
  end

  def archive(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, archived_workspace} <-
           Workspaces.archive_workspace(workspace, actor: current_user, tenant: current_team) do
      render(conn, :show, workspace: archived_workspace)
    end
  end

  def restore(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, restored_workspace} <-
           Workspaces.restore_workspace(workspace, actor: current_user, tenant: current_team) do
      render(conn, :show, workspace: restored_workspace)
    end
  end

  def duplicate(conn, %{"id" => id, "options" => options}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, duplicate_workspace} <-
           Workspaces.duplicate_workspace(
             workspace,
             Map.merge(options, %{
               "copy_to_team_id" => current_team.id,
               "include_documents" => Map.get(options, "include_documents", true),
               "include_notebooks" => Map.get(options, "include_notebooks", true)
             }),
             actor: current_user,
             tenant: current_team
           ) do
      conn
      |> put_status(:created)
      |> render(:show, workspace: duplicate_workspace)
    end
  end

  def statistics(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, stats} <-
           Workspaces.get_statistics(workspace, actor: current_user, tenant: current_team) do
      render(conn, :statistics, statistics: stats)
    end
  end

  def storage_info(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, storage_info} <-
           Workspaces.get_storage_info(workspace, actor: current_user, tenant: current_team) do
      render(conn, :storage_info, storage_info: storage_info)
    end
  end

  def change_storage_backend(conn, %{"id" => id, "backend" => backend_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, workspace} <-
           Workspaces.get_workspace(id, actor: current_user, tenant: current_team),
         {:ok, updated_workspace} <-
           Workspaces.change_storage_backend(
             workspace,
             backend_params,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :show, workspace: updated_workspace)
    end
  end

  def documents(conn, %{"workspace_id" => workspace_id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, _workspace} <-
           Workspaces.get_workspace(workspace_id, actor: current_user, tenant: current_team),
         {:ok, documents} <-
           Workspaces.list_documents(
             query: [filter: [workspace_id: workspace_id]],
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :documents, documents: documents)
    end
  end

  def notebooks(conn, %{"workspace_id" => workspace_id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, _workspace} <-
           Workspaces.get_workspace(workspace_id, actor: current_user, tenant: current_team),
         {:ok, notebooks} <-
           Workspaces.list_notebooks(
             query: [filter: [workspace_id: workspace_id]],
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :notebooks, notebooks: notebooks)
    end
  end

  def list_services(conn, %{"workspace_id" => workspace_id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, _workspace} <-
           Workspaces.get_workspace(workspace_id, actor: current_user, tenant: current_team),
         {:ok, services} <-
           Dirup.Containers.list_service_instances(
             query: [filter: [workspace_id: workspace_id]],
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :services, services: services)
    end
  end

  def deploy_service(conn, %{"workspace_id" => workspace_id} = params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    service_params =
      Map.merge(params["service"] || %{}, %{
        "workspace_id" => workspace_id,
        "team_id" => current_team.id
      })

    with {:ok, _workspace} <-
           Workspaces.get_workspace(workspace_id, actor: current_user, tenant: current_team),
         {:ok, service} <-
           Dirup.Containers.create_service_instance(
             service_params,
             actor: current_user,
             tenant: current_team
           ),
         {:ok, deployed_service} <-
           Dirup.Containers.start_container_deployment(
             service,
             actor: current_user,
             tenant: current_team
           ) do
      conn
      |> put_status(:created)
      |> render(:service, service: deployed_service)
    end
  end

  def analyze_topology(conn, %{"workspace_id" => workspace_id} = params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    folder_path = params["folder_path"] || "/"

    with {:ok, _workspace} <-
           Workspaces.get_workspace(workspace_id, actor: current_user, tenant: current_team),
         {:ok, detection} <-
           Dirup.Containers.analyze_topology(
             %{
               workspace_id: workspace_id,
               folder_path: folder_path,
               team_id: current_team.id,
               triggered_by_id: current_user.id
             },
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :diruplogy_analysis, analysis: detection)
    end
  end

  defp build_query(params) do
    query = []

    query =
      if status = params["status"] do
        Keyword.put(query, :filter, status: status)
      else
        query
      end

    query =
      if search = params["search"] do
        existing_filter = Keyword.get(query, :filter, [])
        updated_filter = Keyword.put(existing_filter, :search, search)
        Keyword.put(query, :filter, updated_filter)
      else
        query
      end

    query =
      if sort_by = params["sort_by"] do
        sort_order = String.to_atom(params["sort_order"] || "asc")
        sort_field = String.to_atom(sort_by)
        Keyword.put(query, :sort, [{sort_field, sort_order}])
      else
        Keyword.put(query, :sort, updated_at: :desc)
      end

    query
  end
end
