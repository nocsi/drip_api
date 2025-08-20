# Kyozo Store API Specifications

## Overview

Kyozo Store provides dual API interfaces: a primary JSON:API implementation and a secondary GraphQL endpoint. Both APIs are built using the Ash Framework with automatic schema generation and comprehensive documentation.

## API Endpoints

### Base Configuration
- **JSON:API Base URL**: `/api/v1`
- **GraphQL Endpoint**: `/graphql`
- **API Documentation**: `/open_api` (OpenAPI 3.0 specification)
- **GraphiQL Interface**: `/graphiql` (development only)

### Authentication
All API endpoints require authentication via:
- **Bearer Token**: `Authorization: Bearer <jwt_token>`
- **API Key**: `Authorization: Bearer <api_key>`
- **Session Cookie**: For web interface integration

## JSON:API Endpoints

### Authentication Endpoints

#### User Registration
```http
POST /api/v1/users/register
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "user",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com", 
      "password": "securepassword123",
      "password_confirmation": "securepassword123"
    }
  }
}
```

**Response**:
```json
{
  "data": {
    "type": "user",
    "id": "01234567-89ab-cdef-0123-456789abcdef",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com",
      "confirmed_at": null,
      "current_team": null
    },
    "relationships": {
      "teams": {
        "data": []
      }
    }
  },
  "meta": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### User Sign In
```http
POST /api/v1/users/sign-in
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "user",
    "attributes": {
      "email": "john@example.com",
      "password": "securepassword123"
    }
  }
}
```

**Response**:
```json
{
  "data": {
    "type": "user",
    "id": "01234567-89ab-cdef-0123-456789abcdef",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com",
      "confirmed_at": "2024-01-15T10:30:00Z",
      "current_team": "team-uuid"
    }
  },
  "meta": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### Current User Info
```http
GET /api/v1/users/me
Authorization: Bearer <token>
```

### Team Management Endpoints

#### List User Teams
```http
GET /api/v1/teams
Authorization: Bearer <token>
```

**Response**:
```json
{
  "data": [
    {
      "type": "team",
      "id": "team-uuid-1",
      "attributes": {
        "name": "Acme Corp",
        "domain": "acme-corp",
        "description": "Main team workspace"
      },
      "relationships": {
        "workspaces": {
          "data": [
            {"type": "workspace", "id": "workspace-uuid-1"}
          ]
        },
        "members": {
          "data": [
            {"type": "user", "id": "user-uuid-1"}
          ]
        }
      }
    }
  ],
  "included": [
    {
      "type": "workspace", 
      "id": "workspace-uuid-1",
      "attributes": {
        "name": "Main Workspace",
        "status": "active"
      }
    }
  ]
}
```

#### Create Team
```http
POST /api/v1/teams
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "team",
    "attributes": {
      "name": "New Team",
      "domain": "new-team",
      "description": "A new collaborative workspace"
    }
  }
}
```

### Workspace Management Endpoints

#### List Workspaces
```http
GET /api/v1/workspaces
Authorization: Bearer <token>
```

**Query Parameters**:
- `filter[status]` - Filter by status (active, archived)
- `sort` - Sort by field (name, created_at, updated_at)
- `page[limit]` - Pagination limit (default: 20)
- `page[offset]` - Pagination offset
- `include` - Include related resources (files, notebooks, team)

**Response**:
```json
{
  "data": [
    {
      "type": "workspace",
      "id": "workspace-uuid",
      "attributes": {
        "name": "Development Workspace",
        "description": "Main development environment",
        "status": "active",
        "storage_backend": "hybrid",
        "settings": {
          "auto_save": true,
          "collaborative_mode": true
        },
        "tags": ["development", "primary"],
        "created_at": "2024-01-15T10:30:00Z",
        "updated_at": "2024-01-15T15:45:00Z"
      },
      "relationships": {
        "team": {
          "data": {"type": "team", "id": "team-uuid"}
        },
        "files": {
          "data": [
            {"type": "file", "id": "file-uuid-1"},
            {"type": "file", "id": "file-uuid-2"}
          ]
        }
      }
    }
  ],
  "meta": {
    "total_count": 5,
    "page_count": 1
  }
}
```

#### Create Workspace
```http
POST /api/v1/workspaces
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "workspace",
    "attributes": {
      "name": "New Project Workspace",
      "description": "Workspace for the new project",
      "storage_backend": "hybrid",
      "settings": {
        "auto_save": true,
        "collaborative_mode": false
      },
      "tags": ["project", "new"]
    }
  }
}
```

#### Update Workspace
```http
PATCH /api/v1/workspaces/{id}
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "workspace",
    "id": "workspace-uuid",
    "attributes": {
      "name": "Updated Workspace Name",
      "description": "Updated description",
      "settings": {
        "auto_save": false,
        "collaborative_mode": true
      }
    }
  }
}
```

