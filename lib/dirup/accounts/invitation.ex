defmodule Dirup.Accounts.Invitation do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "invitations"
    repo Dirup.Repo

    references do
      reference :invited_user, on_delete: :delete
      reference :inviter_user, on_delete: :delete
      reference :team, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    read :list_received_invitations do
      multitenancy :bypass
      filter expr(invited_user_id == ^actor(:id))
      prepare build(load: :team)
    end

    read :list_invitations_sent do
      prepare build(load: [:invited_user])
    end

    create :invite_user do
      accept [:invited_user_id]
      change relate_actor(:inviter_user)
      change load [:invited_user]
    end

    destroy :cancel_invitation

    destroy :decline_invitation

    destroy :accept_invitation do
      require_atomic? false

      change before_action(fn changeset, _context ->
               team_member_attrs = %{
                 user_id: changeset.data.invited_user_id,
                 role: "member"
               }

               Dirup.Accounts.add_team_member!(team_member_attrs,
                 tenant: changeset.data.team_id,
                 authorize?: false
               )

               changeset
             end)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type([:create, :read, :update, :destroy]) do
      authorize_if always()
    end

    policy action([:list_received_invitations, :decline_invitation, :accept_invitation]) do
      authorize_if relates_to_actor_via(:invited_user)
    end

    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if relates_to_actor_via(:invited_user)
    end

    policy action([:list_invitations_sent, :invite_user, :cancel_invitation]) do
      authorize_if actor_attribute_equals(:role, "admin")
    end
  end

  pub_sub do
    module DirupWeb.Endpoint

    publish_all :create, ["invitations", :_tenant]
    publish_all :destroy, ["invitations", :_tenant]

    publish_all :create, ["invitations", :invited_user_id]
    publish_all :destroy, ["invitations", :invited_user_id]
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id
  end

  relationships do
    belongs_to :invited_user, Dirup.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :inviter_user, Dirup.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :team, Dirup.Accounts.Team do
      public? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_user_invitation, [:invited_user_id, :team_id]
  end
end
