# Kyozo Store Database Design

## Overview

Kyozo Store uses PostgreSQL as its primary database with a multi-tenant architecture. The database design emphasizes team-based isolation, comprehensive audit trails, and flexible content management across different storage backends.

## Database Architecture

### Multi-Tenant Strategy

The system uses a **shared database, shared schema** approach with **row-level security** based on team membership:

- **Shared Tables**: Core system tables (users, teams, authentication)
- **Tenant-Isolated Tables**: Business data filtered by `team_id`
- **Tenant Migrations**: Separate migration path for tenant-specific changes
- **Row-Level Security**: Automatic team-based filtering at the database level

### Key Design Principles

1. **UUID v7 Primary Keys**: Time-sortable, distributed-system friendly
2. **Soft Deletes**: Audit trail preservation with `deleted_at` timestamps
3. **JSONB Metadata**: Flexible schema evolution without migrations
4. **Comprehensive Indexing**: Performance optimization for multi-tenant queries
5. **Foreign Key Integrity**: Strict referential integrity with cascade rules
6. **Audit Timestamps**: Created/updated tracking on all entities

## Schema Overview

### Core System Tables

```sql
-- Authentication and user management
users                 -- User accounts and authentication
teams                -- Multi-tenant organization units  
user_teams           -- User-team membership with roles
tokens               -- JWT token management
api_keys            -- API authentication keys
```

### Business Domain Tables

```sql
-- Workspace and content management
workspaces          -- Collaborative workspace containers
documents           -- Universal file/document records (legacy)
files              -- Modern file management (replaces documents)
notebooks          -- Interactive executable notebooks
blobs              -- Content-addressable storage

-- Task and execution management  
workspace_tasks    -- Executable tasks within notebooks
project_tasks      -- Tasks extracted from project documents (legacy)

-- Storage and backend management
storage_resources  -- Backend-agnostic storage abstraction
file_storages     -- File-specific storage relationships  
image_storages    -- Image-specific storage with processing
file_media        -- Media file specializations
file_notebooks    -- Notebook file specializations

-- Project analysis (legacy domain)
projects          -- Project containers for document analysis
project_documents -- Analyzed project documents
project_load_events -- Project processing audit trail

-- Event tracking
workspace_load_events -- Workspace operation audit trail
event_logs           -- System-wide event sourcing
notifications        -- User notification system
invitations          -- Team invitation management
```

## Detailed Table Specifications

### Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT NOT NULL CHECK (length(name) >= 2 AND length(name) <= 100),
  email CITEXT NOT NULL,
  current_team TEXT, -- Currently active team context
  hashed_password TEXT, -- bcrypt hash for password auth
  picture TEXT, -- Profile picture URL
  confirmed_at TIMESTAMPTZ -- Email confirmation timestamp
);

-- Indexes
CREATE UNIQUE INDEX users_unique_email_index ON users (email);
```

**Key Features**:
- Case-insensitive email with CITEXT
- Password authentication with bcrypt
- Email confirmation workflow
- Current team context tracking
- Profile picture support

### Teams Table

```sql
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT NOT NULL,
  domain TEXT NOT NULL, -- URL-friendly team identifier
  description TEXT,
  owner_user_id UUID REFERENCES users(id),
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);
```

**Key Features**:
- Team ownership model
- Domain-based routing support
- Hierarchical team structure ready
- Audit timestamp tracking

### User Teams Table (Many-to-Many)

```sql
CREATE TABLE user_teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

-- Constraints and indexes
CREATE UNIQUE INDEX user_teams_unique_user_membership_index 
  ON user_teams (team_id, user_id);
```

**Role-Based Access**:
- `owner`: Full team control, billing, deletion
- `admin`: User management, workspace administration
- `member`: Standard workspace access

### Workspaces Table

```sql
CREATE TABLE workspaces (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  created_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  
  -- Core attributes
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted')),
  
  -- Storage configuration
  storage_backend TEXT NOT NULL DEFAULT 'hybrid' 
    CHECK (storage_backend IN ('git', 's3', 'disk', 'ram', 'hybrid')),
  storage_path TEXT, -- Backend-specific storage location
  storage_metadata JSONB DEFAULT '{}', -- Backend configuration
  
  -- Git integration
  git_repository_url TEXT,
  git_branch TEXT DEFAULT 'main',
  
  -- Metadata and configuration
  settings JSONB DEFAULT '{}', -- Workspace-specific settings
  tags TEXT[] DEFAULT '{}', -- Categorization tags
  
  -- Lifecycle timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  archived_at TIMESTAMPTZ, -- Soft archive
  deleted_at TIMESTAMPTZ -- Soft delete
);