### File Management Endpoints

#### List Files
```http
GET /api/v1/workspaces/{workspace_id}/files
Authorization: Bearer <token>
```

**Query Parameters**:
- `filter[content_type]` - Filter by MIME type
- `filter[storage_backend]` - Filter by storage backend
- `filter[tags]` - Filter by tags
- `sort` - Sort by field (name, updated_at, file_size)
- `include` - Include relationships (storage, media, notebook)

**Response**:
```json
{
  "data": [
    {
      "type": "file",
      "id": "file-uuid",
      "attributes": {
        "title": "Project Documentation",
        "file_path": "/docs/readme.md",
        "content_type": "text/markdown",
        "file_size": 2048,
        "storage_backend": "git",
        "tags": ["documentation", "important"],
        "version": "1.2.0",
        "checksum": "sha256:abcdef...",
        "is_binary": false,
        "view_count": 15,
        "created_at": "2024-01-15T10:30:00Z",
        "updated_at": "2024-01-16T09:15:00Z",
        "last_viewed_at": "2024-01-16T14:30:00Z"
      },
      "relationships": {
        "workspace": {
          "data": {"type": "workspace", "id": "workspace-uuid"}
        },
        "primary_storage": {
          "data": {"type": "file_storage", "id": "storage-uuid"}
        }
      }
    }
  ]
}
```

#### Create File
```http
POST /api/v1/workspaces/{workspace_id}/files
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "file",
    "attributes": {
      "title": "New Document",
      "file_path": "/docs/new-doc.md",
      "content_type": "text/markdown",
      "description": "A new document",
      "tags": ["draft"],
      "storage_backend": "git"
    }
  }
}
```

#### Update File Content
```http
PATCH /api/v1/files/{id}
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "file",
    "id": "file-uuid",
    "attributes": {
      "title": "Updated Document Title",
      "description": "Updated description",
      "tags": ["documentation", "updated"]
    }
  }
}
```

### Notebook Management Endpoints

#### List Notebooks
```http
GET /api/v1/workspaces/{workspace_id}/notebooks
Authorization: Bearer <token>
```

**Response**:
```json
{
  "data": [
    {
      "type": "notebook",
      "id": "notebook-uuid",
      "attributes": {
        "title": "Data Analysis Notebook",
        "status": "draft",
        "execution_state": {
          "kernel_status": "idle",
          "execution_count": 5
        },
        "collaborative_mode": true,
        "auto_save_enabled": true,
        "execution_timeout": 300,
        "created_at": "2024-01-15T10:30:00Z",
        "updated_at": "2024-01-16T09:15:00Z",
        "last_executed_at": "2024-01-16T08:45:00Z"
      },
      "relationships": {
        "workspace": {
          "data": {"type": "workspace", "id": "workspace-uuid"}
        },
        "tasks": {
          "data": [
            {"type": "task", "id": "task-uuid-1"},
            {"type": "task", "id": "task-uuid-2"}
          ]
        }
      }
    }
  ]
}
```

#### Execute Notebook
```http
POST /api/v1/notebooks/{id}/execute
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "execution_request",
    "attributes": {
      "execution_mode": "all",
      "environment_variables": {
        "ENV": "development"
      }
    }
  }
}
```

### Task Management Endpoints

#### List Notebook Tasks
```http
GET /api/v1/notebooks/{notebook_id}/tasks
Authorization: Bearer <token>
```

**Response**:
```json
{
  "data": [
    {
      "type": "task",
      "id": "task-uuid",
      "attributes": {
        "name": "Data Processing",
        "language": "python",
        "code": "import pandas as pd\ndf = pd.read_csv('data.csv')",
        "description": "Load and process data",
        "order_index": 1,
        "is_executable": true,
        "execution_count": 3,
        "last_execution_status": "success",
        "last_execution_output": "Data loaded: 100 rows",
        "execution_time_ms": 1250,
        "dependencies": ["pandas"],
        "environment_variables": {},
        "timeout_seconds": 30,
        "created_at": "2024-01-15T10:30:00Z",
        "last_executed_at": "2024-01-16T08:45:00Z"
      }
    }
  ]
}
```

#### Execute Task
```http
POST /api/v1/tasks/{id}/execute
Authorization: Bearer <token>
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "execution_request",
    "attributes": {
      "environment_variables": {
        "DEBUG": "true"
      },
      "timeout_seconds": 60
    }
  }
}
```

## GraphQL API

### Endpoint
```
POST /graphql
Authorization: Bearer <token>
```

### Schema Overview

