defmodule DirupWeb.Live.Auth.SignInLive do
  use DirupWeb, :live_view

  on_mount {DirupWeb.LiveUserAuth, :live_no_user}

  @impl true
  def mount(_params, _session, socket) do
    # Redirect to built-in AshAuthentication sign-in route
    {:ok, push_navigate(socket, to: "/auth/sign_in")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Redirecting to sign in...</div>
    """
  end
end
