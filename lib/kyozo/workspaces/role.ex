defmodule Kyozo.Workspaces.Role do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "roles"
    repo Kyozo.Repo
  end

  attributes do
    attribute :name, :string do
      primary_key? true
      allow_nil? false
      public? true
    end
  end

  relationships do
    has_many :team_members, Kyozo.Accounts.UserTeam do
      source_attribute :name
      destination_attribute :role
    end
  end
end
