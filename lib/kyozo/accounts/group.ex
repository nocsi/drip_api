# lib/helpcenter/accounts/group.ex
defmodule Kyozo.Accounts.Group do
  use Ash.Resource,
    domain: Kyozo.Accounts,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub

  postgres do
    table "groups"
    repo Kyozo.Repo
  end

  actions do
    default_accept [:name, :description]
    defaults [:create, :read, :update, :destroy]
  end

  # Confirm how Ash will wor
  pub_sub do
    module KyozoWeb.Endpoint

    prefix "groups"

    publish_all :update, [[:id, nil]]
    publish_all :create, [[:id, nil]]
    publish_all :destroy, [[:id, nil]]
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

    attribute :name, :string do
      description "Group name unique name"
      allow_nil? false
    end

    attribute :description, :string do
      description "Describes the intention of the group"
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    many_to_many :users, Kyozo.Accounts.User do
      through Kyozo.Accounts.UserGroup
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :user_id
    end

    # lib/helpcenter/accounts/group.ex
    has_many :permissions, Kyozo.Accounts.GroupPermission do
      description "List of permission assigned to this group"
      destination_attribute :group_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
