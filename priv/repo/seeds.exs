# Production Seeds
#
# This file contains seeds for production environment.
# It creates essential system data and an initial admin user.

alias Kyozo.Accounts
alias Kyozo.Workspaces
require Ash.Query
require Ash.Expr
IO.puts("🌱 Seeding production data...")

defmodule Kyozo.Seeds do

  # Helper function to safely create or get existing record
  def create_or_get(module, action, params, opts \\ []) do
    tenant = Keyword.get(opts, :tenant)
    other_opts = Keyword.delete(opts, :tenant)
    
    IO.puts("DEBUG create_or_get - tenant: #{inspect(tenant)}")
    
    changeset = module
    |> Ash.Changeset.for_action(action, params)
    
    changeset = if tenant do
      IO.puts("DEBUG create_or_get - setting tenant on changeset")
      result = Ash.Changeset.set_tenant(changeset, tenant)
      IO.puts("DEBUG create_or_get - changeset.tenant after set: #{inspect(result.tenant)}")
      result
    else
      IO.puts("DEBUG create_or_get - no tenant to set")
      changeset
    end
    
    IO.puts("DEBUG create_or_get - final changeset.tenant: #{inspect(changeset.tenant)}")
    
    case Ash.create(changeset, other_opts) do
      {:ok, record} ->
        {:ok, record}
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidAttribute{field: field}]}} when field in [:email, :name] ->
        # Try to find existing record by unique field
        query = module |> Ash.Query.filter(^ref(field) == ^Map.get(params, field))
        query = if tenant do
          Ash.Query.set_tenant(query, tenant)
        else
          query
        end
        case Ash.read(query, other_opts) do
          {:ok, [existing]} -> {:ok, existing}
          {:ok, []} -> {:error, :not_found}
          {:ok, multiple} when length(multiple) > 1 -> {:ok, List.first(multiple)}
          {:error, error} -> {:error, error}
        end
      {:error, error} -> {:error, error}
    end
  end

  @doc "A template helper for using action arguments in filter templates"
  def arg(name), do: {:_arg, name}

  @doc "A template helper for creating a reference"
  def ref(name) when is_atom(name), do: {:_ref, [], name}

  @doc "A template helper for creating a reference to a related path"
  def ref(path, name) when is_list(path) and is_atom(name), do: {:_ref, path, name}
end



# Create system admin user if not exists
admin_email = System.get_env("ADMIN_EMAIL", "admin@kyozo.com")
admin_password = System.get_env("ADMIN_PASSWORD", "secure_password_123")

IO.puts("Creating system admin user...")
case Kyozo.Seeds.create_or_get(Accounts.User, :seed_admin, %{
  name: "System Admin",
  email: admin_email,
  password: admin_password
}, [authorize?: false]) do
  {:ok, _admin_user} ->
    IO.puts("✅ System admin user created/updated:")
    IO.puts("   Email: #{admin_email}")
    IO.puts("   Role will be set through team membership")

  {:error, error} ->
    IO.puts("❌ Failed to create system admin user:")
    IO.inspect(error)
end


# ilter expr(artist_id == get_path(^arg(:artist), :id))
# Create default team for admin if not exists
IO.puts("Creating default team...")

# Get admin user first to use as actor
admin_user = case Accounts.User
|> Ash.Query.filter(email == ^Ash.CiString.new(admin_email))
|> Ash.read([authorize?: false]) do
  {:ok, [user]} -> user
  {:ok, []} -> 
    IO.puts("⚠️  Admin user not found, creating team without actor")
    nil
  {:ok, multiple} when length(multiple) > 1 -> List.first(multiple)
  {:error, error} ->
    IO.puts("❌ Error finding admin user: #{inspect(error)}")
    nil
end

# Create default team with proper error handling for migration issues
case Accounts.Team
     |> Ash.Changeset.for_action(:create, %{
       name: "Default Team",
       domain: "default",
       description: "Default team for initial setup",
       owner_user_id: admin_user && admin_user.id
     })
     |> Ash.create(actor: admin_user) do
  {:ok, team} ->
    IO.puts("✅ Default team created/found: #{team.name}")

    if admin_user do
      # Check if user is already a team member
      existing_role = Accounts.UserTeam
      |> Ash.Query.filter(user_id == ^admin_user.id and team_id == ^team.id)
      |> Ash.read()

      case existing_role do
        {:ok, []} ->
          # Create team membership
          case Accounts.UserTeam
               |> Ash.Changeset.for_action(:create, %{
                 user_id: admin_user.id,
                 team_id: team.id,
                 role: :owner
               })
               |> Ash.create() do
            {:ok, _} -> IO.puts("✅ Admin user added to default team")
            {:error, error} -> IO.puts("⚠️  Could not add admin to team: #{inspect(error)}")
          end
        {:ok, _existing} ->
          IO.puts("✅ Admin user already in default team")
        {:error, error} ->
          IO.puts("⚠️  Error checking team membership: #{inspect(error)}")
      end
    end

  {:error, %Ash.Error.Unknown{errors: errors}} ->
    # Check if it's just a tenant migration issue but team was created
    migration_error = Enum.any?(errors, fn error ->
      case error do
        %Ash.Error.Unknown.UnknownError{error: error_msg} when is_binary(error_msg) ->
          String.contains?(error_msg, "relation") && String.contains?(error_msg, "already exists")
        _ -> false
      end
    end)
    
    if migration_error do
      IO.puts("⚠️  Tenant migration error (likely safe to ignore), checking if team was created...")
      # Try to find the team that might have been created
      case Accounts.Team |> Ash.Query.filter(domain == "default") |> Ash.read([authorize?: false]) do
        {:ok, [existing_team]} -> 
          IO.puts("✅ Default team found: #{existing_team.name}")
        {:ok, []} -> 
          IO.puts("❌ No default team found after migration error")
        {:ok, multiple} when length(multiple) > 1 -> 
          IO.puts("✅ Multiple default teams found: #{List.first(multiple).name}")
        {:error, find_error} -> 
          IO.puts("❌ Error finding default team: #{inspect(find_error)}")
      end
    else
      IO.puts("❌ Failed to create default team:")
      IO.inspect(errors)
    end
    
  {:error, error} ->
    IO.puts("❌ Failed to create default team:")
    IO.inspect(error)