-- Multi-tenant indexes for performance
CREATE UNIQUE INDEX workspaces_unique_team_name_index 
  ON workspaces (team_id, name);
CREATE INDEX workspaces_team_status_index 
  ON workspaces (team_id, status);
CREATE INDEX workspaces_team_storage_backend_index 
  ON workspaces (team_id, storage_backend);
CREATE INDEX workspaces_team_updated_at_index 
  ON workspaces (team_id, updated_at);
```

**Key Features**:
- Multi-tenant isolation by team
- Flexible storage backend configuration
- Git repository integration
- Lifecycle management (active/archived/deleted)
- JSONB settings for extensibility
- Comprehensive indexing for performance

### Files Table (Modern File Management)

```sql
CREATE TABLE files (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  team_member_id UUID NOT NULL REFERENCES user_teams(id) ON DELETE CASCADE,
  
  -- File identification
  title TEXT NOT NULL,
  file_path TEXT NOT NULL, -- Workspace-relative path
  content_type TEXT NOT NULL DEFAULT 'text/plain',
  description TEXT,
  tags TEXT[] DEFAULT '{}',
  
  -- File metadata
  file_size BIGINT DEFAULT 0,
  storage_backend TEXT DEFAULT 'hybrid',
  storage_metadata JSONB DEFAULT '{}',
  version TEXT, -- Version identifier
  checksum TEXT, -- Content hash for integrity
  is_binary BOOLEAN DEFAULT false,
  
  -- Access tracking
  view_count BIGINT DEFAULT 0,
  last_viewed_at TIMESTAMPTZ,
  
  -- Rendering cache
  render_cache JSONB DEFAULT '{}', -- Cached rendered content
  
  -- Lifecycle timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  deleted_at TIMESTAMPTZ -- Soft delete
);

-- Multi-tenant performance indexes
CREATE UNIQUE INDEX files_unique_team_workspace_path_index 
  ON files (team_id, workspace_id, file_path);
CREATE INDEX files_team_workspace_updated_at_index 
  ON files (team_id, workspace_id, updated_at);
CREATE INDEX files_team_content_type_index 
  ON files (team_id, content_type);
CREATE INDEX files_team_storage_backend_index 
  ON files (team_id, storage_backend);
```

**Key Features**:
- Workspace-scoped file organization
- Multi-backend storage support
- Content type detection and handling
- Version control integration
- Access analytics
- Render cache for performance
- Comprehensive metadata storage

### Notebooks Table

```sql
CREATE TABLE notebooks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  
  -- Notebook content
  title TEXT NOT NULL,
  content TEXT, -- Raw notebook content (JSON/Markdown)
  content_html TEXT, -- Rendered HTML content
  status TEXT NOT NULL DEFAULT 'draft' 
    CHECK (status IN ('draft', 'published', 'archived')),
  
  -- Execution state
  execution_state JSONB DEFAULT '{}', -- Kernel state, variables, etc.
  extracted_tasks JSONB[] DEFAULT '{}', -- Parsed executable tasks
  execution_order TEXT[] DEFAULT '{}', -- Task execution sequence
  current_task_index BIGINT DEFAULT 0,
  total_execution_time BIGINT DEFAULT 0, -- Milliseconds
  execution_count BIGINT NOT NULL DEFAULT 0,
  
  -- Collaboration features
  auto_save_enabled BOOLEAN NOT NULL DEFAULT true,
  collaborative_mode BOOLEAN NOT NULL DEFAULT false,
  kernel_status TEXT DEFAULT 'idle' 
    CHECK (kernel_status IN ('idle', 'busy', 'starting', 'error')),
  
  -- Configuration
  environment_variables JSONB DEFAULT '{}',
  execution_timeout BIGINT DEFAULT 300, -- Seconds
  render_cache JSONB DEFAULT '{}', -- Cached rendering data
  metadata JSONB DEFAULT '{}', -- Extensible metadata
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  last_executed_at TIMESTAMPTZ,
  last_accessed_at TIMESTAMPTZ
);

