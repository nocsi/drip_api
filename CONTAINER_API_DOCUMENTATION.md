# Container Services API Documentation

## Overview

The Kyozo Container Services API provides a comprehensive interface for managing containerized applications using a "Folder as a Service" approach. This API enables automatic service detection, deployment, monitoring, and management of Docker containers within team-isolated environments.

## Base URL

```
https://api.kyozo.com/api/v1
```

## Authentication

All API requests require authentication using either:
- **API Key**: Include `X-API-Key` header with your API key
- **Bearer Token**: Include `Authorization: Bearer <token>` header

Team-based requests also require:
- **Team ID**: Include `X-Team-ID` header with the team identifier

### Example Headers

```http
Content-Type: application/json
Authorization: Bearer your_api_token_here
X-Team-ID: team_uuid_here
X-CSRF-Token: csrf_token_here
```

---

## Container Services

### List Services

Retrieve all container services for a team.

**Endpoint:** `GET /teams/{team_id}/services`

**Parameters:**
- `status` (optional): Filter by service status (`running`, `stopped`, `error`, etc.)
- `service_type` (optional): Filter by service type (`nodejs`, `python`, `docker`, etc.)
- `workspace_id` (optional): Filter by workspace ID
- `search` (optional): Search by service name or folder path
- `sort_by` (optional): Sort field (`name`, `created_at`, `deployed_at`, `status`)
- `sort_order` (optional): Sort order (`asc`, `desc`)

**Response:**
```json
{
  "data": [
    {
      "id": "01234567-89ab-cdef-0123-456789abcdef",
      "name": "my-web-app",
      "folder_path": "/app/web-frontend",
      "service_type": "nodejs",
      "detection_confidence": 0.95,
      "status": "running",
      "container_id": "docker_container_id",
      "image_id": "sha256:image_hash",
      "deployment_config": {
        "dockerfile_path": "Dockerfile",
        "build_context": "./",
        "auto_deploy": true
      },
      "port_mappings": {
        "3000": {
          "host_port": 8080,
          "protocol": "tcp"
        }
      },
      "environment_variables": {
        "NODE_ENV": "production",
        "PORT": "3000"
      },
      "resource_limits": {
        "memory_mb": 512,
        "cpu_cores": 1
      },
      "created_at": "2024-12-19T10:30:00Z",
      "updated_at": "2024-12-19T15:45:00Z",
      "deployed_at": "2024-12-19T15:45:00Z",
      "workspace_id": "workspace_uuid",
      "team_id": "team_uuid",
      "workspace": {
        "id": "workspace_uuid",
        "name": "My Project",
        "storage_backend": "git"
      },
      "team": {
        "id": "team_uuid",
        "name": "My Team"
      }
    }
  ]
}
```

### Get Service Details

Retrieve detailed information about a specific service.

**Endpoint:** `GET /teams/{team_id}/services/{service_id}`

**Response:**
```json
{
  "data": {
    "id": "service_uuid",
    "name": "my-web-app",
    "folder_path": "/app/web-frontend",
    "service_type": "nodejs",
    "status": "running",
    "container_id": "docker_container_id",
    "deployment_config": { /* ... */ },
    "port_mappings": { /* ... */ },
    "environment_variables": { /* ... */ },
    "resource_limits": { /* ... */ },
    "health_check_config": {
      "enabled": true,
      "type": "http",
      "endpoint": "/health",
      "interval_seconds": 30,
      "timeout_seconds": 5,
      "retries": 3
    },
    "scaling_config": {
      "min_replicas": 1,
      "max_replicas": 5,
      "auto_scaling_enabled": false
    },
    "deployment_events": [
      {
        "id": "event_uuid",
        "event_type": "deployment_completed",
        "occurred_at": "2024-12-19T15:45:00Z",
        "duration_ms": 45000
      }
    ],
    "health_checks": [
      {
        "id": "health_uuid",
        "status": "healthy",
        "response_time_ms": 125,
        "checked_at": "2024-12-19T16:00:00Z"
      }
    ]
  }
}
```

