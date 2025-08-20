# Kyozo Store - Folder as a Service Specification

## Executive Summary

Kyozo Store is a revolutionary "Folder as a Service" platform that transforms folder structures into running service topologies, enabling AI-walkable paths and intuitive microservices orchestration through file organization.

The core innovation: **Your folder structure IS your service architecture.**

## Core Philosophy

### The Fundamental Shift

Traditional DevOps requires developers to learn complex orchestration tools, service mesh configurations, and deployment strategies. Kyozo Store inverts this model:

- **Folder structure = Service architecture**
- **Directory organization = Deployment strategy**
- **File explorer = Service dashboard**
- **Moving files = Reconfiguring services**

### Key Principles

1. **Intuitive by Design**: If you can organize files, you can orchestrate services
2. **AI-Walkable**: Every folder structure provides context for AI agents
3. **Emergent Capabilities**: Complex behaviors from simple organization
4. **Pure Storage**: Server stores topology, client handles conflicts

## 1. System Architecture

### Core Domains

#### 1.1 Storage Layer (`Kyozo.Storage`)
```elixir
# Pure storage - no server-side processing
# Handles encrypted content and folder topology
# Real-time change notifications
# Docker orchestration commands
```

**Responsibilities:**
- Folder hierarchy persistence
- Service instance tracking
- Container lifecycle management
- Change event broadcasting

#### 1.2 Workspace Layer (`Kyozo.Workspaces`)
```elixir
# Workspace = Root folder + service topology
# Team collaboration boundaries
# Resource isolation and permissions
```

**Key Resources:**
- Workspace (root service store)
- File (individual service components)
- Folder (service groupings)

#### 1.3 Topology Layer (`Kyozo.Topology`)
```elixir
# Analyzes folder structure to detect service patterns
# Classifies folders by service type
# Maps dependencies and relationships
```

**Pattern Detection:**
- Service folders (individual microservices)
- Proxy folders (load balancers/gateways)
- Neighborhood folders (service groups)
- Store folders (complete ecosystems)

#### 1.4 Orchestration Layer (`Kyozo.Orchestration`)
```elixir
# Translates folder changes to container operations
# Manages Docker Compose generation
# Handles service lifecycle
```

**Container Management:**
- Dockerfile-based services
- Docker Compose stacks
- Auto-detected language services
- Proxy configuration

#### 1.5 AI Navigation (`Kyozo.AI`)
```elixir
# Provides contextual understanding of folder structures
# Enables agents to navigate service topologies
# Generates intelligent suggestions
```

**AI Capabilities:**
- Path description and context
- Relationship inference
- Service pattern recognition
- Navigation assistance

## 2. Service Classification System

### Folder Types

#### 2.1 Service Folder
**Definition**: A folder that represents a single, deployable service

**Detection Criteria:**
- Contains `Dockerfile` or `docker-compose.yml`
- Has language-specific files (`package.json`, `requirements.txt`, etc.)
- Contains application source code

**Example Structure:**
```
/user-service/
├── Dockerfile
├── package.json
├── src/
│   ├── index.js
│   └── routes/
└── tests/
```

**Capabilities:**
- Individual container deployment
- Health check endpoints
- Auto-scaling potential
- Independent versioning

#### 2.2 Proxy Folder
**Definition**: A folder that routes traffic to child service folders

**Detection Criteria:**
- Contains multiple service subfolders
- Has proxy configuration (nginx.conf, traefik.yml)
- Acts as traffic coordinator

**Example Structure:**
```
/api-gateway/
├── nginx.conf
├── /user-service/
├── /product-service/
└── /order-service/
```

**Capabilities:**
- Load balancing
- Traffic routing
- SSL termination
- Rate limiting

#### 2.3 Neighborhood Folder
**Definition**: A folder containing related services that work together

**Detection Criteria:**
- Multiple service folders
- Shared configuration or dependencies
- Logical service grouping

**Example Structure:**
```
/e-commerce-backend/
├── /user-service/
├── /product-service/
├── /order-service/
└── docker-compose.yml
```

**Capabilities:**
- Service coordination
- Shared networking
- Group deployment
- Inter-service communication

#### 2.4 Store Folder
**Definition**: Top-level workspace containing complete service ecosystem

