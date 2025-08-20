# MCP Connection Guide for Kyozo API

This guide helps you connect Claude to the Kyozo API via MCP (Model Context Protocol) for efficient debugging and development.

## Overview

The Kyozo API has AshAi.Mcp configured to provide MCP tools for interacting with the system without burning tokens on hanging terminal processes.

## MCP Endpoints

- **Primary MCP**: `http://localhost:4000/mcp`
- **Dev MCP**: `http://localhost:4000/ash_ai/mcp`
- **Protocol Version**: `2024-11-05`

## Available Tools

```elixir
:read_ash_resource    # Read any Ash resource
:create_ash_resource  # Create new Ash resources  
:update_ash_resource  # Update existing Ash resources
:list_ash_resources   # List resources with filters
:read_file           # Read files from the system
:write_file          # Write files to the system
:list_directory      # List directory contents
```

## Authentication Setup

The MCP endpoints require API key authentication via the `x-api-key` header.

### Step 1: Generate API Key

Start an IEx session and create an API key:

```bash
iex -S mix
```

```elixir
# Create MCP user
user_params = %{
  email: "mcp@kyozo.dev",
  password: "secure-mcp-password",
  password_confirmation: "secure-mcp-password"
}

{:ok, user} = Kyozo.Accounts.create_user(user_params)

# Generate API key (expires in 1 year)
expires_at = DateTime.utc_now() |> DateTime.add(365, :day)
{:ok, api_key_record} = Ash.create(Kyozo.Accounts.ApiKey, %{
  user_id: user.id, 
  expires_at: expires_at
})

# The API key will be returned in the changeset metadata
IO.inspect(api_key_record)
```

### Step 2: Test MCP Connection

Once you have the API key, test the connection:

```bash
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY_HERE" \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

## Claude Desktop Configuration

Add to your Claude Desktop `settings.json`:

```json
{
  "mcpServers": {
    "kyozo": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "http://localhost:4000/mcp",
        "-H", "Content-Type: application/json",
        "-H", "x-api-key: YOUR_API_KEY_HERE",
        "-d", "@-"
      ]
    }
  }
}
```

## Usage Examples

Once connected, you can use MCP tools to:

```
# Read Ash resources
read_ash_resource(resource: "Kyozo.Accounts.User", id: "user-id")

# List workspaces
list_ash_resources(resource: "Kyozo.Workspaces.Workspace", filters: %{})

# Read application files
read_file(path: "lib/kyozo/application.ex")

# Debug server startup issues
list_directory(path: "lib/kyozo")
```

## Troubleshooting

### Server Won't Start
If Phoenix hangs during startup:

1. **Check logs**: `tail -f server.log`
2. **Use MCP**: Connect via MCP to debug without hanging terminals
3. **Disable components**: Comment out problematic supervisors in `application.ex`

### Authentication Issues
- Verify API key is correct
- Check `x-api-key` header format
- Ensure user has valid API key relationship

### MCP Connection Fails
- Confirm Phoenix server is running
- Test basic HTTP connectivity: `curl http://localhost:4000/`
- Check MCP route is accessible: `curl http://localhost:4000/mcp`

## Benefits

✅ **No hanging terminals** - Debug via MCP tools instead of terminal commands
✅ **Direct system access** - Read files, query resources, modify data
✅ **Efficient debugging** - No token waste on stuck processes
✅ **Real-time interaction** - Live system manipulation and monitoring

## Next Steps

1. Generate your API key using the IEx commands above
2. Test the MCP connection with curl
3. Configure your Claude client
4. Start debugging the server startup issues efficiently via MCP!

The key advantage is that once MCP is working, you can debug the hanging server issue without wasting tokens on terminal timeouts.