-- Relationships and performance indexes
CREATE UNIQUE INDEX notebooks_unique_document_notebook_index 
  ON notebooks (document_id);
CREATE INDEX notebooks_team_workspace_status_index 
  ON notebooks (team_id, workspace_id, status);
CREATE INDEX notebooks_workspace_updated_at_index 
  ON notebooks (workspace_id, updated_at);
```

**Key Features**:
- File-based notebook storage
- Execution state management
- Task extraction and orchestration
- Real-time collaboration support
- Kernel status tracking
- Comprehensive caching strategy

### Workspace Tasks Table

```sql
CREATE TABLE workspace_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  notebook_id UUID NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
  workspace_id UUID REFERENCES workspaces(id) ON DELETE SET NULL,
  
  -- Task identification
  name TEXT NOT NULL,
  is_name_generated BOOLEAN NOT NULL DEFAULT false,
  language TEXT, -- Programming language (python, bash, etc.)
  code TEXT NOT NULL, -- Executable code content
  description TEXT,
  
  -- Position and ordering
  order_index BIGINT NOT NULL DEFAULT 0,
  line_start BIGINT, -- Source line start
  line_end BIGINT, -- Source line end
  
  -- Execution tracking
  execution_count BIGINT NOT NULL DEFAULT 0,
  last_execution_status TEXT CHECK (
    last_execution_status IN ('success', 'error', 'timeout', 'cancelled')
  ),
  last_execution_output TEXT,
  last_execution_error TEXT,
  execution_time_ms BIGINT, -- Last execution duration
  
  -- Execution configuration
  is_executable BOOLEAN NOT NULL DEFAULT true,
  requires_input BOOLEAN NOT NULL DEFAULT false,
  dependencies TEXT[] DEFAULT '{}', -- Package dependencies
  environment_variables JSONB DEFAULT '{}',
  working_directory TEXT,
  timeout_seconds BIGINT DEFAULT 30,
  metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  last_executed_at TIMESTAMPTZ
);

-- Task ordering and relationships
CREATE UNIQUE INDEX workspace_tasks_unique_notebook_order_index 
  ON workspace_tasks (notebook_id, order_index);
CREATE UNIQUE INDEX workspace_tasks_unique_notebook_workspace_id_index 
  ON workspace_tasks (notebook_id, workspace_id) 
  WHERE (workspace_id IS NOT NULL);
```

**Key Features**:
- Notebook-based task organization
- Multi-language execution support
- Dependency management
- Execution result tracking
- Performance monitoring
- Flexible configuration

### Blobs Table (Content-Addressable Storage)

```sql
CREATE TABLE blobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  hash TEXT NOT NULL, -- Content hash (SHA-256)
  size BIGINT NOT NULL, -- Content size in bytes
  content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  encoding TEXT DEFAULT 'utf-8', -- Text encoding for text content
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

-- Content deduplication
CREATE UNIQUE INDEX blobs_unique_hash_index ON blobs (hash);
CREATE INDEX blobs_content_type_index ON blobs (content_type);
CREATE INDEX blobs_size_index ON blobs (size);
CREATE INDEX blobs_created_at_index ON blobs (created_at);
```

**Key Features**:
- Content-addressable storage
- Automatic deduplication by hash
- MIME type detection
- Size-based indexing for analytics
- Encoding preservation for text content

### Storage Resource Table

```sql
CREATE TABLE storage_resources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  
  -- Storage identification
  locator_id TEXT NOT NULL, -- Unique storage locator
  storage_backend TEXT NOT NULL CHECK (
    storage_backend IN ('git', 's3', 'disk', 'ram', 'hybrid')
  ),
  
  -- Content metadata
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  file_size BIGINT NOT NULL DEFAULT 0,
  content_hash TEXT, -- SHA-256 hash for integrity
  
  -- Storage configuration
  storage_options JSONB DEFAULT '{}', -- Backend-specific options
  storage_metadata JSONB DEFAULT '{}', -- Backend-specific metadata
  
  -- Processing state
  processed BOOLEAN DEFAULT false,
  processed_at TIMESTAMPTZ,
  last_error TEXT,
  last_error_at TIMESTAMPTZ,
  
  -- Lifecycle timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