**Detection Criteria:**
- Root workspace folder
- Contains multiple neighborhoods or services
- Has workspace-level configuration

**Example Structure:**
```
/my-ecommerce-platform/
├── /frontend/
├── /backend-services/
│   ├── /user-service/
│   └── /product-service/
├── /databases/
└── /monitoring/
```

**Capabilities:**
- Complete system orchestration
- Multi-environment deployment
- Resource management
- Team collaboration

## 3. Vocabulary & Mental Models

### Service Topology Vocabulary

**Core Terms:**
- **"Folder Services"** - Individual microservices as folders
- **"Proxy Folders"** - Traffic routing through parent directories
- **"Service Neighborhoods"** - Related services grouped together
- **"Service Stores"** - Complete application ecosystems

### Workflow Vocabulary

**Development Patterns:**
- **"Folder-First Development"** - Design structure, get architecture
- **"Directory-Driven Deployment"** - File organization IS deployment
- **"Filesystem Service Discovery"** - Services find each other via paths
- **"Hierarchical Load Balancing"** - Parent folders balance children

### Operations Vocabulary

**DevOps Redefined:**
- **"Folder Ops"** - DevOps through directory manipulation
- **"Service Gardening"** - Tending services like organizing files
- **"Directory Choreography"** - Service orchestration via folders

## 4. AI Navigation System

### Concept: AI-Walkable Paths

Every folder structure provides rich context for AI agents:

```elixir
defmodule Kyozo.AI.PathWalker do
  def describe_path(workspace_id, folder_path) do
    %{
      path: folder_path,
      type: classify_folder_type(folder_path),
      purpose: infer_folder_purpose(folder_path),
      technologies: detect_technologies(folder_path),
      relationships: map_relationships(folder_path),
      capabilities: analyze_capabilities(folder_path),
      ai_instructions: generate_navigation_hints(folder_path)
    }
  end

  def navigate_to_related(workspace_id, current_path, relation_type) do
    case relation_type do
      :parent -> find_parent_service(current_path)
      :children -> find_child_services(current_path) 
      :siblings -> find_sibling_services(current_path)
      :dependencies -> find_dependency_services(current_path)
    end
  end
end
```

### AI Context Generation

For each folder, the AI system provides:

1. **Purpose Inference**: "This appears to be a Node.js API service"
2. **Technology Detection**: "Uses Express.js, connects to PostgreSQL"
3. **Relationship Mapping**: "Depends on user-service, serves frontend"
4. **Capability Assessment**: "Can be containerized, has health checks"
5. **Navigation Hints**: "Related services in ../backend/, database in ../db/"

## 5. Docker Integration Strategy

### Automatic Compose Generation

The platform automatically generates Docker Compose configurations from folder structure:

```yaml
# Auto-generated from folder structure
version: '3.8'
services:
  frontend:
    build: ./frontend
    ports: ["3000:3000"]
    depends_on: [api-gateway]
    
  api-gateway:
    build: ./api-gateway
    ports: ["8080:80"]
    depends_on: [user-service, product-service]
    
  user-service:
    build: ./backend/user-service
    environment:
      - DATABASE_URL=postgresql://db:5432/users
    depends_on: [database]
    
  database:
    image: postgres:15
    environment:
      - POSTGRES_DB=myapp
    volumes: ["db_data:/var/lib/postgresql/data"]

volumes:
  db_data:
```

### Service Detection Rules

1. **Dockerfile Present**: Direct container build
2. **docker-compose.yml Present**: Multi-service stack
3. **package.json Present**: Node.js service (auto-Dockerfile)
4. **requirements.txt Present**: Python service (auto-Dockerfile)
5. **Multiple Subfolders**: Proxy/gateway service

## 6. Technical Implementation

### Core Architecture Principles

#### Storage Layer (Server)
✅ **What It Does:**
- Pure folder topology storage
- Encrypted content handling
- Docker orchestration commands
- Real-time change notifications

❌ **What It Doesn't Do:**
- Server-side CRDT processing
- Content modification
- Conflict resolution
- Rich text processing

#### Client Layer (iOS/Web)
✅ **What It Does:**
- Client-side CRDT for collaboration
- Local conflict resolution
- Rich UI rendering (120fps on iOS)
- AI integration and context