### Create Service

Create a new container service.

**Endpoint:** `POST /teams/{team_id}/services`

**Request Body:**
```json
{
  "service": {
    "name": "my-new-service",
    "folder_path": "/app/backend-api",
    "service_type": "nodejs",
    "workspace_id": "workspace_uuid",
    "deployment_config": {
      "dockerfile_path": "Dockerfile",
      "build_context": "./",
      "auto_deploy": true
    },
    "port_mappings": {
      "3000": {
        "host_port": 8081,
        "protocol": "tcp"
      }
    },
    "environment_variables": {
      "NODE_ENV": "production",
      "DATABASE_URL": "postgres://..."
    },
    "resource_limits": {
      "memory_mb": 1024,
      "cpu_cores": 2
    },
    "health_check_config": {
      "enabled": true,
      "type": "http",
      "endpoint": "/api/health",
      "port": 3000,
      "interval_seconds": 30
    }
  }
}
```

**Response:** `201 Created`
```json
{
  "data": {
    "id": "new_service_uuid",
    "name": "my-new-service",
    "status": "pending",
    /* ... other service fields ... */
  }
}
```

### Update Service

Update an existing container service configuration.

**Endpoint:** `PUT /teams/{team_id}/services/{service_id}`

**Request Body:**
```json
{
  "service": {
    "name": "updated-service-name",
    "environment_variables": {
      "NODE_ENV": "staging",
      "NEW_VARIABLE": "value"
    },
    "resource_limits": {
      "memory_mb": 2048,
      "cpu_cores": 4
    }
  }
}
```

**Response:** `200 OK`
```json
{
  "data": {
    /* Updated service object */
  }
}
```

### Delete Service

Delete a container service and stop its container.

**Endpoint:** `DELETE /teams/{team_id}/services/{service_id}`

**Response:** `204 No Content`

---

## Service Lifecycle Operations

### Start Service

Start a stopped container service.

**Endpoint:** `POST /teams/{team_id}/services/{service_id}/start`

**Response:** `200 OK`
```json
{
  "data": {
    "id": "service_uuid",
    "status": "starting",
    /* ... service fields ... */
  }
}
```

### Stop Service

Stop a running container service.

**Endpoint:** `POST /teams/{team_id}/services/{service_id}/stop`

**Response:** `200 OK`
```json
{
  "data": {
    "id": "service_uuid",
    "status": "stopping",
    "stopped_at": "2024-12-19T16:30:00Z",
    /* ... service fields ... */
  }
}
```

### Restart Service

Restart a container service (stop then start).

**Endpoint:** `POST /teams/{team_id}/services/{service_id}/restart`

**Response:** `200 OK`
```json
{
  "data": {
    "id": "service_uuid",
    "status": "restarting",
    /* ... service fields ... */
  }
}
```

### Scale Service

Scale a service to a specific number of replicas.

**Endpoint:** `POST /teams/{team_id}/services/{service_id}/scale`

**Request Body:**
```json
{
  "replica_count": 3
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "id": "service_uuid",
    "status": "scaling",
    "scaling_config": {
      "current_replicas": 3,
      "target_replicas": 3
    },
    /* ... service fields ... */
  }
}
```

---

## Monitoring & Diagnostics

### Get Service Status

Get real-time status information for a service.

**Endpoint:** `GET /teams/{team_id}/services/{service_id}/status`

**Response:**
```json
{
  "data": {
    "id": "service_uuid",
    "name": "my-web-app",
    "status": "running",
    "container_id": "docker_container_id",
    "uptime": "2d 14h 30m",
    "deployment_status": "Deployment successful",
    "ports": [
      {
        "container_port": 3000,
        "host_port": 8080,
        "protocol": "tcp"
      }
    ],
    "resource_usage": {
      "cpu_percent": 15.5,
      "memory_percent": 45.2,
      "memory_usage_mb": 231
    }
  }
}
```

