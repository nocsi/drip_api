defmodule Kyozo.Containers.Changes.SetTeamFromWorkspace do
  @moduledoc """
  Sets the team_id from the associated workspace.

  This change ensures that container resources inherit the team membership
  from their parent workspace, maintaining proper multitenancy isolation.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :workspace_id) do
      nil ->
        changeset

      workspace_id ->
        workspace = Kyozo.Workspaces.get!(workspace_id, load: [:team])
        Ash.Changeset.change_attribute(changeset, :team_id, workspace.team_id)
    end
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end
end
