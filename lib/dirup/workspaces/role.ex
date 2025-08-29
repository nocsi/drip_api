defmodule Dirup.Workspaces.Role do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Workspaces,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "roles"
    repo Dirup.Repo
  end

  code_interface do
    define :create
    define :read
    define :get, args: [:name], get?: true
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :get do
      argument :name, :string do
        allow_nil? false
      end

      get? true
      filter expr(name == ^arg(:name))
    end
  end

  attributes do
    attribute :name, :string do
      primary_key? true
      allow_nil? false
      public? true
    end
  end

  relationships do
    has_many :team_members, Dirup.Accounts.UserTeam do
      source_attribute :name
      destination_attribute :role
    end
  end
end
