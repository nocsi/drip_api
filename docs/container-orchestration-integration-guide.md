# Container Orchestration Integration Guide

## Overview

This guide details how to integrate the container orchestration features into the existing Kyozo Store codebase, following established patterns and maintaining compatibility with the current architecture.

## Database Migrations

### 1. Create Container Domain Tables

```elixir
# priv/repo/migrations/20240120000001_create_service_instances.exs
defmodule Kyozo.Repo.Migrations.CreateServiceInstances do
  use Ecto.Migration

  def up do
    # Create service_instances table
    create table(:service_instances, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v7()")
      
      # Core identification
      add :name, :text, null: false
      add :folder_path, :text, null: false
      add :service_type, :text, null: false
      add :status, :text, null: false, default: "detecting"
      
      # Container runtime
      add :container_id, :text
      add :deployment_config, :map, default: %{}
      add :port_mappings, :map, default: %{}
      add :environment_variables, :map, default: %{}
      add :resource_limits, :map, default: %{}
      add :health_check_config, :map
      add :scaling_config, :map, default: %{}
      
      # Runtime status
      add :last_health_check_at, :utc_datetime_usec
      add :health_status, :text, default: "unknown"
      add :deployment_logs, :text
      add :startup_time_ms, :integer
      add :memory_usage_mb, :integer
      add :cpu_usage_percent, :decimal
      
      # Relationships
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :topology_detection_id, references(:topology_detections, type: :binary_id, on_delete: :nilify_all)
      add :parent_service_id, references(:service_instances, type: :binary_id, on_delete: :nilify_all)
      
      # Timestamps
      add :created_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :deployed_at, :utc_datetime_usec
      add :last_accessed_at, :utc_datetime_usec
    end
    
    # Indexes for performance
    create index(:service_instances, [:team_id, :workspace_id, :status])
    create index(:service_instances, [:team_id, :service_type])
    create index(:service_instances, [:status, :health_status])
    create unique_index(:service_instances, [:workspace_id, :folder_path])
    create index(:service_instances, [:created_at])
    create index(:service_instances, [:updated_at])
    
    # Check constraints
    create constraint(:service_instances, :valid_service_type, 
                     check: "service_type IN ('containerized', 'nodejs', 'python', 'golang', 'rust', 'compose_stack', 'proxy')")
    create constraint(:service_instances, :valid_status,
                     check: "status IN ('detecting', 'deployable', 'deploying', 'running', 'stopped', 'error', 'scaling')")
    create constraint(:service_instances, :valid_health_status,
                     check: "health_status IN ('healthy', 'unhealthy', 'unknown')")
    create constraint(:service_instances, :positive_startup_time,
                     check: "startup_time_ms IS NULL OR startup_time_ms >= 0")
    create constraint(:service_instances, :positive_memory_usage,
                     check: "memory_usage_mb IS NULL OR memory_usage_mb >= 0")
  end

  def down do
    drop table(:service_instances)
  end
end
```

```elixir
# priv/repo/migrations/20240120000002_create_topology_detections.exs
defmodule Kyozo.Repo.Migrations.CreateTopologyDetections do
  use Ecto.Migration

  def up do
    create table(:topology_detections, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v7()")
      
      # Analysis data
      add :folder_path, :text, null: false
      add :detected_patterns, :map, default: %{}
      add :service_indicators, :map, default: %{}
      add :dependency_map, :map, default: %{}
      add :deployment_recommendations, :map, default: %{}
      add :confidence_score, :decimal
      add :analysis_metadata, :map, default: %{}
      
      # Relationships
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      
      # Timestamps
      add :created_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
    end
    
    # Indexes
    create index(:topology_detections, [:team_id, :workspace_id])
    create unique_index(:topology_detections, [:workspace_id, :folder_path])
    create index(:topology_detections, [:confidence_score])
    create index(:topology_detections, [:created_at])
    
    # Constraints
    create constraint(:topology_detections, :valid_confidence_score,
                     check: "confidence_score IS NULL OR (confidence_score >= 0.0 AND confidence_score <= 1.0)")
  end

  def down do
    drop table(:topology_detections)
  end
end
```

