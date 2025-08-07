defmodule KyozoWeb.API.DocumentsController do
  use KyozoWeb, :controller

  alias Kyozo.Workspaces

  action_fallback KyozoWeb.FallbackController

  def index(conn, params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    workspace_id = params["workspace_id"]

    query = build_query(params, workspace_id)

    with {:ok, documents} <- Workspaces.list_documents(
      query: query,
      actor: current_user,
      tenant: current_team
    ) do
      render(conn, :index, documents: documents)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.get_document(id, 
      actor: current_user,
      tenant: current_team,
      load: [:workspace, :team]
    ) do
      render(conn, :show, document: document)
    end
  end

  def create(conn, %{"document" => document_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.create_document(
      document_params,
      actor: current_user,
      tenant: current_team
    ) do
      conn
      |> put_status(:created)
      |> render(:show, document: document)
    end
  end

  def update(conn, %{"id" => id, "document" => document_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, updated_document} <- Workspaces.update_document(
           document,
           document_params,
           actor: current_user,
           tenant: current_team
         ) do
      render(conn, :show, document: updated_document)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, _document} <- Workspaces.delete_document(document, actor: current_user, tenant: current_team) do
      send_resp(conn, :no_content, "")
    end
  end

  def duplicate(conn, %{"id" => id, "options" => options}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, duplicate_document} <- Workspaces.duplicate_document(
           document,
           options,
           actor: current_user,
           tenant: current_team
         ) do
      conn
      |> put_status(:created)
      |> render(:show, document: duplicate_document)
    end
  end

  def content(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    version = conn.params["version"]

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, content} <- get_document_content(document, version, current_user, current_team) do
      render(conn, :content, content: content, document: document)
    end
  end

  def update_content(conn, %{"id" => id, "content" => content, "commit_message" => commit_message}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, updated_document} <- update_document_content(
           document,
           content,
           commit_message,
           current_user,
           current_team
         ) do
      render(conn, :show, document: updated_document)
    end
  end

  def versions(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, versions} <- get_document_versions(document, current_user, current_team) do
      render(conn, :versions, versions: versions, document: document)
    end
  end

  def render_as(conn, %{"id" => id, "format" => format}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    options = conn.params["options"] || %{}

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, rendered_content} <- render_document_as(
           document,
           String.to_atom(format),
           options,
           current_user,
           current_team
         ) do
      render(conn, :rendered_content, content: rendered_content, format: format, document: document)
    end
  end

  def upload(conn, %{"workspace_id" => workspace_id, "file" => file_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    upload_params = %{
      "workspace_id" => workspace_id,
      "file_upload" => file_params,
      "initial_commit_message" => conn.params["commit_message"] || "Upload document"
    }

    with {:ok, document} <- upload_document(upload_params, current_user, current_team) do
      conn
      |> put_status(:created)
      |> render(:show, document: document)
    end
  end

  def rename(conn, %{"id" => id, "new_title" => new_title}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    commit_message = conn.params["commit_message"] || "Rename document"

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, renamed_document} <- rename_document(
           document,
           new_title,
           commit_message,
           current_user,
           current_team
         ) do
      render(conn, :show, document: renamed_document)
    end
  end

  def view(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, document} <- Workspaces.get_document(id, actor: current_user, tenant: current_team),
         {:ok, _} <- record_document_view(document, current_user, current_team) do
      render(conn, :show, document: document)
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

    query = if search = params["search"] do
      existing_filter = Keyword.get(query, :filter, [])
      updated_filter = Keyword.put(existing_filter, :search, search)
      Keyword.put(query, :filter, updated_filter)
    else
      query
    end

    query = if content_type = params["content_type"] do
      existing_filter = Keyword.get(query, :filter, [])
      updated_filter = Keyword.put(existing_filter, :content_type, content_type)
      Keyword.put(query, :filter, updated_filter)
    else
      query
    end

    query = if tags = params["tags"] do
      tag_list = String.split(tags, ",")
      existing_filter = Keyword.get(query, :filter, [])
      updated_filter = Keyword.put(existing_filter, :tags, tag_list)
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

  # These functions would need to be implemented based on your specific document actions
  defp get_document_content(document, version, actor, tenant) do
    case version do
      nil ->
        # Get current content using the get_content action
        Workspaces.Document.get_content(document, actor: actor, tenant: tenant)
      
      version_id ->
        # Get specific version content
        Workspaces.Document.get_content(document, %{version: version_id}, actor: actor, tenant: tenant)
    end
  end

  defp update_document_content(document, content, commit_message, actor, tenant) do
    Workspaces.Document.update_content(
      document,
      %{content: content, commit_message: commit_message},
      actor: actor,
      tenant: tenant
    )
  end

  defp get_document_versions(document, actor, tenant) do
    Workspaces.Document.list_versions(document, actor: actor, tenant: tenant)
  end

  defp render_document_as(document, format, options, actor, tenant) do
    Workspaces.Document.render_as(
      document,
      %{target_format: format, options: options},
      actor: actor,
      tenant: tenant
    )
  end

  defp upload_document(params, actor, tenant) do
    Workspaces.Document.upload_document(params, actor: actor, tenant: tenant)
  end

  defp rename_document(document, new_title, commit_message, actor, tenant) do
    Workspaces.Document.rename_document(
      document,
      %{new_title: new_title, commit_message: commit_message},
      actor: actor,
      tenant: tenant
    )
  end

  defp record_document_view(document, actor, tenant) do
    Workspaces.Document.view_document(document, actor: actor, tenant: tenant)
  end
end