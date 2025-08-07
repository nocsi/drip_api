# Kyozo Workspace API Demo

This document demonstrates how to use the Kyozo Workspace API with practical examples.

## Prerequisites

1. A running Kyozo application
2. A valid API token for authentication
3. curl or similar HTTP client

## Getting Your API Token

First, you need to generate an API token for your user account. You can do this through the application interface or by using the following commands in the Elixir console:

```elixir
# In iex -S mix
user = Kyozo.Accounts.get_user_by_email("your-email@example.com")
{:ok, user_with_token} = Kyozo.Accounts.generate_api_token(user)
IO.puts("Your API token: #{user_with_token.api_token}")
```

## API Demo Script

### 1. List Workspaces

```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  http://localhost:4000/api/workspaces
```

**Expected Response:**
```json
{
  "data": []
}
```

### 2. Create a New Workspace

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "workspaces",
      "attributes": {
        "name": "Demo Project",
        "description": "A demonstration workspace for the API",
        "git_url": "https://github.com/demo/project.git"
      }
    }
  }' \
  http://localhost:4000/api/workspaces
```

**Expected Response:**
```json
{
  "data": {
    "type": "workspaces",
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "attributes": {
      "name": "Demo Project",
      "description": "A demonstration workspace for the API",
      "git_url": "https://github.com/demo/project.git",
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z"
    }
  }
}
```

### 3. Create an Execution Context

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "execution_contexts",
      "attributes": {
        "name": "Python Environment"
      }
    }
  }' \
  http://localhost:4000/api/workspaces/WORKSPACE_ID/execution-contexts
```

**Expected Response:**
```json
{
  "data": {
    "type": "execution_contexts",
    "id": "660f9500-f39c-52e5-b827-557766551000",
    "attributes": {
      "name": "Python Environment",
      "status": "idle",
      "created_at": "2024-01-01T12:05:00Z",
      "last_execution": null
    }
  }
}
```

### 4. Execute Code

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "execution_requests",
      "attributes": {
        "code": "print(\"Hello from Kyozo API!\")",
        "context_id": "EXECUTION_CONTEXT_ID",
        "timeout": 30
      }
    }
  }' \
  http://localhost:4000/api/workspaces/WORKSPACE_ID/execute
```

**Expected Response:**
```json
{
  "data": {
    "type": "execution_results",
    "attributes": {
      "result": "success",
      "output": "Hello from Kyozo API!",
      "status": "success",
      "execution_time": 150,
      "context_id": "660f9500-f39c-52e5-b827-557766551000"
    }
  }
}
```

### 5. Create a File

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "files",
      "attributes": {
        "filename": "hello.py",
        "content": "print(\"Hello, World!\")\nprint(\"This is a demo file\")",
        "mime_type": "text/x-python"
      },
      "relationships": {
        "workspace": {
          "data": {
            "type": "workspaces",
            "id": "WORKSPACE_ID"
          }
        }
      }
    }
  }' \
  http://localhost:4000/api/files
```

**Expected Response:**
```json
{
  "data": {
    "type": "files",
    "id": "770fa600-04ad-63f6-c938-668877662000",
    "attributes": {
      "filename": "hello.py",
      "content": "print(\"Hello, World!\")\nprint(\"This is a demo file\")",
      "mime_type": "text/x-python",
      "size": 47,
      "created_at": "2024-01-01T12:10:00Z",
      "updated_at": "2024-01-01T12:10:00Z"
    },
    "relationships": {
      "workspace": {
        "data": {
          "type": "workspaces",
          "id": "550e8400-e29b-41d4-a716-446655440000"
        }
      }
    }
  }
}
```

### 6. Get Git Status

```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  http://localhost:4000/api/workspaces/WORKSPACE_ID/git/status
```

**Expected Response:**
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

### 7. Sync with Git Repository

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "git_sync",
      "attributes": {
        "operation": "pull",
        "remote": "origin",
        "branch": "main",
        "force": false
      }
    }
  }' \
  http://localhost:4000/api/workspaces/WORKSPACE_ID/git/sync
```

**Expected Response:**
```json
{
  "data": {
    "type": "git_sync_results",
    "attributes": {
      "operation": "pull",
      "status": "success",
      "message": "Already up to date",
      "commits_ahead": 0,
      "commits_behind": 0
    }
  }
}
```

### 8. Create a Team

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "teams",
      "attributes": {
        "title": "Development Team"
      }
    }
  }' \
  http://localhost:4000/api/teams
```

**Expected Response:**
```json
{
  "data": {
    "type": "teams",
    "id": "880fb700-15be-74f7-da49-779988773000",
    "attributes": {
      "title": "Development Team",
      "created_at": "2024-01-01T12:15:00Z",
      "updated_at": "2024-01-01T12:15:00Z"
    }
  }
}
```

### 9. List Teams

```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  http://localhost:4000/api/teams
```