```graphql
type Query {
  # User queries
  currentUser: User
  
  # Team queries  
  teams: [Team!]!
  team(id: ID!): Team
  
  # Workspace queries
  workspaces: [Workspace!]!
  workspace(id: ID!): Workspace
  
  # File queries
  files(workspaceId: ID!): [File!]!
  file(id: ID!): File
  
  # Notebook queries
  notebooks(workspaceId: ID!): [Notebook!]!
  notebook(id: ID!): Notebook
}

type Mutation {
  # User mutations
  registerUser(input: RegisterUserInput!): UserResult!
  signInUser(input: SignInInput!): UserResult!
  
  # Team mutations
  createTeam(input: CreateTeamInput!): TeamResult!
  updateTeam(id: ID!, input: UpdateTeamInput!): TeamResult!
  
  # Workspace mutations
  createWorkspace(input: CreateWorkspaceInput!): WorkspaceResult!
  updateWorkspace(id: ID!, input: UpdateWorkspaceInput!): WorkspaceResult!
  
  # File mutations
  createFile(input: CreateFileInput!): FileResult!
  updateFile(id: ID!, input: UpdateFileInput!): FileResult!
  
  # Notebook mutations
  createNotebook(input: CreateNotebookInput!): NotebookResult!
  executeNotebook(id: ID!, input: ExecutionInput!): ExecutionResult!
}

type Subscription {
  # Real-time updates
  workspaceUpdates(workspaceId: ID!): WorkspaceEvent!
  documentUpdates(documentId: ID!): DocumentEvent!
  notebookExecution(notebookId: ID!): ExecutionEvent!
}
```

### GraphQL Type Definitions

#### User Types
```graphql
type User {
  id: ID!
  name: String!
  email: String!
  confirmedAt: DateTime
  currentTeam: String
  teams: [Team!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Team {
  id: ID!
  name: String!
  domain: String!
  description: String
  workspaces: [Workspace!]!
  members: [TeamMember!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type TeamMember {
  id: ID!
  user: User!
  team: Team!
  role: TeamRole!
  joinedAt: DateTime!
}

enum TeamRole {
  OWNER
  ADMIN  
  MEMBER
}
```

#### Workspace Types
```graphql
type Workspace {
  id: ID!
  name: String!
  description: String
  status: WorkspaceStatus!
  storageBackend: StorageBackend!
  settings: WorkspaceSettings!
  tags: [String!]!
  files: [File!]!
  notebooks: [Notebook!]!
  team: Team!
  createdBy: User
  createdAt: DateTime!
  updatedAt: DateTime!
  archivedAt: DateTime
}

enum WorkspaceStatus {
  ACTIVE
  ARCHIVED
  DELETED
}

enum StorageBackend {
  GIT
  S3
  DISK
  RAM
  HYBRID
}

type WorkspaceSettings {
  autoSave: Boolean!
  collaborativeMode: Boolean!
  defaultStorageBackend: StorageBackend!
}
```

#### File Types
```graphql
type File {
  id: ID!
  title: String!
  filePath: String!
  contentType: String!
  description: String
  tags: [String!]!
  fileSize: Int!
  storageBackend: StorageBackend!
  version: String
  checksum: String
  isBinary: Boolean!
  viewCount: Int!
  workspace: Workspace!
  primaryStorage: FileStorage
  createdAt: DateTime!
  updatedAt: DateTime!
  lastViewedAt: DateTime
}

type FileStorage {
  id: ID!
  storageBackend: StorageBackend!
  storageLocator: String!
  storageMetadata: JSON!
  processed: Boolean!
  processedAt: DateTime
}
```

#### Notebook Types
```graphql
type Notebook {
  id: ID!
  title: String!
  status: NotebookStatus!
  executionState: ExecutionState!
  collaborativeMode: Boolean!
  autoSaveEnabled: Boolean!
  executionTimeout: Int!
  tasks: [Task!]!
  workspace: Workspace!
  createdAt: DateTime!
  updatedAt: DateTime!
  lastExecutedAt: DateTime
}

enum NotebookStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}

type ExecutionState {
  kernelStatus: KernelStatus!
  currentTaskIndex: Int!
  executionCount: Int!
  totalExecutionTime: Int!
}

enum KernelStatus {
  IDLE
  BUSY
  STARTING
  ERROR
}

type Task {
  id: ID!
  name: String!
  language: String
  code: String!
  description: String
  orderIndex: Int!
  isExecutable: Boolean!
  executionCount: Int!
  lastExecutionStatus: ExecutionStatus
  lastExecutionOutput: String
  lastExecutionError: String
  executionTimeMs: Int
  dependencies: [String!]!
  environmentVariables: JSON!
  timeoutSeconds: Int!
  notebook: Notebook!
  createdAt: DateTime!
  lastExecutedAt: DateTime
}

enum ExecutionStatus {
  SUCCESS
  ERROR
  TIMEOUT
  CANCELLED
}
```

### GraphQL Query Examples

