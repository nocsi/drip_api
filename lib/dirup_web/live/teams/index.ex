defmodule DirupWeb.Live.Teams.Index do
  @moduledoc """
  This module is responsible for the teams page.
  """
  use DirupWeb, :live_view

  import DirupWeb.Components.Button
  import DirupWeb.Components.Modal

  alias Dirup.Teams
  alias Dirup.Teams.Team

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
        user
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

    socket =
      assign(socket,
        current_user: user_with_teams,
        teams: teams,
        current_team: nil
      )
      |> stream(:teams, teams)

    # Subscribe to team updates if connected
    if connected?(socket) do
      try do
        Phoenix.PubSub.subscribe(Dirup.PubSub, "teams:#{user.id}")
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

  defp apply_action(socket, :index, _) do
    socket
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    try do
      case Teams.get_team(id, actor: socket.assigns.current_user) do
        {:ok, team} ->
          assign(socket, current_team: team)

        {:error, _} ->
          socket
          |> put_flash(:error, "Team not found")
          |> push_patch(to: ~p"/teams")
      end
    rescue
      _ ->
        socket
        |> put_flash(:error, "Failed to load team")
        |> push_patch(to: ~p"/teams")
    end
  end

  defp apply_action(socket, _, _) do
    socket
  end

  @impl true
  def handle_event("select_team", %{"id" => id}, socket) do
    try do
      case Teams.get_team(id, actor: socket.assigns.current_user) do
        {:ok, team} ->
          socket =
            assign(socket, current_team: team)
            |> put_flash(:info, "Team selected: #{team.name}")

          {:noreply, socket}

        {:error, _} ->
          socket =
            put_flash(socket, :error, "Failed to select team")

          {:noreply, socket}
      end
    rescue
      _ ->
        socket =
          put_flash(socket, :error, "An error occurred while selecting team")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("leave_team", %{"id" => id}, socket) do
    try do
      case Teams.leave_team(id, actor: socket.assigns.current_user) do
        {:ok, _} ->
          socket =
            stream_delete_by_dom_id(socket, :teams, "team-#{id}")
            |> put_flash(:info, "Successfully left team")

          {:noreply, socket}

        {:error, _} ->
          socket =
            put_flash(socket, :error, "Failed to leave team")

          {:noreply, socket}
      end
    rescue
      _ ->
        socket =
          put_flash(socket, :error, "An error occurred while leaving team")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:team_created, team}, socket) do
    socket = stream_insert(socket, :teams, team)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:team_updated, team}, socket) do
    socket = stream_insert(socket, :teams, team)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:team_deleted, team}, socket) do
    socket = stream_delete(socket, :teams, team)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_left_team, team_id}, socket) do
    socket = stream_delete_by_dom_id(socket, :teams, "team-#{team_id}")
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
