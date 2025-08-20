# Kyozo Store - Folder Service Architecture

## Overview

This document provides a comprehensive technical architecture for the Kyozo Store "Folder as a Service" platform, detailing the system design, component interactions, and implementation patterns.

## System Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS/Web       │    │   Phoenix       │    │   Docker        │
│   Client        │◄──►│   Server        │◄──►│   Engine        │
│                 │    │                 │    │                 │
│ • File Explorer │    │ • Folder API    │    │ • Containers    │
│ • CRDT Engine   │    │ • Topology      │    │ • Compose       │
│ • Metal UI      │    │ • AI Walker     │    │ • Orchestration │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Local         │    │   PostgreSQL    │    │   Service       │
│   Storage       │    │   Database      │    │   Registry      │
│                 │    │                 │    │                 │
│ • Encrypted     │    │ • Workspaces    │    │ • Running       │
│ • Versioned     │    │ • Topology      │    │   Services      │
│ • Synchronized  │    │ • Metadata      │    │ • Health Status │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Component Breakdown

## 1. Phoenix Server Layer

### 1.1 Core Domains

#### Workspace Management (`Kyozo.Workspaces`)

```elixir
defmodule Kyozo.Workspaces.Workspace do
  use Ash.Resource,
    domain: Kyozo.Workspaces,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workspaces"
    repo Kyozo.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :root_path, :string, allow_nil?: false
    attribute :topology_cache, :map
    attribute :service_count, :integer, default: 0
    attribute :last_analyzed_at, :utc_datetime
    
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug))
    end

    update :analyze_topology do
      change fn changeset, _ ->
        workspace = Ash.Changeset.get_data(changeset)
        topology = Kyozo.Topology.Detector.analyze_workspace(workspace.id)
        
        changeset
        |> Ash.Changeset.change_attribute(:topology_cache, topology)
        |> Ash.Changeset.change_attribute(:service_count, length(topology.services))
        |> Ash.Changeset.change_attribute(:last_analyzed_at, DateTime.utc_now())
      end
    end
  end

  relationships do
    has_many :files, Kyozo.Workspaces.File
    has_many :service_instances, Kyozo.Orchestration.ServiceInstance
    belongs_to :owner, Kyozo.Accounts.User
    many_to_many :collaborators, Kyozo.Accounts.User do
      through Kyozo.Workspaces.WorkspaceCollaborator
    end
  end
end
```

#### File Management (`Kyozo.Workspaces.File`)

```elixir
defmodule Kyozo.Workspaces.File do
  use Ash.Resource,
    domain: Kyozo.Workspaces,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "files"
    repo Kyozo.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :path, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :content_type, :string
    attribute :size, :integer
    attribute :encrypted_content, :binary
    attribute :content_hash, :string
    attribute :service_indicators, :map, default: %{}
    attribute :is_service_root, :boolean, default: false
    
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :create_from_upload do
      argument :file_data, :binary, allow_nil?: false
      argument :encryption_key, :string, allow_nil?: false
      
      change fn changeset, _ ->
        file_data = Ash.Changeset.get_argument(changeset, :file_data)
        encryption_key = Ash.Changeset.get_argument(changeset, :encryption_key)
        
        encrypted_content = Kyozo.Encryption.encrypt(file_data, encryption_key)
        content_hash = :crypto.hash(:sha256, file_data) |> Base.encode16()
        
        changeset
        |> Ash.Changeset.change_attribute(:encrypted_content, encrypted_content)
        |> Ash.Changeset.change_attribute(:content_hash, content_hash)
        |> Ash.Changeset.change_attribute(:size, byte_size(file_data))
      end
    end

    update :detect_service_type do
      change after_action(fn changeset, file, _context ->
        service_indicators = detect_service_indicators(file)
        is_service_root = determine_if_service_root(file, service_indicators)
        
        file
        |> Ash.Changeset.for_update(:update, %{
          service_indicators: service_indicators,
          is_service_root: is_service_root
        })
        |> Kyozo.Workspaces.update!()
        
        {:ok, file}
      end)
    end
  end

  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace
    belongs_to :parent_folder, __MODULE__, define_attribute?: false
    has_many :child_files, __MODULE__, destination_attribute: :parent_folder_id
  end

  defp detect_service_indicators(file) do
    case file.name do
      "Dockerfile" -> %{type: :dockerfile, deployable: true}
      "docker-compose.yml" -> %{type: :compose_stack, orchestrated: true}
      "package.json" -> %{type: :nodejs_service, runtime: :node}
      "requirements.txt" -> %{type: :python_service, runtime: :python}
      "Cargo.toml" -> %{type: :rust_service, runtime: :rust}
      "go.mod" -> %{type: :go_service, runtime: :go}
      _ -> %{}
    end
  end
end
```

