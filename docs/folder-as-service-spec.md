# Kyozo Store: Folder as a Service Specification

## Overview

Folder as a Service (FaaS) is a container orchestration pattern that treats file system folders as deployable service units. In the context of Kyozo Store, this specification defines how to integrate containerized workspace environments with the existing multi-tenant architecture, leveraging the platform's storage abstraction and collaborative features.

## Integration with Kyozo Store Architecture

### Core Principles

1. **Workspace-Container Mapping**: Each Kyozo workspace can spawn isolated container environments
2. **Storage Backend Integration**: Leverage existing storage backends (Git, S3, Disk, Hybrid) for container persistence
3. **Multi-Tenant Isolation**: Container environments inherit team-based security boundaries
4. **Event-Driven Orchestration**: Use existing event system for container lifecycle management
5. **Real-time Collaboration**: Extend collaborative editing to containerized environments

### Architectural Integration Points

#### 1. Workspace Resource Extension

```elixir
# lib/kyozo/workspaces/workspace.ex
defmodule Kyozo.Workspaces.Workspace do
  attributes do
    # Existing attributes...
    
    # FaaS-specific attributes
    attribute :container_enabled, :boolean do
      default false
      public? true
    end
    
    attribute :container_config, :map do
      default %{}
      public? true
    end
    
    attribute :container_status, :atom do
      constraints one_of: [:stopped, :starting, :running, :stopping, :error]
      default :stopped
      public? true
    end
    
    attribute :container_metadata, :map do
      default %{}
      public? false
    end
  end
  
  actions do
    # Existing actions...
    
    action :start_container, :update do
      argument :container_image, :string, allow_nil?: false
      argument :environment_vars, :map, default: %{}
      argument :resource_limits, :map, default: %{}
      
      change {Kyozo.Workspaces.Changes.StartContainer}
    end
    
    action :stop_container, :update do
      change {Kyozo.Workspaces.Changes.StopContainer}
    end
    
    action :get_container_status, :read do
      prepare {Kyozo.Workspaces.Preparations.LoadContainerStatus}
    end
  end
  
  calculations do
    # Existing calculations...
    
    calculate :container_uptime, :integer, {Kyozo.Workspaces.Calculations.ContainerUptime, []}
    calculate :container_resource_usage, :map, {Kyozo.Workspaces.Calculations.ResourceUsage, []}
  end
end
```

#### 2. Container Orchestration Domain

```elixir
# lib/kyozo/containers.ex
defmodule Kyozo.Containers do
  use Ash.Domain, otp_app: :kyozo, extensions: [AshJsonApi.Domain]
  
  resources do
    resource Kyozo.Containers.Container do
      define :create_container
      define :start_container
      define :stop_container
      define :delete_container
      define :list_containers
      define :get_container_status
    end
    
    resource Kyozo.Containers.ContainerImage do
      define :list_images
      define :pull_image
      define :build_image
    end
    
    resource Kyozo.Containers.ContainerVolume do
      define :create_volume
      define :mount_volume
      define :unmount_volume
    end
  end
end
```

#### 3. Container Resource Definition

```elixir
# lib/kyozo/containers/container.ex
defmodule Kyozo.Containers.Container do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]
  
  attributes do
    uuid_v7_primary_key :id
    
    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end
    
    attribute :image, :string do
      allow_nil? false
      public? true
    end
    
    attribute :status, :atom do
      constraints one_of: [:created, :running, :paused, :stopped, :removed]
      default :created
      public? true
    end
    
    attribute :config, :map do
      default %{}
      public? true
    end
    
    attribute :environment_vars, :map do
      default %{}
      public? true
    end
    
    attribute :resource_limits, :map do
      default %{
        memory: "512Mi",
        cpu: "0.5",
        storage: "1Gi"
      }
      public? true
    end
    
    attribute :ports, {:array, :map} do
      default []
      public? true
    end
    
    attribute :volumes, {:array, :map} do
      default []
      public? true
    end
    
    attribute :networks, {:array, :string} do
      default []
      public? true
    end
    
    attribute :labels, :map do
      default %{}
      public? true
    end
    
    attribute :health_check, :map do
      public? true
    end
    
    attribute :restart_policy, :atom do
      constraints one_of: [:no, :always, :unless_stopped, :on_failure]
      default :unless_stopped
      public? true
    end
    
    # Runtime information
    attribute :container_id, :string do
      public? false
    end
    
    attribute :ip_address, :string do
      public? true
    end
    
    attribute :started_at, :utc_datetime_usec do
      public? true
    end
    
    attribute :finished_at, :utc_datetime_usec do
      public? true
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
    
    belongs_to :created_by, Kyozo.Accounts.User do
      public? true
    end
    
    has_many :volume_mounts, Kyozo.Containers.ContainerVolume do
      public? true
    end
    
    has_many :logs, Kyozo.Containers.ContainerLog do
      public? true
    end
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :create do
      accept [:name, :image, :config, :environment_vars, :resource_limits, :ports, :volumes, :networks]
      
      argument :workspace_id, :uuid, allow_nil?: false
      
      change set_attribute(:workspace_id, arg(:workspace_id))
      change relate_actor(:created_by)
      change {Kyozo.Containers.Changes.ValidateContainerConfig}
      change {Kyozo.Containers.Changes.SetTeamFromWorkspace}
    end
    
    update :start do
      change {Kyozo.Containers.Changes.StartContainer}
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :stop do
      change {Kyozo.Containers.Changes.StopContainer}
      change set_attribute(:finished_at, &DateTime.utc_now/0)
    end
    
    update :restart do
      change {Kyozo.Containers.Changes.RestartContainer}
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
      authorize_if actor_attribute_in_relationship(:team, :users)
    end
    
    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end
  end
  
  calculations do
    calculate :uptime, :integer, {Kyozo.Containers.Calculations.Uptime, []}
    calculate :resource_usage, :map, {Kyozo.Containers.Calculations.ResourceUsage, []}
  end
  
  postgres do
    table "containers"
    repo Kyozo.Repo
    
    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :created_by, on_delete: :nilify
    end
    
    custom_indexes do
      index [:team_id, :workspace_id, :status]
      index [:team_id, :status]
      index [:created_at]
    end
  end
end
```

