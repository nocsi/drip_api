defmodule Dirup.Storage.Providers.Ram do
  @moduledoc """
  In-memory storage provider for the Kyozo storage
  system.

  Provides fast, temporary storage using ETS tables with optional
  persistence and versioning capabilities. Data is lost on application restart.
  """

  require Logger

  @table_name :dirup_ram_storage
  @versions_table_name :dirup_ram_storage_versions

  @doc """
  Initialize the RAM storage tables.
  """
  def init do
    create_tables()
  end

  @doc """
  Write content to RAM storage.
  """
  def write(locator_id, content, opts \\ []) when is_binary(locator_id) and is_binary(content) do
    Logger.debug("Writing to RAM storage", locator_id: locator_id, size: byte_size(content))

    ensure_tables()

    record = %{
      locator_id: locator_id,
      content: content,
      size: byte_size(content),
      stored_at: DateTime.utc_now(),
      storage_backend: :ram
    }

    :ets.insert(@table_name, {locator_id, record})

    {:ok, Map.delete(record, :content)}
  end

  @doc """
  Read content from RAM storage.
  """
  def read(locator_id, opts \\ []) when is_binary(locator_id) do
    Logger.debug("Reading from RAM storage", locator_id: locator_id)

    ensure_tables()

    case :ets.lookup(@table_name, locator_id) do
      [{^locator_id, record}] ->
        {:ok, record.content}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Delete content from RAM storage.
  """
  def delete(locator_id, opts \\ []) when is_binary(locator_id) do
    Logger.debug("Deleting from RAM storage", locator_id: locator_id)

    ensure_tables()

    :ets.delete(@table_name, locator_id)
    # Also clean up versions
    :ets.match_delete(@versions_table_name, {{locator_id, :_}, :_})

    :ok
  end

  @doc """
  Create a new version of content in RAM storage.
  """
  def create_version(locator_id, content, commit_message, opts \\ []) do
    version_id = generate_version_id()

    Logger.debug("Creating RAM storage version",
      locator_id: locator_id,
      version_id: version_id,
      commit_message: commit_message
    )

    ensure_tables()

    version_record = %{
      version_id: version_id,
      locator_id: locator_id,
      content: content,
      size: byte_size(content),
      commit_message: commit_message,
      created_at: DateTime.utc_now(),
      storage_backend: :ram
    }

    # Store the version
    :ets.insert(@versions_table_name, {{locator_id, version_id}, version_record})

    # Update the main record
    case write(locator_id, content, opts) do
      {:ok, _} ->
        {:ok, version_id, Map.delete(version_record, :content)}

      error ->
        # Clean up the version record if main write failed
        :ets.delete(@versions_table_name, {locator_id, version_id})
        error
    end
  end

  @doc """
  List all versions for a given file.
  """
  def list_versions(locator_id, opts \\ []) do
    Logger.debug("Listing RAM storage versions", locator_id: locator_id)

    ensure_tables()

    pattern = {{locator_id, :"$1"}, :"$2"}
    guard = []
    result = [:"$2"]

    versions =
      :ets.select(@versions_table_name, [{pattern, guard, result}])
      |> Enum.map(&Map.delete(&1, :content))
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    {:ok, versions}
  end

  @doc """
  Get a specific version of content.
  """
  def get_version(locator_id, version_id, opts \\ []) do
    Logger.debug("Getting RAM storage version",
      locator_id: locator_id,
      version_id: version_id
    )

    ensure_tables()

    case :ets.lookup(@versions_table_name, {locator_id, version_id}) do
      [{{^locator_id, ^version_id}, record}] ->
        {:ok, record.content}

      [] ->
        {:error, :version_not_found}
    end
  end

  @doc """
  Check if a file exists in RAM storage.
  """
  def exists?(locator_id, opts \\ []) do
    ensure_tables()
    :ets.member(@table_name, locator_id)
  end

  @doc """
  Get file information from RAM storage.
  """
  def stat(locator_id, opts \\ []) do
    ensure_tables()

    case :ets.lookup(@table_name, locator_id) do
      [{^locator_id, record}] ->
        {:ok,
         %{
           size: record.size,
           modified_at: record.stored_at,
           storage_backend: :ram
         }}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  List all files in RAM storage.
  """
  def list_files(opts \\ []) do
    ensure_tables()

    pattern = {:"$1", :"$2"}
    guard = []
    result = [:"$1"]

    files = :ets.select(@table_name, [{pattern, guard, result}])

    {:ok, files}
  end

  @doc """
  Get storage statistics.
  """
  def get_stats(opts \\ []) do
    ensure_tables()

    file_count = :ets.info(@table_name, :size)
    version_count = :ets.info(@versions_table_name, :size)
    memory_usage = :ets.info(@table_name, :memory) + :ets.info(@versions_table_name, :memory)

    total_size =
      :ets.foldl(
        fn {_id, record}, acc ->
          acc + record.size
        end,
        0,
        @table_name
      )

    {:ok,
     %{
       file_count: file_count,
       version_count: version_count,
       total_size: total_size,
       memory_usage_words: memory_usage,
       storage_backend: :ram
     }}
  end

  @doc """
  Clear all data from RAM storage.
  """
  def clear_all(opts \\ []) do
    Logger.warn("Clearing all RAM storage data")

    ensure_tables()

    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(@versions_table_name)

    :ok
  end

  @doc """
  Export all data from RAM storage (for persistence).
  """
  def export_data(opts \\ []) do
    ensure_tables()

    main_data = :ets.tab2list(@table_name)
    version_data = :ets.tab2list(@versions_table_name)

    {:ok,
     %{
       main_data: main_data,
       version_data: version_data,
       exported_at: DateTime.utc_now()
     }}
  end

  @doc """
  Import data into RAM storage (for persistence restoration).
  """
  def import_data(data, opts \\ []) when is_map(data) do
    Logger.info("Importing data into RAM storage")

    ensure_tables()

    # Clear existing data first if specified
    if Keyword.get(opts, :clear_first, false) do
      clear_all()
    end

    # Import main data
    if main_data = data[:main_data] do
      Enum.each(main_data, fn record ->
        :ets.insert(@table_name, record)
      end)
    end

    # Import version data
    if version_data = data[:version_data] do
      Enum.each(version_data, fn record ->
        :ets.insert(@versions_table_name, record)
      end)
    end

    :ok
  end

  # Private helper functions

  defp ensure_tables do
    unless :ets.whereis(@table_name) != :undefined do
      create_tables()
    end

    :ok
  end

  defp create_tables do
    # Main storage table
    :ets.new(@table_name, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    # Versions table - using compound key {locator_id, version_id}
    :ets.new(@versions_table_name, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    Logger.info("RAM storage tables created")
    :ok
  rescue
    ArgumentError ->
      # Tables already exist
      :ok
  end

  defp generate_version_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