### 1.2 Topology Detection Engine (`Kyozo.Topology`)

```elixir
defmodule Kyozo.Topology.Detector do
  @moduledoc """
  Analyzes workspace folder structures to detect service topologies
  and classify folders by their service potential.
  """

  def analyze_workspace(workspace_id) do
    workspace = Kyozo.Workspaces.get!(workspace_id, load: [:files])
    folder_tree = build_folder_tree(workspace.files)
    
    %{
      workspace_id: workspace_id,
      folders: classify_folders(folder_tree),
      patterns: detect_service_patterns(folder_tree),
      topology_map: generate_topology_map(folder_tree),
      analyzed_at: DateTime.utc_now()
    }
  end

  def classify_folders(folder_tree) do
    Enum.map(folder_tree, &classify_single_folder/1)
  end

  defp classify_single_folder(folder) do
    service_type = determine_service_type(folder)
    capabilities = analyze_capabilities(folder)
    dependencies = detect_dependencies(folder)
    
    %{
      path: folder.path,
      name: folder.name,
      type: service_type,
      capabilities: capabilities,
      dependencies: dependencies,
      children: classify_folders(folder.children || [])
    }
  end

  defp determine_service_type(folder) do
    files = folder.files || []
    children = folder.children || []
    
    cond do
      has_dockerfile?(files) -> :containerized_service
      has_compose_file?(files) -> :service_composition
      has_package_json?(files) -> :nodejs_service
      has_requirements_txt?(files) -> :python_service
      has_multiple_services?(children) -> :service_neighborhood
      has_proxy_config?(files) -> :proxy_service
      has_database_files?(files) -> :database_service
      true -> :unknown_folder
    end
  end

  defp analyze_capabilities(folder) do
    capabilities = []
    
    capabilities
    |> maybe_add_capability(:can_containerize, can_containerize?(folder))
    |> maybe_add_capability(:has_health_check, has_health_check?(folder))
    |> maybe_add_capability(:has_monitoring, has_monitoring?(folder))
    |> maybe_add_capability(:auto_scalable, is_auto_scalable?(folder))
    |> maybe_add_capability(:load_balanceable, is_load_balanceable?(folder))
  end

  defp detect_dependencies(folder) do
    files = folder.files || []
    
    dependencies = []
    
    # Detect database dependencies
    dependencies = if needs_database?(files) do
      [{:database, detect_database_type(files)} | dependencies]
    else
      dependencies
    end
    
    # Detect service dependencies from imports/requires
    service_deps = detect_service_dependencies(files)
    dependencies ++ service_deps
  end

  defp detect_service_patterns(classified_folders) do
    patterns = []
    
    patterns
    |> maybe_add_pattern(:microservices, has_microservices_pattern?(classified_folders))
    |> maybe_add_pattern(:api_gateway, has_api_gateway_pattern?(classified_folders))
    |> maybe_add_pattern(:database_per_service, has_database_per_service?(classified_folders))
    |> maybe_add_pattern(:service_mesh, has_service_mesh_pattern?(classified_folders))
  end

  defp generate_topology_map(%{folders: folders, patterns: patterns}) do
    %{
      services: extract_services(folders),
      proxies: extract_proxies(folders),
      databases: extract_databases(folders),
      relationships: map_relationships(folders),
      deployment_order: calculate_deployment_order(folders),
      scaling_groups: identify_scaling_groups(folders)
    }
  end

  # Helper functions for pattern detection
  defp has_dockerfile?(files), do: Enum.any?(files, &(&1.name == "Dockerfile"))
  defp has_compose_file?(files), do: Enum.any?(files, &(&1.name in ["docker-compose.yml", "docker-compose.yaml"]))
  defp has_package_json?(files), do: Enum.any?(files, &(&1.name == "package.json"))
  defp has_requirements_txt?(files), do: Enum.any?(files, &(&1.name == "requirements.txt"))
  
  defp can_containerize?(folder) do
    files = folder.files || []
    has_dockerfile?(files) or has_language_manifest?(files)
  end
  
  defp has_language_manifest?(files) do
    manifest_files = ["package.json", "requirements.txt", "Cargo.toml", "go.mod", "pom.xml"]
    Enum.any?(files, &(&1.name in manifest_files))
  end
end
```

### 1.3 Container Orchestration (`Kyozo.Orchestration`)

