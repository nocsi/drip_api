defmodule Kyozo.Accounts do
  use Ash.Domain, otp_app: :kyozo

  # GraphQL configuration removed during GraphQL cleanup

  resources do
    resource Kyozo.Accounts.Token

    resource Kyozo.Accounts.Team do
      define :create_team, action: :create
      define :list_user_teams
      define :update_team
      define :delete_team, action: :destroy
      define :get_team, action: :read
    end

    resource Kyozo.Accounts.UserTeam do
      define :add_team_member
      define :list_team_members
      define :change_member_role
      define :remove_team_member
      define :leave_team
      define :is_member?
    end

    resource Kyozo.Accounts.Invitation do
      define :invite_user
      define :list_received_invitations
      define :list_invitations_sent
      define :accept_invitation
      define :decline_invitation
      define :cancel_invitation
    end

    resource Kyozo.Accounts.Group
    resource Kyozo.Accounts.GroupPermission
    resource Kyozo.Accounts.UserGroup

    resource Kyozo.Accounts.User do
      define :register_with_password

      define :register_user,
        action: :register_with_password,
        args: [:name, :email, :password, :password_confirmation]

      define :sign_in_with_password
      define :search_users
      define :get_user_by_email, action: :get_by_email, args: [:email]
      define :get_user, action: :read, get_by: :id
      define :update_user, action: :update
      define :list_users, action: :read
    end

    resource Kyozo.Accounts.UserIdentity

    resource Kyozo.Accounts.Notification do
      define :notifications_for_user, action: :for_user
      define :dismiss_notification, action: :destroy
      define :notifiy, action: :create
    end

    resource Kyozo.Accounts.ApiKey
  end

  def confirm_user(token) do
    Kyozo.Accounts.User
    |> AshAuthentication.Info.strategy!(:confirm_new_user)
    |> AshAuthentication.AddOn.Confirmation.Actions.confirm(%{"confirm" => token})
  end

  def generate_new_user_confirmation_token(user) do
    now = DateTime.utc_now()
    changeset = Ash.Changeset.for_update(user, :update, %{"confirmed_at" => now})

    Kyozo.Accounts.User
    |> AshAuthentication.Info.strategy!(:confirm_new_user)
    |> AshAuthentication.AddOn.Confirmation.confirmation_token(changeset, user)
  end
end
