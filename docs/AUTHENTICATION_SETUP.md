# Kyozo Authentication System Implementation Guide

This guide provides a complete implementation of authentication for the Kyozo application using AshAuthentication and AshAuthenticationPhoenix with support for:
- Password-based authentication
- Magic Link authentication
- OAuth2 (Apple & Google)
- Development admin user
- LiveSvelte integration

## Overview

The authentication system is built on top of:
- **AshAuthentication**: Core authentication framework
- **AshAuthenticationPhoenix**: Phoenix integration
- **LiveSvelte**: Frontend components
- **Assent**: OAuth2 provider support

## Current Status

### ✅ Implemented
- Password authentication strategy
- Magic Link authentication strategy
- API Key authentication strategy
- Email confirmation system
- Password reset functionality
- LiveView authentication pages
- Svelte authentication components
- User policies and authorization
- Token management

### 🚧 In Progress
- OAuth2 strategies (Apple & Google)
- Development admin user seeding
- Complete LiveSvelte integration

### ❌ Pending
- Production OAuth2 configuration
- Email templates customization
- Advanced security features

## Implementation Steps

### Step 1: Fix OAuth2 Strategy Configuration

The current OAuth2 implementation has configuration issues. Here's the corrected approach:

#### 1.1 Update User Resource

```elixir
# lib/kyozo/accounts/user.ex
defmodule Kyozo.Accounts.User do
  use Ash.Resource,
    # ... existing configuration

  authentication do
    # ... existing strategies

    strategies do
      # ... existing strategies

      # Apple OAuth2 Strategy
      oauth2 :apple do
        client_id fn _, _ ->
          System.get_env("APPLE_CLIENT_ID") ||
          Application.get_env(:kyozo, :apple_client_id)
        end

        client_secret fn _, _ ->
          System.get_env("APPLE_CLIENT_SECRET") ||
          Application.get_env(:kyozo, :apple_client_secret)
        end

        base_url "https://appleid.apple.com"
        authorize_url "https://appleid.apple.com/auth/authorize"
        token_url "https://appleid.apple.com/auth/token"
        user_url "https://appleid.apple.com/auth/userinfo"

        redirect_uri fn _, _ ->
          System.get_env("APPLE_REDIRECT_URI") ||
          "http://localhost:4000/auth/apple/callback"
        end

        registration_enabled? true
        sign_in_enabled? true
      end

      # Google OAuth2 Strategy
      oauth2 :google do
        client_id fn _, _ ->
          System.get_env("GOOGLE_CLIENT_ID") ||
          Application.get_env(:kyozo, :google_client_id)
        end

        client_secret fn _, _ ->
          System.get_env("GOOGLE_CLIENT_SECRET") ||
          Application.get_env(:kyozo, :google_client_secret)
        end

        base_url "https://accounts.google.com"
        authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
        token_url "https://oauth2.googleapis.com/token"
        user_url "https://www.googleapis.com/oauth2/v2/userinfo"

        redirect_uri fn _, _ ->
          System.get_env("GOOGLE_REDIRECT_URI") ||
          "http://localhost:4000/auth/google/callback"
        end

        registration_enabled? true
        sign_in_enabled? true
      end
    end
  end

  # ... rest of resource
end
```

#### 1.2 Add OAuth2 Identity Functions

```elixir
# Add to user.ex after identities block
def oauth2_identity(user_info, _oauth_tokens, _context) do
  case user_info do
    %{"email" => email} when is_binary(email) ->
      {:ok, %{email: String.downcase(email)}}
    %{email: email} when is_binary(email) ->
      {:ok, %{email: String.downcase(email)}}
    _ ->
      {:error, "No email found in OAuth2 user info"}
  end
end

def oauth2_update(user, user_info, _oauth_tokens, _context) do
  # Optionally update user with additional OAuth2 info
  {:ok, user}
end
```

### Step 2: Configure Router

#### 2.1 Update Router for OAuth2

