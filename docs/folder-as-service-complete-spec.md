# Kyozo Store: Folder-as-a-Service Complete Specification

## Overview

This specification defines the complete "Folder as a Service" (FaaS) functionality for Kyozo Store, enabling automatic detection and deployment of folder structures as containerized services. The core principle: **Directory organization IS deployment strategy**.

## Architecture Integration

### Current Kyozo Patterns (Documented)

Based on the codebase analysis, Kyozo Store follows these established patterns:

#### Resource Patterns
- **UUID v7 Primary Keys**: All resources use `uuid_v7_primary_key :id`
- **Separate Concern Resources**: Each responsibility gets its own resource (like `DownloadLog`)
- **Proper Ash Relationships**: Using `belongs_to`, `has_many` with explicit foreign keys
- **JSON:API Compliance**: All endpoints follow standardized JSON:API patterns
- **Multi-tenant Architecture**: Team-scoped resources with `team_id` isolation
- **Soft Deletes**: Using `deleted_at` timestamps for audit trails

#### Domain Structure
```
lib/kyozo/
├── accounts/          # User and team management
├── workspaces/        # Content and collaboration  
├── projects/          # Project analysis (legacy)
├── storage/           # File storage abstraction
└── containers/        # NEW: Container orchestration domain
```

## New Container Orchestration Domain

### 1. Containers Domain (`Kyozo.Containers`)

```elixir
# lib/kyozo/containers.ex
defmodule Kyozo.Containers do
  use Ash.Domain, 
    otp_app: :kyozo, 
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]
  
  resources do
    resource Kyozo.Containers.ServiceInstance
    resource Kyozo.Containers.TopologyDetection
    resource Kyozo.Containers.ContainerRegistry
    resource Kyozo.Containers.DeploymentEvent
  end
end
```

### 2. ServiceInstance Resource