```elixir
# priv/repo/migrations/20240120000003_create_deployment_events.exs
defmodule Kyozo.Repo.Migrations.CreateDeploymentEvents do
  use Ecto.Migration

  def up do
    create table(:deployment_events, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v7()")
      
      # Event data
      add :event_type, :text, null: false
      add :event_data, :map, default: %{}
      add :error_message, :text
      add :duration_ms, :integer
      
      # Relationships
      add :service_instance_id, references(:service_instances, type: :binary_id, on_delete: :delete_all), null: false
      add :triggered_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      
      # Timestamps
      add :created_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
    end
    
    # Indexes
    create index(:deployment_events, [:service_instance_id, :created_at])
    create index(:deployment_events, [:event_type, :created_at])
    create index(:deployment_events, [:created_at])
    
    # Constraints
    create constraint(:deployment_events, :valid_event_type,
                     check: "event_type IN ('deployment_started', 'deployment_completed', 'deployment_failed', 'service_started', 'service_stopped', 'service_scaled', 'health_check_failed')")
    create constraint(:deployment_events, :positive_duration,
                     check: "duration_ms IS NULL OR duration_ms >= 0")
  end

  def down do
    drop table(:deployment_events)
  end
end
```

### 2. Extend Existing Tables

```elixir
# priv/repo/migrations/20240120000004_add_container_fields_to_workspaces.exs
defmodule Kyozo.Repo.Migrations.AddContainerFieldsToWorkspaces do
  use Ecto.Migration

  def up do
    alter table(:workspaces) do
      add :container_enabled, :boolean, default: false, null: false
      add :service_topology, :map, default: %{}
      add :auto_deploy_enabled, :boolean, default: false, null: false
      add :container_registry_url, :text
      add :deployment_environment, :text, default: "development", null: false
    end
    
    create index(:workspaces, [:team_id, :container_enabled])
    create index(:workspaces, [:deployment_environment])
    
    create constraint(:workspaces, :valid_deployment_environment,
                     check: "deployment_environment IN ('development', 'staging', 'production')")
  end

  def down do
    alter table(:workspaces) do
      remove :container_enabled
      remove :service_topology
      remove :auto_deploy_enabled
      remove :container_registry_url
      remove :deployment_environment
    end
  end
end
```

```elixir
# priv/repo/migrations/20240120000005_add_service_metadata_to_files.exs
defmodule Kyozo.Repo.Migrations.AddServiceMetadataToFiles do
  use Ecto.Migration

  def up do
    alter table(:files) do
      add :service_metadata, :map, default: %{}
      add :is_service_indicator, :boolean, default: false, null: false
      add :detected_technologies, {:array, :text}, default: []
    end
    
    create index(:files, [:workspace_id, :is_service_indicator])
    create index(:files, [:detected_technologies], using: :gin)
  end

  def down do
    alter table(:files) do
      remove :service_metadata
      remove :is_service_indicator
      remove :detected_technologies
    end
  end
end
```

## Application Configuration

### 3. Update Application Supervision Tree

```elixir
# lib/kyozo/application.ex
defmodule Kyozo.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ... existing children ...
      
      # Container orchestration components
      {Kyozo.Containers.ContainerManager, []},
      {Kyozo.Containers.HealthCheckScheduler, []},
      {Kyozo.Containers.TopologyAnalyzer, []},
      
      # Background job processing for containers
      {Oban.Pro.Workers.SmartEngine, [name: Kyozo.ContainerOban, concurrency: 5]}
    ]

    opts = [strategy: :one_for_one, name: Kyozo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 4. Add Container Configuration

```elixir
# config/config.exs
config :kyozo, :containers,
  # Docker configuration
  docker_socket: System.get_env("DOCKER_SOCKET", "/var/run/docker.sock"),
  docker_api_version: "1.41",
  
  # Default resource limits
  default_memory_limit: "512Mi",
  default_cpu_limit: "0.5",
  default_storage_limit: "1Gi",
  
  # Health check configuration
  health_check_interval: 30_000,
  health_check_timeout: 10_000,
  
  # Service registry
  registry_url: System.get_env("CONTAINER_REGISTRY_URL"),
  
  # Deployment configuration
  workspace_root: System.get_env("WORKSPACE_ROOT", "/tmp/kyozo/workspaces"),
  enable_auto_deploy: System.get_env("ENABLE_AUTO_DEPLOY", "false") == "true"

