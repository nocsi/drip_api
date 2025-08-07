defmodule KyozoWeb.Live.Auth.RegisterLive do
  use KyozoWeb, :live_view

  on_mount {KyozoWeb.LiveUserAuth, :live_no_user}

  @impl true
  def mount(_params, _session, socket) do
    # Redirect to built-in AshAuthentication register route
    {:ok, push_navigate(socket, to: "/auth/sign_in?register=true")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Redirecting to register...</div>
    """
  end
end