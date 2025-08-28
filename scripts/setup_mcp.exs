# MCP Setup Script for Kyozo API
# Run with: mix run scripts/setup_mcp.exs

alias Dirup.Accounts
alias Dirup.Accounts.{User, ApiKey}

IO.puts("🔧 Setting up MCP connection for Kyozo API...")

# Create or find a user for MCP access
email = "mcp-user@kyozo.dev"

user =
  case Accounts.get_user_by_email(email) do
    {:ok, user} ->
      IO.puts("✅ Found existing MCP user: #{email}")
      user

    {:error, _} ->
      IO.puts("🆕 Creating new MCP user...")

      user_params = %{
        email: email,
        password: "mcp-secure-password-123",
        password_confirmation: "mcp-secure-password-123"
      }

      case Accounts.create_user(user_params) do
        {:ok, user} ->
          IO.puts("✅ Created MCP user: #{email}")
          user

        {:error, changeset} ->
          IO.puts("❌ Failed to create user:")
          IO.inspect(changeset.errors)
          System.halt(1)
      end
  end

# Generate an API key for MCP access
IO.puts("🔑 Generating API key...")

# Set expiration to 1 year from now
expires_at = DateTime.utc_now() |> DateTime.add(365, :day)

case Ash.create(ApiKey, %{user_id: user.id, expires_at: expires_at}) do
  {:ok, api_key_record} ->
    api_key = api_key_record.api_key
    IO.puts("✅ API Key generated successfully!")
    IO.puts("")
    IO.puts("📋 MCP Connection Details:")
    IO.puts("  Server URL: http://localhost:4000/mcp")
    IO.puts("  Protocol Version: 2024-11-05")
    IO.puts("  API Key: #{api_key}")
    IO.puts("  Header: x-api-key: #{api_key}")
    IO.puts("")

    # Test basic MCP endpoint accessibility
    IO.puts("🧪 Testing MCP endpoint...")

    # Create a basic curl test
    curl_command = """
    curl -X POST http://localhost:4000/mcp \\
      -H "Content-Type: application/json" \\
      -H "x-api-key: #{api_key}" \\
      -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
    """

    IO.puts("Test command:")
    IO.puts(curl_command)
    IO.puts("")

    # Save connection details to a file
    config_content = """
    # Kyozo MCP Connection Configuration
    # Generated on #{DateTime.utc_now() |> DateTime.to_iso8601()}

    MCP_SERVER_URL=http://localhost:4000/mcp
    MCP_API_KEY=#{api_key}
    MCP_PROTOCOL_VERSION=2024-11-05

    # For Claude Desktop MCP Configuration:
    # Add to your Claude Desktop settings.json:
    {
      "mcpServers": {
        "kyozo": {
          "command": "curl",
          "args": [
            "-X", "POST",
            "http://localhost:4000/mcp",
            "-H", "Content-Type: application/json",
            "-H", "x-api-key: #{api_key}",
            "-d", "@-"
          ]
        }
      }
    }
    """

    File.write!("mcp_config.txt", config_content)
    IO.puts("💾 Connection details saved to mcp_config.txt")
    IO.puts("")

    IO.puts("🚀 Next Steps:")
    IO.puts("1. Start your Phoenix server: mix phx.server")
    IO.puts("2. Test the MCP endpoint with the curl command above")
    IO.puts("3. Configure your Claude client with the connection details")

    IO.puts(
      "4. Available MCP tools: :read_ash_resource, :create_ash_resource, :update_ash_resource, :list_ash_resources, :read_file, :write_file, :list_directory"
    )

  {:error, changeset} ->
    IO.puts("❌ Failed to generate API key:")
    IO.inspect(changeset.errors)
    System.halt(1)
end

IO.puts("")
IO.puts("🎉 MCP setup complete!")