```elixir
# lib/kyozo/containers/service_instance.ex
defmodule Kyozo.Containers.ServiceInstance do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]
  
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
      description "Workspace-relative path to service folder"
    end
    
    attribute :service_type, :atom do
      constraints one_of: [:containerized, :nodejs, :python, :golang, :rust, :compose_stack, :proxy]
      allow_nil? false
      public? true
    end
    
    attribute :status, :atom do
      constraints one_of: [:detecting, :deployable, :deploying, :running, :stopped, :error, :scaling]
      default :detecting
      public? true
    end
    
    attribute :container_id, :string do
      public? true
      description "Docker container ID when running"
    end
    
    attribute :deployment_config, :map do
      default %{}
      public? true
      description "Service deployment configuration"
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
    
    attribute :resource_limits, :map do
      default %{memory: "512Mi", cpu: "0.5", storage: "1Gi"}
      public? true
    end
    
    attribute :health_check_config, :map do
      public? true
      description "Health check configuration"
    end
    
    attribute :scaling_config, :map do
      default %{min_replicas: 1, max_replicas: 3, target_cpu: 70}
      public? true
    end
    
    # Runtime status tracking
    attribute :last_health_check_at, :utc_datetime_usec do
      public? true
    end
    
    attribute :health_status, :atom do
      constraints one_of: [:healthy, :unhealthy, :unknown]
      default :unknown
      public? true
    end
    
    attribute :deployment_logs, :string do
      public? false
      description "Deployment and runtime logs"
    end
    
    attribute :startup_time_ms, :integer do
      public? true
      description "Service startup time in milliseconds"
    end
    
    attribute :memory_usage_mb, :integer do
      public? true
      description "Current memory usage"
    end
    
    attribute :cpu_usage_percent, :decimal do
      public? true
      description "Current CPU usage percentage"
    end
    
    create_timestamp :created_at
    update_timestamp :updated_at
    
    attribute :deployed_at, :utc_datetime_usec do
      public? true
    end
    
    attribute :last_accessed_at, :utc_datetime_usec do
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
    end
    
    belongs_to :created_by, Kyozo.Accounts.User do
      public? true
    end
    
    belongs_to :topology_detection, Kyozo.Containers.TopologyDetection do
      public? true
    end
    
    has_many :deployment_events, Kyozo.Containers.DeploymentEvent do
      public? true
      sort created_at: :desc
    end
    
    has_many :dependent_services, __MODULE__ do
      destination_attribute :parent_service_id
      public? true
    end
    
    belongs_to :parent_service, __MODULE__ do
      public? true
      description "Parent service in dependency chain"
    end
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:name, :folder_path, :service_type, :deployment_config, :port_mappings, 
              :environment_variables, :resource_limits, :health_check_config, :scaling_config]
      
      argument :workspace_id, :uuid, allow_nil?: false
      
      change set_attribute(:workspace_id, arg(:workspace_id))
      change relate_actor(:created_by)
      change {Kyozo.Containers.Changes.SetTeamFromWorkspace}
      change {Kyozo.Containers.Changes.ValidateDeploymentConfig}
    end
    
    update :deploy do
      change set_attribute(:status, :deploying)
      change set_attribute(:deployed_at, &DateTime.utc_now/0)
      change {Kyozo.Containers.Changes.StartContainerDeployment}
      change after_action(&log_deployment_event/3)
    end
    
    update :start do
      change {Kyozo.Containers.Changes.StartContainer}
      change set_attribute(:status, :running)
      change after_action(&log_lifecycle_event/3)
    end
    
    update :stop do
      change {Kyozo.Containers.Changes.StopContainer}
      change set_attribute(:status, :stopped)
      change after_action(&log_lifecycle_event/3)
    end
    
    update :scale do
      argument :replica_count, :integer, allow_nil?: false
      
      change {Kyozo.Containers.Changes.ScaleService}
      change set_attribute(:status, :scaling)
      change after_action(&log_scaling_event/3)
    end
    
    update :update_health_status do
      accept [:health_status, :memory_usage_mb, :cpu_usage_percent]
      change set_attribute(:last_health_check_at, &DateTime.utc_now/0)
    end
    
    read :list_by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false
      filter expr(workspace_id == ^arg(:workspace_id))
      prepare build(sort: [updated_at: :desc])
    end
    
    read :list_running do
      filter expr(status == :running)
    end
    
    read :list_by_type do
      argument :service_type, :atom, allow_nil?: false
      filter expr(service_type == ^arg(:service_type))
    end
  end
  
  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_in_relationship(:team, :users)
    end
    
    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end
    
    policy action(:deploy) do
      authorize_if actor_attribute_in_relationship(:team, :users)
      authorize_if expr(team.user_teams.role in [:owner, :admin] and team.user_teams.user_id == ^actor(:id))
    end
  end
  
  calculations do
    calculate :uptime_seconds, :integer, {Kyozo.Containers.Calculations.Uptime, []}
    calculate :deployment_status, :string, {Kyozo.Containers.Calculations.DeploymentStatus, []}
    calculate :resource_utilization, :map, {Kyozo.Containers.Calculations.ResourceUtilization, []}
  end
  
  validations do
    validate match(:name, ~r/^[a-zA-Z0-9\-_]+$/), message: "name must contain only alphanumeric characters, hyphens, and underscores"
    validate {Kyozo.Containers.Validations.ValidatePortMappings, []}
    validate {Kyozo.Containers.Validations.ValidateResourceLimits, []}
  end
  
  postgres do
    table "service_instances"
    repo Kyozo.Repo
    
    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :created_by, on_delete: :nilify
      reference :topology_detection, on_delete: :nilify
      reference :parent_service, on_delete: :nilify
    end
    
    custom_indexes do
      index [:team_id, :workspace_id, :status]
      index [:team_id, :service_type]
      index [:status, :health_status]
      index [:workspace_id, :folder_path], unique: true
    end
  end
  
  json_api do
    type "service_instance"
    
    routes do
      base "/service_instances"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
      
      # Container lifecycle operations
      post :deploy, route: "/:id/deploy"
      post :start, route: "/:id/start"
      post :stop, route: "/:id/stop"
      post :scale, route: "/:id/scale"
      
      # Service monitoring
      get :logs, route: "/:id/logs"
      get :health, route: "/:id/health"
      get :metrics, route: "/:id/metrics"
    end
    
    includes [:workspace, :team, :created_by, :deployment_events]
  end
  
  graphql do
    type :service_instance
    
    queries do
      list :service_instances, :read
      get :service_instance, :read
    end
    
    mutations do
      create :create_service_instance, :create
      update :deploy_service, :deploy
      update :start_service, :start
      update :stop_service, :stop
      update :scale_service, :scale
    end
  end
  
  defp log_deployment_event(changeset, service_instance, _context) do
    DeploymentEvent.create!(%{
      service_instance_id: service_instance.id,
      event_type: :deployment_started,
      event_data: %{
        deployment_config: service_instance.deployment_config,
        triggered_by: changeset.actor && changeset.actor.id
      }
    })
    
    {:ok, service_instance}
  end
  
  defp log_lifecycle_event(changeset, service_instance, _context) do
    event_type = case changeset.action.name do
      :start -> :service_started
      :stop -> :service_stopped
      _ -> :service_updated
    end
    
    DeploymentEvent.create!(%{
      service_instance_id: service_instance.id,
      event_type: event_type,
      event_data: %{
        previous_status: changeset.data.status,
        new_status: service_instance.status,
        triggered_by: changeset.actor && changeset.actor.id
      }
    })
    
    {:ok, service_instance}
  end
  
  defp log_scaling_event(changeset, service_instance, _context) do
    replica_count = Ash.Changeset.get_argument(changeset, :replica_count)
    
    DeploymentEvent.create!(%{
      service_instance_id: service_instance.id,
      event_type: :service_scaled,
      event_data: %{
        replica_count: replica_count,
        scaling_config: service_instance.scaling_config,
        triggered_by: changeset.actor && changeset.actor.id
      }
    })
    
    {:ok, service_instance}
  end
end
```

