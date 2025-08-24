defmodule KyozoWeb.Plugs.WebhookBodyReader do
  @moduledoc """
  Captures raw body for webhook signature verification.
  Required for Stripe webhooks.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        conn
        |> Plug.Conn.assign(:raw_body, body)
        |> Plug.Conn.put_private(:raw_body_read, body)

      {:more, _partial, conn} ->
        # Body too large, skip
        conn

      {:error, _reason} ->
        conn
    end
  end
end

# Add to endpoint.ex before Plug.Parsers:
# plug KyozoWeb.Plugs.WebhookBodyReader, only: ["/webhooks/stripe"]

# # Or in router.ex:
# defmodule KyozoWeb.Router do
#   pipeline :webhook do
#     plug KyozoWeb.Plugs.WebhookBodyReader
#     plug :accepts, ["json"]
#   end

#   scope "/webhooks", KyozoWeb do
#     pipe_through :webhook

#     post "/stripe", WebhookController, :stripe
#   end
# end
