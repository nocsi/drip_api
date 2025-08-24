defmodule KyozoWeb.API.FilesController do
  use KyozoWeb, :controller

  alias Kyozo.Workspaces

  action_fallback KyozoWeb.FallbackController

  def index(conn, params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    workspace_id = params["workspace_id"]

    query = build_query(params, workspace_id)

    with {:ok, files} <-
           Workspaces.list_files(
             query: query,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :index, files: files)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.get_file(id,
             actor: current_user,
             tenant: current_team,
             load: [:workspace, :team]
           ) do
      render(conn, :show, file: file)
    end
  end

  def create(conn, %{"file" => file_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.create_file(
             file_params,
             actor: current_user,
             tenant: current_team
           ) do
      conn
      |> put_status(:created)
      |> render(:show, file: file)
    end
  end

  def update(conn, %{"id" => id, "file" => file_params}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, updated_file} <-
           Workspaces.update_file(
             file,
             file_params,
             actor: current_user,
             tenant: current_team
           ) do
      render(conn, :show, file: updated_file)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, _file} <-
           Workspaces.delete_file(file, actor: current_user, tenant: current_team) do
      send_resp(conn, :no_content, "")
    end
  end

  def duplicate(conn, %{"id" => id, "options" => _options}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, duplicate_file} <-
           Workspaces.duplicate_file(
             file,
             actor: current_user,
             tenant: current_team
           ) do
      conn
      |> put_status(:created)
      |> render(:show, file: duplicate_file)
    end
  end

  def content(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    version = conn.params["version"]

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, content} <- get_file_content(file, version, current_user, current_team) do
      render(conn, :content, content: content, file: file)
    end
  end

  def update_content(conn, %{"id" => id, "content" => content, "commit_message" => commit_message}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, updated_file} <-
           update_file_content(
             file,
             content,
             commit_message,
             current_user,
             current_team
           ) do
      render(conn, :show, file: updated_file)
    end
  end

  def versions(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, versions} <- get_file_versions(file, current_user, current_team) do
      render(conn, :versions, versions: versions, file: file)
    end
  end

  def render_as(conn, %{"id" => id, "format" => format}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team
    options = conn.params["options"] || %{}

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, rendered_content} <-
           render_file_as(
             file,
             String.to_atom(format),
             options,
             current_user,
             current_team
           ) do
      render(conn, :rendered_content,
        content: rendered_content,
        format: format,
        file: file
      )
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

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, renamed_file} <-
           rename_file(
             file,
             new_title,
             commit_message,
             current_user,
             current_team
           ) do
      render(conn, :show, file: renamed_file)
    end
  end

  def view(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    with {:ok, file} <-
           Workspaces.get_file(id, actor: current_user, tenant: current_team),
         {:ok, _} <- record_file_view(file, current_user, current_team) do
      render(conn, :show, file: file)
    end
  end

  # Private helper functions

  defp build_query(params, workspace_id) do
    query = []

    query =
      if workspace_id do
        Keyword.put(query, :filter, workspace_id: workspace_id)
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
      if content_type = params["content_type"] do
        existing_filter = Keyword.get(query, :filter, [])
        updated_filter = Keyword.put(existing_filter, :content_type, content_type)
        Keyword.put(query, :filter, updated_filter)
      else
        query
      end

    query =
      if tags = params["tags"] do
        tag_list = String.split(tags, ",")
        existing_filter = Keyword.get(query, :filter, [])
        updated_filter = Keyword.put(existing_filter, :tags, tag_list)
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

  # These functions would need to be implemented based on your specific document actions
  defp get_file_content(file, _version, _actor, _tenant) do
    # Just return the file content directly
    {:ok, file.content || ""}
  end

  defp update_file_content(file, content, _commit_message, actor, tenant) do
    # For now, use the generic update function with content
    Workspaces.update_file(
      file,
      %{content: content},
      actor: actor,
      tenant: tenant
    )
  end

  defp get_file_versions(file, _actor, _tenant) do
    # This would need to be implemented based on your versioning system
    # For now, return an empty list or basic version info
    {:ok,
     [
       %{
         id: 1,
         created_at: file.updated_at,
         commit_message: "Current version",
         author: "current_user"
       }
     ]}
  end

  defp render_file_as(file, format, _options, _actor, _tenant) do
    # Basic rendering - this would need proper implementation
    case {file.content_type, format} do
      {"text/markdown", :html} ->
        # Would use a markdown renderer
        {:ok, "<p>Rendered markdown content</p>"}

      {"text/plain", :html} ->
        {:ok, "<pre>#{file.content || "No content"}</pre>"}

      _ ->
        {:ok, file.content || "No content available"}
    end
  end

  defp upload_document(params, actor, tenant) do
    # This would handle file upload processing
    Workspaces.create_file(
      params,
      actor: actor,
      tenant: tenant
    )
  end

  defp rename_file(file, new_title, commit_message, actor, tenant) do
    Workspaces.update_file(
      file,
      %{name: new_title, metadata: %{commit_message: commit_message}},
      actor: actor,
      tenant: tenant
    )
  end

  defp record_file_view(file, actor, tenant) do
    # Update view count and last viewed timestamp
    current_count = file.view_count || 0

    Workspaces.update_file(
      file,
      %{
        view_count: current_count + 1,
        last_viewed_at: DateTime.utc_now()
      },
      actor: actor,
      tenant: tenant
    )
  end
end
