#!/usr/bin/env elixir

# Run with: mix run enforce_uuid_v7.exs

defmodule UUIDv7Enforcer do
  @moduledoc """
  Enforces UUID v7 across entire Ash/Phoenix application
  """

  require Logger

  def run do
    Logger.info("🚀 Starting UUID v7 enforcement...")

    # Start the app
    {:ok, _} = Application.ensure_all_started(:dirup)

    # Step 1: Ensure UUID v7 function exists
    ensure_uuid_v7_function()

    # Step 2: Find all tables with UUID columns
    tables = find_uuid_tables()

    # Step 3: Update all UUID columns to use v7
    update_all_tables(tables)

    # Step 4: Update all Ash resources
    update_ash_resources()

    # Step 5: Verify everything
    verify_uuid_v7()

    Logger.info("✅ UUID v7 enforcement complete!")
  end

  defp ensure_uuid_v7_function do
    Logger.info("Ensuring UUID v7 function exists...")

    Ecto.Adapters.SQL.query!(Dirup.Repo, """
    -- Drop old function if exists
    DROP FUNCTION IF EXISTS uuid_generate_v7() CASCADE;

    -- Create optimized UUID v7 function
    CREATE OR REPLACE FUNCTION uuid_generate_v7()
    RETURNS UUID AS $$
    DECLARE
      unix_millis BIGINT;
      uuid_bytes BYTEA;
    BEGIN
      -- Get current timestamp in milliseconds
      unix_millis := (extract(epoch FROM clock_timestamp()) * 1000)::BIGINT;
      
      -- Generate random bytes
      uuid_bytes := gen_random_bytes(16);
      
      -- Set timestamp (48 bits)
      uuid_bytes := set_byte(uuid_bytes, 0, (unix_millis >> 40)::BIT(8)::INT);
      uuid_bytes := set_byte(uuid_bytes, 1, (unix_millis >> 32)::BIT(8)::INT);
      uuid_bytes := set_byte(uuid_bytes, 2, (unix_millis >> 24)::BIT(8)::INT);
      uuid_bytes := set_byte(uuid_bytes, 3, (unix_millis >> 16)::BIT(8)::INT);
      uuid_bytes := set_byte(uuid_bytes, 4, (unix_millis >> 8)::BIT(8)::INT);
      uuid_bytes := set_byte(uuid_bytes, 5, unix_millis::BIT(8)::INT);
      
      -- Set version (0111 = 7) and variant (10)
      uuid_bytes := set_byte(uuid_bytes, 6, 
        ((substring(uuid_bytes FROM 7 FOR 1)::BIT(8) & b'00001111') | b'01110000')::BIT(8)::INT
      );
      uuid_bytes := set_byte(uuid_bytes, 8, 
        ((substring(uuid_bytes FROM 9 FOR 1)::BIT(8) & b'00111111') | b'10000000')::BIT(8)::INT
      );
      
      RETURN encode(uuid_bytes, 'hex')::UUID;
    END;
    $$ LANGUAGE plpgsql VOLATILE;
    """)

    # Also create Ash wrapper
    Ecto.Adapters.SQL.query!(Dirup.Repo, """
    CREATE OR REPLACE FUNCTION ash_uuidv7_generate()
    RETURNS UUID AS $$
      SELECT uuid_generate_v7();
    $$ LANGUAGE SQL VOLATILE;
    """)

    Logger.info("✓ UUID v7 functions created")
  end

  defp find_uuid_tables do
    Logger.info("Finding all tables with UUID columns...")

    result =
      Ecto.Adapters.SQL.query!(Dirup.Repo, """
      SELECT DISTINCT 
        c.table_name,
        c.column_name,
        c.column_default,
        c.is_nullable,
        CASE 
          WHEN tc.constraint_type = 'PRIMARY KEY' THEN true
          ELSE false
        END as is_primary_key,
        CASE
          WHEN tc.constraint_type = 'FOREIGN KEY' THEN true
          ELSE false
        END as is_foreign_key
      FROM information_schema.columns c
      LEFT JOIN information_schema.key_column_usage kcu 
        ON c.table_name = kcu.table_name 
        AND c.column_name = kcu.column_name
      LEFT JOIN information_schema.table_constraints tc
        ON kcu.constraint_name = tc.constraint_name
      WHERE c.data_type = 'uuid'
        AND c.table_schema = 'public'
        AND c.table_name NOT LIKE 'schema_%'
      ORDER BY c.table_name, c.column_name;
      """)

    tables =
      Enum.map(result.rows, fn [table, column, default, nullable, is_pk, is_fk] ->
        %{
          table: table,
          column: column,
          current_default: default,
          nullable: nullable == "YES",
          is_primary_key: is_pk,
          is_foreign_key: is_fk
        }
      end)

    Logger.info("Found #{length(tables)} UUID columns across tables")
    tables
  end

  defp update_all_tables(tables) do
    Logger.info("Updating all UUID columns to use UUID v7...")

    tables
    |> Enum.group_by(& &1.table)
    |> Enum.each(fn {table_name, columns} ->
      update_table(table_name, columns)
    end)
  end

  defp update_table(table_name, columns) do
    Logger.info("Updating table: #{table_name}")

    Enum.each(columns, fn col ->
      # Only update defaults for non-FK columns
      if !col.is_foreign_key && col.column == "id" do
        case col.current_default do
          nil ->
            # No default, add UUID v7
            alter_query = """
            ALTER TABLE #{table_name} 
            ALTER COLUMN #{col.column} 
            SET DEFAULT uuid_generate_v7();
            """

            execute_safe(alter_query, "Set default for #{table_name}.#{col.column}")

          "gen_random_uuid()" ->
            # Replace v4 with v7
            alter_query = """
            ALTER TABLE #{table_name} 
            ALTER COLUMN #{col.column} 
            SET DEFAULT uuid_generate_v7();
            """

            execute_safe(alter_query, "Replace v4 with v7 for #{table_name}.#{col.column}")

          default when is_binary(default) ->
            if String.contains?(default, "uuid_generate_v7") do
              Logger.info("  ✓ #{col.column} already uses UUID v7")
            else
              # Replace any other UUID function
              alter_query = """
              ALTER TABLE #{table_name} 
              ALTER COLUMN #{col.column} 
              SET DEFAULT uuid_generate_v7();
              """

              execute_safe(alter_query, "Update default for #{table_name}.#{col.column}")
            end
        end
      end
    end)
  end

  defp execute_safe(query, description) do
    try do
      Ecto.Adapters.SQL.query!(Dirup.Repo, query)
      Logger.info("  ✓ #{description}")
    rescue
      e ->
        Logger.warning("  ⚠ Failed: #{description} - #{inspect(e)}")
    end
  end

  defp update_ash_resources do
    Logger.info("Generating Ash resource update file...")

    # Find all Ash resource files
    resource_files =
      Path.wildcard("lib/kyozo/**/*.ex")
      |> Enum.filter(&String.contains?(&1, ["workspaces", "accounts", "billing"]))
      |> Enum.filter(&(File.read!(&1) |> String.contains?("use Ash.Resource")))

    Logger.info("Found #{length(resource_files)} Ash resource files")

    # Generate update instructions
    instructions =
      Enum.map(resource_files, fn file ->
        """
        # File: #{file}
        # Ensure the resource uses UUID v7:

        attributes do
          uuid_primary_key :id do
            type :uuid_v7
            default nil       # Let PostgreSQL handle it
            generated? true   # Database generates it
          end
        end
        """
      end)

    File.write!("uuid_v7_resource_updates.txt", Enum.join(instructions, "\n\n"))
    Logger.info("  ✓ Written resource update instructions to uuid_v7_resource_updates.txt")
  end

  defp verify_uuid_v7 do
    Logger.info("Verifying UUID v7 setup...")

    # Test function exists
    result =
      Ecto.Adapters.SQL.query!(Dirup.Repo, """
      SELECT 
        uuid_generate_v7() as v7_uuid,
        gen_random_uuid() as v4_uuid;
      """)

    [[v7, v4]] = result.rows
    Logger.info("  Sample UUID v7: #{v7}")
    Logger.info("  Sample UUID v4: #{v4}")

    # Check all tables
    result =
      Ecto.Adapters.SQL.query!(Dirup.Repo, """
      SELECT 
        table_name,
        column_name,
        column_default
      FROM information_schema.columns
      WHERE data_type = 'uuid'
        AND column_default IS NOT NULL
        AND table_schema = 'public'
      ORDER BY table_name;
      """)

    Logger.info("\n📊 UUID Column Report:")
    Logger.info("=" |> String.duplicate(60))

    Enum.each(result.rows, fn [table, column, default] ->
      status =
        cond do
          String.contains?(default || "", "uuid_generate_v7") -> "✅ v7"
          String.contains?(default || "", "gen_random_uuid") -> "⚠️  v4"
          true -> "❓ other"
        end

      Logger.info(
        "#{String.pad_trailing(table, 30)} #{String.pad_trailing(column, 20)} #{status}"
      )
    end)

    Logger.info("=" |> String.duplicate(60))
  end
end

# Run it!
UUIDv7Enforcer.run()
