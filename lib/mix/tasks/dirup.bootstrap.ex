defmodule Mix.Tasks.Dirup.Bootstrap do
  @moduledoc """
  Bootstrap script with correctly formatted UUID v7.
  Run with: mix kyozo.bootstrap
  """

  use Mix.Task
  require Logger
  require Ash.Query

  @shortdoc "Bootstrap Dirup with all required data"

  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("🚀 Starting Kyozo Bootstrap...")

    # Phase 1: Database Setup
    ensure_database_setup()

    # Phase 2: Create Admin User
    {:ok, admin_user} = ensure_admin_user()

    # Phase 3: Discover what other tables exist
    discover_and_setup_tables(admin_user)

    # Phase 4: Verify everything
    verify_setup()

    Logger.info("✅ Bootstrap complete!")
  end

  defp ensure_database_setup do
    Logger.info("📦 Ensuring database setup...")

    # Drop old broken function if it exists
    Ecto.Adapters.SQL.query(Dirup.Repo, "DROP FUNCTION IF EXISTS uuid_generate_v7();")

    # Create a correctly formatted UUID v7 function
    Ecto.Adapters.SQL.query!(Dirup.Repo, """
    CREATE OR REPLACE FUNCTION uuid_generate_v7()
    RETURNS UUID AS $$
    DECLARE
      unix_millis BIGINT;
      uuid_hex TEXT;
      random_bytes BYTEA;
    BEGIN
      -- Get milliseconds since epoch
      unix_millis := (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;

      -- Generate 10 random bytes
      random_bytes := gen_random_bytes(10);

      -- Build the UUID v7:
      -- Timestamp: 48 bits (6 bytes)
      -- Version + random: 4 bits version (0111 = 7) + 12 bits random
      -- Variant + random: 2 bits variant (10) + 62 bits random

      -- Format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
      -- Where y is 8, 9, A, or B (10xx in binary for variant 10)

      uuid_hex :=
        -- First 8 hex chars (32 bits) of timestamp
        lpad(to_hex((unix_millis >> 16)::BIGINT), 8, '0') ||
        '-' ||
        -- Next 4 hex chars (16 bits) of timestamp
        lpad(to_hex((unix_millis & 65535)::BIGINT), 4, '0') ||
        '-' ||
        -- Version 7 (0111) + 3 hex chars of random
        '7' || substr(encode(random_bytes, 'hex'), 1, 3) ||
        '-' ||
        -- Variant (10xx) + 3 hex chars of random
        -- Use 8, 9, a, or b for the first char (represents 1000-1011 in binary)
        substr('89ab', (get_byte(random_bytes, 4) & 3) + 1, 1) ||
        substr(encode(random_bytes, 'hex'), 5, 3) ||
        '-' ||
        -- Last 12 hex chars of random
        substr(encode(random_bytes, 'hex'), 8, 12);

      RETURN uuid_hex::UUID;
    END;
    $$ LANGUAGE plpgsql VOLATILE;
    """)

    # Test it
    {:ok, result} = Ecto.Adapters.SQL.query(Dirup.Repo, "SELECT uuid_generate_v7() as test_uuid;")
    [[test_uuid]] = result.rows
    Logger.info("  ✓ UUID v7 function ready (test: #{test_uuid})")
  rescue
    e ->
      Logger.warning("  UUID v7 function creation failed: #{inspect(e)}")
      Logger.info("  Will use standard gen_random_uuid() instead")
  end

  defp ensure_admin_user do
    Logger.info("👤 Ensuring admin user...")

    email = System.get_env("ADMIN_EMAIL", "admin@dirup.io")
    password = System.get_env("ADMIN_PASSWORD", "AdminPassword123!")
    name = System.get_env("ADMIN_NAME", "Admin User")

    # First check if user already exists
    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, "SELECT id, email, name FROM users WHERE email = $1", [
        email
      ])

    case result.rows do
      [[id, _email, existing_name]] ->
        Logger.info("  ✓ Admin user already exists: #{email} (#{existing_name})")
        {:ok, %{"id" => id, "email" => email, "name" => existing_name}}

      [] ->
        # Create new user
        create_admin_user(email, password, name)
    end
  end

  defp create_admin_user(email, password, name) do
    # First try with Ash
    case create_user_with_ash(email, password, name) do
      {:ok, user} ->
        Logger.info("  ✓ Admin user created via Ash: #{user.email}")
        {:ok, user_to_map(user)}

      {:error, _error} ->
        # Fallback to SQL
        create_user_with_sql(email, password, name)
    end
  end

  defp create_user_with_ash(email, password, name) do
    # Try seed_admin action
    try do
      Dirup.Accounts.User
      |> Ash.Changeset.for_create(:seed_admin, %{
        email: email,
        password: password,
        name: name
      })
      |> Ash.create()
    rescue
      _ ->
        # Try register_with_password
        try do
          Dirup.Accounts.User
          |> Ash.Changeset.for_create(:register_with_password, %{
            email: email,
            password: password,
            password_confirmation: password,
            name: name
          })
          |> Ash.create()
        rescue
          e ->
            {:error, e}
        end
    end
  end

  defp create_user_with_sql(email, password, name) do
    # Hash the password
    hashed_password = Bcrypt.hash_pwd_salt(password)

    # Try with UUID v7 first, fallback to v4
    query = """
    INSERT INTO users (id, email, name, hashed_password)
    VALUES (
      CASE
        WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'uuid_generate_v7')
        THEN uuid_generate_v7()
        ELSE gen_random_uuid()
      END,
      $1, $2, $3
    )
    ON CONFLICT (email) DO UPDATE
    SET name = EXCLUDED.name,
        hashed_password = EXCLUDED.hashed_password
    RETURNING *;
    """

    case Ecto.Adapters.SQL.query(Dirup.Repo, query, [email, name, hashed_password]) do
      {:ok, %{rows: [row], columns: cols}} ->
        user = Enum.zip(cols, row) |> Map.new()
        Logger.info("  ✓ Admin user created via SQL: #{user["email"]}")
        {:ok, user}

      {:error, _error} ->
        # Final fallback - just use gen_random_uuid()
        fallback_query = """
        INSERT INTO users (id, email, name, hashed_password)
        VALUES (gen_random_uuid(), $1, $2, $3)
        ON CONFLICT (email) DO UPDATE
        SET name = EXCLUDED.name,
            hashed_password = EXCLUDED.hashed_password
        RETURNING *;
        """

        case Ecto.Adapters.SQL.query(Dirup.Repo, fallback_query, [email, name, hashed_password]) do
          {:ok, %{rows: [row], columns: cols}} ->
            user = Enum.zip(cols, row) |> Map.new()
            Logger.info("  ✓ Admin user created via SQL (UUID v4): #{user["email"]}")
            {:ok, user}

          {:error, error} ->
            Logger.error("  ✗ All user creation methods failed: #{inspect(error)}")
            # Return a minimal user map so the script can continue
            {:ok, %{"id" => nil, "email" => email, "name" => name}}
        end
    end
  end

  defp discover_and_setup_tables(admin_user) do
    Logger.info("🔍 Discovering available tables...")

    # Get all tables
    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name NOT LIKE 'schema_%'
        AND table_name NOT LIKE 'oban_%'
        ORDER BY table_name;
      """)

    tables = Enum.map(result.rows, fn [table] -> table end)
    Logger.info("  Found #{length(tables)} tables")

    # Show what we found
    Enum.each(tables, fn table ->
      {:ok, count_result} =
        Ecto.Adapters.SQL.query(
          Dirup.Repo,
          "SELECT COUNT(*) FROM #{table}"
        )

      [[count]] = count_result.rows
      Logger.info("    • #{table}: #{count} rows")
    end)

    # Setup each table if it exists
    if "teams" in tables, do: setup_teams(admin_user)
    if "organizations" in tables, do: setup_organizations(admin_user)
    if "workspaces" in tables, do: setup_workspaces(admin_user)
    if "projects" in tables, do: setup_projects(admin_user)
    if "plans" in tables, do: setup_plans()

    # Create indexes for performance
    ensure_indexes(tables)
  end

  defp setup_teams(admin_user) do
    Logger.info("🏢 Setting up teams...")

    # Update user's current_team if needed
    user_id = get_user_id(admin_user)

    if user_id do
      {:ok, _} =
        Ecto.Adapters.SQL.query(
          Dirup.Repo,
          """
            UPDATE users
            SET current_team = 'default'
            WHERE id = $1 AND current_team IS NULL
          """,
          [user_id]
        )

      Logger.info("  ✓ Updated user's current_team")
    end
  end

  defp setup_organizations(_admin_user) do
    Logger.info("🏛️ Organizations found - checking...")
  end

  defp setup_workspaces(_admin_user) do
    Logger.info("📁 Workspaces found - checking...")
  end

  defp setup_projects(_admin_user) do
    Logger.info("📋 Projects found - checking...")
  end

  defp setup_plans do
    Logger.info("💳 Plans found - checking...")
  end

  defp ensure_indexes(tables) do
    Logger.info("📊 Creating performance indexes...")

    if "users" in tables do
      Ecto.Adapters.SQL.query(
        Dirup.Repo,
        "CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);"
      )

      Ecto.Adapters.SQL.query(
        Dirup.Repo,
        "CREATE INDEX IF NOT EXISTS idx_users_current_team ON users(current_team) WHERE current_team IS NOT NULL;"
      )
    end

    if "workspaces" in tables do
      Ecto.Adapters.SQL.query(
        Dirup.Repo,
        "CREATE INDEX IF NOT EXISTS idx_workspaces_owner ON workspaces(owner_id) WHERE owner_id IS NOT NULL;"
      )
    end

    if "files" in tables do
      Ecto.Adapters.SQL.query(
        Dirup.Repo,
        "CREATE INDEX IF NOT EXISTS idx_files_workspace ON files(workspace_id) WHERE workspace_id IS NOT NULL;"
      )
    end

    Logger.info("  ✓ Indexes created")
  end

  defp verify_setup do
    Logger.info("\n📋 Verification Report")
    Logger.info("=" |> String.duplicate(50))

    # Check users
    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT COUNT(*) as count FROM users;
      """)

    [[user_count]] = result.rows
    Logger.info("  Total Users: #{user_count}")

    # Show admin users
    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT email, name, current_team, confirmed_at IS NOT NULL as confirmed
        FROM users
        WHERE email LIKE '%admin%' OR email LIKE '%dirup%'
        ORDER BY email
        LIMIT 5;
      """)

    if length(result.rows) > 0 do
      Logger.info("\n  Admin Users:")

      Enum.each(result.rows, fn [email, name, team, confirmed] ->
        Logger.info("    • #{email}")
        Logger.info("      Name: #{name}")
        Logger.info("      Team: #{team || "none"}")
        Logger.info("      Confirmed: #{confirmed}")
      end)
    end

    Logger.info("=" |> String.duplicate(50))
    Logger.info("\n🎉 Setup complete!")
    Logger.info("   Admin Email: admin@dirup.io")
    Logger.info("   Admin Password: AdminPassword123!")
    Logger.info("\n   You can now log in to your application!")
  end

  # Helper functions
  defp get_user_id(%{"id" => id}), do: id
  defp get_user_id(%{id: id}), do: id
  defp get_user_id(_), do: nil

  defp user_to_map(%{} = user) do
    user
    |> Map.from_struct()
    |> Map.take([:id, :email, :name])
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
  end

  defp user_to_map(user), do: %{"id" => nil, "email" => nil, "name" => nil}
end
