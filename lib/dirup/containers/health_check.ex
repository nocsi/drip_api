defmodule Dirup.Containers.HealthCheck do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshOban]

  @moduledoc """
  HealthCheck resource representing health monitoring results for service instances.

  This resource stores the results of periodic health checks performed on
  running containers, providing visibility into service availability,
  response times, and overall system health.
  """

  json_api do
    type "health-check"

    routes do
      base "/health-checks"
      get :read
      index :read
    end

    includes [:service_instance]
  end

  postgres do
    table "health_checks"
    repo Dirup.Repo

    references do
      reference :service_instance, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:service_instance_id, :checked_at]
      index [:service_instance_id, :status]
    end
  end

  # AshOban triggers for health monitoring
  oban do
    triggers do
      # Ensure triggers run for all tenants
      list_tenants(fn -> Dirup.Repo.all_tenants() end)

      trigger :single_check do
        action :create
        queue(:health_monitoring)
      end

      trigger :batch_check do
        action :create
        queue(:health_monitoring)
      end
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :service_instance_id,
        :check_type,
        :endpoint,
        :status,
        :response_time_ms,
        :status_code,
        :response_body,
        :error_message
      ]

      change set_attribute(:checked_at, &DateTime.utc_now/0)
    end

    read :for_service_instance do
      argument :service_instance_id, :uuid, allow_nil?: false
      filter expr(service_instance_id == ^arg(:service_instance_id))
      prepare build(sort: [checked_at: :desc])
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
      prepare build(sort: [checked_at: :desc])
    end

    read :recent_checks do
      argument :hours, :integer, default: 24

      prepare build(
                filter: expr(checked_at > ago(^arg(:hours), :hour)),
                sort: [checked_at: :desc]
              )
    end

    read :failed_checks do
      filter expr(status == :unhealthy)
      prepare build(sort: [checked_at: :desc])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:service_instance, :workspace, :team, :users])
    end

    policy action_type(:create) do
      # Only allow creation through internal health monitoring systems
      authorize_if never()
    end
  end

  validations do
    validate present([:service_instance_id, :check_type, :status])

    validate {Dirup.Containers.Validations.ValidateHealthCheckEndpoint, []}
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :check_type, :atom do
      constraints one_of: [:http, :tcp, :exec, :grpc]
      default :http
      public? true
    end

    attribute :endpoint, :string do
      public? true
      description "Health check endpoint or command"
    end

    attribute :status, :atom do
      constraints one_of: [:healthy, :unhealthy, :unknown]
      allow_nil? false
      public? true
    end

    attribute :response_time_ms, :integer do
      public? true
    end

    attribute :status_code, :integer do
      public? true
    end

    attribute :response_body, :string do
      public? false
    end

    attribute :error_message, :string do
      public? true
    end

    create_timestamp :checked_at
  end

  relationships do
    belongs_to :service_instance, Dirup.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :is_healthy, :boolean, expr(status == :healthy)

    calculate :is_recent, :boolean, expr(checked_at > ago(5, :minute))

    calculate :formatted_response_time,
              :string,
              {Dirup.Containers.Calculations.FormatResponseTime, []}

    calculate :health_score, :decimal, {Dirup.Containers.Calculations.HealthScore, []}
  end

  aggregates do
    count :total_checks, [:service_instance, :health_checks]

    count :healthy_checks, [:service_instance, :health_checks], filter: [status: :healthy]

    count :unhealthy_checks, [:service_instance, :health_checks], filter: [status: :unhealthy]
  end
end
