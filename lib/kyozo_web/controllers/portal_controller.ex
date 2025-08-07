defmodule KyozoWeb.PortalController do
  use KyozoWeb, :controller

  # Ensure Jason encoder for Ash.NotLoaded is loaded
  require KyozoWeb.JasonEncoders

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    
    # Load teams with basic error handling
    teams = case Kyozo.Accounts.list_user_teams(actor: current_user) do
      {:ok, teams} -> teams
      {:error, _} -> []
      teams when is_list(teams) -> teams
      _ -> []
    end
    
    # Load invitations with basic error handling
    invitations = case Kyozo.Accounts.list_received_invitations(actor: current_user) do
      {:ok, invitations} -> invitations
      {:error, _} -> []
      invitations when is_list(invitations) -> invitations
      _ -> []
    end

    conn
    |> Plug.Conn.assign(:teams, teams)
    |> Plug.Conn.assign(:invitations, invitations)
    |> render(:index)
  end
end