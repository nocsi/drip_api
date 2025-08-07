defmodule Kyozo.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email
  """

  use AshAuthentication.Sender
  use KyozoWeb, :verified_routes

  import Swoosh.Email
  alias Kyozo.Mailer

  @impl true
  def send(user_or_email, token, _) do
    # if you get a user, its for a user that already exists.
    # if you get an email, then the user does not yet exist.
    Kyozo.Accounts.Emails.deliver_magic_link(
          user_or_email,
          url(~p"/auth/user/magic_link/?token=#{token}")
        )
  end

end
