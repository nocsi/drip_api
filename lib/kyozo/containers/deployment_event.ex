defmodule Kyozo.Containers.DeploymentEvent do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

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
    table "deployment_events"
    repo Kyozo.Repo

    references do
      reference :service_instance, on_delete: :delete, index?: true
      reference :triggered_by, on_delete: :nilify
    end

    custom_indexes do
      index [:service_instance_id, :occurred_at]
      index [:event_type, :occurred_at]
    end
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

    validate {Kyozo.Containers.Validations.ValidateEventData, []}
  end

  attributes do
    uuid_v7_primary_key :id

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
    belongs_to :service_instance, Kyozo.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end

    belongs_to :triggered_by, Kyozo.Accounts.User do
      public? true
    end
  end

  calculations do
    calculate :formatted_duration, :string, {Kyozo.Containers.Calculations.FormatDuration, []}

    calculate :event_summary, :string, {Kyozo.Containers.Calculations.EventSummary, []}

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
