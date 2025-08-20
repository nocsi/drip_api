#!/usr/bin/env elixir

# OAuth Verification Script for Kyozo
# This script verifies that OAuth2 configuration is properly set up

Mix.install([
  {:req, "~> 0.3"}
])

defmodule OAuthVerifier do
  @moduledoc """
  Verifies OAuth2 configuration for Kyozo development environment
  """

  def verify_all do
    IO.puts("🔍 Verifying OAuth2 Configuration for Kyozo...")
    IO.puts("=" |> String.duplicate(50))

    results = [
      verify_environment_variables(),
      verify_google_oauth(),
      verify_github_oauth(),
      verify_server_routes(),
      verify_configuration()
    ]

    print_summary(results)
  end

  defp verify_environment_variables do
    IO.puts("\n📋 Checking Environment Variables...")

    required_vars = [
      "GOOGLE_CLIENT_ID",
      "GOOGLE_CLIENT_SECRET",
      "GITHUB_CLIENT_ID",
      "GITHUB_CLIENT_SECRET"
    ]

    results =
      Enum.map(required_vars, fn var ->
        case System.get_env(var) do
          nil ->
            IO.puts("❌ #{var}: Not set")
            {var, :missing}

          "" ->
            IO.puts("⚠️  #{var}: Empty")
            {var, :empty}

          value when byte_size(value) < 10 ->
            IO.puts("⚠️  #{var}: Too short (#{byte_size(value)} chars)")
            {var, :short}

          _value ->
            IO.puts("✅ #{var}: Set")
            {var, :ok}
        end
      end)

    case Enum.all?(results, fn {_, status} -> status == :ok end) do
      true -> {:env_vars, :pass}
      false -> {:env_vars, :fail}
    end
  end

  defp verify_google_oauth do
    IO.puts("\n🔍 Testing Google OAuth2 Configuration...")

    case {System.get_env("GOOGLE_CLIENT_ID"), System.get_env("GOOGLE_CLIENT_SECRET")} do
      {nil, _} ->
        IO.puts("❌ Google Client ID not set")
        {:google, :fail}

      {_, nil} ->
        IO.puts("❌ Google Client Secret not set")
        {:google, :fail}

      {client_id, _client_secret} ->
        # Test if we can construct a valid OAuth URL
        oauth_url = build_google_oauth_url(client_id)
        IO.puts("✅ Google OAuth URL: #{String.slice(oauth_url, 0, 80)}...")

        # Test if the client ID looks valid
        if String.contains?(client_id, ".apps.googleusercontent.com") do
          IO.puts("✅ Google Client ID format looks correct")
          {:google, :pass}
        else
          IO.puts("⚠️  Google Client ID format may be incorrect")
          {:google, :warning}
        end
    end
  end

  defp verify_github_oauth do
    IO.puts("\n🔍 Testing GitHub OAuth2 Configuration...")

    case {System.get_env("GITHUB_CLIENT_ID"), System.get_env("GITHUB_CLIENT_SECRET")} do
      {nil, _} ->
        IO.puts("❌ GitHub Client ID not set")
        {:github, :fail}

      {_, nil} ->
        IO.puts("❌ GitHub Client Secret not set")
        {:github, :fail}

      {client_id, _client_secret} ->
        # Test if we can construct a valid OAuth URL
        oauth_url = build_github_oauth_url(client_id)
        IO.puts("✅ GitHub OAuth URL: #{String.slice(oauth_url, 0, 80)}...")

        # GitHub client IDs are typically hex strings
        if String.match?(client_id, ~r/^[a-fA-F0-9]+$/) and String.length(client_id) >= 16 do
          IO.puts("✅ GitHub Client ID format looks correct")
          {:github, :pass}
        else
          IO.puts("⚠️  GitHub Client ID format may be incorrect")
          {:github, :warning}
        end
    end
  end

  defp verify_server_routes do
    IO.puts("\n🌐 Testing Server Routes...")

    test_urls = [
      "http://localhost:4000/auth/google",
      "http://localhost:4000/auth/github",
      "http://localhost:4000/auth/google/callback",
      "http://localhost:4000/auth/github/callback"
    ]

    # Only test if server appears to be running
    case test_server_health() do
      :running ->
        IO.puts("✅ Server is running on localhost:4000")

        results =
          Enum.map(test_urls, fn url ->
            case make_request(url) do
              {:ok, status} when status in [302, 200] ->
                IO.puts("✅ #{url} - Status: #{status}")
                :ok

              {:ok, status} ->
                IO.puts("⚠️  #{url} - Status: #{status}")
                :warning

              {:error, reason} ->
                IO.puts("❌ #{url} - Error: #{reason}")
                :error
            end
          end)

        case Enum.all?(results, fn status -> status in [:ok, :warning] end) do
          true -> {:routes, :pass}
          false -> {:routes, :fail}
        end

      :not_running ->
        IO.puts("⚠️  Server not running on localhost:4000")
        IO.puts("   Start server with: mix phx.server")
        {:routes, :skip}
    end
  end

  defp verify_configuration do
    IO.puts("\n⚙️  Checking Configuration Files...")

    config_checks = [
      check_dev_config(),
      check_secrets_module(),
      check_user_resource()
    ]

    case Enum.all?(config_checks, & &1) do
      true -> {:config, :pass}
      false -> {:config, :fail}
    end
  end

  defp test_server_health do
    case make_request("http://localhost:4000") do
      {:ok, _} -> :running
      {:error, _} -> :not_running
    end
  end

  defp make_request(url) do
    try do
      response = Req.get!(url, redirect: false, max_redirects: 0)
      {:ok, response.status}
    rescue
      _ -> {:error, "Connection failed"}
    end
  end

  defp build_google_oauth_url(client_id) do
    params =
      URI.encode_query(%{
        "client_id" => client_id,
        "redirect_uri" => "http://localhost:4000/auth/google/callback",
        "response_type" => "code",
        "scope" => "openid email profile"
      })

    "https://accounts.google.com/o/oauth2/v2/auth?" <> params
  end

  defp build_github_oauth_url(client_id) do
    params =
      URI.encode_query(%{
        "client_id" => client_id,
        "redirect_uri" => "http://localhost:4000/auth/github/callback",
        "scope" => "user:email"
      })

    "https://github.com/login/oauth/authorize?" <> params
  end

  defp check_dev_config do
    config_path = "config/dev.exs"

    if File.exists?(config_path) do
      content = File.read!(config_path)

      oauth_configs = [
        "google_client_id",
        "google_client_secret",
        "github_client_id",
        "github_client_secret"
      ]

      has_oauth_config =
        Enum.any?(oauth_configs, fn config ->
          String.contains?(content, config)
        end)

      if has_oauth_config do
        IO.puts("✅ OAuth configuration found in config/dev.exs")
        true
      else
        IO.puts("⚠️  OAuth configuration not found in config/dev.exs")
        false
      end
    else
      IO.puts("❌ config/dev.exs not found")
      false
    end
  end

  defp check_secrets_module do
    secrets_path = "lib/kyozo/secrets.ex"

    if File.exists?(secrets_path) do
      content = File.read!(secrets_path)

      if String.contains?(content, "google") and String.contains?(content, "github") do
        IO.puts("✅ Secrets module configured for OAuth")
        true
      else
        IO.puts("⚠️  Secrets module missing OAuth configuration")
        false
      end
    else
      IO.puts("❌ lib/kyozo/secrets.ex not found")
      false
    end
  end

  defp check_user_resource do
    user_path = "lib/kyozo/accounts/user.ex"

    if File.exists?(user_path) do
      content = File.read!(user_path)

      has_oauth =
        String.contains?(content, "oauth2 :google") or String.contains?(content, "oauth2 :github")

      if has_oauth do
        IO.puts("✅ User resource has OAuth strategies configured")
        true
      else
        IO.puts("⚠️  User resource missing OAuth strategies")
        false
      end
    else
      IO.puts("❌ lib/kyozo/accounts/user.ex not found")
      false
    end
  end

  defp print_summary(results) do
    IO.puts("\n" <> ("=" |> String.duplicate(50)))
    IO.puts("📊 OAUTH VERIFICATION SUMMARY")
    IO.puts("=" |> String.duplicate(50))

    {passes, fails, warnings, skips} =
      Enum.reduce(results, {0, 0, 0, 0}, fn
        {_, :pass}, {p, f, w, s} -> {p + 1, f, w, s}
        {_, :fail}, {p, f, w, s} -> {p, f + 1, w, s}
        {_, :warning}, {p, f, w, s} -> {p, f, w + 1, s}
        {_, :skip}, {p, f, w, s} -> {p, f, w, s + 1}
      end)

    IO.puts("✅ Passed: #{passes}")
    IO.puts("❌ Failed: #{fails}")
    IO.puts("⚠️  Warnings: #{warnings}")
    IO.puts("⏭️  Skipped: #{skips}")

    cond do
      fails > 0 ->
        IO.puts("\n🚨 OAuth configuration has issues that need to be fixed.")
        print_next_steps()

      warnings > 0 ->
        IO.puts("\n⚠️  OAuth configuration is mostly ready but has some warnings.")
        print_next_steps()

      true ->
        IO.puts("\n🎉 OAuth configuration looks good!")
        IO.puts("🚀 Ready to test OAuth flows in your browser.")
    end

    IO.puts("\n" <> ("=" |> String.duplicate(50)))
  end

  defp print_next_steps do
    IO.puts("\n📋 Next Steps:")
    IO.puts("1. Set missing environment variables in .env file")
    IO.puts("2. Start server: mix phx.server")
    IO.puts("3. Visit: http://localhost:4000")
    IO.puts("4. Test OAuth buttons in sign-in flow")
    IO.puts("5. Check server logs for any errors")
    IO.puts("\n📖 See: priv/repo/oauth_setup_guide.md for detailed setup")
  end
end

# Run verification
OAuthVerifier.verify_all()
