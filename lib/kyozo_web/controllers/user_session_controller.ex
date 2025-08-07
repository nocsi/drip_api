defmodule KyozoWeb.UserSessionController do
  use KyozoWeb, :controller
  use Phoenix.LiveView, layout: {KyozoWeb.Layouts, :app}

  alias Kyozo.Accounts
  alias KyozoWeb.UserAuth

  def new(conn, _params) do
    live_render(
    conn,
    KyozoWeb.Live.Editor,
      id: "editor",

      session: %{"user_id" => nil},
      container: {:div, class: "contents"}
    )
  end

  def create(conn, params) do
    case Accounts.sign_in_with_password(params, authorize?: false) do
      {:ok, user} ->
        UserAuth.log_in(conn, user)

      {:error, _error} ->
        conn
        # |> put_flash(:error, "Invalid email or password.")
        |> push_redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    UserAuth.log_out(conn)
  end
end
