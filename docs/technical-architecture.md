# Kyozo Store Technical Architecture

## Executive Summary

Kyozo Store is a comprehensive collaborative workspace platform built on modern Elixir/Phoenix architecture, leveraging the Ash Framework for domain-driven design. The system provides multi-tenant collaborative document editing, notebook execution, project management, and file storage with real-time synchronization capabilities.

## System Overview

### Core Technology Stack

- **Backend Framework**: Phoenix 1.8+ (Elixir 1.14+)
- **Domain Framework**: Ash Framework 3.0 with extensions
- **Database**: PostgreSQL with tenant-aware schemas
- **Frontend**: Svelte 5 with TypeScript
- **UI Components**: shadcn/ui adapted for Svelte
- **Real-time**: Phoenix LiveView + WebSockets
- **Authentication**: AshAuthentication with multi-strategy support
- **API Layer**: Dual JSON:API and GraphQL endpoints
- **Background Jobs**: Oban with AshOban integration
- **File Storage**: Multi-backend storage system (Git, S3, Disk, RAM)

### Architecture Principles

1. **Domain-Driven Design**: Clear separation of business domains
2. **Multi-Tenancy**: Team-based isolation at all layers
3. **Event Sourcing**: Comprehensive audit trails and event tracking
4. **API-First**: RESTful JSON:API and GraphQL endpoints
5. **Progressive Enhancement**: Real-time features with offline resilience
6. **Extensible Storage**: Pluggable storage backends for different content types

## Domain Architecture

### Primary Domains

#### 1. Accounts Domain (`Kyozo.Accounts`)

**Purpose**: User management, authentication, and team organization

**Core Resources**:
- `User` - User accounts with authentication strategies
- `Team` - Multi-tenant organization units
- `UserTeam` - User-team membership with roles
- `Invitation` - Team invitation management
- `ApiKey` - API authentication tokens
- `Notification` - User notification system

**Key Features**:
- Password-based authentication with email confirmation
- Multi-strategy auth (API keys, OAuth2 ready)
- Role-based team membership (owner, admin, member)
- Invitation workflow with email notifications
- Personal team creation on user registration

#### 2. Workspaces Domain (`Kyozo.Workspaces`)

**Purpose**: Collaborative workspace containers and content management

**Core Resources**:
- `Workspace` - Primary collaboration containers
- `File` - Universal file management with metadata
- `FileStorage` - Storage backend abstraction layer
- `FileMedia` - Image/media processing specialization
- `FileNotebook` - Notebook file type specialization
- `Notebook` - Interactive executable documents
- `Task` - Executable code blocks within notebooks
- `Blob` - Content-addressable storage primitives
- `Events` - Comprehensive workspace event tracking

**Key Features**:
- Git-based version control integration
- Multiple storage backends (Git, S3, Disk, RAM, Hybrid)
- Real-time collaborative editing
- Executable notebook environments
- Event-driven architecture for audit trails
- File type detection and specialized handling

#### 3. Projects Domain (`Kyozo.Projects`)

**Purpose**: Project structure analysis and task extraction

**Core Resources**:
- `Project` - File system project containers
- `Document` - Project document analysis
- `Task` - Extracted executable tasks from documents
- `LoadEvent` - Project loading and parsing events

**Key Features**:
- Automatic project structure detection
- Markdown parsing with executable code extraction
- Task dependency analysis
- Project topology detection

#### 4. Storage Domain (`Kyozo.Storage`)

**Purpose**: Unified file storage abstraction layer

**Core Resources**:
- `StorageResource` - Backend-agnostic storage interface
- `AbstractStorage` - Base storage behavior definitions
- Storage implementations (Git, S3, Disk, RAM, Hybrid)

**Key Features**:
- Intelligent backend selection based on content type
- Unified API across storage backends
- Background processing with Oban workers
- Content validation and metadata extraction
- Automatic cleanup and maintenance

### Cross-Domain Patterns

#### Multi-Tenancy
- Team-based isolation at database level
- Tenant context injection in all operations
- Row-level security with team_id filtering
- Tenant-aware migration system

#### Event Tracking
- AshEvents integration for audit trails
- Structured event payloads with metadata
- Event versioning for schema evolution
- Real-time event streaming via PubSub

#### Policy-Based Authorization
- Ash.Policy.Authorizer for fine-grained access control
- Team membership validation
- Role-based permissions
- Resource ownership checks

## Database Design

### Schema Organization

The system uses PostgreSQL with a main schema and tenant-specific schemas:

```sql
-- Main schema (public)
- users
- teams  
- user_teams
- tokens
- api_keys

-- Tenant-aware tables (filtered by team_id)
- workspaces
- files (documents)
- notebooks
- blobs
- storage_resources
- events
- invitations
```

### Key Design Patterns

#### UUID v7 Primary Keys
All resources use UUID v7 for:
- Natural sorting by creation time
- Distributed system compatibility
- Security through unpredictability

