# Kyozo Store - Folder Service API Specification

## Overview

The Folder Service API enables developers to interact with Kyozo Store's "Folder as a Service" platform programmatically. This REST API provides endpoints for managing workspaces, analyzing folder topologies, orchestrating services, and leveraging AI navigation capabilities.

## Base URL

```
Production: https://api.kyozo.store/v1
Development: http://localhost:4000/api/v1
```

## Authentication

All API requests require authentication via Bearer token or API key.

```http
Authorization: Bearer <your_access_token>
```

Or using API key:

```http
X-API-Key: <your_api_key>
```

## Core Concepts

- **Workspace**: A root folder containing your complete service ecosystem
- **Folder**: A directory that may represent a service, proxy, or neighborhood
- **Service Instance**: A running container deployed from a folder
- **Topology**: The detected service architecture from folder structure

## API Endpoints

### 1. Workspaces

#### List Workspaces

```http
GET /workspaces
```

**Response:**
```json
{
  "data": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "name": "My E-commerce Platform",
      "slug": "my-ecommerce-platform",
      "root_path": "/workspaces/my-ecommerce-platform",
      "service_count": 5,
      "status": "healthy",
      "last_analyzed_at": "2024-01-15T10:30:00Z",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "per_page": 20
  }
}
```

#### Create Workspace

```http
POST /workspaces
```

**Request Body:**
```json
{
  "name": "My New Project",
  "slug": "my-new-project",
  "description": "A new microservices project"
}
```

