defmodule Kyozo.Workspaces.ServiceInstance do
  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :folder_path,
             :service_type,
             :detection_confidence,
             :status,
             :container_id,
             :image_id,
             :deployment_config,
             :port_mappings,
             :environment_variables,
             :resource_limits,
             :scaling_config,
             :health_check_config,
             :created_at,
             :updated_at,
             :deployed_at,
             :last_health_check_at
           ]}

  @moduledoc """
  ServiceInstance resource representing a containerized service within a workspace.

  A service instance is a deployable unit that represents a service discovered through
  topology analysis or manually created. It contains configuration for deployment,
  scaling, health checks, and monitoring.
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    type "service-instance"

    routes do
      base "/service-instances"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy

      # Custom routes for service management
      post :deploy, route: "/:id/deploy"
      post :start, route: "/:id/start"
      post :stop, route: "/:id/stop"
      post :scale, route: "/:id/scale"
    end

    # JSON-LD context metadata temporarily disabled during GraphQL cleanup
    # TODO: Re-enable JSON-LD metadata when AshJsonApi meta function is available
  end

  postgres do
    table "service_instances"
    repo Kyozo.Repo

    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :topology_detection, on_delete: :nilify, index?: true
    end

    custom_indexes do
      index [:workspace_id, :name], unique: true
      index [:workspace_id, :status]
      index [:workspace_id, :service_type]
      index [:team_id, :status]
      index [:status, :updated_at]
      index [:service_type, :status]
    end
  end

  actions do
    default_accept [
      :name,
      :folder_path,
      :service_type,
      :deployment_config,
      :port_mappings,
      :environment_variables,
      :resource_limits,
      :scaling_config,
      :health_check_config
    ]

    defaults [:create, :read, :update, :destroy]

    read :list_service_instances do
      prepare build(
                load: [:workspace, :team, :health_status, :resource_usage],
                filter: [
                  status: [:detecting, :deployable, :deploying, :running, :stopped, :error]
                ]
              )
    end

    read :list_running_services do
      prepare build(
                filter: [status: :running],
                load: [:workspace, :team, :health_status, :resource_usage],
                sort: [updated_at: :desc]
              )
    end

    read :list_by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false

      prepare build(
                filter: [workspace_id: arg(:workspace_id)],
                load: [:workspace, :team, :health_status]
              )
    end

    read :search_services do
      argument :query, :string, allow_nil?: false

      prepare build(
                filter:
                  expr(
                    contains(name, ^arg(:query)) or
                      contains(folder_path, ^arg(:query)) or
                      contains(service_type, ^arg(:query))
                  ),
                load: [:workspace, :team]
              )
    end

    create :create_service_instance do
      accept [
        :name,
        :folder_path,
        :service_type,
        :deployment_config,
        :port_mappings,
        :environment_variables,
        :resource_limits,
        :scaling_config,
        :health_check_config,
        :workspace_id,
        :topology_detection_id
      ]

      change set_attribute(:status, :deployable)

    end

    update :update_service_instance do
      accept [
        :name,
        :deployment_config,
        :port_mappings,
        :environment_variables,
        :resource_limits,
        :scaling_config,
        :health_check_config
      ]


    end

    action :deploy, :struct do
      constraints instance_of: __MODULE__
      argument :environment, :string, default: "production"
      argument :build_args, :map, default: %{}
      argument :force_rebuild, :boolean, default: false

      run {Kyozo.Workspaces.ServiceInstance.Actions.DeployService, []}
    end

    action :start, :struct do
      constraints instance_of: __MODULE__
      run {Kyozo.Workspaces.ServiceInstance.Actions.StartService, []}
    end

    action :stop, :struct do
      constraints instance_of: __MODULE__
      argument :graceful, :boolean, default: true
      argument :timeout_seconds, :integer, default: 30

      run {Kyozo.Workspaces.ServiceInstance.Actions.StopService, []}
    end

    action :scale, :struct do
      constraints instance_of: __MODULE__
      argument :replica_count, :integer, allow_nil?: false

      run {Kyozo.Workspaces.ServiceInstance.Actions.ScaleService, []}
    end

    action :get_logs, :map do
      argument :lines, :integer, default: 100
      argument :since, :utc_datetime_usec, allow_nil?: true
      argument :follow, :boolean, default: false
      argument :timestamps, :boolean, default: true

      run {Kyozo.Workspaces.ServiceInstance.Actions.GetServiceLogs, []}
    end

    action :get_metrics, :map do
      argument :metric_type, :string, default: "all"
      argument :period, :string, default: "24h"
      argument :interval, :string, default: "15m"

      run {Kyozo.Workspaces.ServiceInstance.Actions.GetServiceMetrics, []}
    end

    action :get_health_status, :map do
      run {Kyozo.Workspaces.ServiceInstance.Actions.GetHealthStatus, []}
    end

    destroy :destroy_service_instance do

    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type(:create) do
      authorize_if actor_present()
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])

      authorize_if expr(
                     exists(
                       workspace.team.users,
                       id == ^actor(:id) and team_members.role in ["admin", "owner"]
                     )
                   )
    end

    policy action([:deploy, :start, :stop, :scale]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])

      authorize_if expr(
                     exists(
                       workspace.team.users,
                       id == ^actor(:id) and team_members.role in ["admin", "owner", "developer"]
                     )
                   )
    end

    policy action([:get_logs, :get_metrics, :get_health_status]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end
  end

  pub_sub do
    module KyozoWeb.Endpoint

    publish_all :create, ["service_instances", :workspace_id]
    publish_all :update, ["service_instances", :workspace_id]
    publish_all :destroy, ["service_instances", :workspace_id]
  end

  preparations do
    prepare build(load: [:workspace, :team])
  end

  changes do

  end

  validations do
    validate present([:name, :folder_path, :service_type, :workspace_id, :team_id])

    validate match(:name, ~r/^[a-zA-Z0-9\-_]+$/) do
      message "Service name can only contain letters, numbers, hyphens, and underscores"
    end


  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :folder_path, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 500
    end

    attribute :service_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    # Web Application Services
                    :nodejs,
                    :python,
                    :ruby,
                    :java,
                    :golang,
                    :rust,
                    :php,
                    :dotnet,
                    :django,
                    :flask,
                    :express,
                    :spring_boot,
                    :rails,
                    :laravel,

                    # Database Services
                    :postgres,
                    :mysql,
                    "mongodb",
                    "redis",
                    "elasticsearch",
                    "cassandra",
                    "sqlite",

                    # Message Queue Services
                    "rabbitmq",
                    "kafka",
                    "nats",
                    "redis_queue",

                    # Cache Services
                    "memcached",
                    "redis_cache",

                    # Load Balancer Services
                    "nginx",
                    "apache",
                    "haproxy",
                    "traefik",

                    # Static File Services
                    "static_files",
                    "cdn",

                    # Worker Services
                    "celery",
                    "sidekiq",
                    "resque",
                    "background_worker",

                    # Cron Services
                    "cron",
                    "scheduler",

                    # Proxy Services
                    "reverse_proxy",
                    "api_gateway",

                    # Monitoring Services
                    "prometheus",
                    "grafana",
                    "jaeger",
                    "zipkin",

                    # Container/Generic
                    "docker",
                    "custom_container"
                  ]
    end

    attribute :detection_confidence, :decimal do
      public? true
      constraints min: 0.0, max: 1.0
      default Decimal.new("0.0")
    end

    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    # Detection Phase
                    :detecting,
                    :detected,
                    :analysis_failed,

                    # Preparation Phase
                    :deployable,
                    :building,
                    :build_failed,
                    :image_pulling,
                    :image_pull_failed,

                    # Deployment Phase
                    :deploying,
                    :deployment_failed,
                    :starting,
                    :start_failed,

                    # Running States
                    :running,
                    :healthy,
                    :unhealthy,
                    :degraded,

                    # Stopped States
                    :stopped,
                    :stopping,
                    :crashed,
                    :killed,

                    # Maintenance States
                    :updating,
                    :scaling,
                    :restarting,
                    :migrating,

                    # Error States
                    :error,
                    :timeout,
                    :resource_limit_exceeded,
                    :configuration_error,

                    # Cleanup States
                    :terminating,
                    :terminated,
                    :cleanup_failed
                  ]

      default :deployable
    end

    attribute :container_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :image_id, :string do
      public? true
      constraints max_length: 200
    end

    attribute :deployment_config, :map do
      public? true
      default %{}
    end

    attribute :port_mappings, :map do
      public? true
      default %{}
    end

    attribute :environment_variables, :map do
      public? true
      default %{}
      sensitive? true
    end

    attribute :resource_limits, :map do
      public? true

      default %{
        "memory" => "512Mi",
        "cpu" => "0.5",
        "storage" => "1Gi"
      }
    end

    attribute :scaling_config, :map do
      public? true

      default %{
        "min_replicas" => 1,
        "max_replicas" => 3,
        "target_cpu" => 70
      }
    end

    attribute :health_check_config, :map do
      public? true

      default %{
        "path" => "/health",
        "interval" => 30,
        "timeout" => 10,
        "retries" => 3
      }
    end

    attribute :deployed_at, :utc_datetime_usec do
      public? true
    end

    attribute :last_health_check_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :topology_detection, Kyozo.Workspaces.TopologyDetection do
      allow_nil? true
      attribute_writable? true
    end

    has_many :deployment_events, Kyozo.Workspaces.DeploymentEvent do
      destination_attribute :service_instance_id
    end



    has_many :dependent_services, Kyozo.Workspaces.ServiceDependency do
      destination_attribute :dependent_service_id
    end

    has_many :required_by_services, Kyozo.Workspaces.ServiceDependency do
      destination_attribute :required_service_id
    end


  end

  calculations do
    calculate :health_status, :string do
      calculation fn service_instances, _context ->
        Enum.map(service_instances, fn service_instance ->
          case service_instance.status do
            :running ->
              if service_instance.last_health_check_at &&
                   DateTime.diff(DateTime.utc_now(), service_instance.last_health_check_at) < 300 do
                "healthy"
              else
                "unknown"
              end

            :stopped ->
              "stopped"

            :error ->
              "unhealthy"

            _ ->
              "unknown"
          end
        end)
      end
    end

    calculate :uptime_seconds, :integer do
      calculation fn service_instances, _context ->
        Enum.map(service_instances, fn service_instance ->
          if service_instance.deployed_at && service_instance.status == :running do
            DateTime.diff(DateTime.utc_now(), service_instance.deployed_at)
          else
            0
          end
        end)
      end
    end

    calculate :resource_usage, :map do
      calculation fn service_instances, _context ->
        Enum.map(service_instances, fn service_instance ->
          # This would be populated by actual container metrics in production
          %{
            cpu_usage: 0.0,
            memory_usage_mb: 0,
            storage_usage_gb: 0.0,
            network_rx_bytes: 0,
            network_tx_bytes: 0
          }
        end)
      end
    end

    calculate :deployment_url, :string do
      load [:workspace, :port_mappings]

      calculation fn service_instances, _context ->
        Enum.map(service_instances, fn service_instance ->
          if service_instance.status == :running && service_instance.port_mappings do
            primary_port = service_instance.port_mappings |> Map.values() |> List.first()

            if primary_port do
              "https://#{service_instance.name}-#{service_instance.workspace.id}.kyozo.store"
            else
              nil
            end
          else
            nil
          end
        end)
      end
    end

    calculate :can_deploy, :boolean, {Kyozo.Calculations.CanPerformAction, action: :deploy}
    calculate :can_start, :boolean, {Kyozo.Calculations.CanPerformAction, action: :start}
    calculate :can_stop, :boolean, {Kyozo.Calculations.CanPerformAction, action: :stop}
    calculate :can_scale, :boolean, {Kyozo.Calculations.CanPerformAction, action: :scale}
  end

  # Resource-specific functions

  @doc """
  Gets the deployment URL for the service instance.
  """
  def deployment_url(%{
        status: :running,
        name: name,
        workspace: workspace,
        port_mappings: port_mappings
      })
      when is_map(port_mappings) and map_size(port_mappings) > 0 do
    "https://#{name}-#{workspace.id}.kyozo.store"
  end

  def deployment_url(_), do: nil

  @doc """
  Determines if service is currently deployable.
  """
  def deployable?(%{status: status}) do
    status in [:deployable, :stopped, :error]
  end

  @doc """
  Determines if service is currently running.
  """
  def running?(%{status: :running}), do: true
  def running?(_), do: false

  @doc """
  Gets the primary port for the service.
  """
  def primary_port(%{port_mappings: port_mappings}) when is_map(port_mappings) do
    port_mappings
    |> Map.values()
    |> List.first()
  end

  def primary_port(_), do: nil

  @doc """
  Builds default deployment configuration for a service type.
  """
  def default_deployment_config("nodejs") do
    %{
      "build_command" => "npm install && npm run build",
      "start_command" => "npm start",
      "node_version" => "18",
      "package_manager" => "npm"
    }
  end

  def default_deployment_config("python") do
    %{
      "build_command" => "pip install -r requirements.txt",
      "start_command" => "python app.py",
      "python_version" => "3.11",
      "package_manager" => "pip"
    }
  end

  def default_deployment_config("docker") do
    %{
      "dockerfile" => "Dockerfile",
      "context" => ".",
      "build_args" => %{}
    }
  end

  def default_deployment_config(_service_type) do
    %{
      "build_command" => "echo 'No build required'",
      "start_command" => "echo 'Custom start command required'"
    }
  end

  @doc """
  Validates deployment configuration structure.
  """
  def valid_deployment_config?(%{"start_command" => start_command})
      when is_binary(start_command) do
    String.length(start_command) > 0
  end

  def valid_deployment_config?(_), do: false

  @doc """
  Normalizes port mappings format.
  """
  def normalize_port_mappings(port_mappings) when is_map(port_mappings) do
    port_mappings
    |> Enum.map(fn {container_port, host_port} ->
      normalized_container = normalize_port_key(container_port)
      normalized_host = ensure_integer(host_port)
      {normalized_container, normalized_host}
    end)
    |> Map.new()
  end

  def normalize_port_mappings(_), do: %{}

  defp normalize_port_key(port) when is_integer(port), do: "#{port}/tcp"

  defp normalize_port_key(port) when is_binary(port) do
    if String.contains?(port, "/") do
      port
    else
      "#{port}/tcp"
    end
  end

  defp ensure_integer(port) when is_integer(port), do: port

  defp ensure_integer(port) when is_binary(port) do
    case Integer.parse(port) do
      {int, ""} -> int
      _ -> 0
    end
  end

  defp ensure_integer(_), do: 0
end
