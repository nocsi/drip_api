#!/usr/bin/env elixir

# Authentication Verification Script for Kyozo
# This script verifies that authentication is properly set up and working

Mix.install([])

defmodule AuthVerifier do
  @moduledoc """
  Verifies authentication configuration for Kyozo development environment
  """

  def verify_all do
    IO.puts("🔍 Verifying Authentication Configuration for Kyozo...")
    IO.puts("=" |> String.duplicate(60))

    results = [
      verify_user_resource(),
      verify_secrets_module(),
      verify_router_configuration(),
      verify_email_senders(),
      verify_database_setup(),
      verify_development_seeds()
    ]

    print_summary(results)
  end

  defp verify_user_resource do
    IO.puts("\n📋 Checking User Resource...")

    user_path = "lib/kyozo/accounts/user.ex"

    if File.exists?(user_path) do
      content = File.read!(user_path)

      checks = [
        {"Password Strategy", String.contains?(content, "password :password")},
        {"OAuth2 Google", String.contains?(content, "oauth2 :google")},
        {"OAuth2 GitHub", String.contains?(content, "oauth2 :github")},
        {"Magic Link", String.contains?(content, "magic_link :magic_link")},
        {"API Key Strategy", String.contains?(content, "api_key :api_key")},
        {"Email Confirmation", String.contains?(content, "confirmation :confirm_new_user")},
        {"Password Reset", String.contains?(content, "resettable do")},
        {"Register Action", String.contains?(content, "register_with_password")},
        {"Google Register", String.contains?(content, "register_with_google")},
        {"GitHub Register", String.contains?(content, "register_with_github")}
      ]

      results =
        Enum.map(checks, fn {name, passed} ->
          status = if passed, do: "✅", else: "❌"
          IO.puts("   #{status} #{name}")
          passed
        end)

      case Enum.all?(results) do
        true -> {:user_resource, :pass}
        false -> {:user_resource, :fail}
      end
    else
      IO.puts("❌ User resource not found at #{user_path}")
      {:user_resource, :fail}
    end
  end

  defp verify_secrets_module do
    IO.puts("\n🔐 Checking Secrets Module...")

    secrets_path = "lib/kyozo/secrets.ex"

    if File.exists?(secrets_path) do
      content = File.read!(secrets_path)

      checks = [
        {"Token Signing", String.contains?(content, "token_signing_secret")},
        {"Google OAuth", String.contains?(content, "google_client_id")},
        {"GitHub OAuth", String.contains?(content, "github_client_id")},
        {"Environment Variables", String.contains?(content, "Application.fetch_env")}
      ]

      results =
        Enum.map(checks, fn {name, passed} ->
          status = if passed, do: "✅", else: "❌"
          IO.puts("   #{status} #{name}")
          passed
        end)

      case Enum.all?(results) do
        true -> {:secrets, :pass}
        false -> {:secrets, :fail}
      end
    else
      IO.puts("❌ Secrets module not found at #{secrets_path}")
      {:secrets, :fail}
    end
  end

  defp verify_router_configuration do
    IO.puts("\n🌐 Checking Router Configuration...")

    router_path = "lib/kyozo_web/router.ex"

    if File.exists?(router_path) do
      content = File.read!(router_path)

      checks = [
        {"AshAuthentication Router",
         String.contains?(content, "use AshAuthentication.Phoenix.Router")},
        {"Auth Routes", String.contains?(content, "auth_routes AuthController")},
        {"Sign In Route", String.contains?(content, "sign_in_route")},
        {"Password Reset", String.contains?(content, "reset_route")},
        {"Email Confirmation", String.contains?(content, "confirm_route")},
        {"Magic Link", String.contains?(content, "magic_sign_in_route")},
        {"OAuth Google",
         String.contains?(content, "oauth_sign_in_route(Kyozo.Accounts.User, :google")},
        {"OAuth GitHub",
         String.contains?(content, "oauth_sign_in_route(Kyozo.Accounts.User, :github")},
        {"Sign Out", String.contains?(content, "sign_out_route")}
      ]

      results =
        Enum.map(checks, fn {name, passed} ->
          status = if passed, do: "✅", else: "❌"
          IO.puts("   #{status} #{name}")
          passed
        end)

      case Enum.count(results, & &1) >= 7 do
        true -> {:router, :pass}
        false -> {:router, :fail}
      end
    else
      IO.puts("❌ Router not found at #{router_path}")
      {:router, :fail}
    end
  end

  defp verify_email_senders do
    IO.puts("\n📧 Checking Email Senders...")

    senders_path = "lib/kyozo/accounts/user/senders"

    if File.dir?(senders_path) do
      files = File.ls!(senders_path)

      expected_senders = [
        "send_magic_link_email.ex",
        "send_new_user_confirmation_email.ex",
        "send_password_reset_email.ex"
      ]

      results =
        Enum.map(expected_senders, fn sender ->
          exists = sender in files
          status = if exists, do: "✅", else: "❌"
          IO.puts("   #{status} #{sender}")
          exists
        end)

      # Check emails module
      emails_exists = File.exists?("lib/kyozo/accounts/emails.ex")
      emails_status = if emails_exists, do: "✅", else: "❌"
      IO.puts("   #{emails_status} emails.ex")

      case Enum.all?(results) && emails_exists do
        true -> {:email_senders, :pass}
        false -> {:email_senders, :fail}
      end
    else
      IO.puts("❌ Email senders directory not found")
      {:email_senders, :fail}
    end
  end

  defp verify_database_setup do
    IO.puts("\n💾 Checking Database Setup...")

    # Check for migration files
    migrations_path = "priv/repo/migrations"

    if File.dir?(migrations_path) do
      migrations = File.ls!(migrations_path)

      user_migration = Enum.any?(migrations, &String.contains?(&1, "users"))
      tokens_migration = Enum.any?(migrations, &String.contains?(&1, "tokens"))

      IO.puts("   #{if user_migration, do: "✅", else: "❌"} User migration exists")
      IO.puts("   #{if tokens_migration, do: "✅", else: "❌"} Token migration exists")

      case user_migration && tokens_migration do
        true -> {:database, :pass}
        false -> {:database, :warning}
      end
    else
      IO.puts("❌ Migrations directory not found")
      {:database, :fail}
    end
  end

  defp verify_development_seeds do
    IO.puts("\n🌱 Checking Development Seeds...")

    seed_files = [
      {"Production Seeds", "priv/repo/seeds.exs"},
      {"Development Seeds", "priv/repo/dev_seeds.exs"},
      {"Seeder Module", "lib/kyozo/seeder.ex"}
    ]

    results =
      Enum.map(seed_files, fn {name, path} ->
        exists = File.exists?(path)
        status = if exists, do: "✅", else: "❌"
        IO.puts("   #{status} #{name}")
        exists
      end)

    # Check if seeder has admin creation
    if File.exists?("lib/kyozo/seeder.ex") do
      content = File.read!("lib/kyozo/seeder.ex")
      has_admin = String.contains?(content, "seed_dev_admin")
      admin_status = if has_admin, do: "✅", else: "❌"
      IO.puts("   #{admin_status} Admin user seeding")
    end

    case Enum.count(results, & &1) >= 2 do
      true -> {:seeds, :pass}
      false -> {:seeds, :fail}
    end
  end

  defp print_summary(results) do
    IO.puts("\n" <> ("=" |> String.duplicate(60)))
    IO.puts("📊 AUTHENTICATION VERIFICATION SUMMARY")
    IO.puts("=" |> String.duplicate(60))

    {passes, fails, warnings} =
      Enum.reduce(results, {0, 0, 0}, fn
        {_, :pass}, {p, f, w} -> {p + 1, f, w}
        {_, :fail}, {p, f, w} -> {p, f + 1, w}
        {_, :warning}, {p, f, w} -> {p, f, w + 1}
      end)

    IO.puts("✅ Passed: #{passes}")
    IO.puts("❌ Failed: #{fails}")
    IO.puts("⚠️  Warnings: #{warnings}")

    cond do
      fails > 0 ->
        IO.puts("\n🚨 Authentication setup has critical issues that need fixing.")
        print_next_steps()

      warnings > 0 ->
        IO.puts("\n⚠️  Authentication setup is mostly ready but has some warnings.")
        print_quick_start()

      true ->
        IO.puts("\n🎉 Authentication configuration looks excellent!")
        print_quick_start()
    end

    print_testing_info()
    IO.puts("\n" <> ("=" |> String.duplicate(60)))
  end

  defp print_next_steps do
    IO.puts("\n📋 Next Steps to Fix Issues:")
    IO.puts("1. Run: mix ash.codegen to generate missing migrations")
    IO.puts("2. Run: mix ecto.setup to set up the database")
    IO.puts("3. Check User resource authentication configuration")
    IO.puts("4. Verify router OAuth routes are enabled")
    IO.puts("5. Ensure all email sender modules exist")
  end

  defp print_quick_start do
    IO.puts("\n🚀 Quick Start Guide:")
    IO.puts("1. Set up database: mix ecto.setup")
    IO.puts("2. Create admin user: mix run priv/repo/dev_seeds.exs")
    IO.puts("3. Start server: mix phx.server")
    IO.puts("4. Visit: http://localhost:4000/auth/test")
  end

  defp print_testing_info do
    IO.puts("\n🧪 Authentication Testing:")
    IO.puts("📝 Test Page: http://localhost:4000/auth/test")
    IO.puts("🔐 Sign In: http://localhost:4000/auth/sign_in")
    IO.puts("📝 Register: http://localhost:4000/auth/register")
    IO.puts("")
    IO.puts("👤 Development Admin Credentials:")
    IO.puts("   📧 Email: admin@kyozo.dev")
    IO.puts("   🔒 Password: devpassword123")
    IO.puts("   👑 Role: admin")
    IO.puts("")
    IO.puts("🔗 OAuth Testing (requires credentials):")
    IO.puts("   🔵 Google: http://localhost:4000/auth/google")
    IO.puts("   🐙 GitHub: http://localhost:4000/auth/github")
  end
end

# Run verification
AuthVerifier.verify_all()
