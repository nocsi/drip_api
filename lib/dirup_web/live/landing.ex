defmodule DirupWeb.Live.Landing do
  use DirupWeb, :live_view

  on_mount {DirupWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :env, Application.get_env(:dirup, :env, :dev))}
  end

  @impl true
  def handle_event("newsletter_subscribe", %{"email" => email}, socket) do
    # Here you can integrate with your email service (e.g., Mailchimp, ConvertKit, etc.)
    # For now, we'll just simulate a successful subscription

    case validate_email(email) do
      {:ok, _email} ->
        # TODO: Integrate with actual newsletter service
        # Example: MyApp.Newsletter.subscribe(email)

        {:reply, %{success: true}, socket}

      {:error, reason} ->
        {:reply, %{success: false, error: reason}, socket}
    end
  end

  defp validate_email(email) when is_binary(email) do
    if String.contains?(email, "@") and String.length(email) > 3 do
      {:ok, email}
    else
      {:error, "Please enter a valid email address"}
    end
  end

  defp validate_email(_), do: {:error, "Please enter a valid email address"}

  @impl true
  def render(assigns) do
    ~H"""
    <.svelte
      name="LandingPage"
      props={%{}}
    />
    """
  end
end