## Container Orchestration Implementation

### Docker Integration

```elixir
# lib/kyozo/containers/orchestrators/docker_orchestrator.ex
defmodule Kyozo.Containers.Orchestrators.DockerOrchestrator do
  @behaviour Kyozo.Containers.OrchestratorBehaviour
  
  alias Kyozo.Containers.Container
  alias Kyozo.Storage
  
  @impl true
  def create_container(%Container{} = container) do
    with {:ok, volumes} <- setup_workspace_volumes(container),
         {:ok, network} <- setup_container_network(container),
         {:ok, docker_config} <- build_docker_config(container, volumes, network),
         {:ok, container_id} <- Docker.API.create_container(docker_config) do
      
      Container.update(container, %{container_id: container_id})
    end
  end
  
  @impl true
  def start_container(%Container{container_id: container_id} = container) do
    with {:ok, _} <- Docker.API.start_container(container_id),
         {:ok, inspect_data} <- Docker.API.inspect_container(container_id) do
      
      Container.update(container, %{
        status: :running,
        ip_address: get_ip_address(inspect_data),
        started_at: DateTime.utc_now()
      })
    end
  end
  
  @impl true
  def stop_container(%Container{container_id: container_id} = container) do
    with {:ok, _} <- Docker.API.stop_container(container_id) do
      Container.update(container, %{
        status: :stopped,
        finished_at: DateTime.utc_now()
      })
    end
  end
  
  defp setup_workspace_volumes(%Container{workspace: workspace} = container) do
    # Map workspace storage to container volumes
    workspace_path = get_workspace_storage_path(workspace)
    
    volumes = [
      %{
        name: "workspace-data",
        host_path: workspace_path,
        container_path: "/workspace",
        read_only: false
      },
      %{
        name: "workspace-config",
        host_path: "#{workspace_path}/.kyozo",
        container_path: "/workspace/.kyozo",
        read_only: true
      }
    ]
    
    {:ok, volumes}
  end
  
  defp build_docker_config(container, volumes, network) do
    config = %{
      "Image" => container.image,
      "Env" => format_environment_vars(container.environment_vars),
      "WorkingDir" => "/workspace",
      "NetworkMode" => network,
      "HostConfig" => %{
        "Memory" => parse_memory_limit(container.resource_limits["memory"]),
        "CpuShares" => parse_cpu_shares(container.resource_limits["cpu"]),
        "Binds" => format_volume_binds(volumes),
        "PortBindings" => format_port_bindings(container.ports),
        "RestartPolicy" => %{"Name" => to_string(container.restart_policy)}
      },
      "Labels" => Map.merge(container.labels, %{
        "kyozo.workspace.id" => container.workspace_id,
        "kyozo.team.id" => container.team_id,
        "kyozo.container.type" => "workspace"
      })
    }
    
    {:ok, config}
  end
end
```

### Kubernetes Integration

