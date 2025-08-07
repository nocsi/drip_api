defmodule Kyozo.Accounts.User.Notifiers.CreatePersonalTeamNotification do
  alias Ash.Notifier.Notification
  use Ash.Notifier

  def notify(%Notification{data: user, action: %{name: :register_with_password}}) do
    create_personal_team(user)
  end

  def notify(%Notification{} = _notification), do: :ok

  defp create_personal_team(user) do
    # Determine the count of existing team and use it as a
    # suffix to the team domain.
    team_count = Ash.count!(Kyozo.Accounts.Team, authorize?: false) + 1

    team_attrs = %{
      name: "Personal Team",
      domain: "personal_team_#{team_count}",
      description: "Personal workspace for #{user.name}",
      owner_user_id: user.id
    }

    # Create team without authorization since this is a system operation
    case Ash.create(Kyozo.Accounts.Team, team_attrs, authorize?: false) do
      {:ok, team} ->
        # Create the user team membership
        user_team_attrs = %{
          user_id: user.id,
          team_id: team.id,
          role: "owner"
        }
        
        Ash.create!(Kyozo.Accounts.UserTeam, user_team_attrs, authorize?: false)
        team

      {:error, error} ->
        # Log error but don't fail user registration
        require Logger
        Logger.error("Failed to create personal team for user #{user.id}: #{inspect(error)}")
        nil
    end
  end
end
