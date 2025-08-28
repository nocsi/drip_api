defmodule DirupWeb.Webhooks.AppleController do
  use DirupWeb, :controller
  require Logger

  def webhook(conn, params) do
    Logger.info("Apple webhook received: #{inspect(params)}")

    conn
    |> put_status(:ok)
    |> json(%{status: "received"})
  end
end
