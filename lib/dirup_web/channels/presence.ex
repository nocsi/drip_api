defmodule DirupWeb.Presence do
  @moduledoc """
  Provides presence tracking to determine which users are online.
  """
  use Phoenix.Presence,
    otp_app: :dirup,
    pubsub_server: Dirup.PubSub
end
