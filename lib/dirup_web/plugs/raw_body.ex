defmodule DirupWeb.Plugs.RawBody do
  @moduledoc """
  A plug to store the raw body of a request for webhook signature verification.

  This plug is essential for Stripe webhooks which require the raw body
  to verify the signature sent in the stripe-signature header.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.method do
      "POST" ->
        parse_raw_body(conn)

      _ ->
        conn
    end
  end

  defp parse_raw_body(conn) do
    case read_body(conn) do
      {:ok, body, conn} ->
        conn
        |> assign(:raw_body, body)

      {:more, _partial_body, conn} ->
        # Handle cases where body is too large
        conn
        |> put_status(:request_entity_too_large)
        |> halt()

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> assign(:raw_body_error, reason)
    end
  end
end
