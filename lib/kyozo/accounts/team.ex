defmodule Kyozo.Accounts.Team do
  @derive {Jason.Encoder, only: [:id, :name, :domain, :description]}

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer



  postgres do
    table "teams"
    repo Kyozo.Repo

    manage_tenant do
      template ["", :domain]
      create? true
      update? false
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept [:name, :domain, :description]

    create :create do
      primary? true
      accept [:name, :domain, :description, :owner_user_id]
      
      # Set owner_user_id manually since actor context isn't working in seeds
      change Kyozo.Accounts.Team.Changes.AssociateUserToTeam
      change Kyozo.Accounts.Team.Changes.SetOwnerCurrentTeam
    end

    # create :create_team do
    #   description "Creates a new Team and assigns the actor as an admin by creating a new UserTeam record in a single transaction"

    #   accept [:name, :domain, :description]

    #   change after_action(fn _changeset, team, context ->
    #            user_team_attrs = %{
    #              user_id: context.actor.id,
    #              role: "admin"
    #            }

    #            Kyozo.Accounts.add_team_member!(user_team_attrs,
    #              tenant: team,
    #              authorize?: false
    #            )

    #            {:ok, team}
    #          end)
    # end

    read :list_user_teams do
      description "List all teams that a user is a member of"
      filter expr(users.id == ^actor(:id))
    end

    update :update_team do
      accept [:name, :domain, :description]
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type([:create, :read, :update, :destroy]) do
      authorize_if always()
    end
  end

  pub_sub do
    module KyozoWeb.Endpoint

    publish_all :destroy, ["members", :_pkey]
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :domain, :string, allow_nil?: false, public?: true
    attribute :description, :string, allow_nil?: true, public?: true
    attribute :owner_user_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :owner, Kyozo.Accounts.User do
      source_attribute :owner_user_id
    end

    many_to_many :users, Kyozo.Accounts.User do
      through Kyozo.Accounts.UserTeam
      source_attribute_on_join_resource :team_id
      destination_attribute_on_join_resource :user_id
    end

    has_many :invitations, Kyozo.Accounts.Invitation

    has_many :user_teams, Kyozo.Accounts.UserTeam
  end

end

defimpl Ash.ToTenant, for: Kyozo.Accounts.Team do
  def to_tenant(resource, %{:domain => domain, :id => id}) do
    if Ash.Resource.Info.data_layer(resource) == AshPostgres.DataLayer &&
         Ash.Resource.Info.multitenancy_strategy(resource) == :context do
      domain
    else
      id
    end
  end

  def to_tenant(%{id: id} = _tenant, _resource) when is_map(_tenant), do: id
  def to_tenant(id, _resource) when is_binary(id), do: id
end
