defmodule Kyozo.Storage do
  require Ash.Query

  @moduledoc """
  Storage domain for managing file storage across different backends.

  This domain provides a unified interface for storing, retrieving, and managing
  files across various storage backends including Git, S3, disk, RAM, and hybrid
  storage solutions.

  ## Key Features

  - **Multi-backend support**: Seamlessly work with different storage providers
  - **Unified API**: Consistent interface regardless of storage backend
  - **Automatic backend selection**: Intelligent storage backend selection
  - **Version control**: Built-in versioning support for compatible backends
  - **Metadata management**: Comprehensive file metadata tracking
  - **Content validation**: MIME type validation and content verification

  ## Storage Backends

  - **Git**: Version-controlled storage ideal for text files and code
  - **S3**: Scalable cloud storage for large files and binary content
  - **Disk**: Local file system storage for frequently accessed files
  - **RAM**: In-memory storage for temporary or cache files
  - **Hybrid**: Intelligent combination of multiple backends based on content

  ## Usage Examples

      # Store a file
      {:ok, storage_resource} = Kyozo.Storage.store_file(content, "document.md", backend: :git)

      # Retrieve content
      {:ok, content} = Kyozo.Storage.retrieve_content(storage_resource)

      # Create a new version
      {:ok, versioned_resource} = Kyozo.Storage.create_version(storage_resource, new_content)
  """

  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  alias Kyozo.Storage.{StorageResource, Upload, Locator}

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    authorize? true
    prefix "/api/v1/storage"
  end

  resources do
    # Existing resources
    resource Kyozo.Storage.StorageResource
    # VFS is not a persisted resource, just a service
  end

  # VFS API - delegates to VFS module
  defdelegate list_files_with_virtual(workspace_id, path, opts \\ %{}),
    to: Kyozo.Storage.VFS,
    as: :list_files

  defdelegate read_virtual_file(workspace_id, path), to: Kyozo.Storage.VFS, as: :read_file

  @doc """
  Stores content in the appropriate storage backend.

  ## Options

  - `:backend` - Storage backend to use (defaults to :hybrid)
  - `:file_name` - Name of the file
  - `:storage_options` - Backend-specific options
  """
  def store_content(content, file_name, opts \\ []) do
    backend = Keyword.get(opts, :backend, :hybrid)
    storage_options = Keyword.get(opts, :storage_options, %{})

    StorageResource.store_content(%{
      content: content,
      file_name: file_name,
      storage_backend: backend,
      storage_options: storage_options
    })
  end

  @doc """
  Retrieves content from a storage resource.
  """
  def retrieve_content(%StorageResource{} = storage_resource) do
    StorageResource.retrieve_content(storage_resource)
  end

  @doc """
  Creates a new version of stored content (for versioned backends).
  """
  def create_version(%StorageResource{} = storage_resource, content, opts \\ []) do
    version_name = Keyword.get(opts, :version_name)
    commit_message = Keyword.get(opts, :commit_message, "Update content")

    StorageResource.create_version(storage_resource, %{
      content: content,
      version_name: version_name,
      commit_message: commit_message
    })
  end

  @doc """
  Deletes content from storage.
  """
  def delete_content(%StorageResource{} = storage_resource) do
    StorageResource.delete_content(storage_resource)
  end

  @doc """
  Creates a storage resource from an upload.
  """
  def store_upload(%Upload{} = upload, opts \\ []) do
    backend = Keyword.get(opts, :backend, :hybrid)
    storage_options = Keyword.get(opts, :storage_options, %{})
    actor = Keyword.get(opts, :actor)

    StorageResource.create(
      %{
        upload: upload,
        storage_backend: backend,
        storage_options: storage_options
      },
      actor: actor
    )
  end

  @doc """
  Schedules storage processing using dedicated Oban workers.

  This function enqueues a job to process storage content using the appropriate
  storage backend. The job will be handled by ProcessStorageWorker.

  ## Options

  - `:content` - Content to process (optional - will retrieve existing if not provided)
  - `:storage_options` - Backend-specific storage options
  - `:priority` - Job priority (0 = normal, higher = more priority)
  - `:actor` - The actor context for authorization

  ## Examples

      {:ok, job} = Kyozo.Storage.schedule_storage_processing(storage_resource,
        content: "new content",
        storage_options: %{compression: true},
        priority: 1
      )
  """
  def schedule_storage_processing(%StorageResource{} = storage_resource, opts \\ []) do
    content = Keyword.get(opts, :content)
    storage_options = Keyword.get(opts, :storage_options, %{})
    priority = Keyword.get(opts, :priority, 0)

    Kyozo.Storage.Workers.schedule_processing(
      storage_resource.id,
      content: content,
      storage_options: storage_options,
      priority: priority
    )
  end

  @doc """
  Schedules storage cleanup using dedicated Oban workers.

  This function enqueues a job to clean up storage content from the backend.
  The job will be handled by CleanupStorageWorker.

  ## Options

  - `:priority` - Job priority (0 = normal, higher = more priority)

  ## Examples

      {:ok, job} = Kyozo.Storage.schedule_storage_cleanup(storage_resource,
        priority: 1
      )
  """
  def schedule_storage_cleanup(%StorageResource{} = storage_resource, opts \\ []) do
    priority = Keyword.get(opts, :priority, 0)

    Kyozo.Storage.Workers.schedule_cleanup(
      storage_resource.id,
      priority: priority
    )
  end

  @doc """
  Schedules version creation using dedicated Oban workers.

  This function enqueues a job to create a new version of the storage content.
  The job will be handled by CreateVersionWorker and is only available for
  versioned storage backends.

  ## Options

  - `:version_name` - Custom name for the version
  - `:commit_message` - Message describing the changes
  - `:priority` - Job priority (0 = normal, higher = more priority)

  ## Examples

      {:ok, job} = Kyozo.Storage.schedule_version_creation(storage_resource, content,
        version_name: "v2.0",
        commit_message: "Major update with new features",
        priority: 1
      )
  """
  def schedule_version_creation(%StorageResource{} = storage_resource, content, opts \\ []) do
    version_name = Keyword.get(opts, :version_name)
    commit_message = Keyword.get(opts, :commit_message, "Update content")
    priority = Keyword.get(opts, :priority, 0)

    Kyozo.Storage.Workers.schedule_version_creation(
      storage_resource.id,
      content: content,
      version_name: version_name,
      commit_message: commit_message,
      priority: priority
    )
  end

  @doc """
  Gets the processing status of a storage resource from its metadata.

  Returns status information about scheduled operations and their results.

  ## Examples

      {:ok, status} = Kyozo.Storage.get_processing_status(storage_resource)

      IO.inspect(status)
      # %{
      #   processed: true,
      #   processed_at: ~U[2024-01-15 10:30:00Z],
      #   cleanup_scheduled: false,
      #   version_scheduled: false
      # }
  """
  def get_processing_status(%StorageResource{} = storage_resource) do
    metadata = storage_resource.storage_metadata || %{}

    status = %{
      processed: Map.get(metadata, "processed", false),
      processed_at: Map.get(metadata, "processed_at"),
      processing_scheduled_at: Map.get(metadata, "processing_scheduled_at"),
      last_error: Map.get(metadata, "last_error"),
      last_error_at: Map.get(metadata, "last_error_at"),
      cleanup_scheduled: Map.get(metadata, "cleanup_scheduled", false),
      cleanup_scheduled_at: Map.get(metadata, "cleanup_scheduled_at"),
      cleaned_up: Map.get(metadata, "cleaned_up", false),
      cleaned_up_at: Map.get(metadata, "cleaned_up_at"),
      version_scheduled: Map.get(metadata, "version_scheduled", false),
      version_scheduled_at: Map.get(metadata, "version_scheduled_at"),
      version_created: Map.get(metadata, "version_created", false),
      version_created_at: Map.get(metadata, "version_created_at")
    }

    {:ok, status}
  end

  @doc """
  Cancels scheduled Oban jobs for a storage resource.

  This will attempt to cancel any pending Oban jobs related to this storage resource.
  Only jobs in 'available' or 'scheduled' state can be cancelled.

  ## Examples

      {:ok, cancelled_count} = Kyozo.Storage.cancel_scheduled_operations(storage_resource)
  """
  def cancel_scheduled_operations(%StorageResource{} = storage_resource, opts \\ []) do
    import Ecto.Query

    # Cancel jobs for this specific storage resource
    cancelled_jobs =
      Kyozo.Repo.all(
        from j in Oban.Job,
          where:
            fragment("?->>'storage_resource_id' = ?", j.args, ^storage_resource.id) and
              j.state in ["available", "scheduled"],
          select: j.id
      )

    if length(cancelled_jobs) > 0 do
      Oban.cancel_all_jobs(
        from j in Oban.Job,
          where: j.id in ^cancelled_jobs
      )

      {:ok, length(cancelled_jobs)}
    else
      {:ok, 0}
    end
  end

  @doc """
  Gets information about scheduled Ash actions for storage resources.

  Returns information about the configured scheduled actions including their schedules.

  ## Examples

      {:ok, schedules} = Kyozo.Storage.get_schedule_info()

      schedules
      |> Enum.each(fn schedule ->
        IO.puts "Schedule \#{schedule.name}: \#{schedule.cron}"
      end)
  """
  def get_schedule_info do
    schedules = [
      %{
        name: :process_unprocessed,
        action: :schedule_bulk_processing,
        cron: "*/5 * * * *",
        description: "Process unprocessed storage resources every 5 minutes",
        args: %{operation: :process_unprocessed, batch_size: 50}
      },
      %{
        name: :daily_cleanup,
        action: :schedule_maintenance,
        cron: "0 2 * * *",
        description: "Cleanup maintenance daily at 2 AM",
        args: %{maintenance_type: :cleanup}
      },
      %{
        name: :version_creation,
        action: :schedule_maintenance,
        cron: "*/10 * * * *",
        description: "Version creation maintenance every 10 minutes",
        args: %{maintenance_type: :version_creation}
      },
      %{
        name: :weekly_health_check,
        action: :schedule_maintenance,
        cron: "0 3 * * 0",
        description: "Weekly health check on Sundays at 3 AM",
        args: %{maintenance_type: :health_check}
      }
    ]

    {:ok, schedules}
  end

  @doc """
  Gets statistics about storage operations and Oban job queues.

  Returns counts of resources and pending Oban jobs for storage operations.

  ## Examples

      {:ok, stats} = Kyozo.Storage.get_operation_stats()

      IO.inspect(stats)
      # %{
      #   pending_processing: 5,
      #   pending_cleanup: 2,
      #   pending_versions: 1,
      #   total_resources: 150,
      #   oban_stats: %{...}
      # }
  """
  def get_operation_stats do
    require Ash.Query
    import Ecto.Query

    # Get resource statistics
    resource_stats =
      case Ash.read(StorageResource) do
        {:ok, resources} ->
          Enum.reduce(
            resources,
            %{
              unprocessed_resources: 0,
              total_resources: 0
            },
            fn resource, acc ->
              metadata = resource.storage_metadata || %{}

              %{
                unprocessed_resources:
                  acc.unprocessed_resources +
                    if(Map.get(metadata, "processed") != true, do: 1, else: 0),
                total_resources: acc.total_resources + 1
              }
            end
          )

        {:error, _reason} ->
          %{unprocessed_resources: 0, total_resources: 0}
      end

    # Get Oban job statistics
    oban_stats =
      Kyozo.Repo.all(
        from j in Oban.Job,
          where:
            j.queue in [
              "storage_processing",
              "storage_cleanup",
              "storage_versions",
              "storage_bulk"
            ],
          group_by: [j.queue, j.state],
          select: %{queue: j.queue, state: j.state, count: count(j.id)}
      )
      |> Enum.reduce(%{}, fn %{queue: queue, state: state, count: count}, acc ->
        queue_atom = String.to_atom(queue)

        Map.update(acc, queue_atom, %{state => count}, fn queue_stats ->
          Map.put(queue_stats, state, count)
        end)
      end)

    stats = Map.merge(resource_stats, %{oban_stats: oban_stats})
    {:ok, stats}
  end

  @doc """
  Forces processing of a specific storage resource immediately.

  This schedules an Oban job with high priority to process the resource right away.
  Useful for testing or urgent processing needs.

  ## Examples

      {:ok, job} = Kyozo.Storage.force_processing(storage_resource,
        content: "new content",
        storage_options: %{compression: true}
      )
  """
  def force_processing(%StorageResource{} = storage_resource, opts \\ []) do
    content = Keyword.get(opts, :content)
    storage_options = Keyword.get(opts, :storage_options, %{})

    Kyozo.Storage.Workers.schedule_processing(
      storage_resource.id,
      content: content,
      storage_options: storage_options,
      # High priority for immediate processing
      priority: 10
    )
  end

  @doc """
  Forces version creation for a specific storage resource immediately.

  This schedules an Oban job with high priority to create the version right away.

  ## Examples

      {:ok, job} = Kyozo.Storage.force_version_creation(storage_resource,
        content: "new content",
        version_name: "v1.0",
        commit_message: "Urgent update"
      )
  """
  def force_version_creation(%StorageResource{} = storage_resource, opts \\ []) do
    content = Keyword.get(opts, :content)
    version_name = Keyword.get(opts, :version_name)
    commit_message = Keyword.get(opts, :commit_message, "Forced version update")

    Kyozo.Storage.Workers.schedule_version_creation(
      storage_resource.id,
      content: content,
      version_name: version_name,
      commit_message: commit_message,
      # High priority for immediate processing
      priority: 10
    )
  end

  @doc """
  Schedules bulk processing operations using scheduled actions.

  This triggers the scheduled actions directly on the StorageResource.

  ## Examples

      # Process all unprocessed resources
      {:ok, result} = Kyozo.Storage.schedule_bulk_processing(
        operation: :process_unprocessed,
        batch_size: 100
      )

      # Schedule maintenance
      {:ok, result} = Kyozo.Storage.schedule_maintenance(
        maintenance_type: :cleanup
      )
  """
  def schedule_bulk_processing(opts \\ []) do
    operation = Keyword.get(opts, :operation, :process_unprocessed)
    batch_size = Keyword.get(opts, :batch_size, 50)
    backend = Keyword.get(opts, :backend)

    args = %{
      operation: operation,
      batch_size: batch_size
    }

    args =
      if backend do
        Map.put(args, :backend, backend)
      else
        args
      end

    # Use the first available storage resource to trigger the scheduled action
    case list_storage_resources(limit: 1) do
      {:ok, [storage_resource | _]} ->
        StorageResource
        |> Ash.Changeset.for_action(:schedule_bulk_processing, storage_resource, args)
        |> Ash.update()

      {:ok, []} ->
        {:error, "No storage resources available to trigger scheduled action"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Schedules maintenance operations using scheduled actions.
  """
  def schedule_maintenance(opts \\ []) do
    maintenance_type = Keyword.get(opts, :maintenance_type, :cleanup)
    max_age_hours = Keyword.get(opts, :max_age_hours, 168)
    batch_size = Keyword.get(opts, :batch_size, 25)

    args = %{
      maintenance_type: maintenance_type,
      max_age_hours: max_age_hours,
      batch_size: batch_size
    }

    # Use the first available storage resource to trigger the scheduled action
    case list_storage_resources(limit: 1) do
      {:ok, [storage_resource | _]} ->
        StorageResource
        |> Ash.Changeset.for_action(:schedule_maintenance, storage_resource, args)
        |> Ash.update()

      {:ok, []} ->
        {:error, "No storage resources available to trigger scheduled action"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Determines the best storage backend for given content.
  """
  def determine_backend(content, file_name, opts \\ []) do
    file_size = byte_size(content)
    mime_type = MIME.from_path(file_name) || "application/octet-stream"

    cond do
      # Large binary files go to S3
      file_size > 10 * 1024 * 1024 and String.starts_with?(mime_type, "application/") ->
        :s3

      # Small text files go to Git for version control
      file_size < 1024 * 1024 and String.starts_with?(mime_type, "text/") ->
        :git

      # Images go to S3 or disk based on size
      String.starts_with?(mime_type, "image/") ->
        if file_size > 5 * 1024 * 1024, do: :s3, else: :disk

      # Code files prefer Git
      code_file?(file_name) ->
        :git

      # Medium-sized documents go to disk
      file_size < 50 * 1024 * 1024 ->
        :disk

      # Very large files go to S3
      true ->
        :s3
    end
    |> then(fn backend ->
      Keyword.get(opts, :backend, backend)
    end)
  end

  @doc """
  Gets storage statistics for a backend.
  """
  def get_storage_stats(backend \\ nil) do
    query = StorageResource

    query =
      if backend do
        Ash.Query.filter(query, storage_backend == ^backend)
      else
        query
      end

    case Ash.read(query) do
      {:ok, resources} ->
        total_files = length(resources)
        total_size = Enum.reduce(resources, 0, &(&1.file_size + &2))

        by_backend =
          resources
          |> Enum.group_by(& &1.storage_backend)
          |> Enum.map(fn {backend, files} ->
            {backend,
             %{
               count: length(files),
               total_size: Enum.reduce(files, 0, &(&1.file_size + &2))
             }}
          end)
          |> Enum.into(%{})

        {:ok,
         %{
           total_files: total_files,
           total_size: total_size,
           formatted_total_size: format_file_size(total_size),
           by_backend: by_backend
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all storage resources with optional filtering.
  """

  def list_storage_resources(opts \\ []) do
    query =
      StorageResource
      |> Ash.Query.load([:storage_info])

    query =
      case Keyword.get(opts, :backend) do
        nil -> query
        backend -> Ash.Query.filter(query, storage_backend == ^backend)
      end

    query =
      case Keyword.get(opts, :mime_type) do
        nil -> query
        mime_type -> Ash.Query.filter(query, mime_type == ^mime_type)
      end

    query =
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> Ash.Query.limit(query, limit)
      end

    Ash.read(query)
  end

  @doc """
  Finds a storage resource by locator ID.
  """
  def get_by_locator(locator_id) do
    StorageResource
    |> Ash.Query.filter(locator_id == ^locator_id)
    |> Ash.Query.load([:storage_info])
    |> Ash.read_one()
  end

  @doc """
  Validates content against MIME type and size constraints.
  """
  def validate_content(content, mime_type, opts \\ []) do
    # 100MB default
    max_size = Keyword.get(opts, :max_size, 100 * 1024 * 1024)

    cond do
      byte_size(content) > max_size ->
        {:error, "Content too large (max #{format_file_size(max_size)})"}

      String.starts_with?(mime_type, "text/") and not String.valid?(content) ->
        {:error, "Invalid text encoding"}

      true ->
        :ok
    end
  end

  @doc """
  Generates a unique locator ID for storage.
  """
  def generate_locator, do: Locator.generate()

  # Private helper functions

  defp code_file?(file_name) do
    extension = Path.extname(file_name)

    extension in [
      ".ex",
      ".exs",
      ".py",
      ".js",
      ".ts",
      ".rb",
      ".go",
      ".rs",
      ".java",
      ".c",
      ".cpp",
      ".h",
      ".hpp",
      ".php",
      ".html",
      ".css",
      ".scss",
      ".sql",
      ".sh",
      ".bash",
      ".zsh",
      ".fish",
      ".dockerfile"
    ]
  end

  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"

  defp format_file_size(size) when size < 1024 * 1024 * 1024,
    do: "#{Float.round(size / (1024 * 1024), 1)} MB"

  defp format_file_size(size), do: "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"
end