### 3. TopologyDetection Resource

```elixir
# lib/kyozo/containers/topology_detection.ex
defmodule Kyozo.Containers.TopologyDetection do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]
  
  attributes do
    uuid_v7_primary_key :id
    
    attribute :folder_path, :string do
      allow_nil? false
      public? true
      description "Path to analyzed folder"
    end
    
    attribute :detected_patterns, :map do
      default %{}
      public? true
      description "Detected service patterns and configurations"
    end
    
    attribute :service_indicators, :map do
      default %{}
      public? true
      description "Files and patterns indicating service type"
    end
    
    attribute :dependency_map, :map do
      default %{}
      public? true
      description "Service dependencies and relationships"
    end
    
    attribute :deployment_recommendations, :map do
      default %{}
      public? true
      description "Recommended deployment configuration"
    end
    
    attribute :confidence_score, :decimal do
      public? true
      description "Detection confidence (0.0 - 1.0)"
    end
    
    attribute :analysis_metadata, :map do
      default %{}
      public? false
      description "Internal analysis metadata"
    end
    
    create_timestamp :created_at
    update_timestamp :updated_at
  end
  
  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? false
      public? true
    end
    
    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      public? true
    end
    
    has_many :service_instances, Kyozo.Containers.ServiceInstance do
      public? true
    end
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :analyze_folder do
      argument :workspace_id, :uuid, allow_nil?: false
      argument :folder_path, :string, allow_nil?: false
      
      change {Kyozo.Containers.Changes.AnalyzeTopology}
      change {Kyozo.Containers.Changes.SetTeamFromWorkspace}
    end
    
    update :reanalyze do
      change {Kyozo.Containers.Changes.AnalyzeTopology}
    end
    
    read :by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false
      filter expr(workspace_id == ^arg(:workspace_id))
    end
  end
  
  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_in_relationship(:team, :users)
    end
    
    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end
  end
  
  postgres do
    table "topology_detections"
    repo Kyozo.Repo
    
    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
    end
    
    custom_indexes do
      index [:team_id, :workspace_id]
      index [:workspace_id, :folder_path], unique: true
      index [:confidence_score]
    end
  end
end
```

### 4. DeploymentEvent Resource (Audit Trail)

