defmodule DirupWeb.AuthPlug do
  use AshAuthentication.Plug,
    otp_app: :dirup,
    domain: :user

  require Logger

  def handle_success(conn, {strategy, phase}, nil, nil) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(
      200,
      Jason.encode!(%{status: :success, strategy: strategy, phase: phase})
    )
  end

  def handle_success(conn, {strategy, phase}, user, token) do
    Logger.debug("Auth success - Strategy: #{inspect(strategy)}")
    Logger.debug("User: #{inspect(user)}")
    Logger.debug("Token: #{inspect(token)}")

    if is_api_request?(conn) do
      conn
      |> assign(:authentication_success, true)
      |> assign(:authentication_token, token)
      |> assign(:current_user, user)
    else
      conn
      |> store_in_session(user)
      |> put_resp_header("content-type", "application/json")
      |> send_resp(
        200,
        Jason.encode!(%{
          status: :success,
          token: token,
          user: Map.take(user, ~w[username id email]a),
          strategy: strategy,
          phase: phase
        })
      )
    end
  end

  def handle_failure(conn, {strategy, phase}, reason) do
    Logger.debug("Auth failure - Strategy: #{inspect(strategy)}")
    Logger.debug("Failure reason: #{inspect(reason)}")

    if is_api_request?(conn) do
      conn
      |> assign(:authentication_success, false)
      |> assign(:authentication_error, reason)
    else
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(
        401,
        Jason.encode!(%{
          status: :failure,
          reason: inspect(reason),
          strategy: strategy,
          phase: phase
        })
      )
    end
  end

  defp is_api_request?(conn) do
    accept = get_req_header(conn, "accept")
    "application/json" in accept || "application/vnd.api+json" in accept
  end
end
