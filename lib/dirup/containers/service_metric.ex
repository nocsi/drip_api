defmodule Dirup.Containers.ServiceMetric do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshOban]

  @moduledoc """
  ServiceMetric resource representing performance metrics for service instances.

  This resource stores time-series metrics data for containerized services,
  including CPU usage, memory consumption, network I/O, and custom application
  metrics for monitoring and alerting purposes.
  """

  json_api do
    type "service-metric"

    routes do
      base "/service-metrics"
      get :read
      index :read
    end

    includes [:service_instance]
  end

  postgres do
    table "service_metrics"
    repo Dirup.Repo

    references do
      reference :service_instance, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:service_instance_id, :metric_type, :recorded_at]
    end
  end

  # AshOban triggers for metrics collection and maintenance
  oban do
    triggers do
      # Ensure triggers run for all tenants
      list_tenants(fn -> Dirup.Repo.all_tenants() end)

      trigger :collect_single do
        action :create
        queue(:metrics_collection)
      end

      trigger :batch_collection do
        action :create
        queue(:metrics_collection)
      end

      trigger :cleanup do
        action :create
        queue(:cleanup)
      end
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :service_instance_id,
        :metric_type,
        :value,
        :unit,
        :metadata
      ]

      change set_attribute(:recorded_at, &DateTime.utc_now/0)
    end

    read :for_service_instance do
      argument :service_instance_id, :uuid, allow_nil?: false
      filter expr(service_instance_id == ^arg(:service_instance_id))
      prepare build(sort: [recorded_at: :desc])
    end

    read :by_metric_type do
      argument :metric_type, :atom, allow_nil?: false
      filter expr(metric_type == ^arg(:metric_type))
      prepare build(sort: [recorded_at: :desc])
    end

    read :time_series do
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :metric_type, :atom, allow_nil?: false
      argument :hours, :integer, default: 24

      prepare build(
                filter:
                  expr(
                    service_instance_id == ^arg(:service_instance_id) and
                      metric_type == ^arg(:metric_type) and
                      recorded_at > ago(^arg(:hours), :hour)
                  ),
                sort: [recorded_at: :asc]
              )
    end

    read :recent_metrics do
      argument :hours, :integer, default: 1

      prepare build(
                filter: expr(recorded_at > ago(^arg(:hours), :hour)),
                sort: [recorded_at: :desc]
              )
    end

    read :high_values do
      argument :metric_type, :atom, allow_nil?: false
      argument :threshold, :decimal, allow_nil?: false

      prepare build(
                filter:
                  expr(
                    metric_type == ^arg(:metric_type) and
                      value > ^arg(:threshold)
                  ),
                sort: [value: :desc, recorded_at: :desc]
              )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:service_instance, :workspace, :team, :users])
    end

    policy action_type(:create) do
      # Only allow creation through internal metrics collection systems
      authorize_if never()
    end
  end

  validations do
    validate present([:service_instance_id, :metric_type, :value, :unit])

    validate {Dirup.Containers.Validations.ValidateMetricValue, []}
    validate {Dirup.Containers.Validations.ValidateMetricUnit, []}
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :metric_type, :atom do
      constraints one_of: [:cpu, :memory, :disk, :network, :requests, :errors]
      allow_nil? false
      public? true
    end

    attribute :value, :decimal do
      allow_nil? false
      public? true
    end

    attribute :unit, :string do
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    attribute :team_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :recorded_at
  end

  relationships do
    belongs_to :service_instance, Dirup.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :formatted_value,
              :string,
              {Dirup.Containers.Calculations.FormatMetricValue, []}

    calculate :is_anomaly, :boolean, {Dirup.Containers.Calculations.MetricAnomaly, []}

    calculate :trend_direction, :atom, {Dirup.Containers.Calculations.MetricTrend, []}
  end

  aggregates do
    avg :average_value, [:service_instance, :metrics], field: :value

    max :max_value, [:service_instance, :metrics], field: :value

    min :min_value, [:service_instance, :metrics], field: :value

    first :latest_value, [:service_instance, :metrics],
      field: :value,
      sort: [recorded_at: :desc]
  end
end
