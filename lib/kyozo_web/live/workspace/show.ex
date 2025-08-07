defmodule KyozoWeb.Live.Workspace.Show do
  @moduledoc """
  This module is responsible for showing individual workspace details.
  """
  use KyozoWeb, :live_view

  import KyozoWeb.Components.Button
  import KyozoWeb.Components.Modal

  alias Kyozo.Workspaces
  alias Kyozo.Workspaces.Workspace

  on_mount {KyozoWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"id" => id}, _, socket) do
    user = socket.assigns.current_user
    
    case Kyozo.Workspaces.get_workspace(id, actor: user, load: [:documents, :notebooks, :team, :created_by]) do
      {:ok, workspace} ->
        documents = Kyozo.Workspaces.list_documents(workspace_id: workspace.id, actor: user)
        notebooks = Kyozo.Workspaces.list_notebooks(workspace_id: workspace.id, actor: user)
        
        socket =
          assign(socket,
            workspace: workspace,
            documents: documents,
            notebooks: notebooks
          )
          |> stream(:documents, documents)
          |> stream(:notebooks, notebooks)

        if connected?(socket) do
          Kyozo.Workspaces.subscribe(workspace.team_id)
        end

        {:ok, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "Workspace not found")
          |> push_navigate(to: ~p"/workspaces")

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  @impl true
  def handle_event("delete_document", %{"id" => id}, socket) do
    case Kyozo.Workspaces.delete_document(id, actor: socket.assigns.current_user) do
      {:ok, document} ->
        socket =
          stream_delete(socket, :documents, document)
          |> put_flash(:info, "Document deleted successfully")

        {:noreply, socket}

      {:error, _} ->
        socket =
          put_flash(socket, :error, "Failed to delete document")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_notebook", %{"id" => id}, socket) do
    case Kyozo.Workspaces.destroy_notebook(id, actor: socket.assigns.current_user) do
      {:ok, notebook} ->
        socket =
          stream_delete(socket, :notebooks, notebook)
          |> put_flash(:info, "Notebook deleted successfully")

        {:noreply, socket}

      {:error, _} ->
        socket =
          put_flash(socket, :error, "Failed to delete notebook")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("archive_workspace", _, socket) do
    case Kyozo.Workspaces.archive_workspace(socket.assigns.workspace.id, actor: socket.assigns.current_user) do
      {:ok, _workspace} ->
        socket =
          socket
          |> put_flash(:info, "Workspace archived successfully")
          |> push_navigate(to: ~p"/workspaces")

        {:noreply, socket}

      {:error, _} ->
        socket =
          put_flash(socket, :error, "Failed to archive workspace")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("restore_workspace", _, socket) do
    case Kyozo.Workspaces.restore_workspace(socket.assigns.workspace.id, actor: socket.assigns.current_user) do
      {:ok, workspace} ->
        socket =
          assign(socket, workspace: workspace)
          |> put_flash(:info, "Workspace restored successfully")

        {:noreply, socket}

      {:error, _} ->
        socket =
          put_flash(socket, :error, "Failed to restore workspace")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:document_created, document}, socket) do
    if document.workspace_id == socket.assigns.workspace.id do
      socket = stream_insert(socket, :documents, document)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:document_updated, document}, socket) do
    if document.workspace_id == socket.assigns.workspace.id do
      socket = stream_insert(socket, :documents, document)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:document_deleted, document}, socket) do
    socket = stream_delete(socket, :documents, document)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:notebook_created, notebook}, socket) do
    if notebook.workspace_id == socket.assigns.workspace.id do
      socket = stream_insert(socket, :notebooks, notebook)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:notebook_updated, notebook}, socket) do
    if notebook.workspace_id == socket.assigns.workspace.id do
      socket = stream_insert(socket, :notebooks, notebook)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:notebook_deleted, notebook}, socket) do
    socket = stream_delete(socket, :notebooks, notebook)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:workspace_updated, workspace}, socket) do
    if workspace.id == socket.assigns.workspace.id do
      socket = assign(socket, workspace: workspace)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}
end