#### Soft Deletes
- `deleted_at` timestamps for recovery
- Archive states for workspace lifecycle
- Immutable audit trails

#### JSONB Metadata
- Flexible metadata storage in JSONB columns
- Extensible schema without migrations
- Efficient querying with GIN indexes

#### Comprehensive Indexing
- Multi-column indexes for tenant isolation
- Performance optimization for common queries
- Unique constraints for business rules

## API Architecture

### Dual API Strategy

#### 1. JSON:API (Primary)
- RESTful resource-oriented design
- Standardized error responses
- Relationship handling and sparse fieldsets
- Pagination and sorting support
- OpenAPI 3.0 documentation

**Endpoints**:
```
GET    /api/v1/users
POST   /api/v1/users/register
POST   /api/v1/users/sign-in
GET    /api/v1/workspaces
POST   /api/v1/workspaces
PATCH  /api/v1/workspaces/:id
GET    /api/v1/files
POST   /api/v1/files
```

#### 2. GraphQL (Secondary)
- Single endpoint with flexible queries
- Real-time subscriptions
- Type-safe schema with introspection
- Batch operations and N+1 problem mitigation

**Schema Structure**:
```graphql
type User {
  id: ID!
  name: String!
  email: String!
  teams: [Team!]!
  workspaces: [Workspace!]!
}

type Workspace {
  id: ID!
  name: String!
  files: [File!]!
  notebooks: [Notebook!]!
}
```

### Authentication & Authorization

#### Authentication Strategies
1. **Password-based** with email/password
2. **API Key** authentication for programmatic access
3. **OAuth2** (configured for Google/Apple, currently disabled)
4. **Magic Link** (configured but disabled)

#### JWT Token Management
- Short-lived access tokens
- Refresh token rotation
- Token blacklisting on logout
- Configurable expiration policies

#### Authorization Patterns
- Team-based resource isolation
- Role-based permissions (owner, admin, member)
- Resource ownership validation
- Policy-driven access control

## Frontend Architecture

### Technology Stack

#### Core Framework
- **Svelte 5** with runes-based reactivity
- **TypeScript** for type safety
- **Vite** for build tooling and HMR
- **Tailwind CSS** for styling

#### UI Framework
- **shadcn/ui** components adapted for Svelte
- **Lucide** icons with correct import paths (`@lucide/svelte`)
- **Radix** primitives for accessibility

#### State Management
- **Svelte stores** for global state
- **LiveView integration** for server-driven updates
- **Reactive data loading** with effect-based subscriptions

### Component Architecture

#### Layout System
```
App.svelte (Root)
├── AppLayout.svelte (Shell)
│   ├── Sidebar.svelte (Navigation)
│   ├── TopBar.svelte (Header)
│   └── MobileNav.svelte (Mobile)
└── Route Components
    ├── Dashboard.svelte
    ├── WorkspaceManager.svelte
    ├── DocumentBrowser.svelte
    ├── NotebookManager.svelte
    └── Settings.svelte
```

#### UI Component Library
- Consistent design system implementation
- Accessibility-first approach
- Mobile-responsive design
- Dark/light theme support

#### Real-time Integration
- WebSocket connections via Phoenix channels
- LiveView hooks for server state synchronization
- Optimistic updates with fallback reconciliation

### Editor Integration

#### TipTap Editor
- Rich text editing with collaborative features
- Custom extensions for notebook cells
- Markdown parsing and rendering
- Live preview capabilities

**Critical Implementation Note**: The system uses an existing `Editor.svelte` component that integrates with the `elim` package components (`ShadcnEditor`, `ShadcnToolBar`, `ShadcnBubbleMenu`, `ShadcnDragHandle`). This should NOT be reimplemented or replaced with custom TipTap components.

## Storage Architecture

### Multi-Backend Strategy

The storage system uses intelligent backend selection based on content characteristics:

#### Storage Backend Selection Logic
```elixir
def determine_backend(content, file_name, opts \\ []) do
  file_size = byte_size(content)
  mime_type = MIME.from_path(file_name)
  
  cond do
    # Large binary files → S3
    file_size > 10MB and binary_content? -> :s3
    
    # Small text files → Git (versioning)
    file_size < 1MB and text_content? -> :git
    
    # Images → S3 or Disk based on size
    image_content? -> 
      if file_size > 5MB, do: :s3, else: :disk
      
    # Code files → Git (versioning)
    code_file?(file_name) -> :git
    
    # Default fallback
    true -> :hybrid
  end
end
```

#### Backend Implementations

1. **Git Storage**
   - Version control for text content
   - Branch-based collaboration
   - Commit history preservation
   - Ideal for code and markdown

2. **S3 Storage**
   - Scalable cloud storage
   - Large file handling
   - CDN integration ready
   - Cost-effective for archives

3. **Disk Storage**
   - Local file system
   - Fast access for frequently used files
   - Development-friendly
   - Cache layer for other backends