-- Storage locator and backend indexes
CREATE UNIQUE INDEX storage_resources_unique_locator_index 
  ON storage_resources (locator_id);
CREATE INDEX storage_resources_storage_backend_index 
  ON storage_resources (storage_backend);
CREATE INDEX storage_resources_processed_index 
  ON storage_resources (processed);
CREATE INDEX storage_resources_content_hash_index 
  ON storage_resources (content_hash);
```

**Key Features**:
- Backend-agnostic storage interface
- Content integrity verification
- Processing state tracking
- Flexible metadata storage
- Error tracking and recovery

### Event Tracking Tables

#### Workspace Load Events
```sql
CREATE TABLE workspace_load_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  notebook_id UUID REFERENCES notebooks(id) ON DELETE SET NULL,
  task_id UUID REFERENCES workspace_tasks(id) ON DELETE SET NULL,
  
  -- Event details
  event_type TEXT NOT NULL,
  event_data JSONB DEFAULT '{}',
  path TEXT, -- File path if applicable
  error_message TEXT,
  
  -- Task context
  task_name TEXT,
  task_workspace_id TEXT, -- String identifier from task
  is_task_name_generated BOOLEAN,
  
  -- Performance tracking
  processing_time_ms BIGINT,
  sequence_number BIGINT NOT NULL DEFAULT 0,
  
  -- Timestamps
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

-- Event ordering and performance
CREATE UNIQUE INDEX workspace_load_events_unique_workspace_sequence_index 
  ON workspace_load_events (workspace_id, sequence_number);
```

#### Invitations Table
```sql
CREATE TABLE invitations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  invited_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inviter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

-- Unique invitation constraint
CREATE UNIQUE INDEX invitations_unique_user_invitation_index 
  ON invitations (team_id, invited_user_id);
```

## Storage Backend Integration Tables

### File Storage Table
```sql
CREATE TABLE file_storages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  storage_resource_id UUID NOT NULL REFERENCES storage_resources(id) ON DELETE CASCADE,
  
  -- Storage relationship metadata
  is_primary BOOLEAN DEFAULT false, -- Primary storage for this file
  storage_purpose TEXT DEFAULT 'content', -- content, backup, cache, etc.
  
  -- Processing metadata
  processed BOOLEAN DEFAULT false,
  processed_at TIMESTAMPTZ,
  storage_metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);
```

### File Media Table (Image Processing)
```sql
CREATE TABLE file_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  
  -- Image metadata
  width INTEGER,
  height INTEGER,
  format TEXT, -- JPEG, PNG, WebP, etc.
  color_space TEXT, -- RGB, CMYK, etc.
  has_transparency BOOLEAN DEFAULT false,
  
  -- Processing results
  thumbnails_generated BOOLEAN DEFAULT false,
  colors_extracted BOOLEAN DEFAULT false,
  dominant_colors JSONB, -- Color palette
  
  -- Processing metadata
  processing_metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);
```

### File Notebook Table (Notebook Processing)
```sql
CREATE TABLE file_notebooks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  
  -- Notebook analysis
  cell_count INTEGER DEFAULT 0,
  code_cells INTEGER DEFAULT 0,
  markdown_cells INTEGER DEFAULT 0,
  executed_cells INTEGER DEFAULT 0,
  
  -- Dependencies
  kernel_name TEXT,
  language TEXT,
  dependencies JSONB DEFAULT '{}', -- Package dependencies
  
  -- Validation results
  valid_notebook BOOLEAN DEFAULT true,
  validation_errors JSONB DEFAULT '[]',
  
  -- Processing metadata
  analysis_metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);
