defmodule KyozoWeb.TenantAuth do
  use KyozoWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  import KyozoWeb.Serializers

  alias Kyozo.Workspace

  def ensure_tenant(conn, _opts) do
    with team_id when not is_nil(team_id) <- get_session(conn, :team_id),
         {:ok, team} <- Workspace.get_team(team_id, actor: conn.assigns.current_user) do
      conn
      |> assign(:current_team, team)
      # |> assign_prop(:current_team, serialize_team(team))
    else
      _ ->
        conn
        |> delete_session(:team_id)
        |> redirect(to: ~p"/portal")
        |> halt()
    end
  end

  def load_user_membership_data(conn, _opts) do
    current_team = conn.assigns.current_team
    current_user = conn.assigns.current_user

    current_user_with_membership =
      Ash.load!(current_user, [:role, :membership_id], tenant: current_team)

    conn
    |> assign(:current_user, current_user_with_membership)
    # |> assign_prop(:current_user, serialize_user_with_membership(current_user_with_membership))
  end

  def set_permissions(conn, _opts) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    permissions = %{
      can_invite_user: Workspace.can_invite_user?(current_user, tenant: current_team),
      can_delete_team: Workspace.can_delete_team?(current_user, current_team)
    }

    conn
    # |> assign_prop(:permissions, permissions)
  end
end