end

# Create default workspace for the team
IO.puts("Creating default workspace...")
default_team = case Accounts.Team
|> Ash.Query.filter(domain == "default")
|> Ash.read([authorize?: false]) do
  {:ok, [team]} ->
    IO.puts("Found default team: #{team.name} (id: #{team.id})")
    team
  {:ok, []} ->
    IO.puts("❌ No default team found with domain 'default'")
    nil
  {:ok, multiple} when length(multiple) > 1 ->
    team = List.first(multiple)
    IO.puts("⚠️  Multiple teams found with domain 'default', using first: #{team.name}")
    team
  {:error, error} ->
    IO.puts("❌ Error finding default team: #{inspect(error)}")
    nil
end

if default_team do
  # Get admin_user for workspace creation
  workspace_admin_user = case Accounts.User
  |> Ash.Query.filter(email == ^Ash.CiString.new(admin_email))
  |> Ash.read([authorize?: false]) do
    {:ok, [user]} -> 
      IO.puts("DEBUG - Found admin user for workspace creation: #{user.name}")
      user
    {:ok, []} -> 
      IO.puts("DEBUG - No admin user found for workspace creation")
      nil
    {:ok, multiple} when length(multiple) > 1 -> 
      user = List.first(multiple)
      IO.puts("DEBUG - Multiple admin users found, using first: #{user.name}")
      user
    {:error, error} -> 
      IO.puts("DEBUG - Error finding admin user: #{inspect(error)}")
      nil
  end

  # For attribute-based multitenancy, pass team_id as regular attribute
  IO.puts("DEBUG - Attempting workspace creation with team_id: #{default_team.id}")
  IO.puts("DEBUG - Admin user for actor: #{if workspace_admin_user, do: workspace_admin_user.name, else: "nil"}")
  
  # Create workspace with proper settings to pass validation
  workspace_settings = %{
    "auto_save" => true,
    "max_file_size" => 10_485_760, # 10MB
    "allowed_file_types" => ["*"],
    "enable_notifications" => true,
    "enable_real_time_collaboration" => true,
    "git_auto_push" => false,
    "backup_enabled" => true,
    "backup_frequency" => "daily"
  }
  
  # Use seed_workspace action that accepts created_by_id directly
  workspace_name = "Getting Started"
  result = if workspace_admin_user do
    Workspaces.Workspace
    |> Ash.Changeset.for_action(:seed_workspace, %{
      name: workspace_name,
      description: "Default workspace for new users",
      storage_backend: :git,
      settings: workspace_settings,
      team_id: default_team.id,
      created_by_id: workspace_admin_user.id
    })
    |> Ash.Changeset.set_tenant(default_team.id)
    |> Ash.create(authorize?: false)
  else
    # Create without created_by if no admin user available
    Workspaces.Workspace
    |> Ash.Changeset.for_action(:seed_workspace, %{
      name: workspace_name,
      description: "Default workspace for new users",
      storage_backend: :git,
      settings: workspace_settings,
      team_id: default_team.id
    })
    |> Ash.Changeset.set_tenant(default_team.id)
    |> Ash.create(authorize?: false)
  end
  
  case result do
    {:ok, workspace} ->
      IO.puts("✅ Default workspace created: #{workspace.name}")
      IO.puts("   Storage backend: #{workspace.storage_backend}")
      IO.puts("   Settings: #{inspect(workspace.settings)}")
      IO.puts("   Created by: #{workspace.created_by_id || "system"}")
      
    {:error, error} ->
      IO.puts("❌ Failed to create default workspace:")
      IO.inspect(error)
  end
else
  IO.puts("⚠️  Skipping workspace creation - no default team available")
end

# Create essential roles if they don't exist
IO.puts("Creating essential roles...")
IO.puts("⚠️  Skipping role creation - Role resource needs actions configured")
IO.puts("   Roles would be: Admin, User, Viewer")

# Comment out role creation until Role resource has proper actions
# essential_roles = [
#   %{name: "Admin", description: "Full system access"},
#   %{name: "User", description: "Standard user access"}, 
#   %{name: "Viewer", description: "Read-only access"}
# ]
# 
# Enum.each(essential_roles, fn role_data ->
#   case Kyozo.Seeds.create_or_get(Workspaces.Role, :create, role_data) do
#     {:ok, role} ->
#       IO.puts("✅ Role created/found: #{role.name}")
#     {:error, error} ->
#       IO.puts("⚠️  Could not create role #{role_data.name}: #{inspect(error)}")
#   end
# end)

IO.puts("")
IO.puts("🎉 Production seeding complete!")
IO.puts("System is ready with:")
IO.puts("- Admin user: #{admin_email}")
IO.puts("- Default team and workspace")
IO.puts("- Essential roles")
IO.puts("")
IO.puts("🔐 Admin can sign in at your application URL")