```elixir
# lib/kyozo/containers/orchestrators/kubernetes_orchestrator.ex
defmodule Kyozo.Containers.Orchestrators.KubernetesOrchestrator do
  @behaviour Kyozo.Containers.OrchestratorBehaviour
  
  alias K8s.Client
  alias Kyozo.Containers.Container
  
  @impl true
  def create_container(%Container{} = container) do
    with {:ok, deployment} <- build_deployment_spec(container),
         {:ok, service} <- build_service_spec(container),
         {:ok, pvc} <- build_persistent_volume_claim(container),
         {:ok, _} <- Client.create(deployment),
         {:ok, _} <- Client.create(service),
         {:ok, _} <- Client.create(pvc) do
      
      Container.update(container, %{
        container_id: deployment.metadata.name,
        status: :running
      })
    end
  end
  
  defp build_deployment_spec(%Container{} = container) do
    spec = %{
      "apiVersion" => "apps/v1",
      "kind" => "Deployment",
      "metadata" => %{
        "name" => "workspace-#{container.workspace_id}",
        "namespace" => "kyozo-workspaces",
        "labels" => Map.merge(container.labels, %{
          "app" => "kyozo-workspace",
          "workspace-id" => container.workspace_id,
          "team-id" => container.team_id
        })
      },
      "spec" => %{
        "replicas" => 1,
        "selector" => %{
          "matchLabels" => %{
            "app" => "kyozo-workspace",
            "workspace-id" => container.workspace_id
          }
        },
        "template" => %{
          "metadata" => %{
            "labels" => %{
              "app" => "kyozo-workspace",
              "workspace-id" => container.workspace_id
            }
          },
          "spec" => %{
            "containers" => [
              %{
                "name" => "workspace",
                "image" => container.image,
                "env" => format_k8s_env_vars(container.environment_vars),
                "resources" => %{
                  "limits" => container.resource_limits,
                  "requests" => calculate_resource_requests(container.resource_limits)
                },
                "volumeMounts" => [
                  %{
                    "name" => "workspace-storage",
                    "mountPath" => "/workspace"
                  }
                ],
                "ports" => format_k8s_ports(container.ports)
              }
            ],
            "volumes" => [
              %{
                "name" => "workspace-storage",
                "persistentVolumeClaim" => %{
                  "claimName" => "workspace-pvc-#{container.workspace_id}"
                }
              }
            ]
          }
        }
      }
    }
    
    {:ok, spec}
  end
end
```

## Storage Integration

### Workspace-Container Volume Mapping

```elixir
# lib/kyozo/containers/storage_integration.ex
defmodule Kyozo.Containers.StorageIntegration do
  alias Kyozo.Storage
  alias Kyozo.Workspaces.Workspace
  
  def setup_workspace_volumes(%Workspace{} = workspace) do
    case workspace.storage_backend do
      :git -> setup_git_volumes(workspace)
      :s3 -> setup_s3_volumes(workspace)
      :disk -> setup_disk_volumes(workspace)
      :hybrid -> setup_hybrid_volumes(workspace)
    end
  end
  
  defp setup_git_volumes(%Workspace{} = workspace) do
    # Clone repository to local volume
    repo_url = workspace.git_repository_url
    branch = workspace.git_branch || "main"
    local_path = get_workspace_local_path(workspace)
    
    with {:ok, _} <- Git.clone(repo_url, local_path, branch: branch),
         {:ok, _} <- setup_git_hooks(workspace, local_path) do
      
      {:ok, %{
        host_path: local_path,
        container_path: "/workspace",
        read_only: false,
        sync_strategy: :git_push_pull
      }}
    end
  end
  
  defp setup_s3_volumes(%Workspace{} = workspace) do
    # Setup S3FS mount point
    s3_path = get_workspace_s3_path(workspace)
    mount_path = get_workspace_mount_path(workspace)
    
    with {:ok, _} <- S3FS.mount(s3_path, mount_path),
         {:ok, _} <- setup_s3_sync_daemon(workspace) do
      
      {:ok, %{
        host_path: mount_path,
        container_path: "/workspace",
        read_only: false,
        sync_strategy: :s3_sync
      }}
    end
  end
  
  defp setup_disk_volumes(%Workspace{} = workspace) do
    # Direct disk mount - fastest option
    disk_path = get_workspace_disk_path(workspace)
    
    {:ok, %{
      host_path: disk_path,
      container_path: "/workspace",
      read_only: false,
      sync_strategy: :direct
    }}
  end
  
  defp setup_hybrid_volumes(%Workspace{} = workspace) do
    # Use intelligent backend selection
    primary_backend = determine_primary_backend(workspace)
    cache_path = get_workspace_cache_path(workspace)
    
    with {:ok, primary_volume} <- setup_primary_volume(workspace, primary_backend),
         {:ok, _} <- setup_cache_layer(workspace, cache_path) do
      
      {:ok, %{
        host_path: cache_path,
        container_path: "/workspace", 
        read_only: false,
        sync_strategy: :hybrid_sync,
        primary_backend: primary_backend
      }}
    end
  end
end
```

### Real-time File Synchronization

