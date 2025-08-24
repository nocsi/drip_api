# Kyozo API Overview for AI Assistants

## Base URL
- Development: `http://localhost:4000/api/v1`
- Production: `https://api.kyozo.app/api/v1`

## Authentication
All requests require a Bearer token:
```
Authorization: Bearer YOUR_TOKEN_HERE
```

## OpenAPI Specification
Full spec available at: `/api/v1/openapi.json`

## Key Endpoints

### Teams & Workspaces
- `GET /teams` - List user's teams
- `POST /teams` - Create team
- `GET /teams/{team_id}/workspaces` - List workspaces
- `POST /teams/{team_id}/workspaces` - Create workspace

### Files (Markdown Documents)
- `GET /teams/{team_id}/files` - List files
- `POST /teams/{team_id}/files` - Create file
- `GET /teams/{team_id}/files/{id}` - Get file
- `PATCH /teams/{team_id}/files/{id}` - Update file
- `DELETE /teams/{team_id}/files/{id}` - Delete file
- `GET /teams/{team_id}/files/{id}/content` - Get raw content

### Notebooks (Markdown as Executable)
- `POST /teams/{team_id}/files/{file_id}/notebooks` - Open markdown as notebook
- `GET /teams/{team_id}/notebooks/{id}` - Get notebook with tasks
- `POST /teams/{team_id}/notebooks/{id}/execute` - Execute all code blocks
- `POST /teams/{team_id}/notebooks/{id}/execute/{task_id}` - Execute specific task
- `POST /teams/{team_id}/notebooks/{id}/stop` - Stop execution
- `DELETE /teams/{team_id}/notebooks/{id}` - Close notebook

### AI Services
- `POST /ai/suggest` - Get code suggestions
- `POST /ai/confidence` - Analyze code quality

### Virtual File System
- `GET /teams/{team_id}/workspaces/{workspace_id}/storage/vfs` - List with virtual files
- `GET /teams/{team_id}/workspaces/{workspace_id}/storage/vfs/content?path={path}` - Read virtual file

## Key Concepts

1. **Everything is Markdown**: All documents are `.md` files
2. **Notebooks are Optional**: Any markdown can become executable
3. **VFS Generates Docs**: Automatic guides based on project type
4. **No Lock-in**: Files remain standard markdown

## Example: Create & Execute

```bash
# 1. Create markdown with code
POST /teams/{team_id}/files
{
  "name": "analysis.md",
  "content": "# Analysis\n\n```python\nprint('Hello')\n```"
}

# 2. Open as notebook
POST /teams/{team_id}/files/{file_id}/notebooks
{
  "title": "My Analysis"
}

# 3. Execute
POST /teams/{team_id}/notebooks/{notebook_id}/execute
```

## Response Format
```json
{
  "data": {
    // Resource data
  }
}
```

## Error Format
```json
{
  "error": "Error message",
  "details": {}
}
```