```elixir
defmodule Kyozo.Orchestration.ServiceInstance do
  use Ash.Resource,
    domain: Kyozo.Orchestration,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "service_instances"
    repo Kyozo.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :folder_path, :string, allow_nil?: false
    attribute :service_type, :atom, constraints: [one_of: [:containerized, :compose_stack, :nodejs, :python, :proxy]]
    attribute :container_id, :string
    attribute :port_mappings, :map, default: %{}
    attribute :environment_vars, :map, default: %{}
    attribute :status, :atom, default: :stopped, constraints: [one_of: [:stopped, :starting, :running, :error, :stopping]]
    attribute :health_check_url, :string
    attribute :last_health_check, :utc_datetime
    attribute :deployment_config, :map, default: %{}
    
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :deploy do
      argument :workspace_id, :uuid, allow_nil?: false
      
      change after_action(fn changeset, service_instance, _context ->
        Kyozo.Orchestration.ContainerManager.deploy(service_instance)
        {:ok, service_instance}
      end)
    end

    update :start do
      change after_action(fn changeset, service_instance, _context ->
        Kyozo.Orchestration.ContainerManager.start_service(service_instance.id)
        {:ok, service_instance}
      end)
    end

    update :stop do
      change after_action(fn changeset, service_instance, _context ->
        Kyozo.Orchestration.ContainerManager.stop_service(service_instance.id)
        {:ok, service_instance}
      end)
    end
  end

  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace
  end
end
```

```elixir
defmodule Kyozo.Orchestration.ContainerManager do
  use GenServer
  require Logger

  @container_registry %{}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def deploy(service_instance) do
    GenServer.call(__MODULE__, {:deploy, service_instance})
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

  ## GenServer Callbacks

  def init(_opts) do
    {:ok, %{running_services: %{}, docker_client: init_docker_client()}}
  end

  def handle_call({:deploy, service_instance}, _from, state) do
    case deploy_service(service_instance, state.docker_client) do
      {:ok, container_id} ->
        new_state = put_in(state.running_services[service_instance.id], %{
          container_id: container_id,
          status: :running,
          started_at: DateTime.utc_now()
        })
        
        # Update service instance in database
        service_instance
        |> Ash.Changeset.for_update(:update, %{
          container_id: container_id,
          status: :running
        })
        |> Kyozo.Orchestration.update!()
        
        {:reply, {:ok, container_id}, new_state}
      
      {:error, reason} ->
        Logger.error("Failed to deploy service #{service_instance.id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:start, service_instance_id}, _from, state) do
    service_instance = Kyozo.Orchestration.get!(service_instance_id)
    
    case start_existing_container(service_instance.container_id, state.docker_client) do
      :ok ->
        new_state = put_in(state.running_services[service_instance_id], %{
          container_id: service_instance.container_id,
          status: :running,
          started_at: DateTime.utc_now()
        })
        {:reply, :ok, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:stop, service_instance_id}, _from, state) do
    case get_in(state.running_services, [service_instance_id]) do
      %{container_id: container_id} ->
        case stop_container(container_id, state.docker_client) do
          :ok ->
            new_state = update_in(state.running_services, &Map.delete(&1, service_instance_id))
            {:reply, :ok, new_state}
          
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      
      nil ->
        {:reply, {:error, :not_running}, state}
    end
  end

  ## Private Functions

  defp deploy_service(service_instance, docker_client) do
    case service_instance.service_type do
      :containerized -> deploy_dockerfile(service_instance.folder_path, docker_client)
      :compose_stack -> deploy_compose_stack(service_instance.folder_path, docker_client)
      :nodejs -> deploy_nodejs_service(service_instance.folder_path, docker_client)
      :python -> deploy_python_service(service_instance.folder_path, docker_client)
      :proxy -> deploy_proxy_service(service_instance.folder_path, docker_client)
    end
  end

  defp deploy_dockerfile(folder_path, docker_client) do
    dockerfile_path = Path.join(folder_path, "Dockerfile")
    
    if File.exists?(dockerfile_path) do
      port = find_available_port()
      internal_port = detect_internal_port(folder_path)
      
      build_opts = %{
        context: folder_path,
        tag: "kyozo-service-#{:rand.uniform(10000)}"
      }
      
      with {:ok, image_id} <- Docker.build_image(docker_client, build_opts),
           {:ok, container_id} <- Docker.run_container(docker_client, %{
             image: image_id,
             ports: %{"#{internal_port}/tcp" => [%{"HostPort" => to_string(port)}]},
             name: "kyozo-service-#{:rand.uniform(10000)}"
           }) do
        {:ok, container_id}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :no_dockerfile}
    end
  end

  defp deploy_nodejs_service(folder_path, docker_client) do
    package_json_path = Path.join(folder_path, "package.json")
    
    if File.exists?(package_json_path) do
      # Generate Dockerfile for Node.js service
      dockerfile_content = """
      FROM node:18-alpine
      WORKDIR /app
      COPY package*.json ./
      RUN npm ci --only=production
      COPY . .
      EXPOSE 3000
      CMD ["npm", "start"]
      """
      
      dockerfile_path = Path.join(folder_path, "Dockerfile.generated")
      File.write!(dockerfile_path, dockerfile_content)
      
      result = deploy_dockerfile(folder_path, docker_client)
      File.rm(dockerfile_path)  # Clean up generated file
      
      result
    else
      {:error, :no_package_json}
    end
  end

  defp find_available_port do
    # Simple port allocation - in production, use proper port management
    Enum.random(8000..9000)
  end

  defp detect_internal_port(folder_path) do
    # Try to detect the port from package.json, Dockerfile, or default to 3000
    3000
  end

  defp init_docker_client do
    # Initialize Docker client connection
    # In real implementation, use proper Docker API client
    %{socket: "/var/run/docker.sock"}
  end
end
```