```elixir
# lib/kyozo/containers/file_sync.ex
defmodule Kyozo.Containers.FileSync do
  use GenServer
  
  alias Phoenix.PubSub
  alias Kyozo.Workspaces
  
  def start_link(container_id) do
    GenServer.start_link(__MODULE__, container_id, name: via_tuple(container_id))
  end
  
  def init(container_id) do
    # Setup file system watcher
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [get_container_workspace_path(container_id)])
    FileSystem.subscribe(watcher_pid)
    
    state = %{
      container_id: container_id,
      watcher_pid: watcher_pid,
      workspace: get_container_workspace(container_id),
      sync_queue: :queue.new(),
      debounce_timer: nil
    }
    
    {:ok, state}
  end
  
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    # Debounce file change events
    state = cancel_debounce_timer(state)
    
    # Add to sync queue
    queue_item = %{path: path, events: events, timestamp: DateTime.utc_now()}
    sync_queue = :queue.in(queue_item, state.sync_queue)
    
    # Start debounce timer
    timer_ref = Process.send_after(self(), :process_sync_queue, 1000)
    
    state = %{state | sync_queue: sync_queue, debounce_timer: timer_ref}
    {:noreply, state}
  end
  
  def handle_info(:process_sync_queue, state) do
    # Process all queued file changes
    changes = :queue.to_list(state.sync_queue)
    
    # Group changes by file and deduplicate
    grouped_changes = group_and_deduplicate_changes(changes)
    
    # Sync each file
    Enum.each(grouped_changes, fn {file_path, file_events} ->
      sync_file_changes(state.workspace, file_path, file_events)
    end)
    
    # Broadcast workspace update
    PubSub.broadcast(
      Kyozo.PubSub,
      "workspace:#{state.workspace.id}",
      {:files_changed, %{container_id: state.container_id, changes: grouped_changes}}
    )
    
    state = %{state | sync_queue: :queue.new(), debounce_timer: nil}
    {:noreply, state}
  end
  
  defp sync_file_changes(workspace, file_path, events) do
    case workspace.storage_backend do
      :git -> sync_to_git(workspace, file_path, events)
      :s3 -> sync_to_s3(workspace, file_path, events)
      :disk -> sync_to_disk(workspace, file_path, events)
      :hybrid -> sync_to_hybrid(workspace, file_path, events)
    end
  end
end
```

## API Extensions

### Container Management Endpoints

```elixir
# JSON:API routes for container management
json_api do
  routes do
    base "/containers", Kyozo.Containers.Container do
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
      
      # Container lifecycle operations
      post :start, route: "/:id/start"
      post :stop, route: "/:id/stop"
      post :restart, route: "/:id/restart"
      
      # Container monitoring
      get :logs, route: "/:id/logs"
      get :stats, route: "/:id/stats"
      get :status, route: "/:id/status"
      
      # File operations
      post :exec, route: "/:id/exec"
      get :files, route: "/:id/files/*path"
      put :upload_file, route: "/:id/files/*path"
    end
  end
end
```

### GraphQL Schema Extensions

```graphql
# GraphQL extensions for container management
extend type Workspace {
  containers: [Container!]!
  containerEnabled: Boolean!
  containerConfig: JSON!
}

type Container {
  id: ID!
  name: String!
  image: String!
  status: ContainerStatus!
  config: JSON!
  environmentVars: JSON!
  resourceLimits: ResourceLimits!
  ports: [Port!]!
  volumes: [Volume!]!
  workspace: Workspace!
  team: Team!
  createdBy: User
  uptime: Int
  resourceUsage: ResourceUsage
  createdAt: DateTime!
  updatedAt: DateTime!
  startedAt: DateTime
  finishedAt: DateTime
}

enum ContainerStatus {
  CREATED
  RUNNING  
  PAUSED
  STOPPED
  REMOVED
}

type ResourceLimits {
  memory: String!
  cpu: String!
  storage: String!
}

type ResourceUsage {
  memoryUsed: String!
  memoryPercent: Float!
  cpuPercent: Float!
  networkIO: NetworkIO!
  diskIO: DiskIO!
}

type Port {
  containerPort: Int!
  hostPort: Int
  protocol: String!
}

type Volume {
  name: String!
  hostPath: String
  containerPath: String!
  readOnly: Boolean!
}

extend type Mutation {
  createContainer(input: CreateContainerInput!): ContainerResult!
  startContainer(id: ID!): ContainerResult!
  stopContainer(id: ID!): ContainerResult!
  restartContainer(id: ID!): ContainerResult!
  deleteContainer(id: ID!): ContainerResult!
  executeCommand(id: ID!, command: String!): ExecutionResult!
}

extend type Subscription {
  containerStatus(containerId: ID!): ContainerStatusUpdate!
  containerLogs(containerId: ID!): ContainerLogEntry!
}
```

## Real-time Container Monitoring

### Container Status Tracking

```elixir
# lib/kyozo/containers/monitor.ex
defmodule Kyozo.Containers.Monitor do
  use GenServer
  
  alias Phoenix.PubSub
  alias Kyozo.Containers.Container
  
  def start_link(container_id) do
    GenServer.start_link(__MODULE__, container_id, name: via_tuple(container_id))
  end
  
  def init(container_id) do
    # Start monitoring timer
    timer_ref = :timer.send_interval(5000, :check_status)
    
    state = %{
      container_id: container_id,
      timer_ref: timer_ref,
      last_status: nil,
      last_stats: nil
    }
    
    {:ok, state}
  end
  
  def handle_info(:check_status, state) do
    with {:ok, container} <- Container.get_by_id(state.container_id),
         {:ok, status} <- get_container_status(container),
         {:ok, stats} <- get_container_stats(container) do
      
      # Check if status changed
      if status != state.last_status do
        broadcast_status_change(container, status)
        update_container_status(container, status)
      end
      
      # Broadcast stats update
      broadcast_stats_update(container, stats)
      
      state = %{state | last_status: status, last_stats: stats}
      {:noreply, state}
    else
      {:error, :not_found} ->
        # Container was deleted, stop monitoring
        {:stop, :normal, state}
      
      {:error, reason} ->
        # Log error but continue monitoring
        Logger.error("Container monitoring error: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  defp broadcast_status_change(container, new_status) do
    PubSub.broadcast(
      Kyozo.PubSub,
      "container:#{container.id}",
      {:status_changed, %{container_id: container.id, status: new_status}}
    )
    
    PubSub.broadcast(
      Kyozo.PubSub,
      "workspace:#{container.workspace_id}",
      {:container_status_changed, %{container_id: container.id, status: new_status}}
    )
  end
  
  defp broadcast_stats_update(container, stats) do
    PubSub.broadcast(
      Kyozo.PubSub,
      "container:#{container.id}:stats",
      {:stats_update, %{container_id: container.id, stats: stats}}
    )
  end
end
```