# Environment-specific overrides
import_config "#{Mix.env()}.exs"
```

```elixir
# config/dev.exs
config :kyozo, :containers,
  # Development-specific container settings
  docker_socket: "/var/run/docker.sock",
  enable_mock_deployment: true,
  workspace_root: "/tmp/kyozo/dev/workspaces"
```

```elixir
# config/prod.exs
config :kyozo, :containers,
  # Production container settings
  docker_socket: "/var/run/docker.sock",
  enable_mock_deployment: false,
  registry_url: System.get_env("CONTAINER_REGISTRY_URL"),
  workspace_root: "/opt/kyozo/workspaces"
```

## API Extensions

### 5. JSON:API Route Integration

```elixir
# lib/kyozo_web/router.ex
defmodule KyozoWeb.Router do
  use KyozoWeb, :router

  # ... existing routes ...

  scope "/api/v1", KyozoWeb do
    pipe_through :api

    # ... existing API routes ...

    # Container orchestration routes
    resources "/service_instances", ServiceInstanceController, except: [:new, :edit] do
      # Service lifecycle actions
      post "/deploy", ServiceInstanceController, :deploy
      post "/start", ServiceInstanceController, :start
      post "/stop", ServiceInstanceController, :stop
      post "/restart", ServiceInstanceController, :restart
      patch "/scale", ServiceInstanceController, :scale
      
      # Monitoring endpoints
      get "/logs", ServiceInstanceController, :logs
      get "/health", ServiceInstanceController, :health
      get "/metrics", ServiceInstanceController, :metrics
      get "/events", ServiceInstanceController, :events
    end
    
    resources "/topology_detections", TopologyDetectionController, except: [:new, :edit] do
      post "/analyze", TopologyDetectionController, :analyze
      post "/reanalyze", TopologyDetectionController, :reanalyze
    end
    
    # Workspace container actions
    scope "/workspaces/:workspace_id" do
      post "/analyze_topology", WorkspaceController, :analyze_topology
      post "/deploy_services", WorkspaceController, :deploy_services
      post "/stop_services", WorkspaceController, :stop_services
      get "/service_status", WorkspaceController, :service_status
    end
  end
