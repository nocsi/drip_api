# Kyozo Workspace API Implementation

This document provides a comprehensive overview of the implemented Workspace API based on the OpenAPI schema specification.

## Overview

The Kyozo Workspace API provides a JSON:API compliant REST interface for managing workspaces, execution contexts, files, git operations, and teams. All endpoints require API key authentication via the `Authorization` header.

## Authentication

All API endpoints require authentication using an API token:

```http
Authorization: Bearer <your-api-token>
```

The API uses the `KyozoWeb.Plugs.ApiAuth` plug to validate tokens and load the current user.

## Implemented Endpoints

### Workspaces

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/api/workspaces` | List all workspaces for authenticated user |
| POST   | `/api/workspaces` | Create a new workspace |
| GET    | `/api/workspaces/{id}` | Get a specific workspace |
| PATCH  | `/api/workspaces/{id}` | Update a workspace |
| DELETE | `/api/workspaces/{id}` | Delete a workspace |

**Example Workspace JSON:**
```json
{
  "data": {
    "type": "workspaces",
    "id": "uuid",
    "attributes": {
      "name": "My Project",
      "description": "A sample workspace",
      "git_url": "https://github.com/user/repo.git",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  }
}
```

### Code Execution

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST   | `/api/workspaces/{id}/execute` | Execute code in workspace |

**Request Body:**
```json
{
  "data": {
    "type": "execution_requests",
    "attributes": {
      "code": "print('Hello, World!')",
      "context_id": "uuid",
      "timeout": 30,
      "block_id": "optional-block-id"
    }
  }
}
```

**Response:**
```json
{
  "data": {
    "type": "execution_results",
    "attributes": {
      "result": "success",
      "output": "Hello, World!",
      "status": "success",
      "execution_time": 150,
      "context_id": "uuid"
    }
  }
}
```

### Execution Contexts

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/api/workspaces/{id}/execution-contexts` | List execution contexts |
| POST   | `/api/workspaces/{id}/execution-contexts` | Create execution context |
| GET    | `/api/workspaces/{id}/execution-contexts/{context_id}` | Get execution context |
| DELETE | `/api/workspaces/{id}/execution-contexts/{context_id}` | Delete execution context |

**Example Execution Context JSON:**
```json
{
  "data": {
    "type": "execution_contexts",
    "id": "uuid",
    "attributes": {
      "name": "Python Context",
      "status": "idle",
      "created_at": "2024-01-01T00:00:00Z",
      "last_execution": "2024-01-01T12:00:00Z"
    }
  }
}
```

### Git Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/api/workspaces/{id}/git/status` | Get git status |
| POST   | `/api/workspaces/{id}/git/sync` | Sync with remote repository |

**Git Status Response:**
```json
{
  "data": {
    "type": "git_status",
    "attributes": {
      "branch": "main",
      "is_clean": true,
      "ahead": 0,
      "behind": 0,
      "modified_files": [],
      "untracked_files": []
    }
  }
}
```

**Git Sync Request:**
```json
{
  "data": {
    "type": "git_sync",
    "attributes": {
      "operation": "pull",
      "remote": "origin",
      "branch": "main",
      "force": false
    }
  }
}
```

### Files

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST   | `/api/files` | Create a new file |
| GET    | `/api/files/{id}` | Get file details |
| PATCH  | `/api/files/{id}` | Update file content |

**File Creation Request:**
```json
{
  "data": {
    "type": "files",
    "attributes": {
      "filename": "hello.py",
      "content": "print('Hello, World!')",
      "mime_type": "text/x-python"
    },
    "relationships": {
      "workspace": {
        "data": {
          "type": "workspaces",
          "id": "workspace-uuid"
        }
      }
    }
  }
}
```

### Teams

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/api/teams` | List user's teams |
| POST   | `/api/teams` | Create a new team |

**Team JSON:**
```json
{
  "data": {
    "type": "teams",
    "id": "uuid",
    "attributes": {
      "title": "Development Team",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  }
}
```

## Database Schema

### Core Tables

1. **workspaces** - Main workspace entities
   - `id` (binary_id, primary key)
   - `name` (string, required)
   - `description` (text, optional)
   - `git_url` (string, optional)
   - `user_id` (binary_id, foreign key)
   - `inserted_at`, `updated_at`

2. **execution_contexts** - Code execution environments
   - `id` (binary_id, primary key)
   - `name` (string, required)
   - `status` (string, default: "idle")
   - `last_execution` (utc_datetime, optional)
   - `workspace_id` (binary_id, foreign key)
   - `inserted_at`, `updated_at`

3. **files** - Workspace files
   - `id` (binary_id, primary key)
   - `filename` (string, required)
   - `content` (text, required)
   - `mime_type` (string, default: "text/plain")
   - `workspace_id` (binary_id, foreign key)
   - `inserted_at`, `updated_at`

### Relationships

- User has many Workspaces
- Workspace has many ExecutionContexts
- Workspace has many Files
- Teams are implemented using the existing Organisations structure

## Implementation Details

### Controllers

1. **KyozoWeb.Api.WorkspaceController** - Handles workspace CRUD, execution, and git operations
2. **KyozoWeb.Api.ExecutionContextController** - Manages execution contexts
3. **KyozoWeb.Api.FileController** - File management
4. **KyozoWeb.Api.TeamController** - Team operations (wraps Organisation context)

### Context Modules

1. **Kyozo.Workspaces** - Main business logic for workspaces, execution contexts, files, and code execution
2. **Kyozo.Organisations** - Used for team functionality

### Security

- All endpoints require API authentication
- Users can only access their own workspaces and related resources
- File operations are scoped to workspace ownership
- Input validation and sanitization on all user inputs

### Error Handling

The API returns JSON:API compliant error responses:

```json
{
  "errors": [
    {
      "status": "400",
      "title": "Validation Error",
      "detail": "name can't be blank",
      "source": {
        "pointer": "/data/attributes/name"
      }
    }
  ]
}
```

### Mock Implementations

Some endpoints include mock implementations for demonstration:

- **Code Execution**: Simulates code execution with configurable responses based on input
- **Git Operations**: Returns mock git status and sync results
- **Teams**: Maps to existing Organisation functionality

## Testing

To test the API endpoints:

1. Ensure you have a valid API token for a user
2. Use tools like curl, Postman, or HTTPie to make requests
3. Include proper `Content-Type: application/vnd.api+json` headers
4. Follow JSON:API specification for request/response format

## Future Enhancements

1. **Real Code Execution**: Integration with containerized execution environments
2. **Git Integration**: Actual git repository operations
3. **File Upload**: Support for binary file uploads
4. **Webhooks**: Event notifications for workspace changes
5. **Collaboration**: Real-time collaborative features
6. **Analytics**: Usage tracking and performance metrics

## Related Files

- OpenAPI Schema: `docs/kyozo_openapi_extended.json`
- Router Configuration: `lib/kyozo_web/router.ex`
- Database Migrations: `priv/repo/migrations/`
- Test Files: `test/kyozo_web/controllers/api/`