### Log Streaming

```elixir
# lib/kyozo/containers/log_streamer.ex
defmodule Kyozo.Containers.LogStreamer do
  use GenServer
  
  alias Phoenix.PubSub
  
  def start_link(container_id, subscriber_pid) do
    GenServer.start_link(__MODULE__, {container_id, subscriber_pid})
  end
  
  def init({container_id, subscriber_pid}) do
    # Start log streaming from Docker/Kubernetes
    {:ok, stream_pid} = start_log_stream(container_id)
    
    state = %{
      container_id: container_id,
      subscriber_pid: subscriber_pid,
      stream_pid: stream_pid,
      buffer: ""
    }
    
    {:ok, state}
  end
  
  def handle_info({:log_data, data}, state) do
    # Buffer and process log lines
    buffer = state.buffer <> data
    {lines, remaining_buffer} = extract_complete_lines(buffer)
    
    # Broadcast each log line
    Enum.each(lines, fn line ->
      log_entry = %{
        container_id: state.container_id,
        timestamp: DateTime.utc_now(),
        message: line,
        stream: :stdout
      }
      
      PubSub.broadcast(
        Kyozo.PubSub,
        "container:#{state.container_id}:logs",
        {:log_entry, log_entry}
      )
    end)
    
    state = %{state | buffer: remaining_buffer}
    {:noreply, state}
  end
end
```

## Security and Isolation

### Container Security Policies

```elixir
# lib/kyozo/containers/security_policy.ex
defmodule Kyozo.Containers.SecurityPolicy do
  
  def validate_container_config(container_config, team_limits) do
    with :ok <- validate_resource_limits(container_config.resource_limits, team_limits),
         :ok <- validate_image_security(container_config.image),
         :ok <- validate_network_access(container_config.networks),
         :ok <- validate_volume_mounts(container_config.volumes) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp validate_resource_limits(resource_limits, team_limits) do
    memory_limit = parse_memory(resource_limits.memory)
    cpu_limit = parse_cpu(resource_limits.cpu)
    storage_limit = parse_storage(resource_limits.storage)
    
    cond do
      memory_limit > team_limits.max_memory ->
        {:error, "Memory limit exceeds team maximum"}
      
      cpu_limit > team_limits.max_cpu ->
        {:error, "CPU limit exceeds team maximum"}
      
      storage_limit > team_limits.max_storage ->
        {:error, "Storage limit exceeds team maximum"}
      
      true ->
        :ok
    end
  end
  
  defp validate_image_security(image_name) do
    # Check against allowed image registry
    allowed_registries = Application.get_env(:kyozo, :allowed_container_registries, [])
    
    case extract_registry_from_image(image_name) do
      nil ->
        # Default registry (Docker Hub) - check allowed images
        validate_public_image(image_name)
      
      registry when registry in allowed_registries ->
        :ok
      
      _unauthorized_registry ->
        {:error, "Image registry not allowed"}
    end
  end
  
  defp validate_network_access(networks) do
    # Prevent access to internal networks
    forbidden_networks = ["host", "bridge", "internal"]
    
    if Enum.any?(networks, &(&1 in forbidden_networks)) do
      {:error, "Network access not allowed"}
    else
      :ok
    end
  end
  
  defp validate_volume_mounts(volumes) do
    # Ensure volumes only access workspace data
    Enum.reduce_while(volumes, :ok, fn volume, acc ->
      if is_safe_volume_mount?(volume) do
        {:cont, acc}
      else
        {:halt, {:error, "Unsafe volume mount: #{volume.host_path}"}}
      end
    end)
  end
end
```

### Network Isolation

