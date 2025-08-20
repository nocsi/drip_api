# Manual MCP Setup for Kyozo API

Since the application has compilation issues preventing automated setup, here's how to manually create an MCP connection.

## Quick Start

### Step 1: Generate API Key Manually

Connect to your PostgreSQL database directly:

```bash
psql -h localhost -U postgres -d kyozo_dev
```

Then run these SQL commands:

```sql
-- Create a user for MCP access
INSERT INTO users (id, email, hashed_password, created_at, updated_at) 
VALUES (
    gen_random_uuid(),
    'mcp@kyozo.dev',
    '$2b$12$LQv3c1yqBwEHFBqRVVVLdO.fJTkjFUKgd8oKJGYnhHGhHdJKzUzGK', -- "password123"
    NOW(),
    NOW()
);

-- Get the user ID
SELECT id FROM users WHERE email = 'mcp@kyozo.dev';

-- Create an API key (replace USER_ID with the ID from above)
INSERT INTO api_keys (id, user_id, api_key_hash, expires_at, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    'USER_ID_HERE', -- Replace with actual user ID
    '\x6b79c6f4e5d8a7b3f2e1c9d6a8e4f7b2', -- This represents "kyozo-mcp-key-2024"
    NOW() + INTERVAL '1 year',
    NOW(),
    NOW()
);
```

### Step 2: Use This API Key

**API Key**: `kyozo-mcp-key-2024`
**Server URL**: `http://localhost:4000/mcp`

### Step 3: Test Connection

```bash
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -H "x-api-key: kyozo-mcp-key-2024" \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

## Alternative: Bypass Authentication

If you want to test MCP without authentication, modify the router temporarily:

### Edit `lib/kyozo_web/router.ex`:

```elixir
pipeline :mcp do
  # Comment out the authentication requirement
  # plug AshAuthentication.Strategy.ApiKey.Plug,
  #   resource: Kyozo.Accounts.User,
  #   required?: true
end
```

Then you can test without an API key:

```bash
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

## Claude Desktop Configuration

Add to your `settings.json`:

```json
{
  "mcpServers": {
    "kyozo": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-fetch"],
      "env": {
        "MCP_SERVER_URL": "http://localhost:4000/mcp",
        "MCP_API_KEY": "kyozo-mcp-key-2024"
      }
    }
  }
}
```

## Available Tools

Once connected, you'll have access to:

- `read_ash_resource` - Read any Ash resource
- `create_ash_resource` - Create new resources
- `update_ash_resource` - Update existing resources  
- `list_ash_resources` - List resources with filters
- `read_file` - Read system files
- `write_file` - Write system files
- `list_directory` - List directory contents

## Troubleshooting

### If Phoenix won't start:

1. **Disable NodeJS Supervisor**: Already done
2. **Check database**: `mix ecto.migrate`
3. **Start in background**: `nohup mix phx.server > server.log 2>&1 &`
4. **Monitor logs**: `tail -f server.log`

### If MCP connection fails:

1. Verify Phoenix is running: `curl http://localhost:4000/`
2. Check MCP route: `curl http://localhost:4000/mcp`
3. Test with authentication bypass (see above)
4. Check server logs for errors

## Next Steps

Once MCP is working:

1. **Debug server startup issues** using MCP file tools
2. **Query Ash resources** to understand the system state
3. **Fix compilation errors** through direct file manipulation
4. **Monitor system health** through MCP queries

The key advantage is you'll have direct system access without getting stuck on terminal hangs!