defmodule DirupWeb.JasonEncoders do
  @moduledoc """
  Custom Jason.Encoder implementations for various structs.
  """

  # Implement Jason.Encoder for Ash.NotLoaded to return null instead of failing
  defimpl Jason.Encoder, for: Ash.NotLoaded do
    def encode(_not_loaded, _opts) do
      "null"
    end
  end
end