### Get Service Logs

Retrieve container logs for a service.

**Endpoint:** `GET /teams/{team_id}/services/{service_id}/logs`

**Parameters:**
- `lines` (optional): Number of log lines to retrieve (default: 100)
- `follow` (optional): Whether to follow logs in real-time (default: false)

**Response:**
```json
{
  "data": {
    "logs": "2024-12-19T16:00:00Z [INFO] Server started on port 3000\n2024-12-19T16:01:15Z [INFO] Database connected\n...",
    "timestamp": "2024-12-19T16:30:00Z"
  }
}
```

### Get Service Metrics

Retrieve performance metrics for a service.

**Endpoint:** `GET /teams/{team_id}/services/{service_id}/metrics`

**Response:**
```json
{
  "data": {
    "service_id": "service_uuid",
    "resource_utilization": {
      "cpu_percent": 15.5,
      "memory_percent": 45.2,
      "memory_usage_bytes": 242221056,
      "memory_limit_bytes": 536870912,
      "network_rx_bytes": 1048576,
      "network_tx_bytes": 2097152,
      "disk_read_bytes": 524288,
      "disk_write_bytes": 1048576,
      "uptime_seconds": 86400,
      "restart_count": 0
    },
    "recent_metrics": [
      {
        "id": "metric_uuid",
        "metric_type": "cpu_percent",
        "value": 15.5,
        "unit": "percent",
        "collected_at": "2024-12-19T16:30:00Z"
      }
    ],
    "updated_at": "2024-12-19T16:30:00Z"
  }
}
```

### Get Service Health

Retrieve health check status for a service.

**Endpoint:** `GET /teams/{team_id}/services/{service_id}/health`

**Response:**
```json
{
  "data": {
    "service_id": "service_uuid",
    "overall_status": "running",
    "last_health_check": {
      "id": "health_uuid",
      "check_type": "http",
      "endpoint": "/health",
      "status": "healthy",
      "response_time_ms": 125,
      "status_code": 200,
      "checked_at": "2024-12-19T16:30:00Z"
    },
    "recent_checks": [
      {
        "id": "health_uuid_1",
        "status": "healthy",
        "response_time_ms": 130,
        "checked_at": "2024-12-19T16:29:30Z"
      },
      {
        "id": "health_uuid_2", 
        "status": "healthy",
        "response_time_ms": 120,
        "checked_at": "2024-12-19T16:29:00Z"
      }
    ]
  }
}
```

---

## Workspace Integration

### List Workspace Services

Get all services deployed from a specific workspace.

**Endpoint:** `GET /teams/{team_id}/workspaces/{workspace_id}/services`

**Response:**
```json
{
  "data": [
    {
      "id": "service_uuid",
      "name": "frontend-app",
      "folder_path": "/frontend",
      "status": "running",
      /* ... service fields ... */
    },
    {
      "id": "service_uuid_2",
      "name": "backend-api",
      "folder_path": "/api",
      "status": "running",
      /* ... service fields ... */
    }
  ]
}
```

### Deploy Service from Workspace

Deploy a new service by analyzing a folder in a workspace.

**Endpoint:** `POST /teams/{team_id}/workspaces/{workspace_id}/services`

**Request Body:**
```json
{
  "service": {
    "name": "auto-detected-service",
    "folder_path": "/app/microservice-a",
    "auto_deploy": true,
    "resource_limits": {
      "memory_mb": 512,
      "cpu_cores": 1
    }
  }
}
```

**Response:** `201 Created`
```json
{
  "data": {
    "id": "new_service_uuid",
    "name": "auto-detected-service",
    "service_type": "nodejs", 
    "detection_confidence": 0.89,
    "status": "deploying",
    /* ... service fields ... */
  }
}
```

### Analyze Workspace Topology

Analyze a workspace folder to detect services and generate deployment recommendations.

**Endpoint:** `POST /teams/{team_id}/workspaces/{workspace_id}/analyze`

