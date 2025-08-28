defmodule Mix.Tasks.Containers.Migrate do
  use Mix.Task

  @shortdoc "Generate and run container domain migrations for Kyozo Store"

  @moduledoc """
  Generate and run container domain migrations for Kyozo Store's "Folder as a Service" functionality.

  This task creates all necessary database migrations for the Dirup.Containers domain,
  including service instances, topology detection, deployment events, and monitoring tables.

  ## Usage

      mix containers.migrate                    # Generate and run all migrations
      mix containers.migrate --dry-run         # Show what would be created
      mix containers.migrate --rollback        # Rollback container migrations
      mix containers.migrate --check           # Verify migration status

  ## Options

    * `--dry-run` - Show generated migrations without applying them
    * `--rollback` - Rollback container domain migrations
    * `--check` - Check if migrations are needed
    * `--force` - Force regeneration of existing migrations

  ## Examples

      # Generate and apply all container migrations
      mix containers.migrate

      # Check what migrations would be created
      mix containers.migrate --dry-run

      # Rollback container functionality
      mix containers.migrate --rollback

      # Verify current state
      mix containers.migrate --check

  The task will:
  1. Generate Ash-compatible migrations for all container resources
  2. Create proper foreign key relationships
  3. Add performance indexes
  4. Set up check constraints
  5. Extend existing tables (workspaces, files) with container fields
  """

  alias Mix.Shell.IO, as: Shell

  @switches [
    dry_run: :boolean,
    rollback: :boolean,
    check: :boolean,
    force: :boolean
  ]

  @container_resources [
    Dirup.Containers.TopologyDetection,
    Dirup.Containers.ServiceInstance,
    Dirup.Containers.DeploymentEvent,
    Dirup.Containers.ServiceDependency,
    Dirup.Containers.HealthCheck,
    Dirup.Containers.ServiceMetric,
    Dirup.Containers.ServicePermission
  ]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    Mix.Task.run("app.start")

    cond do
      opts[:check] -> check_migration_status()
      opts[:rollback] -> rollback_migrations(opts)
      opts[:dry_run] -> dry_run_migrations()
      true -> generate_and_run_migrations(opts)
    end
  end

  defp check_migration_status do
    Shell.info("🔍 Checking container migration status...")
    Shell.info("")

    # Check if container tables exist
    container_tables = [
      "topology_detections",
      "service_instances",
      "deployment_events",
      "service_dependencies",
      "health_checks",
      "service_metrics",
      "service_permissions"
    ]

    existing_tables = get_existing_tables()

    container_tables
    |> Enum.each(fn table ->
      if table in existing_tables do
        Shell.info("✅ #{table} - exists")
      else
        Shell.error("❌ #{table} - missing")
      end
    end)

    # Check workspace extensions
    Shell.info("")
    Shell.info("Checking workspace extensions:")

    workspace_columns = get_table_columns("workspaces")
    container_columns = ["container_enabled", "service_topology", "auto_deploy_enabled"]

    container_columns
    |> Enum.each(fn column ->
      if column in workspace_columns do
        Shell.info("✅ workspaces.#{column} - exists")
      else
        Shell.error("❌ workspaces.#{column} - missing")
      end
    end)

    Shell.info("")

    if length(container_tables -- existing_tables) == 0 and
         length(container_columns -- workspace_columns) == 0 do
      Shell.info("🎉 All container migrations are applied!")
    else
      Shell.error("⚠️  Some container migrations are missing. Run: mix containers.migrate")
    end
  end

  defp dry_run_migrations do
    Shell.info("🧪 Dry run: Container migrations that would be generated...")
    Shell.info("")

    # Show what Ash would generate
    try do
      # Generate migrations without applying
      {output, _} =
        System.cmd(
          "mix",
          ["ash_postgres.generate_migrations", "--name", "add_containers_domain", "--dry-run"],
          stderr_to_stdout: true
        )

      Shell.info(output)
    rescue
      _ ->
        # Fallback to manual listing
        Shell.info("Would generate migrations for:")

        @container_resources
        |> Enum.with_index(1)
        |> Enum.each(fn {resource, index} ->
          table_name = get_table_name(resource)
          Shell.info("#{index}. #{table_name} (#{inspect(resource)})")
        end)

        Shell.info("#{length(@container_resources) + 1}. workspace extensions")
        Shell.info("#{length(@container_resources) + 2}. file extensions")
    end

    Shell.info("")
    Shell.info("To apply these migrations, run: mix containers.migrate")
  end

  defp generate_and_run_migrations(opts) do
    Shell.info("🚀 Generating container domain migrations...")
    Shell.info("")

    # Step 1: Generate Ash migrations
    migration_name = generate_migration_name()

    try do
      # Use Ash to generate migrations
      Mix.Task.run("ash_postgres.generate_migrations", ["--name", migration_name])

      Shell.info("✅ Migrations generated successfully")
      Shell.info("")

      # Step 2: Apply migrations
      Shell.info("🔧 Applying container migrations...")
      Mix.Task.run("ecto.migrate")

      Shell.info("")
      Shell.info("✅ Container migrations applied successfully!")

      # Step 3: Verify installation
      verify_migration_success()

      print_success_message()
    rescue
      error ->
        Shell.error("❌ Migration failed: #{inspect(error)}")
        Shell.error("")
        Shell.error("Troubleshooting steps:")
        Shell.error("1. Ensure all dependencies are started: mix deps.get")
        Shell.error("2. Check database connectivity: mix ecto.setup")
        Shell.error("3. Verify Ash resources compile: mix compile")

        Shell.error(
          "4. Try manual migration: mix ash_postgres.generate_migrations --name add_containers"
        )

        exit({:shutdown, 1})
    end
  end

  defp rollback_migrations(opts) do
    Shell.info("🔄 Rolling back container migrations...")
    Shell.info("")

    unless opts[:force] do
      confirm = Shell.yes?("This will remove all container functionality. Continue?")

      unless confirm do
        Shell.info("Rollback cancelled.")
        :ok
      end
    end

    try do
      # Find container migrations to rollback
      migrations = get_container_migrations()

      if length(migrations) == 0 do
        Shell.info("No container migrations found to rollback.")
        :ok
      end

      # Rollback migrations
      Enum.each(migrations, fn migration ->
        Shell.info("Rolling back: #{migration}")
        Mix.Task.run("ecto.rollback", ["--to", migration])
      end)

      Shell.info("✅ Container migrations rolled back successfully!")
    rescue
      error ->
        Shell.error("❌ Rollback failed: #{inspect(error)}")
        exit({:shutdown, 1})
    end
  end

  defp generate_migration_name do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "add_containers_domain_#{timestamp}"
  end

  defp get_existing_tables do
    query = """
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    """

    case Ecto.Adapters.SQL.query(Dirup.Repo, query, []) do
      {:ok, %{rows: rows}} -> Enum.map(rows, &List.first/1)
      _ -> []
    end
  end

  defp get_table_columns(table_name) do
    query = """
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = $1 AND table_schema = 'public'
    """

    case Ecto.Adapters.SQL.query(Dirup.Repo, query, [table_name]) do
      {:ok, %{rows: rows}} -> Enum.map(rows, &List.first/1)
      _ -> []
    end
  end

  defp get_table_name(resource) do
    # Extract table name from resource module
    case resource do
      Dirup.Containers.TopologyDetection -> "topology_detections"
      Dirup.Containers.ServiceInstance -> "service_instances"
      Dirup.Containers.DeploymentEvent -> "deployment_events"
      Dirup.Containers.ServiceDependency -> "service_dependencies"
      Dirup.Containers.HealthCheck -> "health_checks"
      Dirup.Containers.ServiceMetric -> "service_metrics"
      Dirup.Containers.ServicePermission -> "service_permissions"
      _ -> "unknown"
    end
  end

  defp get_container_migrations do
    # Query schema_migrations table for container-related migrations
    query = """
    SELECT version
    FROM schema_migrations
    WHERE version LIKE '%container%' OR version LIKE '%service%' OR version LIKE '%topology%'
    ORDER BY version DESC
    """

    case Ecto.Adapters.SQL.query(Dirup.Repo, query, []) do
      {:ok, %{rows: rows}} -> Enum.map(rows, &List.first/1)
      _ -> []
    end
  end

  defp verify_migration_success do
    Shell.info("🔍 Verifying migration success...")

    # Check critical tables exist
    existing_tables = get_existing_tables()
    required_tables = ["service_instances", "topology_detections"]

    missing_tables = required_tables -- existing_tables

    if length(missing_tables) == 0 do
      Shell.info("✅ Core container tables created successfully")
    else
      Shell.error("❌ Missing tables: #{Enum.join(missing_tables, ", ")}")
      exit({:shutdown, 1})
    end

    # Check workspace extensions
    workspace_columns = get_table_columns("workspaces")

    if "container_enabled" in workspace_columns do
      Shell.info("✅ Workspace extensions added successfully")
    else
      Shell.error("❌ Workspace extensions missing")
      exit({:shutdown, 1})
    end

    Shell.info("✅ Migration verification complete")
  end

  defp print_success_message do
    Shell.info("")
    Shell.info("=" |> String.duplicate(60))
    Shell.info("🎉 Kyozo Store Container Domain Ready!")
    Shell.info("=" |> String.duplicate(60))
    Shell.info("")
    Shell.info("📋 Next Steps:")
    Shell.info("")
    Shell.info("1. 🔄 Restart your Phoenix server:")
    Shell.info("   mix phx.server")
    Shell.info("")
    Shell.info("2. 🧪 Test the GraphQL API:")
    Shell.info("   Visit http://localhost:4000/graphiql")
    Shell.info("   Query: { listServiceInstances { id name status } }")
    Shell.info("")
    Shell.info("3. 🔍 Analyze a workspace folder:")
    Shell.info(~s|   curl -X POST http://localhost:4000/api/topology-detections \\|)
    Shell.info(~s|     -H "Content-Type: application/json" \\|)
    Shell.info(~s|     -d '{"workspace_id":"your-id","folder_path":"/"}'|)
    Shell.info("")
    Shell.info("4. 📚 Review the implementation:")
    Shell.info("   - lib/kyozo/containers.ex (Domain)")
    Shell.info("   - lib/kyozo/containers/*.ex (Resources)")
    Shell.info("")
    Shell.info("🚀 Transform folders into running containers!")
    Shell.info("   Directory organization IS deployment strategy")
    Shell.info("")
  end
end
