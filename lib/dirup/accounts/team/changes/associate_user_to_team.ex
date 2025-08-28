defmodule Dirup.Accounts.Team.Changes.AssociateUserToTeam do
  @moduledoc """
  Link user to the team via user_teams relationship so that when
  we are listing owners teams, this team will be listed as well
  """

  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, team ->
      associate_owner_to_team(changeset, team, context)
    end)
  end

  defp associate_owner_to_team(_changeset, team, _context) do
    case team.owner_user_id do
      nil ->
        IO.puts("⚠️  No owner_user_id found on team, skipping team member association")
        {:ok, team}

      owner_user_id ->
        params = %{user_id: owner_user_id, role: "owner"}

        {:ok, _user_team} =
          Dirup.Accounts.UserTeam
          |> Ash.Changeset.for_create(:add_team_member, params)
          |> Ash.create(tenant: team)

        {:ok, team}
    end
  end
end