**Request Body:**
```json
{
  "folder_path": "/app"
}
```

**Response:**
```json
{
  "data": {
    "id": "analysis_uuid",
    "folder_path": "/app",
    "detection_timestamp": "2024-12-19T16:00:00Z",
    "detected_patterns": {
      "languages": ["javascript", "python"],
      "frameworks": ["express", "flask"],
      "databases": ["postgresql", "redis"],
      "services": ["web", "api", "worker"]
    },
    "service_graph": {
      "nodes": [
        {
          "id": "web-frontend",
          "name": "Web Frontend",
          "type": "nodejs",
          "port": 3000,
          "file_path": "/app/frontend",
          "confidence": 0.95
        },
        {
          "id": "api-backend", 
          "name": "API Backend",
          "type": "python",
          "port": 8000,
          "file_path": "/app/api",
          "confidence": 0.87
        }
      ],
      "edges": [
        {
          "from": "web-frontend",
          "to": "api-backend",
          "type": "connects_to"
        }
      ]
    },
    "recommended_services": [
      {
        "service_name": "web-frontend",
        "service_type": "nodejs",
        "confidence": 0.95,
        "port_mappings": {
          "3000": {
            "host_port": 8080,
            "protocol": "tcp"
          }
        },
        "environment_variables": {
          "NODE_ENV": "production",
          "API_URL": "http://api-backend:8000"
        },
        "resource_limits": {
          "memory_mb": 512,
          "cpu_cores": 1
        },
        "health_check": {
          "enabled": true,
          "type": "http",
          "endpoint": "/health",
          "interval_seconds": 30
        },
        "dockerfile_content": "FROM node:18-alpine\nWORKDIR /app\nCOPY package*.json ./\nRUN npm ci --only=production\nCOPY . .\nEXPOSE 3000\nCMD [\"npm\", \"start\"]"
      }
    ],
    "deployment_strategy": "docker_compose",
    "total_services_detected": 2
  }
}
```

---

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "error": {
    "message": "Invalid request parameters",
    "details": {
      "field": ["is required"]
    }
  }
}
```

### 401 Unauthorized
```json
{
  "error": {
    "message": "Authentication required",
    "code": "unauthorized"
  }
}
```

### 403 Forbidden
```json
{
  "error": {
    "message": "Insufficient permissions for this operation",
    "code": "forbidden"
  }
}
```

### 404 Not Found
```json
{
  "error": {
    "message": "Service not found",
    "code": "not_found"
  }
}
```

### 422 Unprocessable Entity
```json
{
  "error": {
    "message": "Service validation failed",
    "details": {
      "name": ["has already been taken"],
      "port_mappings": ["port 8080 is already in use"]
    }
  }
}
```

### 500 Internal Server Error
```json
{
  "error": {
    "message": "Internal server error occurred",
    "code": "internal_error"
  }
}
```

---

## WebSocket Events

For real-time updates, connect to the WebSocket endpoint:

**Endpoint:** `wss://api.kyozo.com/live/containers`

**Authentication:** Include `token` and `team_id` as query parameters.

### Event Types

#### Service Status Change
```json
{
  "event": "service_status_changed",
  "payload": {
    "service_id": "service_uuid",
    "status": "running",
    "previous_status": "deploying",
    "timestamp": "2024-12-19T16:00:00Z"
  }
}
```

#### Service Metrics Update
```json
{
  "event": "service_metrics_updated",
  "payload": {
    "service_id": "service_uuid",
    "metrics": {
      "cpu_percent": 15.5,
      "memory_percent": 45.2,
      "response_time_ms": 125
    },
    "timestamp": "2024-12-19T16:00:00Z"
  }
}
```

#### Deployment Event
```json
{
  "event": "deployment_event",
  "payload": {
    "service_id": "service_uuid",
    "event_type": "deployment_completed",
    "duration_ms": 45000,
    "success": true,
    "timestamp": "2024-12-19T16:00:00Z"
  }
}
```