**Response:**
```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "My New Project",
    "slug": "my-new-project",
    "root_path": "/workspaces/my-new-project",
    "service_count": 0,
    "status": "empty",
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

#### Get Workspace Details

```http
GET /workspaces/{workspace_id}
```

**Response:**
```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "My E-commerce Platform",
    "slug": "my-ecommerce-platform",
    "root_path": "/workspaces/my-ecommerce-platform",
    "service_count": 5,
    "topology_cache": {
      "services": [...],
      "patterns": [...],
      "analyzed_at": "2024-01-15T10:30:00Z"
    },
    "collaborators": [
      {
        "id": "user-456",
        "email": "collaborator@example.com",
        "role": "developer"
      }
    ]
  }
}
```

### 2. Folder Operations

#### List Folders

```http
GET /workspaces/{workspace_id}/folders
```

**Query Parameters:**
- `path` (optional): Filter by folder path
- `type` (optional): Filter by folder type (`service`, `proxy`, `neighborhood`)
- `include_files` (boolean): Include file listings

**Response:**
```json
{
  "data": [
    {
      "id": "folder-123",
      "name": "user-service",
      "path": "/user-service",
      "type": "containerized_service",
      "capabilities": ["can_containerize", "has_health_check"],
      "service_indicators": {
        "type": "nodejs_service",
        "runtime": "node"
      },
      "children_count": 3,
      "files_count": 8,
      "last_modified": "2024-01-15T09:15:00Z"
    }
  ]
}
```

#### Create Folder

```http
POST /workspaces/{workspace_id}/folders
```

**Request Body:**
```json
{
  "name": "new-service",
  "path": "/backend/new-service",
  "template": "nodejs-express"
}
```

#### Upload Files to Folder

```http
POST /workspaces/{workspace_id}/folders/{folder_id}/files
```

**Request:** Multipart form data
- `files`: File uploads
- `encryption_key`: Client-side encryption key

**Response:**
```json
{
  "data": [
    {
      "id": "file-789",
      "name": "package.json",
      "path": "/user-service/package.json",
      "content_type": "application/json",
      "size": 1024,
      "content_hash": "sha256:abc123...",
      "uploaded_at": "2024-01-15T10:45:00Z"
    }
  ]
}
```

### 3. Topology Analysis

#### Analyze Workspace Topology

```http
POST /workspaces/{workspace_id}/analyze
```

Triggers topology analysis of the entire workspace.

**Response:**
```json
{
  "data": {
    "workspace_id": "123e4567-e89b-12d3-a456-426614174000",
    "folders": [
      {
        "path": "/user-service",
        "name": "user-service",
        "type": "nodejs_service",
        "capabilities": ["can_containerize", "has_health_check"],
        "dependencies": [
          {"type": "database", "target": "postgresql"}
        ]
      }
    ],
    "patterns": ["microservices", "api_gateway"],
    "topology_map": {
      "services": [...],
      "relationships": [...],
      "deployment_order": [...]
    },
    "analyzed_at": "2024-01-15T10:30:00Z"
  }
}
```

#### Get Folder Analysis

```http
GET /workspaces/{workspace_id}/folders/{folder_path}/analyze
```

**Path Parameters:**
- `folder_path`: URL-encoded folder path (e.g., `%2Fuser-service`)

**Response:**
```json
{
  "data": {
    "path": "/user-service",
    "type": "nodejs_service",
    "purpose": "Node.js web server using Express.js framework",
    "technologies": ["nodejs", "express", "postgresql"],
    "capabilities": [
      "can_containerize",
      "has_health_check",
      "auto_scalable"
    ],
    "dependencies": [
      {
        "type": "database",
        "target": "postgresql",
        "required": true
      }
    ],
    "ai_context": {
      "instructions": "This is a Node.js service...",
      "suggested_actions": [...],
      "navigation_hints": [...]
    }
  }
}
```

### 4. Service Orchestration

#### Deploy Service from Folder

```http
POST /workspaces/{workspace_id}/services/deploy
```

**Request Body:**
```json
{
  "folder_path": "/user-service",
  "environment": {
    "NODE_ENV": "production",
    "DATABASE_URL": "postgresql://..."
  },
  "scaling": {
    "replicas": 2,
    "auto_scale": true
  }
}
```

**Response:**
```json
{
  "data": {
    "id": "service-456",
    "name": "user-service",
    "folder_path": "/user-service",
    "service_type": "nodejs",
    "status": "deploying",
    "container_id": null,
    "port_mappings": {},
    "deployment_started_at": "2024-01-15T10:30:00Z"
  }
}
```

#### List Service Instances

```http
GET /workspaces/{workspace_id}/services
```

**Query Parameters:**
- `status` (optional): Filter by status (`running`, `stopped`, `error`)
- `folder_path` (optional): Filter by folder path

**Response:**
```json
{
  "data": [
    {
      "id": "service-456",
      "name": "user-service",
      "folder_path": "/user-service",
      "service_type": "nodejs",
      "status": "running",
      "container_id": "docker-container-123",
      "port_mappings": {
        "3000": "8001"
      },
      "health_check_url": "http://localhost:8001/health",
      "last_health_check": "2024-01-15T10:29:00Z",
      "started_at": "2024-01-15T10:25:00Z"
    }
  ]
}
```

#### Start Service

```http
POST /workspaces/{workspace_id}/services/{service_id}/start
```

#### Stop Service

```http
POST /workspaces/{workspace_id}/services/{service_id}/stop
```

#### Get Service Logs

```http
GET /workspaces/{workspace_id}/services/{service_id}/logs
```

**Query Parameters:**
- `lines` (optional): Number of log lines to retrieve (default: 100)
- `follow` (boolean): Stream logs in real-time

### 5. AI Navigation

#### Get AI Path Description

```http
GET /workspaces/{workspace_id}/ai/describe/{folder_path}
```

**Response:**
```json
{
  "data": {
    "path": "/user-service",
    "type": "nodejs_service",
    "purpose": "Node.js web server using Express.js framework",
    "technologies": ["nodejs", "express", "postgresql"],
    "context": "This service handles user authentication and profile management",
    "ai_instructions": "You can deploy this service using Docker...",
    "relationships": {
      "depends_on": ["/database"],
      "serves": ["/frontend"],
      "coordinates_with": ["/auth-service"]
    }
  }
}
```

#### Get Related Services

```http
GET /workspaces/{workspace_id}/ai/navigate/{folder_path}/related
```

**Query Parameters:**
- `relation_type`: Type of relationship (`parent`, `children`, `siblings`, `dependencies`)

**Response:**
```json
{
  "data": {
    "current_path": "/user-service",
    "relation_type": "dependencies",
    "related_paths": [
      {
        "path": "/database",
        "relationship": "requires",
        "description": "PostgreSQL database for user data storage"
      },
      {
        "path": "/auth-service",
        "relationship": "coordinates_with",
        "description": "Handles authentication tokens"
      }
    ]
  }
}
```

### 6. Docker Compose Integration

#### Generate Docker Compose

```http
POST /workspaces/{workspace_id}/compose/generate
```

**Request Body:**
```json
{
  "include_paths": ["/user-service", "/database"],
  "environment": "development",
  "networking": "bridge"
}
```

**Response:**
```json
{
  "data": {
    "compose_content": "version: '3.8'\nservices:\n  user-service:\n    ...",
    "services": [
      {
        "name": "user-service",
        "build_context": "/user-service",
        "ports": ["3000:3000"]
      }
    ],
    "generated_at": "2024-01-15T10:30:00Z"
  }
}
```

#### Deploy Compose Stack

```http
POST /workspaces/{workspace_id}/compose/deploy
```

**Request Body:**
```json
{
  "compose_content": "version: '3.8'...",
  "stack_name": "my-app-stack"
}
```

### 7. Real-time Events

#### WebSocket Connection

```
WSS /workspaces/{workspace_id}/events
```

**Authentication:**
```json
{
  "type": "auth",
  "token": "your_access_token"
}
```

**Event Types:**

**Folder Changed:**
```json
{
  "type": "folder_changed",
  "data": {
    "folder_path": "/user-service",
    "change_type": "file_added",
    "details": {
      "file_name": "new-route.js"
    },
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

**Service Status Changed:**
```json
{
  "type": "service_status_changed",
  "data": {
    "service_id": "service-456",
    "old_status": "starting",
    "new_status": "running",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

**Topology Updated:**
```json
{
  "type": "topology_updated",
  "data": {
    "workspace_id": "123e4567-e89b-12d3-a456-426614174000",
    "changes": ["new_service_detected", "dependency_updated"],
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

## Error Handling

### Error Response Format

```json
{
  "error": {
    "code": "FOLDER_NOT_FOUND",
    "message": "The specified folder does not exist",
    "details": {
      "folder_path": "/non-existent-service"
    },
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### Common Error Codes

- `WORKSPACE_NOT_FOUND` (404): Workspace does not exist
- `FOLDER_NOT_FOUND` (404): Folder path not found
- `SERVICE_DEPLOYMENT_FAILED` (500): Service failed to deploy
- `INSUFFICIENT_PERMISSIONS` (403): User lacks required permissions
- `TOPOLOGY_ANALYSIS_FAILED` (500): Failed to analyze folder structure
- `DOCKER_CONNECTION_ERROR` (503): Cannot connect to Docker daemon
- `ENCRYPTION_KEY_INVALID` (400): Invalid encryption key provided

## Rate Limiting

API requests are limited to:
- **Standard endpoints**: 1000 requests per hour
- **Analysis endpoints**: 100 requests per hour
- **Deployment endpoints**: 50 requests per hour
- **WebSocket connections**: 10 concurrent connections per user

Rate limit headers:
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642176000
```

## SDK Examples

### JavaScript/Node.js

```javascript
const KyozoClient = require('@kyozo/api-client');

const client = new KyozoClient({
  apiKey: 'your-api-key',
  baseURL: 'https://api.kyozo.store/v1'
});

// Create workspace
const workspace = await client.workspaces.create({
  name: 'My App',
  slug: 'my-app'
});

// Analyze topology
const topology = await client.workspaces.analyze(workspace.id);

// Deploy service
const service = await client.services.deploy(workspace.id, {
  folder_path: '/api-server',
  environment: { NODE_ENV: 'production' }
});

// Listen to real-time events
client.subscribe(workspace.id, (event) => {
  console.log('Event received:', event);
});
```

### Python

```python
from kyozo_client import KyozoClient

client = KyozoClient(
    api_key='your-api-key',
    base_url='https://api.kyozo.store/v1'
)

# Create workspace
workspace = client.workspaces.create(
    name='My App',
    slug='my-app'
)

# Get AI description of folder
description = client.ai.describe_path(
    workspace_id=workspace['id'],
    folder_path='/user-service'
)

# Deploy services from folder structure
services = client.services.deploy_from_topology(
    workspace_id=workspace['id'],
    environment='production'
)
```

## Webhooks

Configure webhooks to receive notifications about workspace events.

### Webhook Configuration

```http
POST /workspaces/{workspace_id}/webhooks
```

**Request Body:**
```json
{
  "url": "https://your-app.com/webhooks/kyozo",
  "events": ["service_deployed", "topology_changed", "service_failed"],
  "secret": "your-webhook-secret"
}
```

### Webhook Payload

```json
{
  "id": "webhook-event-123",
  "type": "service_deployed",
  "workspace_id": "123e4567-e89b-12d3-a456-426614174000",
  "data": {
    "service_id": "service-456",
    "folder_path": "/user-service",
    "status": "running"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Pagination

List endpoints support pagination:

```http
GET /workspaces?page=2&per_page=50&sort=created_at&order=desc
```

**Response includes pagination metadata:**
```json
{
  "data": [...],
  "meta": {
    "total": 150,
    "page": 2,
    "per_page": 50,
    "total_pages": 3,
    "has_next_page": true,
    "has_prev_page": true
  }
}
```

## OpenAPI Specification

The complete OpenAPI 3.0 specification is available at:
```
GET /api/openapi.json
```

Interactive documentation:
```
https://api.kyozo.store/docs
```

This API enables you to build powerful integrations with Kyozo Store's Folder as a Service platform, bringing the simplicity of folder organization to complex service orchestration workflows.