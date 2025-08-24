# Kyozo API Documentation

## Overview

Kyozo provides a comprehensive REST API for managing workspaces, files, notebooks, and AI services.

## Quick Start

### 1. Get your API Token
```bash
# Login to get an API token
curl -X POST http://localhost:4000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "your@email.com", "password": "yourpassword"}'
```

### 2. Use the Token
Include the token in all API requests:
```bash
curl http://localhost:4000/api/v1/teams \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## API Documentation

### Interactive Documentation
Visit the Swagger UI at: http://localhost:4000/api/v1/docs

### OpenAPI Specification
Download the OpenAPI 3.0 spec: http://localhost:4000/api/v1/openapi.json

## Key Concepts

### Markdown as Notebooks
In Kyozo, all documents are markdown files. Any markdown file can be opened as a notebook for code execution:

1. Create a markdown file with code blocks
2. Open it as a notebook using the notebook API
3. Execute code blocks individually or all at once

### Virtual File System (VFS)
The VFS automatically generates helpful documentation based on your project:
- `guide.md` - Project-specific guides
- `deploy.md` - Deployment instructions
- `overview.md` - Workspace overview

## Common Workflows

### Create and Execute a Notebook

```bash
# 1. Create a markdown file
curl -X POST http://localhost:4000/api/v1/teams/{team_id}/files \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "analysis.md",
    "content": "# Data Analysis\n\n```python\nimport pandas as pd\nprint(\"Hello World\")\n```"
  }'

# 2. Open as notebook (returns notebook_id)
curl -X POST http://localhost:4000/api/v1/teams/{team_id}/files/{file_id}/notebooks \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "My Analysis"}'

# 3. Execute all code blocks
curl -X POST http://localhost:4000/api/v1/teams/{team_id}/notebooks/{notebook_id}/execute \
  -H "Authorization: Bearer $TOKEN"
```

### Use AI Services

```bash
# Get code suggestions
curl -X POST http://localhost:4000/api/v1/ai/suggest \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "def calculate_total(items):",
    "context": "python_function"
  }'

# Analyze code confidence
curl -X POST http://localhost:4000/api/v1/ai/confidence \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "def sum(a, b):\n    return a + b",
    "language": "python"
  }'
```

### Browse Virtual Files

```bash
# List files including virtual ones
curl http://localhost:4000/api/v1/teams/{team_id}/workspaces/{workspace_id}/storage/vfs \
  -H "Authorization: Bearer $TOKEN"

# Read a virtual file
curl "http://localhost:4000/api/v1/teams/{team_id}/workspaces/{workspace_id}/storage/vfs/content?path=guide.md" \
  -H "Authorization: Bearer $TOKEN"
```

## Rate Limiting

- 100 requests per minute per user
- 429 status code when exceeded
- `X-RateLimit-*` headers provided

## Error Handling

All errors follow this format:
```json
{
  "error": "Error message",
  "details": {
    "field": "Additional context"
  }
}
```

Common status codes:
- `200` - Success
- `201` - Created
- `204` - No Content (delete success)
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Too Many Requests
- `500` - Internal Server Error

## SDK Support

### JavaScript/TypeScript
```typescript
import { KyozoClient } from '@kyozo/sdk';

const client = new KyozoClient({
  apiKey: 'YOUR_API_KEY',
  baseUrl: 'http://localhost:4000/api/v1'
});

// Create a file
const file = await client.files.create({
  name: 'test.md',
  content: '# Hello World'
});

// Open as notebook
const notebook = await client.notebooks.createFromFile(file.id);

// Execute
await client.notebooks.execute(notebook.id);
```

### Python
```python
from kyozo import Client

client = Client(
    api_key="YOUR_API_KEY",
    base_url="http://localhost:4000/api/v1"
)

# Create a file
file = client.files.create(
    name="test.md",
    content="# Hello World\n\n```python\nprint('Hello')\n```"
)

# Open as notebook and execute
notebook = client.notebooks.create_from_file(file.id)
result = client.notebooks.execute(notebook.id)
```

## Support

- GitHub Issues: https://github.com/kyozo/kyozo/issues
- Discord: https://discord.gg/kyozo
- Email: support@kyozo.app