#### Get Current User with Teams
```graphql
query GetCurrentUser {
  currentUser {
    id
    name
    email
    teams {
      id
      name
      domain
      workspaces {
        id
        name
        status
        files {
          id
          title
          contentType
          fileSize
        }
      }
    }
  }
}
```

#### Get Workspace with Files and Notebooks
```graphql
query GetWorkspace($id: ID!) {
  workspace(id: $id) {
    id
    name
    description
    status
    settings {
      autoSave
      collaborativeMode
    }
    files {
      id
      title
      filePath
      contentType
      fileSize
      updatedAt
    }
    notebooks {
      id
      title
      status
      executionState {
        kernelStatus
        executionCount
      }
      tasks {
        id
        name
        language
        executionCount
        lastExecutionStatus
      }
    }
  }
}
```

### GraphQL Mutation Examples

#### Create Workspace
```graphql
mutation CreateWorkspace($input: CreateWorkspaceInput!) {
  createWorkspace(input: $input) {
    workspace {
      id
      name
      description
      status
      createdAt
    }
    errors {
      field
      message
    }
  }
}
```

#### Execute Notebook
```graphql
mutation ExecuteNotebook($id: ID!, $input: ExecutionInput!) {
  executeNotebook(id: $id, input: $input) {
    execution {
      id
      status
      startedAt
      completedAt
      results {
        taskId
        status
        output
        error
        executionTime
      }
    }
    errors {
      field
      message
    }
  }
}
```

### GraphQL Subscription Examples

#### Workspace Updates
```graphql
subscription WorkspaceUpdates($workspaceId: ID!) {
  workspaceUpdates(workspaceId: $workspaceId) {
    type
    workspaceId
    userId
    timestamp
    data
  }
}
```

#### Notebook Execution Updates
```graphql
subscription NotebookExecution($notebookId: ID!) {
  notebookExecution(notebookId: $notebookId) {
    type
    notebookId
    taskId
    executionId
    status
    output
    error
    timestamp
  }
}
```

## Error Handling

### JSON:API Error Format
```json
{
  "errors": [
    {
      "id": "error-uuid",
      "status": "422",
      "code": "validation_error",
      "title": "Validation Error",
      "detail": "Name cannot be blank",
      "source": {
        "pointer": "/data/attributes/name"
      },
      "meta": {
        "field": "name",
        "constraint": "required"
      }
    }
  ]
}
```

### GraphQL Error Format
```json
{
  "data": null,
  "errors": [
    {
      "message": "Name cannot be blank",
      "locations": [{"line": 3, "column": 5}],
      "path": ["createWorkspace", "workspace", "name"],
      "extensions": {
        "code": "VALIDATION_ERROR",
        "field": "name",
        "constraint": "required"
      }
    }
  ]
}
```

### Common HTTP Status Codes
- `200` - Success
- `201` - Created
- `204` - No Content
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Unprocessable Entity
- `429` - Too Many Requests
- `500` - Internal Server Error

## Rate Limiting

### Default Limits
- **Authentication endpoints**: 5 requests per minute per IP
- **General API**: 100 requests per minute per user
- **File uploads**: 10 requests per minute per user
- **Notebook execution**: 30 requests per minute per user

### Rate Limit Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1609459200
X-RateLimit-Window: 60
```

## Pagination

### JSON:API Pagination
```http
GET /api/v1/workspaces?page[limit]=20&page[offset]=40
```

**Response**:
```json
{
  "data": [...],
  "meta": {
    "total_count": 150,
    "page_count": 8,
    "current_page": 3
  },
  "links": {
    "first": "/api/v1/workspaces?page[limit]=20&page[offset]=0",
    "prev": "/api/v1/workspaces?page[limit]=20&page[offset]=20", 
    "next": "/api/v1/workspaces?page[limit]=20&page[offset]=60",
    "last": "/api/v1/workspaces?page[limit]=20&page[offset]=140"
  }
}
```

### GraphQL Pagination
```graphql
query GetWorkspaces($first: Int, $after: String) {
  workspaces(first: $first, after: $after) {
    edges {
      node {
        id
        name
      }
      cursor
    }
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
  }
}
```

## Filtering and Sorting

### JSON:API Filtering
```http
GET /api/v1/files?filter[content_type]=text/markdown&filter[tags]=documentation&sort=-updated_at
```

### GraphQL Filtering
```graphql
query GetFiles($filter: FileFilter, $sort: FileSort) {
  files(filter: $filter, sort: $sort) {
    id
    title
    contentType
    updatedAt
  }
}
```

## OpenAPI Specification

The complete OpenAPI 3.0 specification is available at `/open_api` and includes:
- Complete endpoint documentation
- Request/response schemas
- Authentication requirements
- Parameter specifications
- Example requests and responses
- Error response documentation

This API specification provides comprehensive access to all Kyozo Store functionality with both REST and GraphQL interfaces, supporting real-time collaboration and extensive customization options.