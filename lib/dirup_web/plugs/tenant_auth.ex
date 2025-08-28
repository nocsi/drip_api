defmodule DirupWeb.Plugs.TenantAuth do
  @moduledoc """
  Plugs for handling tenant (team) authentication and authorization.
  This module provides functions to load and authorize team-based access.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Dirup.Workspaces

  @doc """
  Loads the current team from the session or params and assigns it as tenant.
  If no team is found, redirects to portal.
  """
  def ensure_tenant(conn, _opts) do
    team_id = get_team_id(conn)
    current_user = conn.assigns[:current_user]

    cond do
      is_nil(team_id) ->
        conn
        |> put_flash(:error, "No team selected. Please select a team first.")
        |> redirect(to: "/portal")
        |> halt()

      is_nil(current_user) ->
        conn
        |> put_flash(:error, "Authentication required.")
        |> redirect(to: "/login")
        |> halt()

      true ->
        case load_team(team_id, current_user) do
          {:ok, team} ->
            conn
            |> assign(:current_team, team)
            |> assign(:tenant, team)

          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Team not found.")
            |> redirect(to: "/portal")
            |> halt()

          {:error, :forbidden} ->
            conn
            |> put_flash(:error, "You don't have access to this team.")
            |> redirect(to: "/portal")
            |> halt()
        end
    end
  end

  @doc """
  Loads user membership data for the current team including roles and permissions.
  Must be called after ensure_tenant.
  """
  def load_user_membership_data(conn, _opts) do
    current_user = conn.assigns[:current_user]
    current_team = conn.assigns[:current_team]

    case get_user_membership(current_user.id, current_team.id, current_user, current_team) do
      {:ok, membership} ->
        conn
        |> assign(:current_membership, membership)
        |> assign(:user_role, membership.role)

      {:error, _} ->
        conn
        |> put_flash(:error, "Unable to load membership data.")
        |> redirect(to: "/portal")
        |> halt()
    end
  end

  @doc """
  Sets permissions based on user role in the current team.
  Must be called after load_user_membership_data.
  """
  def set_permissions(conn, _opts) do
    user_role = conn.assigns[:user_role]

    permissions = %{
      can_manage_team: user_role in ["admin", "owner"],
      can_invite_users: user_role in ["admin", "owner", "manager"],
      can_manage_workspaces: user_role in ["admin", "owner", "manager"],
      can_delete_content: user_role in ["admin", "owner", "manager"],
      can_view_analytics: user_role in ["admin", "owner"]
    }

    assign(conn, :permissions, permissions)
  end

  @doc """
  Requires admin or owner role for the current team.
  """
  def require_admin(conn, _opts) do
    user_role = conn.assigns[:user_role]

    if user_role in ["admin", "owner"] do
      conn
    else
      conn
      |> put_flash(:error, "Admin access required.")
      |> redirect(to: "/portal")
      |> halt()
    end
  end

  @doc """
  Requires manager, admin, or owner role for the current team.
  """
  def require_manager(conn, _opts) do
    user_role = conn.assigns[:user_role]

    if user_role in ["manager", "admin", "owner"] do
      conn
    else
      conn
      |> put_flash(:error, "Manager access required.")
      |> redirect(to: "/portal")
      |> halt()
    end
  end

  @doc """
  Sets the team ID in the session. Used when entering a workspace.
  """
  def set_current_team(conn, team_id) when is_binary(team_id) do
    put_session(conn, :current_team_id, team_id)
  end

  @doc """
  Clears the current team from the session.
  """
  def clear_current_team(conn) do
    delete_session(conn, :current_team_id)
  end

  @doc """
  For API requests, load tenant from team_id parameter or header.
  """
  def load_api_tenant(conn, _opts) do
    current_user = conn.assigns[:current_user]
    team_id = get_api_team_id(conn)

    cond do
      is_nil(current_user) ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Authentication required"})
        |> halt()

      is_nil(team_id) ->
        conn
        |> put_status(:bad_request)
        |> Phoenix.Controller.json(%{error: "Team ID required"})
        |> halt()

      true ->
        case load_team(team_id, current_user) do
          {:ok, team} ->
            conn
            |> assign(:current_team, team)
            |> assign(:tenant, team)

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> Phoenix.Controller.json(%{error: "Team not found"})
            |> halt()

          {:error, :forbidden} ->
            conn
            |> put_status(:forbidden)
            |> Phoenix.Controller.json(%{error: "Access denied"})
            |> halt()
        end
    end
  end

  # Private functions

  defp get_team_id(conn) do
    # Try multiple sources for team ID
    conn.params["team_id"] ||
      get_session(conn, :current_team_id) ||
      get_req_header(conn, "x-team-id") |> List.first()
  end

  defp get_api_team_id(conn) do
    # For API requests, prefer header or param
    get_req_header(conn, "x-team-id") |> List.first() ||
      conn.params["team_id"]
  end

  defp load_team(team_id, current_user) do
    try do
      # Check if user is a member of this team
      case Workspaces.get_team(team_id, actor: current_user) do
        {:ok, team} ->
          {:ok, team}

        {:error, %Ash.Error.Forbidden{}} ->
          {:error, :forbidden}

        {:error, %Ash.Error.Query.NotFound{}} ->
          {:error, :not_found}

        {:error, _} ->
          {:error, :not_found}
      end
    rescue
      _ ->
        {:error, :not_found}
    end
  end

  defp get_user_membership(user_id, team_id, current_user, current_team) do
    try do
      case Workspaces.get_member(user_id, team_id, actor: current_user, tenant: current_team) do
        {:ok, membership} ->
          {:ok, membership}

        {:error, _} ->
          {:error, :not_found}
      end
    rescue
      _ ->
        {:error, :not_found}
    end
  end
end
