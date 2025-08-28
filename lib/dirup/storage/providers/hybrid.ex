defmodule Dirup.Storage.Providers.Hybrid do
  @moduledoc """
  Hybrid storage provider for the Kyozo storage system.

  Combines multiple storage backends for optimal performance and reliability.
  Uses fast storage (RAM/Disk) for hot data and slower storage (S3) for cold data.
  Provides intelligent data tiering and automatic failover between providers.
  """

  require Logger

  alias Dirup.Storage.Providers.{Ram, Disk, S3}

  @default_hot_storage :ram
  @default_cold_storage :s3
  @default_backup_storage :disk
  # 1 hour in seconds
  @hot_storage_ttl 3600
  # Promote to hot after 5 accesses
  @access_threshold 5

  @doc """
  Write content to hybrid storage with intelligent tiering.
  """
  def write(locator_id, content, opts \\ []) when is_binary(locator_id) and is_binary(content) do
    Logger.debug("Writing to hybrid storage",
      locator_id: locator_id,
      size: byte_size(content)
    )

    hot_storage = get_storage_backend(:hot, opts)
    cold_storage = get_storage_backend(:cold, opts)
    backup_storage = get_storage_backend(:backup, opts)

    # Always write to hot storage first for immediate access
    with {:ok, hot_result} <- write_to_backend(hot_storage, locator_id, content, opts),
         # Asynchronously write to cold storage for durability
         {:ok, cold_result} <- write_to_backend(cold_storage, locator_id, content, opts),
         # Write to backup storage if different from cold
         {:ok, backup_result} <-
           maybe_write_backup(backup_storage, cold_storage, locator_id, content, opts) do
      # Track access pattern
      track_access(locator_id, :write)

      {:ok,
       %{
         locator_id: locator_id,
         size: byte_size(content),
         stored_at: DateTime.utc_now(),
         storage_backend: :hybrid,
         hot_storage: hot_storage,
         cold_storage: cold_storage,
         backup_storage: backup_storage,
         hot_result: sanitize_result(hot_result),
         cold_result: sanitize_result(cold_result),
         backup_result: sanitize_result(backup_result)
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to write to hybrid storage",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not write to hybrid storage: #{inspect(reason)}"}
    end
  end

  @doc """
  Read content from hybrid storage with intelligent caching.
  """
  def read(locator_id, opts \\ []) when is_binary(locator_id) do
    Logger.debug("Reading from hybrid storage", locator_id: locator_id)

    hot_storage = get_storage_backend(:hot, opts)
    cold_storage = get_storage_backend(:cold, opts)
    backup_storage = get_storage_backend(:backup, opts)

    # Try hot storage first (fastest)
    case read_from_backend(hot_storage, locator_id, opts) do
      {:ok, content} ->
        track_access(locator_id, :read_hot)
        {:ok, content}

      {:error, :not_found} ->
        # Try cold storage
        case read_from_backend(cold_storage, locator_id, opts) do
          {:ok, content} ->
            # Promote to hot storage if accessed frequently
            maybe_promote_to_hot(locator_id, content, opts)
            track_access(locator_id, :read_cold)
            {:ok, content}

          {:error, :not_found} when backup_storage != cold_storage ->
            # Try backup storage as last resort
            case read_from_backend(backup_storage, locator_id, opts) do
              {:ok, content} ->
                # Restore to hot and cold storage
                restore_to_primary_storages(locator_id, content, opts)
                track_access(locator_id, :read_backup)
                {:ok, content}

              {:error, reason} ->
                Logger.error("Failed to read from any hybrid storage backend",
                  locator_id: locator_id,
                  error: reason
                )

                {:error, :not_found}
            end

          {:error, reason} ->
            Logger.error("Failed to read from hybrid storage",
              locator_id: locator_id,
              error: reason
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to read from hot storage, trying cold",
          locator_id: locator_id,
          hot_storage: hot_storage,
          error: reason
        )

        # Fall back to cold storage read
        read_from_backend(cold_storage, locator_id, opts)
    end
  end

  @doc """
  Delete content from all hybrid storage backends.
  """
  def delete(locator_id, opts \\ []) when is_binary(locator_id) do
    Logger.debug("Deleting from hybrid storage", locator_id: locator_id)

    hot_storage = get_storage_backend(:hot, opts)
    cold_storage = get_storage_backend(:cold, opts)
    backup_storage = get_storage_backend(:backup, opts)

    results = %{
      hot: delete_from_backend(hot_storage, locator_id, opts),
      cold: delete_from_backend(cold_storage, locator_id, opts),
      backup:
        if(backup_storage != cold_storage,
          do: delete_from_backend(backup_storage, locator_id, opts),
          else: :ok
        )
    }

    # Clean up access tracking
    cleanup_access_tracking(locator_id)

    # Consider success if at least one backend succeeded
    if Enum.any?(Map.values(results), &(&1 == :ok)) do
      :ok
    else
      Logger.error("Failed to delete from all hybrid storage backends",
        locator_id: locator_id,
        results: results
      )

      {:error, "Could not delete from any storage backend"}
    end
  end

  @doc """
  Create a new version in hybrid storage.
  """
  def create_version(locator_id, content, commit_message, opts \\ []) do
    Logger.debug("Creating hybrid storage version",
      locator_id: locator_id,
      commit_message: commit_message
    )

    cold_storage = get_storage_backend(:cold, opts)
    version_id = generate_version_id()

    # Create version in cold storage for persistence
    case create_version_in_backend(cold_storage, locator_id, content, commit_message, opts) do
      {:ok, backend_version_id, metadata} ->
        # Update hot storage with new content
        hot_storage = get_storage_backend(:hot, opts)
        write_to_backend(hot_storage, locator_id, content, opts)

        # Use cold storage version ID or generated one
        final_version_id = backend_version_id || version_id

        {:ok, final_version_id,
         Map.merge(metadata, %{
           storage_backend: :hybrid,
           version_storage: cold_storage,
           promoted_to_hot: true
         })}

      {:error, reason} ->
        Logger.error("Failed to create hybrid storage version",
          locator_id: locator_id,
          error: reason
        )

        {:error, reason}
    end
  end

  @doc """
  List versions from the cold storage backend.
  """
  def list_versions(locator_id, opts \\ []) do
    cold_storage = get_storage_backend(:cold, opts)

    case list_versions_from_backend(cold_storage, locator_id, opts) do
      {:ok, versions} ->
        # Add hybrid metadata to versions
        hybrid_versions =
          Enum.map(versions, fn version ->
            Map.put(version, :storage_backend, :hybrid)
          end)

        {:ok, hybrid_versions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get a specific version from hybrid storage.
  """
  def get_version(locator_id, version_id, opts \\ []) do
    cold_storage = get_storage_backend(:cold, opts)

    case get_version_from_backend(cold_storage, locator_id, version_id, opts) do
      {:ok, content} ->
        # Optionally promote version to hot storage if accessed
        maybe_promote_version_to_hot(locator_id, version_id, content, opts)
        {:ok, content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if content exists in any storage backend.
  """
  def exists?(locator_id, opts \\ []) do
    hot_storage = get_storage_backend(:hot, opts)
    cold_storage = get_storage_backend(:cold, opts)

    exists_in_backend?(hot_storage, locator_id, opts) ||
      exists_in_backend?(cold_storage, locator_id, opts)
  end

  @doc """
  Get file statistics from the most appropriate backend.
  """
  def stat(locator_id, opts \\ []) do
    hot_storage = get_storage_backend(:hot, opts)
    cold_storage = get_storage_backend(:cold, opts)

    # Try hot storage first, then cold
    case stat_from_backend(hot_storage, locator_id, opts) do
      {:ok, stat_info} ->
        {:ok, Map.put(stat_info, :storage_backend, :hybrid)}

      {:error, :not_found} ->
        case stat_from_backend(cold_storage, locator_id, opts) do
          {:ok, stat_info} ->
            {:ok, Map.put(stat_info, :storage_backend, :hybrid)}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Get hybrid storage statistics and health information.
  """
  def get_storage_stats(opts \\ []) do
    hot_storage = get_storage_backend(:hot, opts)
    cold_storage = get_storage_backend(:cold, opts)
    backup_storage = get_storage_backend(:backup, opts)

    hot_stats = get_backend_stats(hot_storage, opts)
    cold_stats = get_backend_stats(cold_storage, opts)

    backup_stats =
      if backup_storage != cold_storage,
        do: get_backend_stats(backup_storage, opts),
        else: %{message: "Same as cold storage"}

    {:ok,
     %{
       storage_backend: :hybrid,
       hot_storage: %{backend: hot_storage, stats: hot_stats},
       cold_storage: %{backend: cold_storage, stats: cold_stats},
       backup_storage: %{backend: backup_storage, stats: backup_stats},
       access_patterns: get_access_patterns(),
       configuration: %{
         hot_storage_ttl: @hot_storage_ttl,
         access_threshold: @access_threshold
       }
     }}
  end

  @doc """
  Manually trigger data tiering operations.
  """
  def trigger_tiering(opts \\ []) do
    Logger.info("Triggering hybrid storage tiering")

    # Move cold data from hot storage to cold storage only
    demote_cold_data(opts)

    # Clean up expired access patterns
    cleanup_expired_access_patterns()

    :ok
  end

  # Private helper functions

  defp get_storage_backend(:hot, opts) do
    Keyword.get(opts, :hot_storage, @default_hot_storage)
  end

  defp get_storage_backend(:cold, opts) do
    Keyword.get(opts, :cold_storage, @default_cold_storage)
  end

  defp get_storage_backend(:backup, opts) do
    Keyword.get(opts, :backup_storage, @default_backup_storage)
  end

  defp write_to_backend(:ram, locator_id, content, opts) do
    Ram.write(locator_id, content, opts)
  end

  defp write_to_backend(:disk, locator_id, content, opts) do
    Disk.write(locator_id, content, opts)
  end

  defp write_to_backend(:s3, locator_id, content, opts) do
    S3.write(locator_id, content, opts)
  end

  defp read_from_backend(:ram, locator_id, opts) do
    Ram.read(locator_id, opts)
  end

  defp read_from_backend(:disk, locator_id, opts) do
    Disk.read(locator_id, opts)
  end

  defp read_from_backend(:s3, locator_id, opts) do
    S3.read(locator_id, opts)
  end

  defp delete_from_backend(:ram, locator_id, opts) do
    Ram.delete(locator_id, opts)
  end

  defp delete_from_backend(:disk, locator_id, opts) do
    Disk.delete(locator_id, opts)
  end

  defp delete_from_backend(:s3, locator_id, opts) do
    S3.delete(locator_id, opts)
  end

  defp create_version_in_backend(:ram, locator_id, content, commit_message, opts) do
    Ram.create_version(locator_id, content, commit_message, opts)
  end

  defp create_version_in_backend(:disk, locator_id, content, commit_message, opts) do
    Disk.create_version(locator_id, content, commit_message, opts)
  end

  defp create_version_in_backend(:s3, locator_id, content, commit_message, opts) do
    S3.create_version(locator_id, content, commit_message, opts)
  end

  defp list_versions_from_backend(:ram, locator_id, opts) do
    Ram.list_versions(locator_id, opts)
  end

  defp list_versions_from_backend(:disk, locator_id, opts) do
    Disk.list_versions(locator_id, opts)
  end

  defp list_versions_from_backend(:s3, locator_id, opts) do
    S3.list_versions(locator_id, opts)
  end

  defp get_version_from_backend(:ram, locator_id, version_id, opts) do
    Ram.get_version(locator_id, version_id, opts)
  end

  defp get_version_from_backend(:disk, locator_id, version_id, opts) do
    Disk.get_version(locator_id, version_id, opts)
  end

  defp get_version_from_backend(:s3, locator_id, version_id, opts) do
    S3.get_version(locator_id, version_id, opts)
  end

  defp exists_in_backend?(:ram, locator_id, opts) do
    Ram.exists?(locator_id, opts)
  end

  defp exists_in_backend?(:disk, locator_id, opts) do
    Disk.exists?(locator_id, opts)
  end

  defp exists_in_backend?(:s3, locator_id, opts) do
    S3.exists?(locator_id, opts)
  end

  defp stat_from_backend(:ram, locator_id, opts) do
    Ram.stat(locator_id, opts)
  end

  defp stat_from_backend(:disk, locator_id, opts) do
    Disk.stat(locator_id, opts)
  end

  defp stat_from_backend(:s3, locator_id, opts) do
    S3.stat(locator_id, opts)
  end

  defp maybe_write_backup(backup_storage, cold_storage, _locator_id, _content, _opts)
       when backup_storage == cold_storage do
    {:ok, %{skipped: "same as cold storage"}}
  end

  defp maybe_write_backup(backup_storage, _cold_storage, locator_id, content, opts) do
    write_to_backend(backup_storage, locator_id, content, opts)
  end

  defp maybe_promote_to_hot(locator_id, content, opts) do
    access_count = get_access_count(locator_id)

    if access_count >= @access_threshold do
      hot_storage = get_storage_backend(:hot, opts)
      write_to_backend(hot_storage, locator_id, content, opts)
      Logger.debug("Promoted to hot storage", locator_id: locator_id, access_count: access_count)
    end
  end

  defp maybe_promote_version_to_hot(locator_id, version_id, content, opts) do
    # Only promote if it's a recent version access
    hot_storage = get_storage_backend(:hot, opts)
    write_to_backend(hot_storage, "#{locator_id}@#{version_id}", content, opts)
  end

  defp restore_to_primary_storages(locator_id, content, opts) do
    hot_storage = get_storage_backend(:hot, opts)
    cold_storage = get_storage_backend(:cold, opts)

    # Restore to both hot and cold
    write_to_backend(hot_storage, locator_id, content, opts)
    write_to_backend(cold_storage, locator_id, content, opts)

    Logger.info("Restored from backup", locator_id: locator_id)
  end

  defp track_access(locator_id, operation) do
    # Store access patterns in ETS table for tiering decisions
    table_name = :hybrid_storage_access_patterns
    ensure_access_table(table_name)

    timestamp = System.system_time(:second)

    case :ets.lookup(table_name, locator_id) do
      [{^locator_id, %{count: count, last_access: _last, operations: ops}}] ->
        # Keep last 10 operations
        new_ops = [operation | Enum.take(ops, 9)]

        :ets.insert(
          table_name,
          {locator_id,
           %{
             count: count + 1,
             last_access: timestamp,
             operations: new_ops
           }}
        )

      [] ->
        :ets.insert(
          table_name,
          {locator_id,
           %{
             count: 1,
             last_access: timestamp,
             operations: [operation]
           }}
        )
    end
  end

  defp get_access_count(locator_id) do
    table_name = :hybrid_storage_access_patterns
    ensure_access_table(table_name)

    case :ets.lookup(table_name, locator_id) do
      [{^locator_id, %{count: count}}] -> count
      [] -> 0
    end
  end

  defp cleanup_access_tracking(locator_id) do
    table_name = :hybrid_storage_access_patterns
    ensure_access_table(table_name)
    :ets.delete(table_name, locator_id)
  end

  defp ensure_access_table(table_name) do
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :set, :public, {:read_concurrency, true}])

      _ ->
        :ok
    end
  end

  defp get_access_patterns do
    table_name = :hybrid_storage_access_patterns
    ensure_access_table(table_name)

    :ets.tab2list(table_name)
    |> Enum.map(fn {locator_id, pattern} ->
      {locator_id, pattern}
    end)
    |> Map.new()
  end

  defp cleanup_expired_access_patterns do
    table_name = :hybrid_storage_access_patterns
    ensure_access_table(table_name)

    current_time = System.system_time(:second)
    # 2x TTL
    expired_threshold = current_time - @hot_storage_ttl * 2

    pattern = {:"$1", %{last_access: :"$2", count: :"$3", operations: :"$4"}}
    guards = [{:<, :"$2", expired_threshold}]

    :ets.select_delete(table_name, [{pattern, guards, [true]}])
  end

  defp demote_cold_data(opts) do
    # This would implement logic to move rarely accessed data from hot to cold storage
    # For now, just log the operation
    Logger.debug("Demoting cold data from hot storage")
  end

  defp get_backend_stats(:ram, _opts) do
    case Ram.get_stats() do
      {:ok, stats} -> stats
      {:error, _} -> %{error: "Could not get RAM stats"}
    end
  end

  defp get_backend_stats(_backend, _opts) do
    %{message: "Stats not implemented for this backend"}
  end

  defp sanitize_result(result) when is_map(result) do
    # Remove sensitive information from results
    result
    |> Map.drop([:content, :api_key, :credentials])
    |> Map.take([:locator_id, :size, :stored_at, :storage_backend, :version])
  end

  defp sanitize_result(result), do: result

  defp generate_version_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
