defmodule Kyozo.Accounts.UserTeam do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Accounts,
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_teams"
    repo Kyozo.Repo

    references do
      reference :user, on_delete: :delete
      reference :team, on_delete: :delete
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    default_accept [:user_id, :team_id]

    read :list_team_members do
      prepare build(load: :user)
    end

    create :add_team_member do
      accept [:user_id, :role]
    end

    update :change_member_role do
      accept [:role]
      validate one_of(:role, ["admin", "member", "owner"])
    end

    destroy :remove_team_member

    destroy :leave_team do
      require_atomic? false

      change after_action(fn _changeset, user_team, context ->
               require Ash.Query

               # Check if the member who's leaving is an admin
               if user_team.role == "admin" do
                 # Count remaining admins in the team
                 remaining_admins =
                   Kyozo.Accounts.UserTeam
                   |> Ash.Query.set_tenant(context.tenant)
                   |> Ash.Query.filter(role == "admin" and id != ^user_team.id)
                   |> Ash.count!(authorize?: false)

                 # If no other admins remain, destroy the entire team
                 if remaining_admins == 0 do
                   context.tenant
                   |> Kyozo.Accounts.delete_team!(authorize?: false)
                 end
               end

               {:ok, user_team}
             end)
    end

    action :is_member?, :boolean do
      argument :user_id, :string

      run fn input, context ->
        require Ash.Query

        exists =
          Kyozo.Accounts.UserTeam
          |> Ash.Query.set_tenant(context.tenant)
          |> Ash.Query.filter(user_id == ^input.arguments.user_id)
          |> Ash.exists?(authorize?: false)

        {:ok, exists}
      end
    end
  end

  validations do
    validate one_of(:role, ["admin", "member", "owner"])
  end

  pub_sub do
    module KyozoWeb.Endpoint

    publish_all :create, ["members", :_tenant]
    publish_all :update, ["members", :_tenant]
    publish_all :destroy, ["members", :_tenant]

    publish :remove_team_member, ["members", :user_id]
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end


  resource do
    # We don’t need a primary key for this resource
    require_primary_key? false
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :role, :string do
      allow_nil? false
      default "member"
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Kyozo.Accounts.User do
      source_attribute :user_id
    end

    belongs_to :team, Kyozo.Accounts.Team do
      source_attribute :team_id
    end
  end

  calculations do
    calculate :can_manage,
              :boolean,
              expr(
                ^actor(:role) == "admin" and
                  user_id != ^actor(:id) and
                  exists(team, users.id == ^actor(:id))
              )
  end

  identities do
    identity :unique_user_membership, [:user_id, :team_id]
  end
end
