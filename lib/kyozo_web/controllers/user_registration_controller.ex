defmodule KyozoWeb.UserRegistrationController do
  use KyozoWeb, :controller

  alias KyozoWeb.UserAuth
  alias Kyozo.Accounts

  def new(conn, _params) do
    render(conn, "Register")
  end

  def create(conn, params) do
    case Accounts.register_with_password(params, authorize?: false) do
      {:ok, user} ->
        UserAuth.log_in(conn, user)

      {:error, error} ->
        conn
        # |> assign_errors(error)
        |> redirect(to: ~p"/register")
    end
  end
end