```elixir
# lib/kyozo/containers/network_manager.ex
defmodule Kyozo.Containers.NetworkManager do
  
  def create_team_network(team_id) do
    network_name = "kyozo-team-#{team_id}"
    
    network_config = %{
      "Name" => network_name,
      "Driver" => "bridge",
      "Internal" => false,
      "Attachable" => true,
      "Labels" => %{
        "kyozo.team.id" => team_id,
        "kyozo.network.type" => "team_isolated"
      },
      "IPAM" => %{
        "Config" => [
          %{
            "Subnet" => generate_team_subnet(team_id)
          }
        ]
      },
      "Options" => %{
        "com.docker.network.bridge.enable_icc" => "true",
        "com.docker.network.bridge.enable_ip_masquerade" => "true"
      }
    }
    
    Docker.API.create_network(network_config)
  end
  
  def setup_container_networking(container, team_network) do
    # Connect container to team network
    with {:ok, _} <- Docker.API.connect_network(team_network, container.container_id),
         {:ok, _} <- setup_port_forwarding(container) do
      :ok
    end
  end
  
  defp generate_team_subnet(team_id) do
    # Generate unique subnet for team
    # Use team_id hash to ensure consistency
    hash = :crypto.hash(:sha256, team_id) |> Base.encode16() |> String.slice(0, 4)
    subnet_id = String.to_integer(hash, 16) |> rem(4096) |> max(1)
    
    # Generate subnet in 172.16.0.0/12 range
    base = 172 * 256 * 256 * 256 + 16 * 256 * 256
    subnet_base = base + (subnet_id * 256)
    
    <<a, b, c, d>> = <<subnet_base::32>>
    "#{a}.#{b}.#{c}.#{d}/24"
  end
end
```

## Frontend Integration

### Container Management UI

```svelte
<!-- assets/svelte/components/containers/ContainerManager.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { containers } from '../../stores/containers';
  import { apiService } from '../../stores';
  import { Button } from '../../ui/button';
  import { Card, CardContent, CardHeader, CardTitle } from '../../ui/card';
  import { Badge } from '../../ui/badge';
  import { Play, Square, RotateCcw, Trash2, Terminal, Activity } from '@lucide/svelte';
  
  let { workspaceId } = $props();
  
  let containerStats = $state(new Map());
  let logStreams = $state(new Map());
  let statusUpdateUnsubscribe = $state(null);
  
  onMount(async () => {
    // Load containers for workspace
    await containers.loadForWorkspace($apiService, workspaceId);
    
    // Subscribe to container status updates
    statusUpdateUnsubscribe = $apiService.subscribe(
      `workspace:${workspaceId}`,
      handleContainerUpdate
    );
  });
  
  onDestroy(() => {
    statusUpdateUnsubscribe?.();
  });
  
  function handleContainerUpdate(event) {
    if (event.type === 'container_status_changed') {
      containers.updateStatus(event.container_id, event.status);
    }
  }
  
  async function startContainer(containerId) {
    await containers.start($apiService, containerId);
  }
  
  async function stopContainer(containerId) {
    await containers.stop($apiService, containerId);
  }
  
  async function restartContainer(containerId) {
    await containers.restart($apiService, containerId);
  }
  
  async function deleteContainer(containerId) {
    if (confirm('Are you sure you want to delete this container?')) {
      await containers.delete($apiService, containerId);
    }
  }
  
  function getStatusVariant(status) {
    switch (status) {
      case 'running': return 'success';
      case 'stopped': return 'secondary';
      case 'error': return 'destructive';
      default: return 'outline';
    }
  }
</script>

<div class="space-y-6">
  <div class="flex items-center justify-between">
    <h2 class="text-2xl font-bold">Containers</h2>
    <Button onclick={() => containers.showCreateDialog(true)}>
      Create Container
    </Button>
  </div>
  
  {#if $containers.loading}
    <div class="text-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto"></div>
      <p class="mt-2 text-muted-foreground">Loading containers...</p>
    </div>
  {:else if $containers.items.length === 0}
    <Card>
      <CardContent class="pt-6">
        <div class="text-center py-8">
          <Terminal class="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h3 class="text-lg font-medium mb-2">No containers yet</h3>
          <p class="text-muted-foreground mb-4">
            Create your first container to start developing in an isolated environment.
          </p>
          <Button onclick={() => containers.showCreateDialog(true)}>
            Create Container
          </Button>
        </div>
      </CardContent>
    </Card>
  {:else}
    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {#each $containers.items as container (container.id)}
        <Card>
          <CardHeader class="pb-3">
            <div class="flex items-center justify-between">
              <CardTitle class="text-base">{container.name}</CardTitle>
              <Badge variant={getStatusVariant(container.status)}>
                {container.status}
              </Badge>
            </div>
            <p class="text-sm text-muted-foreground">{container.image}</p>
          </CardHeader>
          <CardContent>
            <div class="space-y-3">
              {#if container.status === 'running'}
                <div class="text-xs text-muted-foreground">
                  <div class="flex items-center gap-2">
                    <Activity class="h-3 w-3" />
                    Uptime: {container.uptime || 0}s
                  </div>
                  {#if container.resourceUsage}
                    <div class="mt-1">
                      CPU: {container.resourceUsage.cpuPercent?.toFixed(1)}% | 
                      Memory: {container.resourceUsage.memoryPercent?.toFixed(1)}%
                    </div>
                  {/if}
                </div>
              {/if}
              
              <div class="flex gap-2">
                {#if container.status === 'stopped'}
                  <Button size="sm" variant="outline" onclick={() => startContainer(container.id)}>
                    <Play class="h-3 w-3 mr-1" />
                    Start
                  </Button>
                {:else if container.status === 'running'}
                  <Button size="sm" variant="outline" onclick={() => stopContainer(container.id)}>
                    <Square class="h-3 w-3 mr-1" />
                    Stop
                  </Button>
                  <Button size="sm" variant="outline" onclick={() => restartContainer(container.id)}>
                    <RotateCcw class="h-3 w-3 mr-1" />
                    Restart
                  </Button>
                {/if}
                
                <Button 
                  size="sm" 
                  variant="outline" 
                  onclick={() => deleteContainer(container.id)}
                  disabled={container.status === 'running'}
                >
                  <Trash2 class="h-3 w-3 mr-1" />
                  Delete
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      {/each}
    </div>
  {/if}
</div>
```

