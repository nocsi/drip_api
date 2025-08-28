defmodule DirupWeb.ScanSocket do
  @moduledoc """
  WebSocket socket for SafeMD streaming markdown analysis.

  Handles authentication and channel routing for real-time
  markdown scanning operations.
  """

  use Phoenix.Socket

  ## Channels
  channel "scan:*", DirupWeb.ScanChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_socket_token(token) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:user, user)
          |> assign(:token, token)

        {:ok, socket}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(socket) do
    "scan_socket:#{socket.assigns.user.id}"
  end

  # Private functions

  defp verify_socket_token("stream_token_" <> token_data) do
    # In production, this would verify against your token store
    # For development, accept basic format validation
    if String.length(token_data) > 10 do
      {:ok,
       %{
         id: 1,
         email: "test@example.com",
         tier: "pro"
       }}
    else
      {:error, "Invalid token format"}
    end
  end

  defp verify_socket_token(token) do
    # Try to verify as API token
    case verify_api_token(token) do
      {:ok, user} -> {:ok, user}
      :error -> {:error, "Invalid authentication token"}
    end
  end

  defp verify_api_token("test_token_123") do
    {:ok,
     %{
       id: 1,
       email: "test@example.com",
       tier: "pro"
     }}
  end

  defp verify_api_token(_token) do
    :error
  end
end
