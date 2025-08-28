Mix.Task.run("app.start")

IO.puts("\n🔍 UUID Configuration Check\n")

# Check database functions
{:ok, result} =
  Ecto.Adapters.SQL.query(
    Dirup.Repo,
    "SELECT proname FROM pg_proc WHERE proname LIKE '%uuid%'",
    []
  )

IO.puts("UUID Functions Available:")
Enum.each(result.rows, fn [name] -> IO.puts("  • #{name}") end)

# Check all tables
{:ok, result} =
  Ecto.Adapters.SQL.query(
    Dirup.Repo,
    """
    SELECT 
      table_name,
      column_name,
      column_default,
      CASE 
        WHEN column_default LIKE '%uuid_generate_v7%' THEN '✅ v7'
        WHEN column_default LIKE '%gen_random_uuid%' THEN '⚠️  v4'
        WHEN column_default IS NULL THEN '❌ none'
        ELSE '❓ other'
      END as status
    FROM information_schema.columns
    WHERE data_type = 'uuid'
      AND table_schema = 'public'
    ORDER BY table_name, column_name
    """,
    []
  )

IO.puts("\n📊 UUID Columns Status:")
IO.puts(String.duplicate("=", 80))
IO.puts("#{String.pad_trailing("Table", 30)} #{String.pad_trailing("Column", 20)} Status")
IO.puts(String.duplicate("-", 80))

Enum.each(result.rows, fn [table, column, default, status] ->
  IO.puts("#{String.pad_trailing(table, 30)} #{String.pad_trailing(column, 20)} #{status}")
end)

IO.puts(String.duplicate("=", 80))

# Test generation
{:ok, result} =
  Ecto.Adapters.SQL.query(
    Dirup.Repo,
    "SELECT uuid_generate_v7() as test_uuid",
    []
  )

[[test_uuid]] = result.rows
IO.puts("\n🎯 Test UUID v7: #{test_uuid}")
IO.puts("✅ All checks complete!\n")