end
```

### 6. JSON:API Controllers

```elixir
# lib/kyozo_web/controllers/service_instance_controller.ex
defmodule KyozoWeb.ServiceInstanceController do
  use KyozoWeb, :controller
  use AshJsonApi.Controller

  def deploy(conn, %{"id" => id}) do
    with {:ok, service_instance} <- Kyozo.Containers.ServiceInstance.deploy!(id, actor: conn.assigns.current_user) do
      conn
      |> put_status(:accepted)
      |> render("show.json", service_instance: service_instance)
    else
      {:error, %Ash.Error.Invalid{} = error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("errors.json", errors: error.errors)
        
      {:error, %Ash.Error.Forbidden{}} ->
        conn
        |> put_status(:forbidden)
        |> render("errors.json", errors: [%{detail: "Insufficient permissions"}])
    end
  end
  
  def start(conn, %{"id" => id}) do
    with {:ok, service_instance} <- Kyozo.Containers.ServiceInstance.start!(id, actor: conn.assigns.current_user) do
      conn
      |> put_status(:ok)
      |> render("show.json", service_instance: service_instance)
    end
  end
  
  def stop(conn, %{"id" => id}) do
    with {:ok, service_instance} <- Kyozo.Containers.ServiceInstance.stop!(id, actor: conn.assigns.current_user) do
      conn
      |> put_status(:ok)
      |> render("show.json", service_instance: service_instance)
    end
  end
  
  def scale(conn, %{"id" => id, "replica_count" => replica_count}) do
    with {:ok, service_instance} <- Kyozo.Containers.ServiceInstance.scale!(id, replica_count: replica_count, actor: conn.assigns.current_user) do
      conn
      |> put_status(:ok)
      |> render("show.json", service_instance: service_instance)
    end
  end
  
  def logs(conn, %{"id" => id} = params) do
    lines = Map.get(params, "lines", "100") |> String.to_integer()
    follow = Map.get(params, "follow", "false") == "true"
    
    case Kyozo.Containers.ContainerManager.get_service_logs(id, lines: lines, follow: follow) do
      {:ok, logs} ->
        conn
        |> put_status(:ok)
        |> json(%{data: %{logs: logs}})
        
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: inspect(reason)}]})
    end
  end
  
  def health(conn, %{"id" => id}) do
    case Kyozo.Containers.ContainerManager.get_service_status(id) do
      {:ok, status} ->
        conn
        |> put_status(:ok)
        |> json(%{data: status})
        
      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{errors: [%{detail: inspect(reason)}]})
    end
  end
  
  def metrics(conn, %{"id" => id}) do
    service_instance = Kyozo.Containers.ServiceInstance.read!(id, actor: conn.assigns.current_user)
    
    metrics = %{
      uptime_seconds: service_instance.uptime_seconds,
      memory_usage_mb: service_instance.memory_usage_mb,
      cpu_usage_percent: service_instance.cpu_usage_percent,
      health_status: service_instance.health_status,
      last_health_check_at: service_instance.last_health_check_at,
      resource_utilization: service_instance.resource_utilization
    }
    
    conn
    |> put_status(:ok)
    |> json(%{data: metrics})
  end
  
  def events(conn, %{"id" => id} = params) do
    limit = Map.get(params, "limit", "50") |> String.to_integer()
    
    events = Kyozo.Containers.DeploymentEvent.by_service!(id, limit: limit, actor: conn.assigns.current_user)
    
    conn
    |> put_status(:ok)
    |> render("events.json", events: events)
  end
end
```

```elixir
# lib/kyozo_web/controllers/topology_detection_controller.ex
defmodule KyozoWeb.TopologyDetectionController do
  use KyozoWeb, :controller
  use AshJsonApi.Controller

  def analyze(conn, %{"workspace_id" => workspace_id, "folder_path" => folder_path}) do
    with {:ok, detection} <- Kyozo.Containers.TopologyDetection.analyze_folder!(
           workspace_id: workspace_id,
           folder_path: folder_path,
           actor: conn.assigns.current_user
         ) do
      conn
      |> put_status(:created)
      |> render("show.json", topology_detection: detection)
    end
  end
  
  def reanalyze(conn, %{"id" => id}) do
    with {:ok, detection} <- Kyozo.Containers.TopologyDetection.reanalyze!(id, actor: conn.assigns.current_user) do
      conn
      |> put_status(:ok)
      |> render("show.json", topology_detection: detection)
    end
  end
