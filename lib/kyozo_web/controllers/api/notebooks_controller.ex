defmodule KyozoWeb.API.NotebooksController do
  use KyozoWeb, :controller

  alias Kyozo.Workspaces

  action_fallback KyozoWeb.FallbackController

  def index(conn, params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    workspace_id = params["workspace_id"]

    query = build_query(params, workspace_id)

    with {:ok, notebooks} <- Workspaces.list_notebooks(
      query: query,
      actor: current_user,
      tenant: current_team
    ) do
      render(conn, :index, notebooks: notebooks)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, 
      actor: current_user,
      tenant: current_team,
      load: [:workspace, :team, :document, :tasks]
    ) do
      render(conn, :show, notebook: notebook)
    end
  end

  def create_from_document(conn, %{"document_id" => document_id, "notebook" => notebook_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    params = Map.merge(notebook_params, %{"document_id" => document_id})

    with {:ok, notebook} <- Workspaces.create_from_document(
      params,
      actor: current_user,
      tenant: current_team
    ) do
      conn
      |> put_status(:created)
      |> render(:show, notebook: notebook)
    end
  end

  def update(conn, %{"id" => id, "notebook" => notebook_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, updated_notebook} <- Workspaces.update_content(
           notebook,
           notebook_params,
           actor: current_user,
           tenant: current_team
         ) do
      render(conn, :show, notebook: updated_notebook)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, _notebook} <- Workspaces.destroy_notebook(notebook, actor: current_user, tenant: current_team) do
      send_resp(conn, :no_content, "")
    end
  end

  def duplicate(conn, %{"id" => id, "options" => options}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, duplicate_notebook} <- Workspaces.duplicate_notebook(
           notebook,
           options,
           actor: current_user,
           tenant: current_team
         ) do
      conn
      |> put_status(:created)
      |> render(:show, notebook: duplicate_notebook)
    end
  end

  def execute(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    
    environment_variables = conn.params["environment_variables"] || %{}
    timeout_seconds = conn.params["timeout_seconds"] || 300

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, executed_notebook} <- Workspaces.execute_notebook(
           notebook,
           %{
             environment_variables: environment_variables,
             timeout_seconds: timeout_seconds
           },
           actor: current_user,
           tenant: current_team
         ) do
      render(conn, :show, notebook: executed_notebook)
    end
  end

  def execute_task(conn, %{"id" => id, "task_id" => task_id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    
    environment_variables = conn.params["environment_variables"] || %{}

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, updated_notebook} <- execute_single_task(
           notebook,
           task_id,
           environment_variables,
           current_user,
           current_team
         ) do
      render(conn, :show, notebook: updated_notebook)
    end
  end

  def stop_execution(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, stopped_notebook} <- stop_notebook_execution(
           notebook,
           current_user,
           current_team
         ) do
      render(conn, :show, notebook: stopped_notebook)
    end
  end

  def reset_execution(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, reset_notebook} <- reset_notebook_execution(
           notebook,
           current_user,
           current_team
         ) do
      render(conn, :show, notebook: reset_notebook)
    end
  end

  def toggle_collaborative_mode(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, updated_notebook} <- toggle_collaboration(
           notebook,
           current_user,
           current_team
         ) do
      render(conn, :show, notebook: updated_notebook)
    end
  end

  def update_access_time(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, updated_notebook} <- update_notebook_access_time(
           notebook,
           current_user,
           current_team
         ) do
      render(conn, :show, notebook: updated_notebook)
    end
  end

  def tasks(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, notebook} <- Workspaces.get_notebook(id, actor: current_user, tenant: current_team),
         {:ok, tasks} <- Workspaces.list_notebook_tasks(notebook.id, actor: current_user, tenant: current_team) do
      render(conn, :tasks, tasks: tasks, notebook: notebook)
    end
  end

  def workspace_tasks(conn, %{"workspace_id" => workspace_id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, tasks} <- Workspaces.list_workspace_tasks(workspace_id, actor: current_user, tenant: current_team) do
      render(conn, :workspace_tasks, tasks: tasks, workspace_id: workspace_id)
    end
  end

  # Private helper functions

  defp build_query(params, workspace_id) do
    query = []

    query = if workspace_id do
      Keyword.put(query, :filter, [workspace_id: workspace_id])
    else
      query
    end

    query = if status = params["status"] do
      existing_filter = Keyword.get(query, :filter, [])
      updated_filter = Keyword.put(existing_filter, :status, String.to_atom(status))
      Keyword.put(query, :filter, updated_filter)
    else
      query
    end

    query = if search = params["search"] do
      existing_filter = Keyword.get(query, :filter, [])
      updated_filter = Keyword.put(existing_filter, :search, search)
      Keyword.put(query, :filter, updated_filter)
    else
      query
    end

    query = if sort_by = params["sort_by"] do
      sort_order = String.to_atom(params["sort_order"] || "asc")
      sort_field = String.to_atom(sort_by)
      Keyword.put(query, :sort, [{sort_field, sort_order}])
    else
      Keyword.put(query, :sort, [updated_at: :desc])
    end

    query
  end

  # These functions would need to be implemented based on your specific notebook actions
  defp execute_single_task(notebook, task_id, environment_variables, actor, tenant) do
    Workspaces.Notebook.execute_task(
      notebook,
      %{
        task_id: task_id,
        environment_variables: environment_variables
      },
      actor: actor,
      tenant: tenant
    )
  end

  defp stop_notebook_execution(notebook, actor, tenant) do
    Workspaces.Notebook.stop_execution(notebook, actor: actor, tenant: tenant)
  end

  defp reset_notebook_execution(notebook, actor, tenant) do
    Workspaces.Notebook.reset_execution(notebook, actor: actor, tenant: tenant)
  end

  defp toggle_collaboration(notebook, actor, tenant) do
    Workspaces.Notebook.toggle_collaborative_mode(notebook, actor: actor, tenant: tenant)
  end

  defp update_notebook_access_time(notebook, actor, tenant) do
    Workspaces.Notebook.update_access_time(notebook, actor: actor, tenant: tenant)
  end
end