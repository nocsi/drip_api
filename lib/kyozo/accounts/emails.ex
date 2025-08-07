defmodule Kyozo.Accounts.Emails do
  use AshAuthentication.Sender
  use KyozoWeb, :verified_routes

  def deliver_magic_link(user, url) do
    if !url do
      raise "Cannot deliver reset instructions without a url"
    end

    email = case user do
      %{email: email} -> email
      email -> email
    end

    # new()
    # # TODO: Replace with your email
    # |> from({"noreply", "noreply@example.com"})
    # |> to(to_string(email))
    # |> subject("Your login link")
    # |> html_body(body(token: token, email: email))
    # |> Mailer.deliver!()

    Mailer.deliver(email, "Magic Link", """
    <html>
      <p>
        Hi #{email},
      </p>

      <p>
        <a href="#{url}">Click here</a> to login.
      </p>
    <html>
    """)
  end
end