#### Health Check Update
```json
{
  "event": "health_check_completed",
  "payload": {
    "service_id": "service_uuid",
    "status": "healthy",
    "response_time_ms": 125,
    "timestamp": "2024-12-19T16:00:00Z"
  }
}
```

---

## Data Types

### Service Status
- `detecting` - Analyzing service type and configuration
- `pending` - Waiting for deployment
- `building` - Building container image
- `deploying` - Deploying container
- `running` - Container is running successfully
- `stopped` - Container has been stopped
- `error` - Error occurred during operation
- `scaling` - Scaling operation in progress
- `restarting` - Restart operation in progress

### Service Types
- `nodejs` - Node.js application
- `python` - Python application
- `golang` - Go application
- `rust` - Rust application
- `java` - Java application
- `ruby` - Ruby application
- `php` - PHP application
- `docker` - Generic Docker container
- `static` - Static website
- `database` - Database service

### Health Status
- `healthy` - Service is responding correctly
- `unhealthy` - Service is not responding or returning errors
- `unknown` - Health check not configured or failed
- `starting` - Service is starting up (grace period)

---

## Rate Limits

API requests are rate limited per team:

- **Standard Plan**: 1000 requests per hour
- **Pro Plan**: 5000 requests per hour
- **Enterprise Plan**: 20000 requests per hour

Rate limit headers are included in all responses:
- `X-RateLimit-Limit`: Maximum requests per hour
- `X-RateLimit-Remaining`: Remaining requests in current window
- `X-RateLimit-Reset`: Unix timestamp when rate limit resets

---

## SDK Examples

### JavaScript/Node.js

```javascript
import { KyozoAPI } from '@kyozo/sdk';

const api = new KyozoAPI({
  apiToken: 'your_api_token',
  teamId: 'your_team_id',
  baseUrl: 'https://api.kyozo.com/api/v1'
});

// List services
const services = await api.services.list();

// Deploy a service
const service = await api.services.create({
  name: 'my-app',
  folder_path: '/app',
  service_type: 'nodejs'
});

// Start service
await api.services.start(service.id);

// Get real-time status
api.services.onStatusChange((serviceId, status) => {
  console.log(`Service ${serviceId} status: ${status}`);
});
```

### Python

```python
from kyozo_sdk import KyozoAPI

api = KyozoAPI(
    api_token='your_api_token',
    team_id='your_team_id',
    base_url='https://api.kyozo.com/api/v1'
)

# List services
services = api.services.list()

# Deploy a service
service = api.services.create({
    'name': 'my-app',
    'folder_path': '/app',
    'service_type': 'python'
})

# Get metrics
metrics = api.services.get_metrics(service.id)
```

### cURL Examples

```bash
# List services
curl -X GET "https://api.kyozo.com/api/v1/teams/team_uuid/services" \
  -H "Authorization: Bearer your_token" \
  -H "X-Team-ID: team_uuid"

# Deploy service
curl -X POST "https://api.kyozo.com/api/v1/teams/team_uuid/services" \
  -H "Authorization: Bearer your_token" \
  -H "X-Team-ID: team_uuid" \
  -H "Content-Type: application/json" \
  -d '{
    "service": {
      "name": "my-app",
      "folder_path": "/app",
      "workspace_id": "workspace_uuid"
    }
  }'

# Start service
curl -X POST "https://api.kyozo.com/api/v1/teams/team_uuid/services/service_uuid/start" \
  -H "Authorization: Bearer your_token" \
  -H "X-Team-ID: team_uuid"
```

---

## Support

For API support and questions:
- **Documentation**: https://docs.kyozo.com/api
- **Community**: https://community.kyozo.com
- **Support Email**: api-support@kyozo.com
- **Status Page**: https://status.kyozo.com

---

**API Version**: v1  
**Last Updated**: December 19, 2024  
**Changelog**: https://docs.kyozo.com/api/changelog