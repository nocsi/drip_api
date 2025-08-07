defmodule KyozoWeb.API.TeamsController do
  use KyozoWeb, :controller

  alias Kyozo.Accounts
  alias Kyozo.Workspaces

  action_fallback KyozoWeb.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, teams} <- Accounts.list_user_teams(actor: current_user) do
      render(conn, :index, teams: teams)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, team} <- Accounts.get_team(id, actor: current_user, load: [:user_teams, :invitations]) do
      render(conn, :show, team: team)
    end
  end

  def create(conn, %{"team" => team_params}) do
    current_user = conn.assigns.current_user

    with {:ok, team} <- Accounts.create_team(team_params, actor: current_user) do
      conn
      |> put_status(:created)
      |> render(:show, team: team)
    end
  end

  def update(conn, %{"id" => id, "team" => team_params}) do
    current_user = conn.assigns.current_user

    with {:ok, team} <- Accounts.update_team(id, team_params, actor: current_user) do
      render(conn, :show, team: team)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, _team} <- Accounts.delete_team(id, actor: current_user) do
      send_resp(conn, :no_content, "")
    end
  end

  def members(conn, %{"team_id" => team_id}) do
    current_user = conn.assigns.current_user

    with {:ok, members} <- Accounts.list_team_members(actor: current_user, tenant: team_id) do
      render(conn, :members, members: members)
    end
  end

  def invite_member(conn, %{"team_id" => team_id, "invitation" => invitation_params}) do
    current_user = conn.assigns.current_user

    with {:ok, invitation} <- Accounts.invite_user(invitation_params, actor: current_user, tenant: team_id) do
      conn
      |> put_status(:created)
      |> render(:invitation, invitation: invitation)
    end
  end

  def remove_member(conn, %{"team_id" => team_id, "member_id" => member_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _} <- Accounts.remove_team_member(%{id: member_id}, actor: current_user, tenant: team_id) do
      send_resp(conn, :no_content, "")
    end
  end

  def update_member_role(conn, %{"team_id" => team_id, "member_id" => member_id, "role" => role}) do
    current_user = conn.assigns.current_user

    with {:ok, member} <- Accounts.change_member_role(%{id: member_id, role: role}, actor: current_user, tenant: team_id) do
      render(conn, :member, member: member)
    end
  end

  def invitations(conn, %{"team_id" => team_id}) do
    current_user = conn.assigns.current_user

    with {:ok, invitations} <- Accounts.list_invitations_sent(actor: current_user, tenant: team_id) do
      render(conn, :invitations, invitations: invitations)
    end
  end

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _invitation} <- Accounts.accept_invitation(%{id: invitation_id}, actor: current_user) do
      send_resp(conn, :no_content, "")
    end
  end

  def decline_invitation(conn, %{"invitation_id" => invitation_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _invitation} <- Accounts.decline_invitation(%{id: invitation_id}, actor: current_user) do
      send_resp(conn, :no_content, "")
    end
  end

  def cancel_invitation(conn, %{"team_id" => team_id, "invitation_id" => invitation_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _invitation} <- Accounts.cancel_invitation(%{id: invitation_id}, actor: current_user, tenant: team_id) do
      send_resp(conn, :no_content, "")
    end
  end

  def workspaces(conn, %{"team_id" => team_id}) do
    current_user = conn.assigns.current_user

    with {:ok, workspaces} <- Workspaces.list_workspaces(actor: current_user, tenant: team_id) do
      render(conn, :workspaces, workspaces: workspaces)
    end
  end
end