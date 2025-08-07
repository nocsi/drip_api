# lib/helpcenter/accounts/user_group.ex
defmodule Kyozo.Accounts.UserGroup do
  use Ash.Resource,
    domain: Kyozo.Accounts,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub

  postgres do
    table "user_groups"
    repo Kyozo.Repo
  end

  actions do
    default_accept [:user_id, :group_id]
    defaults [:create, :read, :update, :destroy]
  end

  preparations do
    prepare Kyozo.Preparations.SetTenant
  end

  changes do
    change Kyozo.Changes.SetTenant
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :group, Kyozo.Accounts.Group do
      description "Relationshp with a group inside a tenant"
      source_attribute :group_id
      allow_nil? false
    end

    belongs_to :user, Kyozo.Accounts.User do
      description "Permission for the user access group"
      source_attribute :user_id
      allow_nil? false
    end
  end

  identities do
    identity :unique_name, [:group_id, :user_id]
  end
end