### 1.4 AI Navigation System (`Kyozo.AI`)

```elixir
defmodule Kyozo.AI.PathWalker do
  @moduledoc """
  Provides AI agents with rich context about folder structures
  and enables intelligent navigation through service topologies.
  """

  def describe_path(workspace_id, folder_path) do
    workspace = Kyozo.Workspaces.get!(workspace_id, load: [:files])
    folder_info = get_folder_info(workspace, folder_path)
    
    %{
      path: folder_path,
      type: classify_folder_type(folder_info),
      purpose: infer_folder_purpose(folder_info),
      technologies: detect_technologies(folder_info),
      capabilities: analyze_capabilities(folder_info),
      relationships: find_relationships(workspace, folder_path),
      ai_instructions: generate_ai_instructions(folder_info),
      context: build_contextual_understanding(folder_info)
    }
  end

  def navigate_to_related(workspace_id, current_path, relation_type) do
    workspace = Kyozo.Workspaces.get!(workspace_id, load: [:files])
    
    case relation_type do
      :parent -> find_parent_service(workspace, current_path)
      :children -> find_child_services(workspace, current_path)
      :siblings -> find_sibling_services(workspace, current_path)
      :dependencies -> find_dependency_services(workspace, current_path)
    end
  end

  defp infer_folder_purpose(folder_info) do
    files = folder_info.files || []
    children = folder_info.children || []
    
    cond do
      has_file?(files, "Dockerfile") ->
        "This appears to be a containerized service with Docker configuration."
        
      has_file?(files, "package.json") ->
        package_json = get_file_content(files, "package.json")
        dependencies = extract_dependencies(package_json)
        
        cond do
          "express" in dependencies -> "Node.js web server using Express.js framework"
          "react" in dependencies -> "React frontend application"
          "next" in dependencies -> "Next.js full-stack React application"
          true -> "Node.js application"
        end
        
      has_file?(files, "requirements.txt") ->
        requirements = get_file_content(files, "requirements.txt")
        
        cond do
          "django" in requirements -> "Django web application"
          "flask" in requirements -> "Flask web API service"
          "fastapi" in requirements -> "FastAPI web service"
          true -> "Python application"
        end
        
      has_file?(files, "docker-compose.yml") ->
        "Multi-service application orchestrated with Docker Compose"
        
      length(children) > 2 and has_services_in_children?(children) ->
        "Service neighborhood containing multiple related microservices"
        
      has_file?(files, "nginx.conf") ->
        "Reverse proxy service for load balancing and traffic routing"
        
      true ->
        "General purpose folder - contents need further analysis"
    end
  end

  defp generate_ai_instructions(folder_info) do
    purpose = infer_folder_purpose(folder_info)
    technologies = detect_technologies(folder_info)
    
    base_instructions = case folder_info.type do
      :containerized_service ->
        """
        This is a containerized service. You can:
        - Deploy it using the existing Dockerfile
        - Scale it horizontally by creating multiple instances
        - Monitor its health through container logs
        - Connect it to other services via environment variables
        """
        
      :nodejs_service ->
        """
        This is a Node.js service. You can:
        - Install dependencies with 'npm install'
        - Start development server with 'npm run dev'
        - Deploy as container or serverless function
        - Connect to databases via connection strings
        """
        
      :service_neighborhood ->
        """
        This is a service neighborhood containing multiple related services. You can:
        - Deploy all services together using Docker Compose
        - Set up service-to-service communication
        - Configure shared databases and volumes
        - Monitor the entire service group as a unit
        """
        
      _ ->
        """
        This folder contains #{purpose}. Analyze the contents to understand
        how to work with this component.
        """
    end
    
    technology_instructions = if length(technologies) > 0 do
      "\n\nDetected technologies: #{Enum.join(technologies, ", ")}"
    else
      ""
    end
    
    base_instructions <> technology_instructions
  end

  defp generate_relationship_hints(folder_info) do
    %{
      suggested_actions: [
        "Explore parent folder to understand broader service context",
        "Check sibling folders for related services",
        "Look for configuration files that reference other services",
        "Examine dependency files for external service connections"
      ],
      navigation_paths: [
        %{path: "../", description: "Parent service or workspace"},
        %{path: "./config/", description: "Service configuration"},
        %{path: "./tests/", description: "Test files and examples"}
      ]
    }
  end

  # Helper functions
  defp has_file?(files, filename), do: Enum.any?(files, &(&1.name == filename))
  defp get_file_content(files, filename) do
    case Enum.find(files, &(&1.name == filename)) do
      %{encrypted_content: content} when not is_nil(content) ->
        # In real implementation, decrypt content here
        "encrypted_content"
      _ ->
        ""
    end
  end
end
```