end
```

## Background Job Integration

### 7. Oban Worker Integration

```elixir
# lib/kyozo/containers/workers/deployment_worker.ex
defmodule Kyozo.Containers.Workers.DeploymentWorker do
  use Oban.Worker, queue: :container_deployment, max_attempts: 3
  
  alias Kyozo.Containers.{ServiceInstance, ContainerManager, DeploymentEvent}
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"service_instance_id" => service_instance_id, "action" => action}}) do
    service_instance = ServiceInstance.read!(service_instance_id)
    
    case action do
      "deploy" -> handle_deployment(service_instance)
      "start" -> handle_start(service_instance)
      "stop" -> handle_stop(service_instance)
      "scale" -> handle_scaling(service_instance)
      _ -> {:error, :unknown_action}
    end
  end
  
  defp handle_deployment(service_instance) do
    case ContainerManager.deploy_service(service_instance.id) do
      {:ok, _container_info} ->
        DeploymentEvent.create!(%{
          service_instance_id: service_instance.id,
          event_type: :deployment_completed,
          event_data: %{worker: __MODULE__}
        })
        :ok
        
      {:error, reason} ->
        DeploymentEvent.create!(%{
          service_instance_id: service_instance.id,
          event_type: :deployment_failed,
          error_message: inspect(reason),
          event_data: %{worker: __MODULE__}
        })
        {:error, reason}
    end
  end
  
  defp handle_start(service_instance) do
    ContainerManager.start_service(service_instance.id)
  end
  
  defp handle_stop(service_instance) do
    ContainerManager.stop_service(service_instance.id)
  end
  
  defp handle_scaling(service_instance) do
    replica_count = service_instance.scaling_config["target_replicas"] || 1
    ContainerManager.scale_service(service_instance.id, replica_count)
  end
end
```

```elixir
# lib/kyozo/containers/workers/health_check_worker.ex
defmodule Kyozo.Containers.Workers.HealthCheckWorker do
  use Oban.Worker, queue: :health_checks, max_attempts: 1
  
  alias Kyozo.Containers.{ServiceInstance, ContainerManager}
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"service_instance_id" => service_instance_id}}) do
    case ContainerManager.get_service_status(service_instance_id) do
      {:ok, status} ->
        ServiceInstance.update_health_status!(
          ServiceInstance.read!(service_instance_id),
          %{
            health_status: status.health_status,
            memory_usage_mb: status.memory_usage_mb,
            cpu_usage_percent: status.cpu_usage_percent,
            last_health_check_at: DateTime.utc_now()
          }
        )
        :ok
        
      {:error, _reason} ->
        ServiceInstance.update_health_status!(
          ServiceInstance.read!(service_instance_id),
          %{
            health_status: :unhealthy,
            last_health_check_at: DateTime.utc_now()
          }
        )
        :ok
    end
  end
end
```

```elixir
# lib/kyozo/containers/workers/topology_analysis_worker.ex
defmodule Kyozo.Containers.Workers.TopologyAnalysisWorker do
  use Oban.Worker, queue: :topology_analysis, max_attempts: 2
  
  alias Kyozo.Containers.{TopologyDetector, TopologyDetection}
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"workspace_id" => workspace_id}}) do
    case TopologyDetector.analyze_workspace(workspace_id) do
      %{} = analysis ->
        # Update workspace service topology cache
        workspace = Kyozo.Workspaces.get!(workspace_id)
        Kyozo.Workspaces.update!(workspace, %{service_topology: analysis})
        :ok
        
      error ->
        {:error, error}
    end
  end
end
```

## Real-time Integration

### 8. Phoenix PubSub Integration

```elixir
# lib/kyozo/containers/events/publisher.ex
defmodule Kyozo.Containers.Events.Publisher do
  @moduledoc """
  Publishes container-related events via Phoenix PubSub for real-time updates.
  """
  
  alias Phoenix.PubSub
  
  def broadcast_service_status_changed(service_instance) do
    PubSub.broadcast(
      Kyozo.PubSub,
      "workspace:#{service_instance.workspace_id}",
      {:service_status_changed, %{
        service_instance_id: service_instance.id,
        status: service_instance.status,
        health_status: service_instance.health_status
      }}
    )
    
    PubSub.broadcast(
      Kyozo.PubSub,
      "service:#{service_instance.id}",
      {:status_changed, %{
        status: service_instance.status,
        health_status: service_instance.health_status,
        timestamp: DateTime.utc_now()
      }}
    )
  end
  
  def broadcast_deployment_event(deployment_event) do
    service_instance = Kyozo.Containers.ServiceInstance.read!(deployment_event.service_instance_id)