4. **RAM Storage**
   - In-memory temporary storage
   - Ultra-fast access
   - Session-based content
   - Development and testing

5. **Hybrid Storage**
   - Intelligent backend routing
   - Content-type optimization
   - Automatic failover
   - Best-of-breed selection

### Content Processing Pipeline

#### Background Job Architecture
- **Oban** for reliable job processing
- **AshOban** integration for Ash resource scheduling
- Multiple queue priorities and strategies

#### Processing Workers
```elixir
# Storage processing pipeline
- ProcessStorageWorker    # Content validation and storage
- CreateVersionWorker     # Version control operations  
- CleanupStorageWorker   # Maintenance and garbage collection
- BulkProcessWorker      # Batch operations
```

#### Scheduled Operations
- Unprocessed content detection (5-minute intervals)
- Storage cleanup (daily at 2 AM)
- Version maintenance (10-minute intervals)
- Health checks (weekly)

## Real-time & Collaboration

### Phoenix PubSub Integration

#### Event Broadcasting
```elixir
# Workspace-scoped events
Phoenix.PubSub.broadcast(
  Kyozo.PubSub, 
  "workspace:#{team_id}", 
  {:document_updated, %{document_id: id, changes: changes}}
)
```

#### Subscription Patterns
- Team-based topic isolation
- Workspace-specific channels
- User-specific notifications
- Real-time status updates

### LiveView Integration

#### Hybrid Architecture
- Server-driven state management
- Client-side optimistic updates
- Automatic reconciliation on conflicts
- Progressive enhancement approach

#### Event Handling
- Document collaboration events
- Workspace activity feeds
- Real-time notifications
- Status updates (online/offline)

## Monitoring & Observability

### Telemetry Integration

#### Metrics Collection
- Request/response timing
- Database query performance  
- Background job statistics
- Storage operation metrics

#### Event Tracking
- User activity monitoring
- System performance metrics
- Error rate tracking
- Business metrics

### Health Checks

#### System Health
- Database connectivity
- Storage backend availability
- External service status
- Background job queue health

#### Business Metrics
- Active user counts
- Workspace utilization
- Storage consumption
- Performance benchmarks

## Security Architecture

### Multi-Layer Security

#### Authentication Security
- Password hashing with bcrypt
- JWT token security
- API key management
- Session security

#### Authorization Security
- Team-based isolation
- Resource ownership validation
- Role-based permissions
- Policy-driven access control

#### Data Security
- Encrypted storage at rest
- TLS for data in transit
- Input validation and sanitization
- SQL injection prevention

#### Infrastructure Security
- Rate limiting
- CORS policy enforcement
- CSP headers
- Security headers

## Deployment Architecture

### Container Strategy

#### Docker Configuration
```dockerfile
# Multi-stage build
FROM elixir:1.14-alpine AS builder
# Build dependencies and compile application

FROM alpine:3.18 AS runtime  
# Runtime environment with minimal footprint
```

#### Environment Configuration
- Development with docker-compose
- Production with container orchestration
- Environment-specific configuration
- Secret management integration

### Scaling Considerations

#### Horizontal Scaling
- Stateless application design
- Database connection pooling
- Session store externalization
- Load balancer compatibility

#### Performance Optimization
- Database query optimization
- Asset pipeline optimization
- CDN integration for static assets
- Caching strategies

## Development Workflow

### Code Organization

#### Domain Structure
```
lib/kyozo/
├── accounts/          # User and team management
├── workspaces/        # Content and collaboration  
├── projects/          # Project analysis
├── storage/           # File storage abstraction
├── events/            # Event tracking
└── application.ex     # Application startup
```

#### Frontend Structure  
```
assets/svelte/
├── components/        # Reusable UI components
├── ui/               # Base UI component library
├── layout/           # Layout components
├── stores/           # State management
├── services/         # API integration
└── types/            # TypeScript definitions
```

### Development Patterns

#### Ash Resource Patterns
- Consistent action definitions
- Standardized validation rules
- Common change and calculation patterns
- Policy-based authorization

#### Frontend Patterns
- Svelte 5 runes-based reactivity
- Consistent error handling
- Loading state management
- Optimistic UI updates

#### API Integration Patterns
- Standardized error responses
- Consistent authentication
- Request/response typing
- Retry and fallback logic

## Future Architecture Considerations

### Scalability Roadmap

#### Microservice Evolution
- Domain service extraction
- Event-driven architecture
- Service mesh integration
- Independent scaling units

#### Data Architecture Evolution
- Read replica strategies
- Event sourcing expansion
- CQRS implementation
- Data lake integration

### Technology Evolution

#### Frontend Modernization
- PWA capabilities
- Offline-first architecture
- Mobile application framework
- Native desktop applications

#### Backend Evolution
- GraphQL Federation
- Real-time collaboration optimization
- AI/ML integration capabilities
- Advanced analytics platform

This technical architecture provides a comprehensive foundation for the Kyozo Store platform, balancing current implementation needs with future scalability and extensibility requirements.