## 2. Client Architecture

### 2.1 iOS Metal Renderer

```swift
import Metal
import MetalKit

class KyozoFolderRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let textRenderer: MetalTextRenderer
    
    // Glyph atlas for efficient text rendering
    private let glyphAtlas: GlyphAtlas
    
    // Buffer pools to eliminate allocations
    private let vertexBufferPool: BufferPool
    private let uniformBufferPool: BufferPool
    
    init(device: MTLDevice) throws {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        // Initialize text rendering subsystem
        self.textRenderer = MetalTextRenderer(device: device)
        self.glyphAtlas = GlyphAtlas(device: device, size: 2048)
        
        // Initialize buffer pools
        self.vertexBufferPool = BufferPool(device: device, bufferSize: 64 * 1024)
        self.uniformBufferPool = BufferPool(device: device, bufferSize: 4 * 1024)
        
        // Create render pipeline
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "folderVertexShader")
        let fragmentFunction = library.makeFunction(name: "folderFragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        super.init()
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Render folder hierarchy with service status overlays
        renderFolderHierarchy(encoder: renderEncoder)
        
        // Render service status indicators
        renderServiceStatusOverlays(encoder: renderEncoder)
        
        // Render AI navigation hints
        renderAINavigationHints(encoder: renderEncoder)
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    private func renderFolderHierarchy(encoder: MTLRenderCommandEncoder) {
        // Use buffer pool to get vertex buffer
        guard let vertexBuffer = vertexBufferPool.nextBuffer() else { return }
        
        // Populate vertex buffer with folder tree geometry
        // Implement viewport culling for large hierarchies
        // Use instanced rendering for repeated folder icons
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}

class MetalTextRenderer {
    private let device: MTLDevice
    private let glyphAtlas: GlyphAtlas
    
    init(device: MTLDevice) {
        self.device = device
        self.glyphAtlas = GlyphAtlas(device: device, size: 2048)
        
        // Pre-populate atlas with common glyphs
        preloadCommonGlyphs()
    }
    
    func renderText(_ text: String, at position: simd_float2, encoder: MTLRenderCommandEncoder) {
        // Batch glyph rendering for efficiency
        // Use SDF (Signed Distance Field) rendering for scalable text
        // Implement text color and effects
    }
}
```

### 2.2 CRDT Client Implementation

```typescript
interface FolderCRDT {
  id: string;
  name: string;
  path: string;
  children: Map<string, FolderCRDT>;
  files: Map<string, FileCRDT>;
  metadata: Map<string, any>;
  tombstones: Set<string>;
  vectorClock: VectorClock;
}

class KyozoFolderSync {
  private localState: FolderCRDT;
  private websocket: WebSocket;
  private conflictResolver: ConflictResolver;
  
  constructor(workspaceId: string) {
    this.localState = this.initializeLocalState(workspaceId);
    this.websocket = this.connectToServer(workspaceId);
    this.conflictResolver = new ConflictResolver();
  }
  
  // Handle local folder changes
  onFolderChange(change: FolderChange) {
    // Apply change locally using CRDT rules
    const updatedState = this.applyLocalChange(this.localState, change);
    
    // Send change to server
    this.broadcastChange(change);
    
    // Update UI immediately
    this.updateUI(updatedState);
  }
  
  // Handle remote changes from server
  onRemoteChange(change: FolderChange) {
    // Merge with local state using CRDT
    
