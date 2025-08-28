defmodule DirupWeb.Live.Workspace.Dashboard do
  @moduledoc """
  Workspace dashboard with comprehensive file management capabilities.
  """
  use DirupWeb, :live_view

  import DirupWeb.Components.Button
  import DirupWeb.Components.Modal

  alias Dirup.Workspaces
  alias Dirup.Workspaces.{Workspace, File, Notebook}

  on_mount {DirupWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"id" => workspace_id}, _session, socket) do
    user = socket.assigns.current_user

    case load_workspace_data(workspace_id, user) do
      {:ok, data} ->
        socket =
          assign(socket, data)
          |> assign(
            selected_file: nil,
            current_path: "/",
            file_tree: build_file_tree(data.files ++ data.notebooks),
            breadcrumbs: [%{name: data.workspace.name, path: "/"}],
            # grid or list
            view_mode: "grid",
            # name, date, size, type
            sort_by: "name",
            sort_order: :asc,
            search_query: "",
            show_hidden: false,
            file_content: nil,
            editing_file: nil,
            creating_file: false,
            file_form: nil
          )
          |> stream(:files, data.files ++ data.notebooks)

        if connected?(socket) do
          subscribe_to_workspace_events(workspace_id)
        end

        {:ok, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to load workspace: #{reason}")
          |> push_navigate(to: ~p"/workspaces")

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_dashboard_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_dashboard_action(socket, :show, _params) do
    socket
  end

  defp apply_dashboard_action(socket, :new_file, _params) do
    assign(socket, creating_file: true, file_form: build_file_form())
  end

  defp apply_dashboard_action(socket, :edit_file, %{"file_id" => file_id}) do
    case find_file_by_id(socket.assigns.files, file_id) do
      {:ok, file} ->
        content = load_file_content(file)

        assign(socket,
          editing_file: file,
          file_content: content,
          file_form: build_edit_form(file, content)
        )

      {:error, _} ->
        socket
        |> put_flash(:error, "File not found")
        |> push_patch(to: ~p"/workspaces/#{socket.assigns.workspace.id}/dashboard")
    end
  end

  @impl true
  def handle_event("select_file", %{"id" => file_id}, socket) do
    case find_file_by_id(socket.assigns.files, file_id) do
      {:ok, file} ->
        content = load_file_content(file)
        socket = assign(socket, selected_file: file, file_content: content)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "File not found")}
    end
  end

  def handle_event("navigate_to", %{"path" => path}, socket) do
    breadcrumbs = build_breadcrumbs(path, socket.assigns.workspace.name)
    filtered_files = filter_files_by_path(socket.assigns.files, path)

    socket =
      assign(socket,
        current_path: path,
        breadcrumbs: breadcrumbs,
        selected_file: nil,
        file_content: nil
      )
      |> stream(:files, filtered_files, reset: true)

    {:noreply, socket}
  end

  def handle_event("change_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, view_mode: mode)}
  end

  def handle_event("sort_files", %{"by" => sort_by}, socket) do
    current_order =
      if socket.assigns.sort_by == sort_by do
        if socket.assigns.sort_order == :asc, do: :desc, else: :asc
      else
        :asc
      end

    sorted_files = sort_files(socket.assigns.files, sort_by, current_order)

    socket =
      assign(socket, sort_by: sort_by, sort_order: current_order)
      |> stream(:files, sorted_files, reset: true)

    {:noreply, socket}
  end

  def handle_event("search_files", %{"query" => query}, socket) do
    filtered_files = filter_files_by_search(socket.assigns.files, query)

    socket =
      assign(socket, search_query: query)
      |> stream(:files, filtered_files, reset: true)

    {:noreply, socket}
  end

  def handle_event("create_file", %{"file" => file_params}, socket) do
    workspace = socket.assigns.workspace
    user = socket.assigns.current_user

    case create_file(workspace, file_params, user) do
      {:ok, file} ->
        socket =
          socket
          |> stream_insert(:files, file)
          |> assign(creating_file: false, file_form: nil)
          |> put_flash(:info, "File created successfully")
          |> push_patch(to: ~p"/workspaces/#{workspace.id}/dashboard")

        {:noreply, socket}

      {:error, changeset} ->
        socket = assign(socket, file_form: to_form(changeset))
        {:noreply, socket}
    end
  end

  def handle_event("update_file", %{"file" => file_params}, socket) do
    file = socket.assigns.editing_file
    user = socket.assigns.current_user

    case update_file(file, file_params, user) do
      {:ok, updated_file} ->
        socket =
          socket
          |> stream_insert(:files, updated_file)
          |> assign(editing_file: nil, file_content: nil, file_form: nil)
          |> put_flash(:info, "File updated successfully")
          |> push_patch(to: ~p"/workspaces/#{socket.assigns.workspace.id}/dashboard")

        {:noreply, socket}

      {:error, changeset} ->
        socket = assign(socket, file_form: to_form(changeset))
        {:noreply, socket}
    end
  end

  def handle_event("delete_file", %{"id" => file_id}, socket) do
    case find_file_by_id(socket.assigns.files, file_id) do
      {:ok, file} ->
        case delete_file(file, socket.assigns.current_user) do
          {:ok, _} ->
            socket =
              socket
              |> stream_delete(:files, file)
              |> assign(selected_file: nil, file_content: nil)
              |> put_flash(:info, "File deleted successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete file")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "File not found")}
    end
  end

  def handle_event("create_folder", %{"name" => _folder_name}, socket) do
    # TODO: Implement folder creation
    {:noreply, put_flash(socket, :info, "Folder creation coming soon")}
  end

  def handle_event("upload_file", _params, socket) do
    # TODO: Implement file upload
    {:noreply, put_flash(socket, :info, "File upload coming soon")}
  end

  def handle_event("duplicate_file", %{"id" => file_id}, socket) do
    case find_file_by_id(socket.assigns.files, file_id) do
      {:ok, file} ->
        case duplicate_file(file, socket.assigns.current_user) do
          {:ok, new_file} ->
            socket =
              socket
              |> stream_insert(:files, new_file)
              |> put_flash(:info, "File duplicated successfully")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to duplicate file")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "File not found")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(editing_file: nil, file_content: nil, file_form: nil, creating_file: false)
      |> push_patch(to: ~p"/workspaces/#{socket.assigns.workspace.id}/dashboard")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:file_created, file}, socket) do
    if file.workspace_id == socket.assigns.workspace.id do
      socket = stream_insert(socket, :files, file)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:file_updated, file}, socket) do
    if file.workspace_id == socket.assigns.workspace.id do
      socket = stream_insert(socket, :files, file)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:file_deleted, file}, socket) do
    socket = stream_delete(socket, :files, file)
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # Private functions

  defp load_workspace_data(workspace_id, user) do
    try do
      case Dirup.Workspaces.get_workspace(workspace_id, actor: user, load: [:team, :created_by]) do
        {:ok, workspace} ->
          files = Dirup.Workspaces.list_files(workspace_id: workspace_id, actor: user) || []

          notebooks =
            Dirup.Workspaces.list_notebooks(workspace_id: workspace_id, actor: user) || []

          {:ok,
           %{
             workspace: workspace,
             files: files,
             notebooks: notebooks
           }}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, "Failed to load workspace: #{inspect(error)}"}
    end
  end

  defp subscribe_to_workspace_events(workspace_id) do
    try do
      Phoenix.PubSub.subscribe(Dirup.PubSub, "workspace:#{workspace_id}")
      Phoenix.PubSub.subscribe(Dirup.PubSub, "files:#{workspace_id}")
      Phoenix.PubSub.subscribe(Dirup.PubSub, "notebooks:#{workspace_id}")
    rescue
      _ -> nil
    end
  end

  defp build_file_tree(files) do
    files
    |> Enum.group_by(&get_file_directory/1)
    |> Enum.map(fn {dir, files} ->
      %{
        name: dir || "/",
        path: dir || "/",
        type: "directory",
        children: files
      }
    end)
  end

  defp get_file_directory(file) do
    case file do
      %{file_path: path} when is_binary(path) ->
        path |> Path.dirname() |> normalize_path()

      %{path: path} when is_binary(path) ->
        path |> Path.dirname() |> normalize_path()

      _ ->
        "/"
    end
  end

  defp normalize_path("."), do: "/"
  defp normalize_path(path), do: path

  defp build_breadcrumbs(path, workspace_name) do
    parts = String.split(path, "/", trim: true)

    base = [%{name: workspace_name, path: "/"}]

    {_, breadcrumbs} =
      Enum.reduce(parts, {"/", base}, fn part, {current_path, acc} ->
        new_path = Path.join(current_path, part)
        new_crumb = %{name: part, path: new_path}
        {new_path, acc ++ [new_crumb]}
      end)

    breadcrumbs
  end

  defp filter_files_by_path(files, "/"), do: files

  defp filter_files_by_path(files, path) do
    Enum.filter(files, fn file ->
      file_path = get_file_directory(file)
      String.starts_with?(file_path, path)
    end)
  end

  defp filter_files_by_search(files, ""), do: files

  defp filter_files_by_search(files, query) do
    query_lower = String.downcase(query)

    Enum.filter(files, fn file ->
      name = get_file_name(file) |> String.downcase()
      content = get_file_searchable_content(file) |> String.downcase()

      String.contains?(name, query_lower) or String.contains?(content, query_lower)
    end)
  end

  defp sort_files(files, "name", order) do
    Enum.sort_by(files, &get_file_name/1, order)
  end

  defp sort_files(files, "date", order) do
    Enum.sort_by(files, &get_file_date/1, order)
  end

  defp sort_files(files, "size", order) do
    Enum.sort_by(files, &get_file_size/1, order)
  end

  defp sort_files(files, "type", order) do
    Enum.sort_by(files, &get_file_type/1, order)
  end

  defp sort_files(files, _, _), do: files

  defp get_file_name(file) do
    file.name || file.file_name || file.title || "Untitled"
  end

  defp get_file_date(file) do
    file.updated_at || file.created_at || DateTime.utc_now()
  end

  defp get_file_size(file) do
    file.file_size || 0
  end

  defp get_file_type(file) do
    case file do
      %File{} -> "document"
      %Notebook{} -> "notebook"
      _ -> "unknown"
    end
  end

  defp get_file_searchable_content(file) do
    file.content || file.description || ""
  end

  defp find_file_by_id(files, file_id) do
    case Enum.find(files, &(&1.id == file_id)) do
      nil -> {:error, :not_found}
      file -> {:ok, file}
    end
  end

  defp load_file_content(file) do
    try do
      case file do
        %File{} ->
          case Dirup.Workspaces.get_file_content(file.id) do
            {:ok, content} -> content
            {:error, _} -> ""
          end

        %Notebook{} ->
          case Dirup.Workspaces.get_notebook(file.id, load: [:content]) do
            {:ok, loaded_file} -> loaded_file.content || ""
            {:error, _} -> ""
          end

        _ ->
          ""
      end
    rescue
      _ -> ""
    end
  end

  defp build_file_form() do
    %{
      "name" => "",
      "content" => "",
      "file_type" => "file",
      "path" => "/"
    }
    |> to_form()
  end

  defp build_edit_form(file, content) do
    %{
      "name" => get_file_name(file),
      "content" => content,
      "file_type" => get_file_type(file),
      "path" => get_file_directory(file)
    }
    |> to_form()
  end

  defp create_file(workspace, file_params, user) do
    case file_params["file_type"] do
      "file" ->
        Dirup.Workspaces.create_file(
          Map.merge(file_params, %{
            "workspace_id" => workspace.id,
            "name" => file_params["name"],
            "file_path" => Path.join(file_params["path"] || "/", file_params["name"])
          }),
          actor: user,
          tenant: workspace.team_id
        )

      "notebook" ->
        Dirup.Workspaces.create_from_document(
          Map.merge(file_params, %{
            "workspace_id" => workspace.id,
            "title" => file_params["name"],
            "name" => file_params["name"]
          }),
          actor: user,
          tenant: workspace.team_id
        )

      _ ->
        {:error, "Invalid file type"}
    end
  rescue
    error ->
      {:error, "Failed to create file: #{inspect(error)}"}
  end

  defp update_file(file, file_params, user) do
    try do
      case file do
        %File{} ->
          Dirup.Workspaces.update_file(
            file.id,
            Map.merge(file_params, %{
              "name" => file_params["name"]
            }),
            actor: user
          )

        %Notebook{} ->
          Dirup.Workspaces.update_content(
            file.id,
            Map.merge(file_params, %{
              "title" => file_params["name"],
              "content" => file_params["content"]
            }),
            actor: user
          )

        _ ->
          {:error, "Invalid file type"}
      end
    rescue
      error ->
        {:error, "Failed to update file: #{inspect(error)}"}
    end
  end

  defp delete_file(file, user) do
    try do
      case file do
        %File{} ->
          Dirup.Workspaces.delete_file(file.id, actor: user)

        %Notebook{} ->
          Dirup.Workspaces.destroy_notebook(file.id, actor: user)

        _ ->
          {:error, "Invalid file type"}
      end
    rescue
      error ->
        {:error, "Failed to delete file: #{inspect(error)}"}
    end
  end

  defp duplicate_file(file, user) do
    try do
      content = load_file_content(file)
      new_name = "#{get_file_name(file)} (copy)"

      case file do
        %File{} ->
          Dirup.Workspaces.create_file(
            %{
              "workspace_id" => file.workspace_id,
              "name" => new_name,
              "file_path" => Path.join(get_file_directory(file), new_name)
            },
            actor: user
          )

        %Notebook{} ->
          Dirup.Workspaces.create_from_document(
            %{
              "workspace_id" => file.workspace_id,
              "title" => new_name,
              "name" => new_name,
              "content" => content
            },
            actor: user
          )

        _ ->
          {:error, "Invalid file type"}
      end
    rescue
      error ->
        {:error, "Failed to duplicate file: #{inspect(error)}"}
    end
  end

  # Helper functions for templates
  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "0 B"

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