```elixir
# lib/kyozo_web/router.ex
defmodule KyozoWeb.Router do
  use KyozoWeb, :router
  use AshAuthentication.Phoenix.Router

  # ... existing pipelines

  scope "/", KyozoWeb do
    pipe_through :browser

    # Existing auth routes
    auth_routes AuthController, Kyozo.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{KyozoWeb.LiveUserAuth, :live_no_user}],
                  overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    reset_route auth_routes_prefix: "/auth",
                overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    confirm_route Kyozo.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    magic_sign_in_route(Kyozo.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    # OAuth2 routes
    oauth_sign_in_route(Kyozo.Accounts.User, :apple,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    oauth_sign_in_route(Kyozo.Accounts.User, :google,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    # Application routes
    live "/", Live.Landing
    live "/home", Live.Home
    live "/editor", Live.Editor
    live "/auth/test", Live.AuthTestLive  # Dev testing page

    # Custom authentication pages (using Svelte)
    live "/auth/sign_in", Live.Auth.SignInLive
    live "/auth/register", Live.Auth.RegisterLive
  end
end
```

### Step 3: Create Development Admin User

#### 3.1 Update Seeder

```elixir
# lib/kyozo/seeder.ex - Add to existing file
def seed_dev_admin do
  admin_email = "admin@kyozo.dev"
  admin_password = "devpassword123"

  case Kyozo.Accounts.get_user_by_email!(admin_email) do
    nil ->
      IO.puts("🔐 Creating development admin user...")

      case Kyozo.Accounts.User
           |> Ash.Changeset.for_action(:register_with_password, %{
             email: admin_email,
             password: admin_password,
             password_confirmation: admin_password
           })
           |> Ash.create() do
        {:ok, user} ->
          # Set admin role
          user = user
          |> Ash.Changeset.for_action(:set_role, %{role: :admin})
          |> Ash.update!()

          # Auto-confirm the user
          user
          |> Ash.Changeset.for_action(:update, %{confirmed_at: DateTime.utc_now()})
          |> Ash.update!()

          IO.puts("✅ Dev admin user created successfully!")
          IO.puts("   📧 Email: #{admin_email}")
          IO.puts("   🔑 Password: #{admin_password}")
          IO.puts("   👑 Role: admin")

          {:ok, user}

        {:error, error} ->
          IO.puts("❌ Failed to create dev admin user:")
          IO.inspect(error)
          {:error, error}
      end

    user ->
      IO.puts("ℹ️ Dev admin user already exists: #{user.email}")
      {:ok, user}
  end
rescue
  error ->
    IO.puts("❌ Error in seed_dev_admin: #{inspect(error)}")
    {:error, error}
end

def seed_development do
  if Mix.env() == :dev do
    IO.puts("🌱 Seeding development data...")
    seed_dev_admin()
    IO.puts("✅ Development seeding complete!")
  else
    IO.puts("⚠️ Development seeding skipped - not in dev environment")
  end
end
```

#### 3.2 Create Dev Seeds File

```elixir
# priv/repo/dev_seeds.exs
alias Kyozo.Seeder

IO.puts("🚀 Running development seeds...")

case Seeder.seed_development() do
  :ok ->
    IO.puts("\n🎉 Development environment ready!")
    IO.puts("👤 Admin user: admin@kyozo.dev / devpassword123")
    IO.puts("🔗 Test page: http://localhost:4000/auth/test")

  {:error, error} ->
    IO.puts("\n❌ Development seeding failed:")
    IO.inspect(error)
end
```

### Step 4: Environment Configuration

#### 4.1 Development Configuration

```elixir
# config/dev.exs - Add OAuth2 configuration
config :kyozo,
  apple_client_id: System.get_env("APPLE_CLIENT_ID"),
  apple_client_secret: System.get_env("APPLE_CLIENT_SECRET"),
  apple_redirect_uri: "http://localhost:4000/auth/apple/callback",
  google_client_id: System.get_env("GOOGLE_CLIENT_ID"),
  google_client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  google_redirect_uri: "http://localhost:4000/auth/google/callback"
```

#### 4.2 Environment Variables

Create `.env.local` file:

```bash
# OAuth2 Configuration (Optional for development)
APPLE_CLIENT_ID=your_apple_client_id
APPLE_CLIENT_SECRET=your_apple_client_secret
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Development settings
PHX_HOST=localhost
PHX_PORT=4000
```

