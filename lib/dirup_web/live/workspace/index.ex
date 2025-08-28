defmodule DirupWeb.Live.Workspace.Index do
  @moduledoc """
  This module is responsible for the workspaces page.
  """
  use DirupWeb, :live_view

  import DirupWeb.Components.Button
  import DirupWeb.Components.Modal

  alias Dirup.Workspaces
  alias Dirup.Workspaces.Workspace

  on_mount {DirupWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_, _, socket) do
    user = socket.assigns.current_user

    # Load user with teams if not already loaded
    user_with_teams =
      if user && (!user.teams || match?(%Ash.NotLoaded{}, user.teams)) do
        try do
          Dirup.Accounts.User
          |> Ash.get!(user.id, load: [:teams], actor: user, domain: Dirup.Accounts)
        rescue
          _ -> user
        end
      else
        socket
        |> assign(:user, user)
      end

    # Get teams from the loaded user
    teams =
      if user_with_teams && user_with_teams.teams do
        case user_with_teams.teams do
          %Ash.NotLoaded{} -> []
          teams when is_list(teams) -> teams
          _ -> []
        end
      else
        []
      end

    # Get workspaces for the first team
    workspaces =
      if teams != [] && length(teams) > 0 do
        team = List.first(teams)

        try do
          # Try to get workspaces using the team as tenant
          case Dirup.Workspaces.list_active_workspaces(actor: user_with_teams, tenant: team) do
            {:ok, ws} -> ws
            _ -> []
          end
        rescue
          _ -> []
        end
      else
        []
      end

    socket =
      assign(socket,
        current_user: user_with_teams,
        teams: teams,
        current_team: List.first(teams),
        workspaces: workspaces
      )
      |> stream(:workspaces, workspaces)

    # Subscribe to updates if connected and has a team
    if connected?(socket) && socket.assigns.current_team do
      try do
        Phoenix.PubSub.subscribe(Dirup.PubSub, "workspace:#{socket.assigns.current_team.id}")
      rescue
        _ -> nil
      end
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _) do
    workspace = %Workspace{team_id: socket.assigns.current_team && socket.assigns.current_team.id}
    assign(socket, workspace: workspace)
  end

  defp apply_action(socket, action, %{"id" => id})
       when action in [:edit, :delete] do
    try do
      case Dirup.Workspaces.get_workspace(id, actor: socket.assigns.current_user) do
        {:ok, workspace} ->
          assign(socket, workspace: workspace)

        {:error, _} ->
          socket
          |> put_flash(:error, "Workspace not found")
          |> push_patch(to: ~p"/workspaces")
      end
    rescue
      _ ->
        socket
        |> put_flash(:error, "Failed to load workspace")
        |> push_patch(to: ~p"/workspaces")
    end
  end

  defp apply_action(socket, _, _) do
    socket
  end

  @impl true
  def handle_event("delete_workspace", %{"id" => id}, socket) do
    try do
      case Dirup.Workspaces.delete_workspace(id, actor: socket.assigns.current_user) do
        {:ok, workspace} ->
          socket =
            stream_delete(socket, :workspaces, workspace)
            |> put_flash(:info, "Workspace deleted successfully")
            |> push_patch(to: ~p"/workspaces")

          {:noreply, socket}

        {:error, _} ->
          socket =
            put_flash(socket, :error, "Failed to delete workspace")

          {:noreply, socket}
      end
    rescue
      _ ->
        socket =
          put_flash(socket, :error, "An error occurred while deleting workspace")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("archive_workspace", %{"id" => id}, socket) do
    try do
      case Dirup.Workspaces.archive_workspace(id, actor: socket.assigns.current_user) do
        {:ok, workspace} ->
          socket =
            stream_delete(socket, :workspaces, workspace)
            |> put_flash(:info, "Workspace archived successfully")

          {:noreply, socket}

        {:error, _} ->
          socket =
            put_flash(socket, :error, "Failed to archive workspace")

          {:noreply, socket}
      end
    rescue
      _ ->
        socket =
          put_flash(socket, :error, "An error occurred while archiving workspace")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("duplicate_workspace", %{"id" => id}, socket) do
    try do
      case Dirup.Workspaces.get_workspace(id, actor: socket.assigns.current_user) do
        {:ok, workspace} ->
          case Dirup.Workspaces.duplicate_workspace(
                 workspace,
                 new_name: nil,
                 copy_to_team_id: socket.assigns.current_team.id,
                 include_documents: true,
                 include_notebooks: true,
                 actor: socket.assigns.current_user,
                 tenant: socket.assigns.current_team
               ) do
            {:ok, duplicate_workspace} ->
              socket =
                stream_insert(socket, :workspaces, duplicate_workspace)
                |> put_flash(:info, "Workspace duplicated successfully")

              {:noreply, socket}

            {:error, _} ->
              socket =
                put_flash(socket, :error, "Failed to duplicate workspace")

              {:noreply, socket}
          end

        {:error, _} ->
          socket =
            put_flash(socket, :error, "Workspace not found")

          {:noreply, socket}
      end
    rescue
      _ ->
        socket =
          put_flash(socket, :error, "An error occurred while duplicating workspace")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({DirupWeb.Live.Workspace.Form, {:saved, workspace}}, socket) do
    socket = stream_insert(socket, :workspaces, workspace)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:workspace_created, workspace}, socket) do
    if workspace.team_id == socket.assigns.current_team.id do
      socket = stream_insert(socket, :workspaces, workspace)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:workspace_updated, workspace}, socket) do
    if workspace.team_id == socket.assigns.current_team.id do
      socket = stream_insert(socket, :workspaces, workspace)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:workspace_deleted, workspace}, socket) do
    socket = stream_delete(socket, :workspaces, workspace)
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
