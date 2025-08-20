#!/usr/bin/env mix run

# Simple MCP API Key Generation Script
# Usage: mix run scripts/generate_mcp_key.exs

IO.puts("🔑 Generating MCP API Key for Kyozo...")

alias Kyozo.Accounts
alias Kyozo.Accounts.{User, ApiKey}

# MCP user credentials
email = "mcp@kyozo.dev"
password = "mcp-secure-password-#{:rand.uniform(9999)}"

IO.puts("📧 Creating MCP user: #{email}")

# Create or find MCP user
user_result =
  case Accounts.get_user_by_email(email) do
    {:ok, user} ->
      IO.puts("✅ Found existing MCP user")
      {:ok, user}

    {:error, _} ->
      IO.puts("🆕 Creating new MCP user...")

      # Try using Ash.create directly
      case Ash.create(User, %{
             email: email,
             password: password,
             password_confirmation: password
           }) do
        {:ok, user} ->
          {:ok, user}

        {:error, _} ->
          # Try alternative creation method
          Accounts.create_user(%{
            email: email,
            password: password,
            password_confirmation: password
          })
      end
  end

case user_result do
  {:ok, user} ->
    IO.puts("✅ User ready: #{user.email}")

    # Generate API key (expires in 1 year)
    expires_at = DateTime.utc_now() |> DateTime.add(365, :day)

    IO.puts("🔐 Generating API key...")

    case Ash.create(ApiKey, %{user_id: user.id, expires_at: expires_at}) do
      {:ok, api_key_record} ->
        # The API key should be in the changeset result
        api_key =
          case api_key_record do
            %{__metadata__: %{api_key: key}} ->
              key

            %{api_key: key} ->
              key

            _ ->
              IO.puts("🔍 API Key record structure:")
              IO.inspect(api_key_record, pretty: true, limit: :infinity)
              "CHECK_OUTPUT_ABOVE"
          end

        IO.puts("")
        IO.puts("🎉 SUCCESS! MCP API Key Generated")
        IO.puts("=" |> String.duplicate(50))
        IO.puts("📋 Connection Details:")
        IO.puts("   Server URL: http://localhost:4000/mcp")
        IO.puts("   API Key: #{api_key}")
        IO.puts("   Header: x-api-key: #{api_key}")
        IO.puts("   Protocol: 2024-11-05")
        IO.puts("")
        IO.puts("🧪 Test Command:")
        IO.puts(~s(curl -X POST http://localhost:4000/mcp \\))
        IO.puts(~s(  -H "Content-Type: application/json" \\))
        IO.puts(~s(  -H "x-api-key: #{api_key}" \\))
        IO.puts(~s(  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'))
        IO.puts("")
        IO.puts("📝 Available Tools:")
        IO.puts("   - read_ash_resource")
        IO.puts("   - create_ash_resource")
        IO.puts("   - update_ash_resource")
        IO.puts("   - list_ash_resources")
        IO.puts("   - read_file")
        IO.puts("   - write_file")
        IO.puts("   - list_directory")
        IO.puts("")

        # Save to file for reference
        config_content = """
        # Kyozo MCP Configuration
        # Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

        MCP_SERVER_URL=http://localhost:4000/mcp
        MCP_API_KEY=#{api_key}
        MCP_PROTOCOL_VERSION=2024-11-05

        # Test command:
        # curl -X POST http://localhost:4000/mcp -H "Content-Type: application/json" -H "x-api-key: #{api_key}" -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
        """

        File.write!("mcp_credentials.txt", config_content)
        IO.puts("💾 Credentials saved to mcp_credentials.txt")

      {:error, changeset} ->
        IO.puts("❌ Failed to generate API key:")
        IO.inspect(changeset.errors, pretty: true)
        System.halt(1)
    end

  {:error, changeset} ->
    IO.puts("❌ Failed to create/find user:")
    IO.inspect(changeset.errors, pretty: true)
    System.halt(1)
end

IO.puts("")
IO.puts("🚀 Next Steps:")
IO.puts("1. Make sure Phoenix server is running: mix phx.server")
IO.puts("2. Test the MCP connection with the curl command above")
IO.puts("3. Configure your Claude client with these credentials")
IO.puts("4. Start debugging efficiently with MCP tools!")