```elixir
# lib/kyozo/containers/deployment_event.ex
defmodule Kyozo.Containers.DeploymentEvent do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]
  
  attributes do
    uuid_v7_primary_key :id
    
    attribute :event_type, :atom do
      constraints one_of: [:deployment_started, :deployment_completed, :deployment_failed,
                          :service_started, :service_stopped, :service_scaled, :health_check_failed]
      allow_nil? false
      public? true
    end
    
    attribute :event_data, :map do
      default %{}
      public? true
      description "Event-specific data and metadata"
    end
    
    attribute :error_message, :string do
      public? true
      description "Error message if event represents a failure"
    end
    
    attribute :duration_ms, :integer do
      public? true
      description "Event duration in milliseconds"
    end
    
    create_timestamp :created_at
  end
  
  relationships do
    belongs_to :service_instance, Kyozo.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end
    
    belongs_to :triggered_by, Kyozo.Accounts.User do
      public? true
      description "User who triggered this event"
    end
  end
  
  actions do
    defaults [:read]
    
    create :create do
      primary? true
      accept [:event_type, :event_data, :error_message, :duration_ms]
      
      argument :service_instance_id, :uuid, allow_nil?: false
      
      change set_attribute(:service_instance_id, arg(:service_instance_id))
      change relate_actor(:triggered_by)
    end
    
    read :by_service do
      argument :service_instance_id, :uuid, allow_nil?: false
      filter expr(service_instance_id == ^arg(:service_instance_id))
      prepare build(sort: [created_at: :desc])
    end
    
    read :recent_events do
      argument :limit, :integer, default: 50
      prepare build(sort: [created_at: :desc], limit: arg(:limit))
    end
  end
  
  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:service_instance, :workspace, :team, :users])
    end
    
    policy action_type(:create) do
      authorize_if always()  # Internal system events
    end
  end
  
  postgres do
    table "deployment_events"
    repo Kyozo.Repo
    
    references do
      reference :service_instance, on_delete: :delete, index?: true
      reference :triggered_by, on_delete: :nilify
    end
    
    custom_indexes do
      index [:service_instance_id, :created_at]
      index [:event_type, :created_at]
      index [:created_at]
    end
  end
end
```

## Integration with Existing Workspaces Domain

### 5. Workspace Extensions

```elixir
# lib/kyozo/workspaces/workspace.ex - Extensions
defmodule Kyozo.Workspaces.Workspace do
  # ... existing attributes ...
  
  attributes do
    # Add container orchestration attributes
    attribute :container_enabled, :boolean do
      default false
      public? true
      description "Enable container orchestration for this workspace"
    end
    
    attribute :service_topology, :map do
      default %{}
      public? true
      description "Detected service topology and deployment configuration"
    end
    
    attribute :auto_deploy_enabled, :boolean do
      default false
      public? true
      description "Automatically deploy detected services"
    end
    
    attribute :container_registry_url, :string do
      public? true
      description "Custom container registry for this workspace"
    end
    
    attribute :deployment_environment, :atom do
      constraints one_of: [:development, :staging, :production]
      default :development
      public? true
    end
  end
  
  # ... existing relationships ...
  
  relationships do
    has_many :service_instances, Kyozo.Containers.ServiceInstance do
      public? true
      sort created_at: :desc
    end
    
    has_many :topology_detections, Kyozo.Containers.TopologyDetection do
      public? true
    end
  end
  
  # ... existing actions ...
  
  actions do
    action :analyze_service_topology, :update do
      change {Kyozo.Workspaces.Changes.AnalyzeServiceTopology}
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end
    
    action :deploy_all_services, :update do
      change {Kyozo.Workspaces.Changes.DeployAllServices}
    end
    
    action :stop_all_services, :update do
      change {Kyozo.Workspaces.Changes.StopAllServices}
    end
  end
  
  # ... existing calculations ...
  
  calculations do
    calculate :running_service_count, :integer, {Kyozo.Workspaces.Calculations.RunningServiceCount, []}
    calculate :total_service_count, :integer, {Kyozo.Workspaces.Calculations.TotalServiceCount, []}
    calculate :deployment_health_score, :decimal, {Kyozo.Workspaces.Calculations.DeploymentHealthScore, []}
  end
end
```

### 6. File Extensions for Service Metadata

```elixir
# lib/kyozo/workspaces/file.ex - Extensions
defmodule Kyozo.Workspaces.File do
  # ... existing attributes ...
  
  attributes do
    # Add service detection metadata
    attribute :service_metadata, :map do
      default %{}
      public? true
      description "Service-related metadata extracted from file analysis"
    end
    
    attribute :is_service_indicator, :boolean do
      default false
      public? true
      description "Whether this file indicates a deployable service"
    end
    
    attribute :detected_technologies, {:array, :string} do
      default []
      public? true
      description "Technologies detected in this file"
    end
  end
  
  # ... existing actions ...
  
  actions do
    action :analyze_service_indicators, :update do
      change {Kyozo.Workspaces.Changes.AnalyzeServiceIndicators}
    end
  end
end
```

