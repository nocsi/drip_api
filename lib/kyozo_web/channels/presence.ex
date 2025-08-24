defmodule KyozoWeb.Presence do
  @moduledoc """
  Provides presence tracking to determine which users are online.
  """
  use Phoenix.Presence,
    otp_app: :kyozo,
    pubsub_server: Kyozo.PubSub
end
