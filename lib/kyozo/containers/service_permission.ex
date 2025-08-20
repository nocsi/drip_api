defmodule Kyozo.Containers.ServicePermission do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  @moduledoc """
  ServicePermission resource representing granular permissions for service operations.

  This resource provides fine-grained access control for container operations,
  allowing teams to control who can deploy, stop, scale, or modify specific
  services within their workspace.
  """

  json_api do
    type "service-permission"

    routes do
      base "/service-permissions"
      get :read
      index :read
      post :create
      delete :destroy
    end

    includes [:user, :service_instance, :granted_by]
  end

  postgres do
    table "service_permissions"
    repo Kyozo.Repo

    references do
      reference :user, on_delete: :delete, index?: true
      reference :service_instance, on_delete: :delete, index?: true
      reference :granted_by, on_delete: :nilify
    end

    custom_indexes do
      index [:user_id, :service_instance_id, :permission_type], unique: true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :user_id,
        :service_instance_id,
        :permission_type,
        :granted
      ]

      change relate_actor(:granted_by)
    end

    create :grant_permission do
      argument :user_id, :uuid, allow_nil?: false
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :permission_type, :atom, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:service_instance_id, arg(:service_instance_id))
      change set_attribute(:permission_type, arg(:permission_type))
      change set_attribute(:granted, true)
      change relate_actor(:granted_by)
    end

    update :revoke_permission do
      change set_attribute(:granted, false)
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and granted == true)
    end

    read :for_service do
      argument :service_instance_id, :uuid, allow_nil?: false
      filter expr(service_instance_id == ^arg(:service_instance_id) and granted == true)
    end

    read :by_permission_type do
      argument :permission_type, :atom, allow_nil?: false
      filter expr(permission_type == ^arg(:permission_type) and granted == true)
    end

    action :check_permission, :boolean do
      argument :user_id, :uuid, allow_nil?: false
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :permission_type, :atom, allow_nil?: false

      run {Kyozo.Containers.Actions.CheckServicePermission, []}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:service_instance, :workspace, :team, :users])
    end

    policy action_type([:create, :update, :destroy]) do
      # Only team admins and owners can manage permissions
      authorize_if expr(
                     exists(
                       service_instance.team.user_teams,
                       user_id == ^actor(:id) and role in [:owner, :admin]
                     )
                   )
    end

    policy action(:check_permission) do
      authorize_if actor_present()
    end
  end

  validations do
    validate present([:user_id, :service_instance_id, :permission_type])

    validate {Kyozo.Containers.Validations.ValidateUserInTeam, []}
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :permission_type, :atom do
      constraints one_of: [
                    :deploy_service,
                    :stop_service,
                    :scale_service,
                    :view_logs,
                    :modify_config,
                    :delete_service
                  ]

      allow_nil? false
      public? true
    end

    attribute :granted, :boolean do
      default true
      public? true
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :user, Kyozo.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :service_instance, Kyozo.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end

    belongs_to :granted_by, Kyozo.Accounts.User do
      public? true
    end
  end

  calculations do
    calculate :permission_scope,
              :string,
              {Kyozo.Containers.Calculations.PermissionScope, []}

    calculate :is_active, :boolean, expr(granted == true)

    calculate :granted_by_name,
              :string,
              expr(granted_by.name) do
      load [:granted_by]
    end
  end
end