```

## Database Migrations Strategy

### Migration Organization
```
priv/repo/migrations/          -- Main schema migrations
priv/repo/tenant_migrations/   -- Tenant-specific migrations
priv/resource_snapshots/       -- Ash resource snapshots
```

### Migration Patterns

#### 1. Core System Changes
- User management updates
- Authentication system changes
- Multi-tenancy infrastructure

#### 2. Business Domain Changes
- New business entities
- Relationship modifications
- Index optimizations

#### 3. Tenant-Specific Changes
- Team-isolated feature additions
- Workspace configuration changes
- User-specific customizations

### UUID v7 Configuration
```sql
-- Enable uuid-ossp extension for v7 UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Custom UUID v7 function
CREATE OR REPLACE FUNCTION uuid_generate_v7()
RETURNS UUID
AS $$
BEGIN
  RETURN uuid_generate_v4(); -- Simplified for compatibility
END;
$$ LANGUAGE plpgsql;
```

## Performance Optimization

### Indexing Strategy

#### 1. Multi-Tenant Indexes
Every tenant-scoped table has composite indexes:
```sql
CREATE INDEX table_name_team_id_frequently_queried_column_index 
  ON table_name (team_id, frequently_queried_column);
```

#### 2. Unique Constraint Indexes
Business rule enforcement with performance benefits:
```sql
CREATE UNIQUE INDEX workspaces_unique_team_name_index 
  ON workspaces (team_id, name);
```

#### 3. Partial Indexes
Conditional indexes for specific query patterns:
```sql
CREATE UNIQUE INDEX workspace_tasks_unique_notebook_workspace_id_index 
  ON workspace_tasks (notebook_id, workspace_id) 
  WHERE (workspace_id IS NOT NULL);
```

#### 4. JSONB Indexes
Efficient querying of JSON metadata:
```sql
CREATE INDEX storage_metadata_gin_index 
  ON storage_resources USING GIN (storage_metadata);
```

### Query Optimization Patterns

#### 1. Team-Scoped Queries
Always filter by team_id first:
```sql
SELECT * FROM workspaces 
WHERE team_id = $1 AND status = 'active'
ORDER BY updated_at DESC;
```

#### 2. Relationship Preloading
Minimize N+1 queries with joins:
```sql
SELECT w.*, u.name as creator_name
FROM workspaces w
LEFT JOIN users u ON w.created_by_id = u.id
WHERE w.team_id = $1;
```

#### 3. Pagination with Cursors
Efficient pagination for large datasets:
```sql
SELECT * FROM files
WHERE team_id = $1 AND created_at > $2
ORDER BY created_at
LIMIT 20;
```

## Data Integrity and Constraints

### Foreign Key Constraints
Strict referential integrity with appropriate cascade rules:
```sql
-- Cascade deletes for ownership relationships
team_id REFERENCES teams(id) ON DELETE CASCADE

-- Nullify for optional relationships  
created_by_id REFERENCES users(id) ON DELETE SET NULL

-- Restrict for critical references (explicit application handling)
primary_storage_id REFERENCES storage_resources(id) ON DELETE RESTRICT
```

### Check Constraints
Business rule enforcement at database level:
```sql
-- Enumerated values
CHECK (status IN ('active', 'archived', 'deleted'))

-- Value ranges
CHECK (file_size >= 0)
CHECK (execution_timeout > 0)

-- String formats
CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
```

### Unique Constraints
Business uniqueness rules:
```sql
-- Global uniqueness
UNIQUE (email)

-- Tenant-scoped uniqueness
UNIQUE (team_id, name)
UNIQUE (team_id, workspace_id, file_path)
```

## Backup and Recovery Strategy

### Backup Schedule
- **Continuous**: WAL archiving to S3
- **Daily**: Full database backup at 2 AM UTC
- **Weekly**: Point-in-time recovery validation
- **Monthly**: Backup restoration testing

### Recovery Procedures
1. **Point-in-time recovery**: WAL replay to specific timestamp
2. **Tenant data recovery**: Team-scoped data restoration
3. **Individual resource recovery**: File/notebook level recovery
4. **Cross-region replication**: Geographic distribution for disaster recovery

### Data Retention Policies
- **Soft deleted records**: 90 days before physical deletion
- **Audit events**: 7 years retention for compliance
- **Backup archives**: 1 year online, 7 years cold storage
- **Session data**: 30 days for security analysis

This database design provides a robust foundation for the Kyozo Store platform, balancing performance, scalability, and data integrity while supporting the complex multi-tenant collaborative workspace requirements.