## Implementation Components

### 7. Topology Detection Engine

```elixir
# lib/kyozo/containers/topology_detector.ex
defmodule Kyozo.Containers.TopologyDetector do
  @moduledoc """
  Analyzes workspace folder structures to detect service patterns
  and generate deployment recommendations.
  """
  
  alias Kyozo.Workspaces
  alias Kyozo.Containers.TopologyDetection
  
  def analyze_workspace(workspace_id) do
    workspace = Workspaces.get!(workspace_id, load: [:files])
    folder_tree = build_folder_tree(workspace.files)
    
    analysis = %{
      workspace_id: workspace_id,
      folders: analyze_folders(folder_tree),
      services: detect_services(folder_tree),
      dependencies: map_dependencies(folder_tree),
      deployment_order: calculate_deployment_order(folder_tree),
      recommendations: generate_recommendations(folder_tree)
    }
    
    # Store analysis results
    TopologyDetection.analyze_folder!(%{
      workspace_id: workspace_id,
      folder_path: "/",
      detected_patterns: analysis.services,
      dependency_map: analysis.dependencies,
      deployment_recommendations: analysis.recommendations,
      confidence_score: calculate_confidence(analysis)
    })
    
    analysis
  end
  
  def detect_service_type(folder_files) do
    patterns = %{
      dockerfile: has_file?(folder_files, "Dockerfile"),
      compose: has_file?(folder_files, "docker-compose.yml") || has_file?(folder_files, "docker-compose.yaml"),
      nodejs: has_file?(folder_files, "package.json"),
      python: has_file?(folder_files, "requirements.txt") || has_file?(folder_files, "pyproject.toml"),
      golang: has_file?(folder_files, "go.mod"),
      rust: has_file?(folder_files, "Cargo.toml"),
      nginx: has_file?(folder_files, "nginx.conf"),
      terraform: has_file?(folder_files, "main.tf") || has_file?(folder_files, "terraform.tf")
    }
    
    cond do
      patterns.dockerfile -> {:containerized, 0.9}
      patterns.compose -> {:compose_stack, 0.95}
      patterns.nodejs -> {:nodejs, 0.8}
      patterns.python -> {:python, 0.8}
      patterns.golang -> {:golang, 0.8}
      patterns.rust -> {:rust, 0.8}
      patterns.nginx -> {:proxy, 0.7}
      patterns.terraform -> {:infrastructure, 0.6}
      true -> {:unknown, 0.1}
    end
  end
  
  def generate_deployment_config(service_type, folder_files) do
    base_config = %{
      environment_variables: %{},
      port_mappings: %{},
      resource_limits: %{memory: "512Mi", cpu: "0.5", storage: "1Gi"},
      health_check_config: %{}
    }
    
    case service_type do
      :nodejs -> 
        package_json = get_file_content(folder_files, "package.json")
        merge_nodejs_config(base_config, package_json)
        
      :python ->
        requirements = get_file_content(folder_files, "requirements.txt")
        merge_python_config(base_config, requirements)
        
      :containerized ->
        dockerfile = get_file_content(folder_files, "Dockerfile")
        merge_dockerfile_config(base_config, dockerfile)
        
      :compose_stack ->
        compose_content = get_file_content(folder_files, "docker-compose.yml")
        merge_compose_config(base_config, compose_content)
        
      _ ->
        base_config
    end
  end
  
  defp merge_nodejs_config(base_config, package_json_content) do
    # Parse package.json and extract port, scripts, dependencies
    package_data = Jason.decode!(package_json_content || "{}")
    
    port = detect_port_from_scripts(package_data["scripts"] || %{})
    
    base_config
    |> put_in([:port_mappings], %{"#{port}/tcp" => port})
    |> put_in([:environment_variables, "NODE_ENV"], "production")
    |> put_in([:health_check_config], %{
      path: "/health",
      interval: 30,
      timeout: 10,
      retries: 3
    })
  end
  
  defp merge_python_config(base_config, requirements_content) do
    # Detect common Python frameworks
    has_django = String.contains?(requirements_content || "", "django")
    has_flask = String.contains?(requirements_content || "", "flask")
    has_fastapi = String.contains?(requirements_content || "", "fastapi")
    
    port = cond do
      has_django -> 8000
      has_flask -> 5000
      has_fastapi -> 8000
      true -> 8000
    end
    
    base_config
    |> put_in([:port_mappings], %{"#{port}/tcp" => port})
    |> put_in([:environment_variables, "PYTHONUNBUFFERED"], "1")
    |> put_in([:health_check_config], %{
      path: "/health",
      interval: 30,
      timeout: 10,
      retries: 3
    })
  end
  
  defp detect_port_from_scripts(scripts) do
    # Simple port detection from npm scripts
    start_script = scripts["start"] || scripts["dev"] || ""
    
    port_match = Regex.run(~r/(?:PORT|port)[:=]\s*(\d+)/, start_script)
    
    case port_match do
      [_, port_str] -> String.to_integer(port_str)
      _ -> 3000  # Default Node.js port
    end
  end
  
  defp has_file?(files, filename) do
    Enum.any?(files, &(&1.title == filename || &1.file_path == "/#{filename}"))
  end
  
  defp get_file_content(files, filename) do
    case Enum.find(files, &(&1.title == filename || &1.file_path == "/#{filename}")) do
      %{encrypted_content: content} when not is_nil(content) ->
        # In real implementation, decrypt and return content
        # For now, return mock content
        get_mock_content(filename)
      _ ->
        nil
    end
  end
  
  defp get_mock_content("package.json") do
    ~s({"name": "example-app", "scripts": {"start": "node index.js", "dev": "nodemon index.js"}})
  end
  
  defp get_mock_content("requirements.txt") do
    "flask==2.3.2\ngunicorn==20.1.0\npsycopg2==2.9.6"
  end
  
  defp get_mock_content(_), do: ""
end
```

