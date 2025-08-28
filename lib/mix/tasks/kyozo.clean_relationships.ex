defmodule Mix.Tasks.Dirup.CleanRelationships do
  @moduledoc """
  Removes all foreign keys, indexes, and constraints that are broken.
  Run with: mix kyozo.clean_relationships

  Options:
    --dry-run    - Show what would be done without executing
    --nuclear    - Remove ALL constraints and indexes (dangerous!)
    --rebuild    - Attempt to rebuild valid relationships after cleaning
  """

  use Mix.Task
  require Logger

  @shortdoc "Clean up broken database relationships"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [dry_run: :boolean, nuclear: :boolean, rebuild: :boolean]
      )

    dry_run = opts[:dry_run] || false
    nuclear = opts[:nuclear] || false
    rebuild = opts[:rebuild] || false

    Logger.info("🧹 Database Relationship Cleaner")
    Logger.info("=" |> String.duplicate(50))
    Logger.info("Mode: #{if nuclear, do: "NUCLEAR 💣", else: "TARGETED 🎯"}")
    Logger.info("Dry Run: #{dry_run}")
    Logger.info("=" |> String.duplicate(50))

    if nuclear do
      Logger.warning("⚠️  NUCLEAR MODE: This will remove ALL constraints and indexes!")
      Logger.warning("   Press Enter to continue or Ctrl+C to abort...")
      IO.gets("")
    end

    # Step 1: Find all broken indexes
    broken_indexes = find_broken_indexes()

    # Step 2: Find all foreign keys
    foreign_keys = find_all_foreign_keys()

    # Step 3: Find orphaned indexes
    orphaned_indexes = find_orphaned_indexes()

    # Step 4: Show what we found
    report_findings(broken_indexes, foreign_keys, orphaned_indexes)

    unless dry_run do
      # Step 5: Clean up
      if nuclear do
        nuclear_cleanup()
      else
        targeted_cleanup(broken_indexes, orphaned_indexes)
      end

      # Step 6: Rebuild if requested
      if rebuild do
        rebuild_valid_relationships()
      end
    end

    Logger.info("\n✅ Cleanup complete!")
  end

  defp find_broken_indexes do
    Logger.info("\n🔍 Finding broken indexes...")

    # Get all indexes
    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT
          schemaname,
          tablename,
          indexname,
          indexdef
        FROM pg_indexes
        WHERE schemaname = 'public'
        ORDER BY tablename, indexname;
      """)

    broken = []

    Enum.each(result.rows, fn [_schema, table, index_name, index_def] ->
      # Try to check if the index references valid columns
      if String.contains?(index_def, ["media_id", "storage_resource_id", "file_media"]) do
        # Check if these columns actually exist
        column_match = Regex.run(~r/\(([^)]+)\)/, index_def)

        if column_match do
          columns = column_match |> List.last() |> String.split(",") |> Enum.map(&String.trim/1)

          Enum.each(columns, fn col ->
            {:ok, check} =
              Ecto.Adapters.SQL.query(
                Dirup.Repo,
                """
                  SELECT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = $1
                    AND column_name = $2
                  )
                """,
                [table, col]
              )

            case check.rows do
              [[false]] ->
                Logger.warning(
                  "  ❌ Broken index: #{index_name} references missing column: #{col}"
                )

                broken ++ [{table, index_name, col}]

              _ ->
                :ok
            end
          end)
        end
      end
    end)

    broken
  end

  defp find_all_foreign_keys do
    Logger.info("\n🔍 Finding all foreign keys...")

    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT
          tc.table_name,
          kcu.column_name,
          ccu.table_name AS foreign_table_name,
          ccu.column_name AS foreign_column_name,
          tc.constraint_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public';
      """)

    Enum.map(result.rows, fn [table, column, foreign_table, foreign_column, constraint] ->
      Logger.info("  • #{table}.#{column} -> #{foreign_table}.#{foreign_column} (#{constraint})")
      {table, column, foreign_table, foreign_column, constraint}
    end)
  end

  defp find_orphaned_indexes do
    Logger.info("\n🔍 Finding orphaned indexes...")

    # Indexes that reference non-existent columns
    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT DISTINCT
          i.schemaname,
          i.tablename,
          i.indexname
        FROM pg_indexes i
        WHERE i.schemaname = 'public'
        AND i.indexname LIKE '%_index'
        AND (
          i.indexdef LIKE '%media_id%'
          OR i.indexdef LIKE '%storage_resource_id%'
          OR i.indexdef LIKE '%file_media%'
          OR i.tablename LIKE '%file_media%'
        )
        ORDER BY i.tablename, i.indexname;
      """)

    result.rows
  end

  defp report_findings(broken_indexes, foreign_keys, orphaned_indexes) do
    Logger.info("\n📊 Findings Report")
    Logger.info("=" |> String.duplicate(50))
    Logger.info("  Broken Indexes: #{length(broken_indexes)}")
    Logger.info("  Foreign Keys: #{length(foreign_keys)}")
    Logger.info("  Suspicious Indexes: #{length(orphaned_indexes)}")
    Logger.info("=" |> String.duplicate(50))
  end

  defp nuclear_cleanup do
    Logger.info("\n💣 NUCLEAR CLEANUP INITIATED...")

    # Drop ALL foreign key constraints
    Logger.info("  Removing all foreign keys...")

    {:ok, fks} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT
          'ALTER TABLE ' || quote_ident(tc.table_name) ||
          ' DROP CONSTRAINT ' || quote_ident(tc.constraint_name) || ';' as cmd
        FROM information_schema.table_constraints tc
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public';
      """)

    Enum.each(fks.rows, fn [cmd] ->
      Logger.info("    Executing: #{cmd}")
      Ecto.Adapters.SQL.query(Dirup.Repo, cmd)
    end)

    # Drop suspicious indexes
    Logger.info("  Removing suspicious indexes...")

    {:ok, indexes} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT
          'DROP INDEX IF EXISTS ' || quote_ident(indexname) || ';' as cmd
        FROM pg_indexes
        WHERE schemaname = 'public'
        AND (
          indexname LIKE '%media%'
          OR indexname LIKE '%storage_resource%'
          OR indexdef LIKE '%media_id%'
          OR indexdef LIKE '%storage_resource_id%'
        )
        AND indexname NOT LIKE '%pkey';
      """)

    Enum.each(indexes.rows, fn [cmd] ->
      Logger.info("    Executing: #{cmd}")
      Ecto.Adapters.SQL.query(Dirup.Repo, cmd)
    end)

    Logger.info("  ✓ Nuclear cleanup complete")
  end

  defp targeted_cleanup(broken_indexes, orphaned_indexes) do
    Logger.info("\n🎯 Targeted cleanup...")

    # Drop only broken indexes
    Enum.each(orphaned_indexes, fn [_schema, _table, index_name] ->
      cmd = "DROP INDEX IF EXISTS #{index_name};"
      Logger.info("  Dropping: #{index_name}")
      Ecto.Adapters.SQL.query(Dirup.Repo, cmd)
    end)

    Logger.info("  ✓ Targeted cleanup complete")
  end

  defp rebuild_valid_relationships do
    Logger.info("\n🔨 Rebuilding valid relationships...")

    # Only rebuild indexes for columns that actually exist
    tables = get_all_tables()

    Enum.each(tables, fn table ->
      columns = get_table_columns(table)

      # Basic indexes for common columns
      if "id" in columns do
        create_index_safe(table, "id", "#{table}_id_index")
      end

      if "email" in columns do
        create_index_safe(table, "email", "#{table}_email_index")
      end

      if "created_at" in columns do
        create_index_safe(table, "created_at", "#{table}_created_at_index")
      end

      # Foreign key indexes (only if column exists)
      if "user_id" in columns do
        create_index_safe(table, "user_id", "#{table}_user_id_index")
      end

      if "workspace_id" in columns do
        create_index_safe(table, "workspace_id", "#{table}_workspace_id_index")
      end

      if "team_id" in columns do
        create_index_safe(table, "team_id", "#{table}_team_id_index")
      end
    end)

    Logger.info("  ✓ Rebuild complete")
  end

  defp get_all_tables do
    {:ok, result} =
      Ecto.Adapters.SQL.query(Dirup.Repo, """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name NOT LIKE 'schema_%'
        AND table_name NOT LIKE 'oban_%'
        ORDER BY table_name;
      """)

    Enum.map(result.rows, fn [table] -> table end)
  end

  defp get_table_columns(table) do
    {:ok, result} =
      Ecto.Adapters.SQL.query(
        Dirup.Repo,
        """
          SELECT column_name
          FROM information_schema.columns
          WHERE table_name = $1
          AND table_schema = 'public';
        """,
        [table]
      )

    Enum.map(result.rows, fn [col] -> col end)
  end

  defp create_index_safe(table, column, index_name) do
    cmd = "CREATE INDEX IF NOT EXISTS #{index_name} ON #{table}(#{column});"

    case Ecto.Adapters.SQL.query(Dirup.Repo, cmd) do
      {:ok, _} ->
        Logger.info("    ✓ Created index: #{index_name}")

      {:error, _} ->
        # Index might already exist or column might not exist
        :ok
    end
  end
end