### Container Creation Dialog

```svelte
<!-- assets/svelte/components/containers/CreateContainerDialog.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { Dialog, DialogContent, DialogHeader, DialogTitle } from '../../ui/dialog';
  import { Button } from '../../ui/button';
  import { Input } from '../../ui/input';
  import { Label } from '../../ui/label';
  import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../ui/select';
  import { Textarea } from '../../ui/textarea';
  
  let { open = false, workspaceId } = $props();
  
  const dispatch = createEventDispatcher();
  
  let formData = $state({
    name: '',
    image: 'ubuntu:22.04',
    resourceLimits: {
      memory: '512Mi',
      cpu: '0.5',
      storage: '1Gi'
    },
    environmentVars: {},
    ports: []
  });
  
  let loading = $state(false);
  let errors = $state({});
  
  const predefinedImages = [
    { value: 'ubuntu:22.04', label: 'Ubuntu 22.04' },
    { value: 'node:18-alpine', label: 'Node.js 18' },
    { value: 'python:3.11-slim', label: 'Python 3.11' },
    { value: 'nginx:alpine', label: 'Nginx' },
    { value: 'postgres:15', label: 'PostgreSQL 15' },
    { value: 'redis:7-alpine', label: 'Redis 7' }
  ];
  
  async function handleSubmit() {
    loading = true;
    errors = {};
    
    try {
      const containerData = {
        ...formData,
        workspaceId
      };
      
      await containers.create($apiService, containerData);
      
      dispatch('created');
      resetForm();
      open = false;
    } catch (error) {
      errors = error.errors || { general: error.message };
    } finally {
      loading = false;
    }
  }
  
  function resetForm() {
    formData = {
      name: '',
      image: 'ubuntu:22.04',
      resourceLimits: {
        memory: '512Mi',
        cpu: '0.5',
        storage: '1Gi'
      },
      environmentVars: {},
      ports: []
    };
  }
  
  function addEnvironmentVar() {
    formData.environmentVars = {
      ...formData.environmentVars,
      '': ''
    };
  }
  
  function removeEnvironmentVar(key) {
    const { [key]: removed, ...rest } = formData.environmentVars;
    formData.environmentVars = rest;
  }
  
  function updateEnvironmentVar(oldKey, newKey, value) {
    if (oldKey !== newKey) {
      removeEnvironmentVar(oldKey);
    }
    formData.environmentVars = {
      ...formData.environmentVars,
      [newKey]: value
    };
  }
</script>

<Dialog bind:open>
  <DialogContent class="sm:max-w-lg">
    <DialogHeader>
      <DialogTitle>Create Container</DialogTitle>
    </DialogHeader>
    
    <form onsubmit|preventDefault={handleSubmit} class="space-y-4">
      <div class="space-y-2">
        <Label for="container-name">Container Name</Label>
        <Input
          id="container-name"
          bind:value={formData.name}
          placeholder="my-container"
          required
        />
        {#if errors.name}
          <p class="text-sm text-destructive">{errors.name}</p>
        {/if}
      </div>
      
      <div class="space-y-2">
        <Label for="container-image">Image</Label>
        <Select bind:value={formData.image}>
          <SelectTrigger>
            <SelectValue placeholder="Select an image" />
          </SelectTrigger>
          <SelectContent>
            {#each predefinedImages as image}
              <SelectItem value={image.value}>{image.label}</SelectItem>
            {/each}
          </SelectContent>
        </Select>
        <Input
          bind:value={formData.image}
          placeholder="Custom image name"
          class="mt-2"
        />
      </div>
      
      <div class="grid grid-cols-3 gap-2">
        <div class="space-y-2">
          <Label for="memory-limit">Memory</Label>
          <Input
            id="memory-limit"
            bind:value={formData.resourceLimits.memory}
            placeholder="512Mi"
          />
        </div>
        <div class="space-y-2">
          <Label for="cpu-limit">CPU</Label>
          <Input
            id="cpu-limit"
            bind:value={formData.resourceLimits.cpu}
            placeholder="0.5"
          />
        </div>
        <div class="space-y-2">
          <Label for="storage-limit">Storage</Label>
          <Input
            id="storage-limit"
            bind:value={formData.resourceLimits.storage}
            placeholder="1Gi"
          />
        </div>
      </div>
      
      <div class="space-y-2">
        <div class="flex items-center justify-between">
          <Label>Environment Variables</Label>
          <Button type="button" size="sm" variant="outline" onclick={addEnvironmentVar}>
            Add Variable
          </Button>
        </div>
        <div class="space-y-2">
          {#each Object.entries(formData.environmentVars) as [key, value]}
            <div class="flex gap-2">
              <Input
                value={key}
                placeholder="Variable name"
                onchange={e => updateEnvironmentVar(key, e.target.value, value)}
              />
              <Input
                {value}
                placeholder="Variable value"
                onchange={e => updateEnvironmentVar(key, key, e.target.value)}
              />
              <Button type="button" size="sm" variant="outline" onclick={() => removeEnvironmentVar(key)}>
                Remove
              </Button>
            </div>
          {/each}
        </div>
      </div>
      
      {#if errors.general}
        <p class="text-sm text-destructive">{errors.general}</p>
      {/if}
      
      <div class="flex justify-end gap-2">
        <Button type="button" variant="outline" onclick={() => open = false}>
          Cancel
        </Button>
        <Button type="submit" disabled={loading}>
          {loading ? 'Creating...' : 'Create Container'}
        </Button>
      </div>
    </form>
  </DialogContent>
</Dialog>
```

