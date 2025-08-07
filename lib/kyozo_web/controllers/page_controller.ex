defmodule KyozoWeb.PageController do
  use KyozoWeb, :controller

  @env Mix.env()

  def home(conn, _) do
    case get_session(conn, :user_id) do
      nil -> maybe_put_development_users(conn) |> render(:home, layout: false)
      _ -> redirect(conn, to: ~p"/profile")
    end
  end

  def workspaces(conn, _params) do
    current_user = conn.assigns[:current_user]
    
    if current_user do
      # Load user's teams for the Svelte app
      teams = case Kyozo.Workspaces.list_user_teams(actor: current_user) do
        {:ok, teams} -> teams
        _ -> []
      end
      
      conn
      |> assign(:current_user, current_user)
      |> assign(:teams, teams)
      |> assign(:page_title, "Workspaces")
      |> render(:workspaces, layout: {KyozoWeb.Layouts, :app})
    else
      redirect(conn, to: ~p"/login")
    end
  end

  def teams(conn, _params) do
    current_user = conn.assigns[:current_user]
    
    if current_user do
      # Load user's teams for the Svelte app
      teams = case Kyozo.Workspaces.list_user_teams(actor: current_user) do
        {:ok, teams} -> teams
        _ -> []
      end
      
      conn
      |> assign(:current_user, current_user)
      |> assign(:teams, teams)
      |> assign(:page_title, "Teams")
      |> render(:teams, layout: {KyozoWeb.Layouts, :app})
    else
      redirect(conn, to: ~p"/login")
    end
  end

  def maybe_put_development_users(conn) do
    users = if @env == :dev do
      Application.get_env(:kyozo, :session)[:dev_users]
      |> Enum.map(&Kyozo.Accounts.get_by(email: to_string(&1)))
    end

    assign(conn, :dev_users, users)
  end
end