### 8. Container Manager GenServer

```elixir
# lib/kyozo/containers/container_manager.ex
defmodule Kyozo.Containers.ContainerManager do
  use GenServer
  require Logger
  
  alias Kyozo.Containers.ServiceInstance
  alias Kyozo.Containers.DeploymentEvent
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def deploy_service(service_instance_id) do
    GenServer.call(__MODULE__, {:deploy, service_instance_id}, 30_000)
  end
  
  def start_service(service_instance_id) do
    GenServer.call(__MODULE__, {:start, service_instance_id})
  end
  
  def stop_service(service_instance_id) do
    GenServer.call(__MODULE__, {:stop, service_instance_id})
  end
  
  def get_service_status(service_instance_id) do
    GenServer.call(__MODULE__, {:status, service_instance_id})
  end
  
  def scale_service(service_instance_id, replica_count) do
    GenServer.call(__MODULE__, {:scale, service_instance_id, replica_count})
  end
  
  ## GenServer Callbacks
  
  def init(opts) do
    docker_config = Keyword.get(opts, :docker_config, %{})
    
    state = %{
      running_services: %{},
      docker_client: init_docker_client(docker_config),
      health_check_timer: nil
    }
    
    # Start health check timer
    timer = Process.send_after(self(), :health_check, 30_000)
    
    {:ok, %{state | health_check_timer: timer}}
  end
  
  def handle_call({:deploy, service_instance_id}, _from, state) do
    service_instance = ServiceInstance.read!(service_instance_id)
    
    case deploy_service_container(service_instance, state.docker_client) do
      {:ok, container_info} ->
        # Update service instance
        ServiceInstance.update!(service_instance, %{
          container_id: container_info.container_id,
          status: :running,
          deployed_at: DateTime.utc_now(),
          startup_time_ms: container_info.startup_time_ms
        })
        
        # Log deployment event
        DeploymentEvent.create!(%{
          service_instance_id: service_instance_id,
          event_type: :deployment_completed,
          event_data: %{
            container_id: container_info.container_id,
            startup_time_ms: container_info.startup_time_ms
          },
          duration_ms: container_info.startup_time_ms
        })
        
        # Update local state
        new_state = put_in(state.running_services[service_instance_id], container_info)
        
        {:reply, {:ok, container_info}, new_state}
      
      {:error, reason} ->
        # Update service instance status
        ServiceInstance.update!(service_instance, %{
          status: :error
        })
        
        # Log deployment failure
        DeploymentEvent.create!(%{
          service_instance_id: service_instance_id,
          event_type: :deployment_failed,
          error_message: inspect(reason)
        })
        
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:start, service_instance_id}, _from, state) do
    service_instance = ServiceInstance.read!(service_instance_id)
    
    case start_existing_container(service_instance.container_id, state.docker_client) do
      :ok ->
        ServiceInstance.update!(service_instance, %{status: :running})
        {:reply, :ok, state}
        
      {:error, reason} ->
        ServiceInstance.update!(service_instance, %{status: :error})
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:stop, service_instance_id}, _from, state) do
    case get_in(state.running_services, [service_instance_id]) do
      %{container_id: container_id} ->
        case stop_container(container_id, state.docker_client) do
          :ok ->
            ServiceInstance.update!(ServiceInstance.read!(service_instance_id), %{
              status: :stopped
            })
            
            new_state = update_in(state.running_services, &Map.delete(&1, service_instance_id))
            {:reply, :ok, new_state}
            
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
        
      nil ->
        {:reply, {:error, :not_running}, state}
    end
  end
  
  def handle_call({:scale, service_instance_id, replica_count}, _from, state) do
    service_instance = ServiceInstance.read!(service_instance_id)
    
    case scale_service_replicas(service_instance, replica_count, state.docker_client) do
      {:ok, scaled_info} ->
        ServiceInstance.update!(service_instance, %{
          status: :running,
          scaling_config: Map.put(service_instance.scaling_config, :current_replicas, replica_count)
        })
        
        {:reply, {:ok, scaled_info}, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_info(:health_check, state) do
    # Perform health checks on all running services
    Task.start(fn -> perform_health_checks(state.running_services) end)
    
    # Schedule next health check
    timer = Process.send_after(self(), :health_check, 30_000)
    
    {:noreply, %{state | health_check_timer: timer}}
  end
  
  ## Private Implementation
  
  defp deploy_service_container(service_instance, docker_client) do
    start_time = System.monotonic_time(:millisecond)
    
    case service_instance.service_type do
      :containerized -> 
        deploy_dockerfile_service(service_instance, docker_client)
        
      :nodejs -> 
        deploy_nodejs_service(service_instance, docker_client)
        
      :python -> 
        deploy_python_service(service_instance, docker_client)
        
      :compose_stack -> 
        deploy_compose_service(service_instance, docker_client)
        
      _ -> 
        {:error, :unsupported_service_type}
    end
    |> case do
      {:ok, container_id} ->
        end_time = System.monotonic_time(:millisecond)
        startup_time = end_time - start_time
        
        {:ok, %{
          container_id: container_id,
          startup_time_ms: startup_time,
          started_at: DateTime.utc_now()
        }}
        
      error -> error
    end
  end
  
  defp deploy_dockerfile_service(service_instance, docker_client) do
    workspace = Kyozo.Workspaces.get!(service_instance.workspace_id)
    folder_path = get_workspace_folder_path(workspace, service_instance.folder_path)
    
    build_config = %{
      context: folder_path,
      dockerfile: "Dockerfile",
      tag: generate_image_tag(service_instance)
    }
    
    with {:ok, image_id} <- build_docker_image(docker_client, build_config),
         {:ok, container_id} <- run_docker_container(docker_client, service_instance, image_id) do
      {:ok, container_id}
    end
  end
  
  defp deploy_nodejs_service(service_instance, docker_client) do
    # Generate Dockerfile for Node.js service
    dockerfile_content = generate_nodejs_dockerfile(service_instance)
    
    workspace = Kyozo.Workspaces.get!(service_instance.workspace_id)
    folder_path = get_workspace_folder_path(workspace, service_instance.folder_path)
    
    # Write generated Dockerfile
    dockerfile_path = Path.join(folder_path, "Dockerfile.generated")
    File.write!(dockerfile_path, dockerfile_content)
    
    build_config = %{
      context: folder_path,
      dockerfile: "Dockerfile.generated",
      tag: generate_image_tag(service_instance)
    }
    
    result = with {:ok, image_id} <- build_docker_image(docker_client, build_config),
                  {:ok, container_id} <- run_docker_container(docker_client, service_instance, image_id) do
      {:ok, container_id}
    end
    
    # Clean up generated Dockerfile
    File.rm(dockerfile_path)
    
    result
  end
  
  defp generate_nodejs_dockerfile(service_instance) do
    """
    FROM node:18-alpine
    WORKDIR /app
    
    # Copy package files
    COPY package*.json ./
    
    # Install dependencies
    RUN npm ci --only=production
    
    # Copy application code
    COPY . .
    
    # Expose port
    EXPOSE #{get_service_port(service_instance)}
    
    # Set environment variables
    #{format_env_vars(service_instance.environment_variables)}
    
    # Start application
    CMD ["npm", "start"]
    """
  end
  
  defp get_service_port(service_instance) do
    case service_instance.port_mappings do
      %{} = mappings when map_size(mappings) > 0 ->
        {port_key, _} = Enum.at(mappings, 0)
        port_key |> String.split("/") |> hd() |> String.to_integer()
      _ ->
        3000
    end
  end
  
  defp format_env_vars(env_vars) do
    env_vars
    |> Enum.map(fn {key, value} -> "ENV #{key}=#{value}" end)
    |> Enum.join("\n")
  end
  
  defp generate_image_tag(service_instance) do
    "kyozo/#{service_instance.name}:#{DateTime.utc_now() |> DateTime.to_unix()}"
  end
  
  defp build_docker_image(docker_client, build_config) do
    # Simulate Docker build - in real implementation, use Docker API
    Logger.info("Building Docker image with config: #{inspect(build_config)}")
    
    # Mock successful build
    image_id = "img_#{:rand.uniform(100000)}"
    {:ok, image_id}
  end
  
  defp run_docker_container(docker_client, service_instance, image_id) do
    container_config = %{
      image: image_id,
      name: "kyozo_#{service_instance.name}_#{:rand.uniform(1000)}",
      ports: format_port_mappings(service_instance.port_mappings),
      environment: format_environment(service_instance.environment_variables),
      restart_policy: "unless-stopped"
    }
    
    Logger.info("Running container with config: #{inspect(container_config)}")
    
    # Mock successful container creation
    container_id = "cnt_#{:rand.uniform(100000)}"
    {:ok, container_id}
  end
  
  defp format_port_mappings(port_mappings) do
    Enum.map(port_mappings, fn {container_port, host_port} ->
      "#{host_port}:#{container_port}"
    end)
  end
  
  defp format_environment(env_vars) do
    Enum.map(env_vars, fn {key, value} -> "#{key}=#{value}" end)
  end
  
  defp perform_health_checks(running_services) do
    Enum.each(running_services, fn {service_instance_id, container_info} ->
      case check_container_health(container_info.container_id) do
        {:ok, health_data} ->
          ServiceInstance.update_health_status!(
            ServiceInstance.read!(service_instance_id),
            %{
              health_status: :healthy,
              memory_usage_mb: health_data.memory_mb,
              cpu_usage_percent: health_data.cpu_percent
            }
          )
          
        {:error, _reason} ->
          ServiceInstance.update_health_status!(
            ServiceInstance.read!(service_instance_id),
            %{health_status: :unhealthy}
          )
      end
    end)
  end
  
  defp check_container_health(container_id) do
    # Mock health check - in real implementation, query Docker API
    {:ok, %{
      memory_mb: :rand.uniform(500),
      cpu_percent: :rand.uniform(100) / 1.0
    }}
  end
  
  defp init_docker_client(config) do
    # Initialize Docker client - mock for now
    %{socket: "/var/run/docker.sock", config: config}
  end
  
  defp get_workspace_folder_path(workspace, folder_path) do
    # Get absolute path to workspace folder
    Path.join([Application.get_env(:kyozo, :workspace_root, "/tmp/workspaces"), 
               workspace.id, folder_path])
  end
end
```

This specification provides a complete foundation for the Folder-as-a-Service functionality while maintaining compatibility with Kyozo Store's existing architecture patterns. The implementation follows the established UUID v7 primary keys, team-based isolation, proper Ash relationships, and JSON:API compliance patterns documented in the codebase.