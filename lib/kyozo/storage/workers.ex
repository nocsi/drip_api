defmodule Kyozo.Storage.Workers do
  @moduledoc """
  Oban workers for handling storage operations asynchronously.

  This module contains dedicated workers for different storage operations:
  - ProcessStorageWorker: Processes storage content using appropriate backends
  - CleanupStorageWorker: Cleans up orphaned or scheduled storage resources
  - CreateVersionWorker: Creates versions for versioned storage backends
  - BulkProcessWorker: Handles bulk processing operations
  """

  defmodule ProcessStorageWorker do
    @moduledoc """
    Worker for processing storage content asynchronously.

    This worker handles the actual storage of content using the appropriate
    storage backend (Git, S3, disk, RAM, or hybrid).
    """

    use Oban.Worker,
      queue: :storage_processing,
      max_attempts: 3,
      unique: [period: 60, states: [:available, :scheduled]]

    require Ash.Query
    alias Kyozo.Storage.StorageResource

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"storage_resource_id" => storage_resource_id} = args}) do
      case get_storage_resource(storage_resource_id) do
        {:ok, storage_resource} ->
          process_storage_content(storage_resource, args)

        {:error, :not_found} ->
          {:discard, "Storage resource not found: #{storage_resource_id}"}

        {:error, reason} ->
          {:error, "Failed to retrieve storage resource: #{inspect(reason)}"}
      end
    end

    def perform(%Oban.Job{args: invalid_args}) do
      {:discard, "Invalid job arguments: #{inspect(invalid_args)}"}
    end

    defp get_storage_resource(id) do
      StorageResource
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.load([:storage_info])
      |> Ash.read_one()
      |> case do
        {:ok, nil} -> {:error, :not_found}
        result -> result
      end
    end

    defp process_storage_content(storage_resource, args) do
      content = Map.get(args, "content")
      storage_options = Map.get(args, "storage_options", %{})

      # Get content from existing storage if not provided
      content = case content do
        nil ->
          case StorageResource.retrieve_content(storage_resource) do
            {:ok, existing_content} -> existing_content
            _ -> nil
          end
        provided_content -> provided_content
      end

      if content do
        provider = get_storage_provider(storage_resource.storage_backend)

        case provider.write(storage_resource.locator_id, content, storage_options) do
          {:ok, metadata} ->
            update_success_metadata(storage_resource, metadata)
            :ok

          {:error, reason} ->
            update_error_metadata(storage_resource, reason)
            {:error, reason}
        end
      else
        update_error_metadata(storage_resource, "No content available for processing")
        {:error, "No content available for processing"}
      end
    end

    defp update_success_metadata(storage_resource, provider_metadata) do
      updated_metadata =
        storage_resource.storage_metadata
        |> Kernel.||((%{}))
        |> Map.merge(provider_metadata)
        |> Map.put("processed", true)
        |> Map.put("processed_at", DateTime.utc_now())
        |> Map.put("last_processed_by", "ProcessStorageWorker")

      StorageResource
      |> Ash.Changeset.for_update(:update, storage_resource, %{storage_metadata: updated_metadata})
      |> Ash.update()
    end

    defp update_error_metadata(storage_resource, reason) do
      updated_metadata =
        storage_resource.storage_metadata
        |> Kernel.||((%{}))
        |> Map.put("processed", false)
        |> Map.put("last_error", to_string(reason))
        |> Map.put("last_error_at", DateTime.utc_now())
        |> Map.put("last_processed_by", "ProcessStorageWorker")

      StorageResource
      |> Ash.Changeset.for_update(:update, storage_resource, %{storage_metadata: updated_metadata})
      |> Ash.update()
    end

    defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
    defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
    defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
    defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.RAM
    defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid
  end

  defmodule CleanupStorageWorker do
    @moduledoc """
    Worker for cleaning up storage resources asynchronously.

    This worker handles cleanup of orphaned storage resources, deletion
    of content from storage backends, and maintenance operations.
    """

    use Oban.Worker,
      queue: :storage_cleanup,
      max_attempts: 2,
      unique: [period: 300, states: [:available, :scheduled]]

    require Ash.Query
    alias Kyozo.Storage.StorageResource

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"storage_resource_id" => storage_resource_id} = args}) do
      case get_storage_resource(storage_resource_id) do
        {:ok, storage_resource} ->
          cleanup_storage_resource(storage_resource, args)

        {:error, :not_found} ->
          {:discard, "Storage resource not found: #{storage_resource_id}"}

        {:error, reason} ->
          {:error, "Failed to retrieve storage resource: #{inspect(reason)}"}
      end
    end

    def perform(%Oban.Job{args: %{"bulk_cleanup" => true} = args}) do
      perform_bulk_cleanup(args)
    end

    def perform(%Oban.Job{args: invalid_args}) do
      {:discard, "Invalid job arguments: #{inspect(invalid_args)}"}
    end

    defp get_storage_resource(id) do
      StorageResource
      |> Ash.Query.filter(id == ^id)
      |> Ash.read_one()
      |> case do
        {:ok, nil} -> {:error, :not_found}
        result -> result
      end
    end

    defp cleanup_storage_resource(storage_resource, _args) do
      provider = get_storage_provider(storage_resource.storage_backend)

      case provider.delete(storage_resource.locator_id) do
        :ok ->
          update_cleanup_success_metadata(storage_resource)
          :ok

        {:error, reason} ->
          update_cleanup_error_metadata(storage_resource, reason)
          {:error, reason}
      end
    end

    defp perform_bulk_cleanup(args) do
      # Find orphaned storage resources
      cleanup_criteria = Map.get(args, "criteria", %{})
      max_age_hours = Map.get(cleanup_criteria, "max_age_hours", 24)
      cutoff_time = DateTime.add(DateTime.utc_now(), -max_age_hours, :hour)

      query = StorageResource
      |> Ash.Query.filter(storage_metadata["cleanup_scheduled"] == true)
      |> Ash.Query.filter(inserted_at < ^cutoff_time)
      |> Ash.Query.limit(100) # Process in batches

      case Ash.read(query) do
        {:ok, resources} ->
          results = Enum.map(resources, fn resource ->
            case cleanup_storage_resource(resource, %{}) do
              :ok -> {:ok, resource.id}
              {:error, reason} -> {:error, resource.id, reason}
            end
          end)

          success_count = Enum.count(results, fn {status, _} -> status == :ok end)
          error_count = Enum.count(results, fn {status, _, _} -> status == :error end)

          if error_count > 0 do
            {:error, "Bulk cleanup completed with errors: #{success_count} success, #{error_count} errors"}
          else
            :ok
          end

        {:error, reason} ->
          {:error, "Failed to query cleanup candidates: #{inspect(reason)}"}
      end
    end

    defp update_cleanup_success_metadata(storage_resource) do
      updated_metadata =
        storage_resource.storage_metadata
        |> Kernel.||((%{}))
        |> Map.put("cleanup_scheduled", false)
        |> Map.put("cleaned_up", true)
        |> Map.put("cleaned_up_at", DateTime.utc_now())
        |> Map.put("cleaned_up_by", "CleanupStorageWorker")

      StorageResource
      |> Ash.Changeset.for_update(:update, storage_resource, %{storage_metadata: updated_metadata})
      |> Ash.update()
    end

    defp update_cleanup_error_metadata(storage_resource, reason) do
      updated_metadata =
        storage_resource.storage_metadata
        |> Kernel.||((%{}))
        |> Map.put("cleanup_scheduled", false)
        |> Map.put("cleanup_failed", true)
        |> Map.put("last_cleanup_error", to_string(reason))
        |> Map.put("last_cleanup_error_at", DateTime.utc_now())
        |> Map.put("cleaned_up_by", "CleanupStorageWorker")

      StorageResource
      |> Ash.Changeset.for_update(:update, storage_resource, %{storage_metadata: updated_metadata})
      |> Ash.update()
    end

    defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
    defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
    defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
    defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.RAM
    defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid
  end

  defmodule CreateVersionWorker do
    @moduledoc """
    Worker for creating versions of storage resources asynchronously.

    This worker handles version creation for versioned storage backends,
    primarily Git-based storage with commit history.
    """

    use Oban.Worker,
      queue: :storage_versions,
      max_attempts: 3,
      unique: [period: 120, states: [:available, :scheduled]]

    require Ash.Query
    alias Kyozo.Storage.StorageResource

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"storage_resource_id" => storage_resource_id} = args}) do
      case get_storage_resource(storage_resource_id) do
        {:ok, storage_resource} ->
          create_storage_version(storage_resource, args)

        {:error, :not_found} ->
          {:discard, "Storage resource not found: #{storage_resource_id}"}

        {:error, reason} ->
          {:error, "Failed to retrieve storage resource: #{inspect(reason)}"}
      end
    end

    def perform(%Oban.Job{args: invalid_args}) do
      {:discard, "Invalid job arguments: #{inspect(invalid_args)}"}
    end

    defp get_storage_resource(id) do
      StorageResource
      |> Ash.Query.filter(id == ^id)
      |> Ash.read_one()
      |> case do
        {:ok, nil} -> {:error, :not_found}
        result -> result
      end
    end

    defp create_storage_version(storage_resource, args) do
      if storage_resource.is_versioned do
        content = get_version_content(storage_resource, args)
        version_name = Map.get(args, "version_name")
        commit_message = Map.get(args, "commit_message", "Automated version update")

        if content do
          provider = get_storage_provider(storage_resource.storage_backend)

          if function_exported?(provider, :create_version, 3) do
            case provider.create_version(storage_resource.locator_id, content, commit_message) do
              {:ok, version_info} ->
                generated_version = version_name || generate_version_name()
                update_version_success_metadata(storage_resource, generated_version, version_info)
                :ok

              {:error, reason} ->
                update_version_error_metadata(storage_resource, reason)
                {:error, reason}
            end
          else
            error_reason = "Storage backend #{storage_resource.storage_backend} does not support versioning"
            update_version_error_metadata(storage_resource, error_reason)
            {:discard, error_reason}
          end
        else
          error_reason = "No content available for version creation"
          update_version_error_metadata(storage_resource, error_reason)
          {:error, error_reason}
        end
      else
        {:discard, "Storage resource does not support versioning"}
      end
    end

    defp get_version_content(storage_resource, args) do
      case Map.get(args, "content") do
        nil ->
          # Try to get scheduled content from metadata first
          case get_in(storage_resource.storage_metadata, ["scheduled_content"]) do
            nil ->
              # Fall back to retrieving existing content
              case StorageResource.retrieve_content(storage_resource) do
                {:ok, existing_content} -> existing_content
                _ -> nil
              end
            scheduled_content -> scheduled_content
          end
        provided_content -> provided_content
      end
    end

    defp update_version_success_metadata(storage_resource, version_name, version_info) do
      updated_metadata =
        storage_resource.storage_metadata
        |> Kernel.||((%{}))
        |> Map.merge(version_info)
        |> Map.put("version_scheduled", false)
        |> Map.put("version_created", true)
        |> Map.put("version_created_at", DateTime.utc_now())
        |> Map.put("last_version", version_name)
        |> Map.put("version_created_by", "CreateVersionWorker")
        |> Map.delete("scheduled_content")
        |> Map.delete("scheduled_version_name")
        |> Map.delete("scheduled_commit_message")

      StorageResource
      |> Ash.Changeset.for_update(:update, storage_resource, %{
        version: version_name,
        storage_metadata: updated_metadata
      })
      |> Ash.update()
    end

    defp update_version_error_metadata(storage_resource, reason) do
      updated_metadata =
        storage_resource.storage_metadata
        |> Kernel.||((%{}))
        |> Map.put("version_scheduled", false)
        |> Map.put("version_creation_failed", true)
        |> Map.put("last_version_error", to_string(reason))
        |> Map.put("last_version_error_at", DateTime.utc_now())
        |> Map.put("version_created_by", "CreateVersionWorker")

      StorageResource
      |> Ash.Changeset.for_update(:update, storage_resource, %{storage_metadata: updated_metadata})
      |> Ash.update()
    end

    defp generate_version_name do
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      "v#{timestamp}"
    end

    defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
    defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
    defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
    defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.RAM
    defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid
  end

  defmodule BulkProcessWorker do
    @moduledoc """
    Worker for handling bulk storage operations.

    This worker processes multiple storage resources in batches,
    useful for maintenance operations and bulk processing tasks.
    """

    use Oban.Worker,
      queue: :storage_bulk,
      max_attempts: 2,
      unique: [period: 600, states: [:available, :scheduled]]

    require Ash.Query
    alias Kyozo.Storage.StorageResource

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) when is_map(args) do
      operation = get_arg(args, "operation") || get_arg(args, :operation)

      case operation do
        op when op in ["process_unprocessed", :process_unprocessed] ->
          batch_size = get_arg(args, "batch_size") || get_arg(args, :batch_size) || 50
          backend_filter = get_arg(args, "backend") || get_arg(args, :backend)
          process_unprocessed(batch_size, backend_filter)

        op when op in ["schedule_maintenance", :schedule_maintenance] ->
          maintenance_type = get_arg(args, "maintenance_type") || get_arg(args, :maintenance_type)
          schedule_maintenance_operation(maintenance_type, args)

        _ ->
          {:discard, "Unknown operation: #{inspect(operation)}"}
      end
    end

    defp get_arg(map, key), do: Map.get(map, key)

    defp process_unprocessed(batch_size, backend_filter) do

      query = StorageResource
      |> Ash.Query.filter(storage_metadata["processed"] != true or is_nil(storage_metadata["processed"]))
      |> Ash.Query.limit(batch_size)

      query = if backend_filter do
        Ash.Query.filter(query, storage_backend == ^String.to_atom(backend_filter))
      else
        query
      end

      case Ash.read(query) do
        {:ok, resources} ->
          process_batch(resources, "process")

        {:error, reason} ->
          {:error, "Failed to query unprocessed resources: #{inspect(reason)}"}
      end
    end

    defp schedule_maintenance_operation(maintenance_type, args) do
      case maintenance_type do
        mt when mt in ["cleanup", :cleanup] -> schedule_cleanup_jobs(args)
        mt when mt in ["version_creation", :version_creation] -> schedule_version_jobs(args)
        mt when mt in ["health_check", :health_check] -> perform_health_check(args)
        _ -> {:discard, "Unknown maintenance type: #{maintenance_type}"}
      end
    end

    def perform(%Oban.Job{args: invalid_args}) do
      {:discard, "Invalid job arguments: #{inspect(invalid_args)}"}
    end

    defp process_batch(resources, operation) do
      results = Enum.map(resources, fn resource ->
        case operation do
          "process" ->
            ProcessStorageWorker.new(%{
              "storage_resource_id" => resource.id,
              "triggered_by" => "BulkProcessWorker"
            })
            |> Oban.insert()

          "cleanup" ->
            CleanupStorageWorker.new(%{
              "storage_resource_id" => resource.id,
              "triggered_by" => "BulkProcessWorker"
            })
            |> Oban.insert()
        end
      end)

      success_count = Enum.count(results, fn {:ok, _job} -> true; _ -> false end)
      total_count = length(resources)

      if success_count == total_count do
        :ok
      else
        {:error, "Batch processing incomplete: #{success_count}/#{total_count} jobs scheduled"}
      end
    end

    defp schedule_cleanup_jobs(args) do
      max_age_hours = get_arg(args, "max_age_hours") || get_arg(args, :max_age_hours) || 168 # 1 week default

      CleanupStorageWorker.new(%{
        "bulk_cleanup" => true,
        "criteria" => %{"max_age_hours" => max_age_hours},
        "triggered_by" => "BulkProcessWorker"
      })
      |> Oban.insert()
      |> case do
        {:ok, _job} -> :ok
        {:error, reason} -> {:error, "Failed to schedule cleanup job: #{inspect(reason)}"}
      end
    end

    defp schedule_version_jobs(args) do
      batch_size = get_arg(args, "batch_size") || get_arg(args, :batch_size) || 25

      query = StorageResource
      |> Ash.Query.filter(storage_metadata["version_scheduled"] == true)
      |> Ash.Query.filter(is_versioned == true)
      |> Ash.Query.limit(batch_size)

      case Ash.read(query) do
        {:ok, resources} ->
          process_batch(resources, "version")

        {:error, reason} ->
          {:error, "Failed to query version candidates: #{inspect(reason)}"}
      end
    end

    defp perform_health_check(_args) do
      # Check storage system health
      stats_result = case Kyozo.Storage.get_operation_stats() do
        {:ok, stats} -> {:ok, stats}
        {:error, reason} -> {:error, "Stats check failed: #{inspect(reason)}"}
      end

      # Could add more health checks here:
      # - Check storage provider connectivity
      # - Verify critical storage resources are accessible
      # - Check for stuck jobs
      # - Validate metadata consistency

      case stats_result do
        {:ok, stats} ->
          # Log health check results or store them somewhere
          # For now, just return success
          :ok

        {:error, reason} ->
          {:error, "Health check failed: #{reason}"}
      end
    end
  end

  @doc """
  Convenience function to schedule a storage processing job.
  """
  def schedule_processing(storage_resource_id, opts \\ []) do
    content = Keyword.get(opts, :content)
    storage_options = Keyword.get(opts, :storage_options, %{})
    priority = Keyword.get(opts, :priority, 0)

    ProcessStorageWorker.new(%{
      "storage_resource_id" => storage_resource_id,
      "content" => content,
      "storage_options" => storage_options
    }, priority: priority)
    |> Oban.insert()
  end

  @doc """
  Convenience function to schedule a storage cleanup job.
  """
  def schedule_cleanup(storage_resource_id, opts \\ []) do
    priority = Keyword.get(opts, :priority, 0)

    CleanupStorageWorker.new(%{
      "storage_resource_id" => storage_resource_id
    }, priority: priority)
    |> Oban.insert()
  end

  @doc """
  Convenience function to schedule a version creation job.
  """
  def schedule_version_creation(storage_resource_id, opts \\ []) do
    content = Keyword.get(opts, :content)
    version_name = Keyword.get(opts, :version_name)
    commit_message = Keyword.get(opts, :commit_message, "Scheduled version update")
    priority = Keyword.get(opts, :priority, 0)

    CreateVersionWorker.new(%{
      "storage_resource_id" => storage_resource_id,
      "content" => content,
      "version_name" => version_name,
      "commit_message" => commit_message
    }, priority: priority)
    |> Oban.insert()
  end

  @doc """
  Convenience function to schedule bulk processing.
  """
  def schedule_bulk_processing(opts \\ []) do
    operation = Keyword.get(opts, :operation, "process_unprocessed")
    batch_size = Keyword.get(opts, :batch_size, 50)
    backend_filter = Keyword.get(opts, :backend)
    priority = Keyword.get(opts, :priority, 0)

    args = %{
      "operation" => operation,
      "batch_size" => batch_size
    }

    args = if backend_filter do
      Map.put(args, "backend", to_string(backend_filter))
    else
      args
    end

    BulkProcessWorker.new(args, priority: priority)
    |> Oban.insert()
  end
end