## Deployment Patterns

### Docker Compose Integration

```yaml
# docker-compose.containers.yml
version: '3.8'

services:
  kyozo_app:
    build: .
    environment:
      - DOCKER_SOCKET_PATH=/var/run/docker.sock
      - CONTAINER_NETWORK=kyozo_containers
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./workspace_storage:/app/workspace_storage
    networks:
      - kyozo_containers
      - kyozo_internal

  # Container workspace template
  workspace_template:
    image: kyozo/workspace-base:latest
    command: tail -f /dev/null
    working_dir: /workspace
    environment:
      - KYOZO_WORKSPACE_ID=${WORKSPACE_ID}
      - KYOZO_TEAM_ID=${TEAM_ID}
    volumes:
      - workspace_data:/workspace
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - kyozo_containers
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'

networks:
  kyozo_containers:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/16

volumes:
  workspace_data:
    driver: local
```

### Kubernetes Deployment

```yaml
# k8s/workspace-template.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kyozo-workspace-template
  namespace: kyozo-workspaces
spec:
  replicas: 0  # Scaled on demand
  selector:
    matchLabels:
      app: kyozo-workspace
  template:
    metadata:
      labels:
        app: kyozo-workspace
    spec:
      containers:
      - name: workspace
        image: kyozo/workspace-base:latest
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
          requests:
            memory: "256Mi"
            cpu: "250m"
        volumeMounts:
        - name: workspace-storage
          mountPath: /workspace
        - name: docker-socket
          mountPath: /var/run/docker.sock
          readOnly: true
        env:
        - name: KYOZO_API_URL
          value: "http://kyozo-api.kyozo.svc.cluster.local"
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
      volumes:
      - name: workspace-storage
        persistentVolumeClaim:
          claimName: workspace-pvc
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
          type: Socket
      serviceAccountName: kyozo-workspace
      securityContext:
        fsGroup: 1000

---
apiVersion: v1
kind: Service
metadata:
  name: kyozo-workspace-service
  namespace: kyozo-workspaces
spec:
  selector:
    app: kyozo-workspace
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  type: ClusterIP
```

## Performance and Scaling

### Container Resource Management

```elixir
# lib/kyozo/containers/resource_manager.ex
defmodule Kyozo.Containers.ResourceManager do
  
  def calculate_team_resource_usage(team_id) do
    containers = Container.list_by_team(team_id)
    
    Enum.reduce(containers, %{memory: 0, cpu: 0, storage: 0}, fn container, acc ->
      usage = get_container_resource_usage(container)
      
      %{
        memory: acc.memory + usage.memory,
        cpu: acc.cpu + usage.cpu,
        storage: acc.storage + usage.storage
      }
    end)
  end
  
  def enforce_team_limits(team_id, new_container_limits) do
    current_usage = calculate_team_resource_usage(team_id)
    team_limits = get_team_resource_limits(team_id)
    
    projected_usage = %{
      memory: current_usage.memory + parse_memory(new_container_limits.memory),
      cpu: current_usage.cpu + parse_cpu(new_container_limits.cpu),
      storage: current_usage.storage + parse_storage(new_container_limits.storage)
    }
    
    cond do
      projected_usage.memory > team_limits.max_memory ->
        {:error, "Would exceed team memory limit"}
      
      projected_usage.cpu > team_limits.max_cpu ->
        {:error, "Would exceed team CPU limit"}
      
      projected_usage.storage > team_limits.max_storage ->
        {:error, "Would exceed team storage limit"}
      
      true ->
        :ok
    end
  end
  
  def scale_container_resources(container_id, new_limits) do
    with {:ok, container} <- Container.get_by_id(container_id),
         :ok <- validate_resource_scaling(container, new_limits),
         {:ok, _} <- update_container_resources(container, new_limits) do
      
      # Update container record
      Container.update(container, %{resource_limits: new_limits})
    end
  end
end
```

This Folder as a Service specification provides a comprehensive integration plan for container orchestration within the Kyozo Store platform, leveraging existing architectural patterns and extending them with containerized workspace capabilities while maintaining security, performance, and collaborative features.