**Expected Response:**
```json
{
  "data": [
    {
      "type": "teams",
      "id": "880fb700-15be-74f7-da49-779988773000",
      "attributes": {
        "title": "Development Team",
        "created_at": "2024-01-01T12:15:00Z",
        "updated_at": "2024-01-01T12:15:00Z"
      }
    }
  ]
}
```

## Error Handling Examples

### Authentication Error (401)

```bash
curl -X GET \
  -H "Content-Type: application/vnd.api+json" \
  http://localhost:4000/api/workspaces
```

**Response:**
```json
{
  "errors": [
    {
      "status": "401",
      "title": "Error",
      "detail": "Unauthorized"
    }
  ]
}
```

### Validation Error (422)

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "workspaces",
      "attributes": {
        "name": "",
        "description": "Invalid workspace"
      }
    }
  }' \
  http://localhost:4000/api/workspaces
```

**Response:**
```json
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "name can't be blank",
      "source": {
        "pointer": "/data/attributes/name"
      }
    }
  ]
}
```

### Execution Timeout Error (408)

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "execution_requests",
      "attributes": {
        "code": "sleep(10)",
        "context_id": "EXECUTION_CONTEXT_ID",
        "timeout": 5
      }
    }
  }' \
  http://localhost:4000/api/workspaces/WORKSPACE_ID/execute
```

**Response:**
```json
{
  "errors": [
    {
      "status": "408",
      "title": "Request Timeout",
      "detail": "The request timed out during execution"
    }
  ]
}
```

## Complete Demo Script

Here's a complete bash script that demonstrates the full API workflow:

```bash
#!/bin/bash

# Configuration
API_BASE="http://localhost:4000/api"
API_TOKEN="YOUR_API_TOKEN_HERE"
HEADERS=(-H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/vnd.api+json")

echo "🚀 Kyozo API Demo Starting..."

# 1. Create workspace
echo "📁 Creating workspace..."
WORKSPACE_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" \
  -d '{"data":{"type":"workspaces","attributes":{"name":"API Demo","description":"Demo workspace"}}}' \
  "$API_BASE/workspaces")

WORKSPACE_ID=$(echo "$WORKSPACE_RESPONSE" | jq -r '.data.id')
echo "✅ Workspace created: $WORKSPACE_ID"

# 2. Create execution context
echo "🔧 Creating execution context..."
CONTEXT_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" \
  -d '{"data":{"type":"execution_contexts","attributes":{"name":"Demo Context"}}}' \
  "$API_BASE/workspaces/$WORKSPACE_ID/execution-contexts")

CONTEXT_ID=$(echo "$CONTEXT_RESPONSE" | jq -r '.data.id')
echo "✅ Execution context created: $CONTEXT_ID"

# 3. Execute code
echo "⚡ Executing code..."
EXEC_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" \
  -d "{\"data\":{\"type\":\"execution_requests\",\"attributes\":{\"code\":\"print('Hello from API!')\",\"context_id\":\"$CONTEXT_ID\",\"timeout\":30}}}" \
  "$API_BASE/workspaces/$WORKSPACE_ID/execute")

echo "✅ Code executed successfully"
echo "$EXEC_RESPONSE" | jq '.data.attributes.output'

# 4. Create file
echo "📄 Creating file..."
FILE_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" \
  -d "{\"data\":{\"type\":\"files\",\"attributes\":{\"filename\":\"demo.py\",\"content\":\"print('Demo file')\"},\"relationships\":{\"workspace\":{\"data\":{\"type\":\"workspaces\",\"id\":\"$WORKSPACE_ID\"}}}}}" \
  "$API_BASE/files")

FILE_ID=$(echo "$FILE_RESPONSE" | jq -r '.data.id')
echo "✅ File created: $FILE_ID"

# 5. Get git status
echo "🔄 Getting git status..."
curl -s -X GET "${HEADERS[@]}" "$API_BASE/workspaces/$WORKSPACE_ID/git/status" | jq '.data.attributes'

# 6. Create team
echo "👥 Creating team..."
TEAM_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" \
  -d '{"data":{"type":"teams","attributes":{"title":"Demo Team"}}}' \
  "$API_BASE/teams")

echo "✅ Team created"

# 7. List all resources
echo "📋 Final summary:"
echo "Workspaces:"
curl -s -X GET "${HEADERS[@]}" "$API_BASE/workspaces" | jq '.data[] | {id, name: .attributes.name}'

echo "Teams:"
curl -s -X GET "${HEADERS[@]}" "$API_BASE/teams" | jq '.data[] | {id, title: .attributes.title}'

echo "🎉 Demo completed successfully!"
```

## Notes

- Replace `YOUR_API_TOKEN` with your actual API token
- Replace `WORKSPACE_ID`, `EXECUTION_CONTEXT_ID`, and `FILE_ID` with actual IDs from responses
- The API supports both JSON and JSON:API formats
- All timestamps are in ISO 8601 format (UTC)
- The API uses UUIDs for all resource identifiers
- Mock implementations simulate real behavior for demonstration purposes

This API provides a solid foundation for building workspace management applications with code execution, file management, and collaboration features.