#### API Design
- **Folder Operations**: CRUD for folder structures
- **Service Management**: Start/stop/scale services
- **Health Monitoring**: Service status and metrics
- **AI Context**: Provide navigation assistance
- **Real-time Events**: Folder changes, service updates

### Metal-Accelerated iOS Rendering

The iOS client leverages Metal for 120fps performance:

```swift
class MetalFolderRenderer {
    // GPU-accelerated folder tree rendering
    // Glyph atlas with bin-packing optimization
    // Buffer pooling for zero allocation spikes
    // Viewport culling with smart margins
    // Real-time service status overlays
}
```

## 7. Example Service Topologies

### Basic Three-Tier Application
```
/my-web-app/
├── /frontend/              # React app → Port 3000
│   ├── Dockerfile
│   ├── package.json
│   └── /src/
├── /backend/               # Node.js API → Port 8080
│   ├── Dockerfile
│   ├── package.json
│   └── /routes/
└── /database/              # PostgreSQL → Port 5432
    ├── Dockerfile
    └── /schema/
```

### Microservices Architecture
```
/ecommerce-platform/
├── /frontend/              # Next.js storefront
├── /api-gateway/           # Nginx proxy
│   ├── nginx.conf
│   └── Dockerfile
├── /services/              # Microservices neighborhood
│   ├── /user-service/      # User management
│   ├── /product-service/   # Product catalog
│   ├── /order-service/     # Order processing
│   └── /payment-service/   # Payment handling
├── /databases/             # Data layer
│   ├── /user-db/
│   ├── /product-db/
│   └── /order-db/
└── /monitoring/            # Observability
    ├── /prometheus/
    └── /grafana/
```

### Service Mesh with Istio
```
/advanced-microservices/
├── /service-mesh/          # Istio configuration
│   ├── /istio-config/
│   └── /envoy-configs/
├── /core-services/
│   ├── /auth-service/
│   ├── /user-service/
│   └── /notification-service/
├── /data-services/
│   ├── /postgres-cluster/
│   ├── /redis-cluster/
│   └── /elasticsearch/
└── /edge-services/
    ├── /api-gateway/
    └── /cdn-cache/
```

## 8. Success Metrics

### Technical Performance
- **Folder Sync Latency**: < 100ms for local changes
- **Service Startup Time**: < 30 seconds from folder to running container
- **Mobile Rendering**: Consistent 120fps on supported devices
- **Memory Usage**: < 100MB baseline for storage service
- **AI Response Time**: < 2 seconds for path analysis

### User Experience
- **Time to First Service**: < 5 minutes from folder to running app
- **AI Navigation Accuracy**: > 90% relevant path suggestions
- **Template Adoption**: > 60% of users leverage folder templates
- **Collaboration Latency**: < 200ms for real-time folder changes

### Business Impact
- **Developer Onboarding**: 10x faster than traditional DevOps
- **Service Creation Speed**: 5x faster than manual configuration
- **Deployment Errors**: 80% reduction through folder validation
- **Team Collaboration**: 3x more effective service coordination

## 9. Implementation Phases

### Phase 1: Foundation (Months 1-3)
- Core Elixir/Phoenix/Ash platform
- Basic folder topology detection
- Simple Docker integration
- iOS file explorer interface

### Phase 2: Intelligence (Months 4-6)
- AI path navigation system
- Advanced pattern detection
- Service health monitoring
- Real-time collaboration

### Phase 3: Scale (Months 7-9)
- Multi-tenant isolation
- Enterprise features
- Service marketplace
- Advanced orchestration

### Phase 4: Ecosystem (Months 10-12)
- Multi-region sync
- Community plugins
- Advanced AI automation
- Production optimization

## Conclusion

Kyozo Store represents a fundamental shift in how we think about service orchestration. By leveraging the universal mental model of file organization, it makes complex microservices architecture accessible to any developer who can organize folders.

The combination of intuitive folder-based design, AI-powered navigation, and modern real-time collaboration creates a platform that doesn't just manage services—it transforms how teams think about and build distributed systems.

**The future of DevOps is as simple as organizing your files.**