### Step 5: Fix LiveSvelte Integration

#### 5.1 Update LiveView Event Handlers

```elixir
# lib/kyozo_web/live/auth/sign_in_live.ex
def handle_event("sign_in_with_password", params, socket) do
  %{"email" => email, "password" => password, "redirect_to" => redirect_to} = params

  case Kyozo.Accounts.User
       |> Ash.Changeset.for_action(:sign_in_with_password, %{
         email: email,
         password: password
       })
       |> Ash.read() do
    {:ok, [user]} ->
      token = user.__metadata__.token

      socket = socket
      |> put_flash(:info, "Welcome back!")
      |> Phoenix.LiveView.put_session(:user_token, token)
      |> push_navigate(to: redirect_to)

      {:reply, %{success: true, redirect_to: redirect_to}, socket}

    {:error, %{errors: errors}} ->
      error_message =
        case Enum.find(errors, &(&1.field == :email)) do
          %{message: message} -> message
          _ -> "Invalid email or password"
        end

      {:reply, %{success: false, error: error_message}, socket}
  end
end
```

### Step 6: Testing and Verification

#### 6.1 Authentication Test Page

The auth test page at `/auth/test` provides a comprehensive view of:
- Current authentication status
- Available authentication methods
- Development admin user info
- Quick access to all auth flows

#### 6.2 Manual Testing Checklist

- [ ] Password registration works
- [ ] Password sign-in works
- [ ] Magic link request works
- [ ] Email confirmation works
- [ ] Password reset works
- [ ] Dev admin user can sign in
- [ ] OAuth2 redirect works (even without valid credentials)
- [ ] LiveSvelte components respond correctly
- [ ] Session management works
- [ ] Sign out works

## Quick Setup Commands

```bash
# 1. Install missing dependencies
mix deps.get

# 2. Run database setup
mix ash.setup

# 3. Generate any needed migrations
mix ash.codegen --check

# 4. Create development admin user
mix run priv/repo/dev_seeds.exs

# 5. Start the server
mix phx.server
```

## Troubleshooting

### Common Issues

1. **OAuth2 compilation errors**: Usually due to missing actions or configuration
2. **Database connection issues**: Check postgres is running
3. **Missing dependencies**: Run `mix deps.get`
4. **Migration issues**: Run `mix ash.codegen` to generate needed changes

### Debug Commands

```bash
# Check what routes are available
mix phx.routes | grep auth

# Check authentication routes specifically
mix ash_authentication.phoenix.routes

# Test compilation without running
mix compile

# Check database status
mix ash.migrate --check
```

## Production Considerations

### Security Checklist

- [ ] Use strong JWT signing secrets
- [ ] Configure proper OAuth2 redirect URIs
- [ ] Set up proper email sending (not local adapter)
- [ ] Enable CSRF protection
- [ ] Configure rate limiting
- [ ] Set secure cookie settings
- [ ] Use HTTPS in production

### Environment Variables for Production

```bash
# Required for production
SECRET_KEY_BASE=your_secret_key_base
DATABASE_URL=your_database_url
JWT_SIGNING_SECRET=your_jwt_secret

# OAuth2 (if using)
APPLE_CLIENT_ID=your_apple_client_id
APPLE_CLIENT_SECRET=your_apple_client_secret
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Email service
SMTP_HOST=your_smtp_host
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
```

## Next Steps

1. **Complete OAuth2 setup**: Get actual OAuth2 credentials and test flows
2. **Customize email templates**: Brand the confirmation and reset emails
3. **Add user profile management**: Allow users to update their information
4. **Implement role-based permissions**: Use the admin role for advanced features
5. **Add social profile integration**: Store additional OAuth2 profile data
6. **Set up monitoring**: Track authentication events and failures

## Support

For issues or questions:
1. Check the AshAuthentication documentation
2. Review the Phoenix LiveView guides
3. Test with the `/auth/test` page
4. Check server logs for detailed error messages

---

**Status**: Implementation guide ready for execution
**Last Updated**: December 2024
**Version**: 1.0
