defmodule Kyozo.Containers.ServiceInstance do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshOban]

  @moduledoc """
  ServiceInstance resource representing a containerized service deployed from a folder.

  A service instance is created when a folder is analyzed and determined to contain
  a deployable service. It manages the entire lifecycle from detection through
  deployment, monitoring, and scaling of containerized applications.
  """

  json_api do
    type "service-instance"
    includes [:workspace, :team, :created_by, :deployment_events]
  end

  postgres do
    table "container_service_instances"
    repo Kyozo.Repo

    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :created_by, on_delete: :nilify
      reference :topology_detection, on_delete: :nilify, index?: true
    end

    custom_indexes do
      index [:team_id, :workspace_id, :status]
      index [:team_id, :service_type]
      index [:workspace_id, :folder_path], unique: true
    end
  end

  # AshOban triggers to run container lifecycle jobs with actor context
  oban do
    triggers do
      # Ensure triggers run for all tenants
      list_tenants(fn -> Kyozo.Repo.all_tenants() end)

      trigger :deploy do
        action :deploy
        queue(:container_deployment)
      end

      trigger :stop do
        action :stop
        queue(:container_deployment)
      end

      trigger :restart do
        action :start
        queue(:container_deployment)
      end

      trigger :scale do
        action :scale
        queue(:container_deployment)
      end

      trigger :health_check do
        action :update
        queue(:health_monitoring)
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :folder_path,
        :service_type,
        :deployment_config,
        :port_mappings,
        :environment_variables,
        :resource_limits
      ]

      argument :workspace_id, :uuid, allow_nil?: false

      change set_attribute(:workspace_id, arg(:workspace_id))
      change relate_actor(:created_by)
      change {Kyozo.Containers.Changes.SetTeamFromWorkspace, []}
      change {Kyozo.Containers.Changes.ValidateDeploymentConfig, []}
    end

    update :update do
      primary? true

      accept [
        :deployment_config,
        :environment_variables,
        :resource_limits,
        :scaling_config,
        :health_check_config
      ]
    end

    update :deploy do
      accept []
      change set_attribute(:status, :deploying)
      change set_attribute(:deployed_at, &DateTime.utc_now/0)
      change {Kyozo.Containers.Changes.StartContainerDeployment, []}
    end

    update :start do
      accept []
      change {Kyozo.Containers.Changes.StartContainer, []}
      change set_attribute(:status, :running)
    end

    update :stop do
      accept []
      change {Kyozo.Containers.Changes.StopContainer, []}
      change set_attribute(:status, :stopped)
      change set_attribute(:stopped_at, &DateTime.utc_now/0)
    end

    update :scale do
      accept []
      argument :replica_count, :integer, allow_nil?: false

      change {Kyozo.Containers.Changes.ScaleService, []}
      change set_attribute(:status, :scaling)
    end

    read :list_by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false
      filter expr(workspace_id == ^arg(:workspace_id))
    end

    read :list_running do
      filter expr(status == :running)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action([:deploy, :start, :stop, :scale]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])

      authorize_if expr(
                     team.user_teams.role in [:owner, :admin] and
                       team.user_teams.user_id == ^actor(:id)
                   )
    end
  end

  validations do
    validate match(:name, ~r/^[a-zA-Z0-9\-_]+$/),
      message: "must contain only alphanumeric characters, hyphens, and underscores"

    validate {Kyozo.Containers.Validations.ValidatePortMappings, []}
    validate {Kyozo.Containers.Validations.ValidateResourceLimits, []}
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
      description "Team that owns this service instance"
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :folder_path, :string do
      allow_nil? false
      public? true
      description "Workspace-relative path to service folder"
    end

    attribute :service_type, :atom do
      constraints one_of: [
                    :nodejs,
                    :python,
                    :golang,
                    :rust,
                    :ruby,
                    :java,
                    :containerized,
                    :compose_stack,
                    :static_site,
                    :proxy
                  ]

      allow_nil? false
      public? true
    end

    attribute :detection_confidence, :decimal do
      public? true
      description "Confidence score from topology detection (0.0-1.0)"
    end

    attribute :status, :atom do
      constraints one_of: [
                    :detecting,
                    :configuring,
                    :building,
                    :deploying,
                    :running,
                    :stopping,
                    :stopped,
                    :error,
                    :scaling
                  ]

      default :detecting
      public? true
    end

    attribute :container_id, :string do
      public? true
      description "Docker container ID when running"
    end

    attribute :image_id, :string do
      public? true
      description "Docker image ID"
    end

    attribute :deployment_config, :map do
      default %{}
      public? true
      description "Generated deployment configuration"
    end

    attribute :port_mappings, :map do
      default %{}
      public? true
      description "Container port to host port mappings"
    end

    attribute :environment_variables, :map do
      default %{}
      public? true
      description "Runtime environment variables"
    end

    attribute :volume_mounts, :map do
      default %{}
      public? true
      description "Docker volume mount configurations"
    end

    attribute :resource_limits, :map do
      default %{
        memory: "512Mi",
        cpu: "0.5",
        storage: "1Gi"
      }

      public? true
    end

    attribute :scaling_config, :map do
      default %{
        min_replicas: 1,
        max_replicas: 3,
        target_cpu: 70,
        target_memory: 80
      }

      public? true
    end

    attribute :health_check_config, :map do
      public? true
      description "Health check endpoint and parameters"
    end

    attribute :labels, :map do
      default %{}
      public? true
      description "Docker labels for service discovery"
    end

    attribute :network_config, :map do
      default %{}
      public? true
      description "Docker network configuration"
    end

    # Lifecycle timestamps
    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :deployed_at, :utc_datetime_usec do
      public? true
    end

    attribute :last_health_check_at, :utc_datetime_usec do
      public? true
    end

    attribute :stopped_at, :utc_datetime_usec do
      public? true
    end
  end

  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? false
      public? true
    end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      public? true
      attribute_writable? false
    end

    belongs_to :created_by, Kyozo.Accounts.User do
      public? true
    end

    belongs_to :topology_detection, Kyozo.Containers.TopologyDetection do
      public? true
    end

    # Service dependencies
    has_many :dependencies, Kyozo.Containers.ServiceDependency do
      public? true
      destination_attribute :dependent_service_id
    end

    has_many :dependents, Kyozo.Containers.ServiceDependency do
      public? true
      destination_attribute :required_service_id
    end

    # Monitoring
    has_many :deployment_events, Kyozo.Containers.DeploymentEvent do
      public? true
      sort created_at: :desc
    end

    has_many :health_checks, Kyozo.Containers.HealthCheck do
      public? true
      sort created_at: :desc
    end

    has_many :metrics, Kyozo.Containers.ServiceMetric do
      public? true
    end
  end

  calculations do
    calculate :uptime_seconds, :integer, {Kyozo.Containers.Calculations.Uptime, []}

    calculate :deployment_status, :string, {Kyozo.Containers.Calculations.DeploymentStatus, []}

    calculate :resource_utilization, :map, {Kyozo.Containers.Calculations.ResourceUtilization, []}
  end

  # Static functions for accessing calculations
  @doc """
  Get the uptime in seconds for a service instance.
  """
  def uptime(service_instance) do
    case service_instance.status do
      :running ->
        case service_instance.deployed_at do
          nil ->
            0

          deployed_at ->
            now = DateTime.utc_now()
            DateTime.diff(now, deployed_at, :second)
        end

      _ ->
        0
    end
  end

  @doc """
  Get the deployment status as a human-readable string.
  """
  def deployment_status(service_instance) do
    case service_instance.status do
      :pending -> "Deployment in progress"
      :running -> "Successfully deployed and running"
      :stopped -> "Stopped"
      :failed -> "Deployment failed"
      :scaling -> "Scaling in progress"
      :unhealthy -> "Running but unhealthy"
      _ -> "Unknown status"
    end
  end

  @doc """
  Get resource utilization metrics for a service instance.
  """
  def resource_utilization(service_instance) do
    # Mock data for now - in production this would fetch from container manager
    %{
      cpu_usage_percent: :rand.uniform(100),
      memory_usage_mb: :rand.uniform(1024),
      memory_limit_mb: 1024,
      disk_usage_mb: :rand.uniform(512),
      network_rx_mb: :rand.uniform(100),
      network_tx_mb: :rand.uniform(50)
    }
  end
end
