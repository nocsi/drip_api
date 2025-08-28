defmodule Dirup.Containers.DeploymentEvent do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshEvents.Events]

  @moduledoc """
  DeploymentEvent resource representing audit trail of container operations.

  This resource provides a complete audit trail of all deployment-related
  events for service instances, including deployments, starts, stops,
  scaling operations, and error conditions.
  """

  json_api do
    type "deployment-event"

    routes do
      base "/deployment-events"
      get :read
      index :read
    end

    includes [:service_instance, :triggered_by]
  end

  postgres do
    table "container_deployment_events"
    repo Dirup.Repo

    references do
      reference :service_instance, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :triggered_by, on_delete: :nilify, index?: true
    end

    custom_indexes do
      index [:service_instance_id, :occurred_at]
      index [:event_type, :occurred_at]
    end
  end

  # Emit AshEvents to the central event log when actions run
  events do
    # Use the shared event log resource
    event_log(Dirup.Events.Event)

    # Track versions for actions that produce events (optional, defaults to 1)
    current_action_versions(create: 1, read: 1)
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :service_instance_id,
        :event_type,
        :event_data,
        :error_message,
        :error_details,
        :duration_ms,
        :sequence_number
      ]

      change relate_actor(:triggered_by)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
      change {Dirup.Containers.Changes.SetTeamFromServiceInstance, []}
    end

    read :for_service_instance do
      argument :service_instance_id, :uuid, allow_nil?: false
      filter expr(service_instance_id == ^arg(:service_instance_id))
      prepare build(sort: [occurred_at: :desc])
    end

    read :by_event_type do
      argument :event_type, :atom, allow_nil?: false
      filter expr(event_type == ^arg(:event_type))
      prepare build(sort: [occurred_at: :desc])
    end

    read :recent_events do
      argument :hours, :integer, default: 24

      prepare build(
                filter: expr(occurred_at > ago(^arg(:hours), :hour)),
                sort: [occurred_at: :desc]
              )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:service_instance, :workspace, :team, :users])
    end

    policy action_type(:create) do
      # Only allow creation through internal systems
      authorize_if never()
    end
  end

  validations do
    validate present([:service_instance_id, :event_type, :sequence_number])

    validate {Dirup.Containers.Validations.ValidateEventData, []}
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :team_id, :uuid do
      allow_nil? false
      public? true
      description "Team that owns this deployment event"
    end

    attribute :event_type, :atom do
      constraints one_of: [
                    :deployment_started,
                    :deployment_completed,
                    :deployment_failed,
                    :service_started,
                    :service_stopped,
                    :service_restarted,
                    :service_scaled,
                    :health_check_passed,
                    :health_check_failed,
                    :configuration_updated,
                    :image_built,
                    :image_pushed
                  ]

      allow_nil? false
      public? true
    end

    attribute :event_data, :map do
      default %{}
      public? true
    end

    attribute :error_message, :string do
      public? true
    end

    attribute :error_details, :map do
      default %{}
      public? false
    end

    attribute :duration_ms, :integer do
      public? true
    end

    attribute :sequence_number, :integer do
      allow_nil? false
      public? true
    end

    create_timestamp :occurred_at
  end

  relationships do
    belongs_to :service_instance, Dirup.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end

    belongs_to :triggered_by, Dirup.Accounts.User do
      public? true
    end

    belongs_to :team, Dirup.Accounts.Team do
      allow_nil? false
      public? true
      attribute_writable? false
    end
  end

  calculations do
    calculate :formatted_duration, :string, {Dirup.Containers.Calculations.FormatDuration, []}

    calculate :event_summary, :string, {Dirup.Containers.Calculations.EventSummary, []}

    calculate :is_error_event,
              :boolean,
              expr(event_type in [:deployment_failed, :health_check_failed, :service_stopped])

    calculate :is_success_event,
              :boolean,
              expr(
                event_type in [
                  :deployment_completed,
                  :service_started,
                  :health_check_passed,
                  :service_scaled
                ]
              )
  end
end
