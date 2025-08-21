defmodule Kyozo.Containers.Changes.SetTeamFromServiceInstance do
  @moduledoc """
  Change that sets the team_id from the service_instance relationship.

  This change is used to automatically populate the team_id field on deployment
  events by looking up the team_id from the associated service instance.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :service_instance_id) do
      nil ->
        changeset

      service_instance_id ->
        service_instance = Kyozo.Containers.get!(service_instance_id, load: [:team])
        Ash.Changeset.change_attribute(changeset, :team_id, service_instance.team_id)
    end
  end
end
