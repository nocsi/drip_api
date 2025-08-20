defmodule Kyozo.Storage.StorageResource do
  @derive {Jason.Encoder,
           only: [
             :id,
             :locator_id,
             :file_name,
             :mime_type,
             :file_size,
             :checksum,
             :version,
             :storage_backend,
             :storage_metadata,
             :is_versioned,
             :created_at,
             :updated_at
           ]}

  @moduledoc """
  Base storage resource for managing file storage across different backends.

  This resource serves as the foundation for all storage operations in Kyozo,
  providing a unified interface for storing, retrieving, and managing files
  across different storage backends like Git, S3, disk, and hybrid storage.

  ## Key Features

  - **Multi-backend support**: Git, S3, disk, RAM, hybrid
  - **Version control**: Automatic versioning with Git backend
  - **Metadata management**: Comprehensive file metadata tracking
  - **Content validation**: MIME type validation and content verification
  - **Flexible storage selection**: Automatic backend selection based on content
  - **Background processing**: AshOban integration for async operations

  ## Storage Backends

  - **Git**: Version-controlled storage for text files and code
  - **S3**: Scalable cloud storage for large files and binaries
  - **Disk**: Local file system storage for frequently accessed files
  - **RAM**: In-memory storage for temporary or cache files
  - **Hybrid**: Intelligent combination of multiple backends
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Storage,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Kyozo.Storage.{Upload, Locator}

  json_api do
    type "storage_resource"

    routes do
      base "/storage_resources"
      get :read
      index :list
      post :create
      patch :update
      delete :destroy
    end
  end

  postgres do
    table "storage_resources"
    repo Kyozo.Repo

    custom_indexes do
      index [:locator_id], unique: true
      index [:storage_backend]
      index [:mime_type]
      index [:file_size]
      index [:checksum]
      index [:is_versioned]
      index [:created_at]
    end
  end

  actions do
    default_accept [
      :file_name,
      :mime_type,
      :file_size,
      :checksum,
      :version,
      :storage_backend,
      :storage_metadata,
      :is_versioned
    ]

    defaults [:read, :update, :destroy]

    read :list do
      prepare build(load: [:storage_info])
    end

    create :create do
      accept [
        :file_name,
        :mime_type,
        :file_size,
        :checksum,
        :version,
        :storage_backend,
        :storage_metadata,
        :is_versioned
      ]

      argument :content, :string
      argument :upload, :struct, constraints: [instance_of: Upload]
      argument :locator_id, :string

      change {__MODULE__.Changes.ProcessStorage, []}
      validate {__MODULE__.Validations.ValidateContent, []}
    end

    create :create_storage_entry do
      accept [
        :file_name,
        :mime_type,
        :file_size,
        :checksum,
        :version,
        :storage_backend,
        :storage_metadata,
        :is_versioned
      ]

      argument :content, :string, allow_nil?: false
      argument :storage_options, :map, default: %{}

      change {__MODULE__.Changes.CreateFromContent, []}
    end

    action :store_content, :struct do
      argument :content, :string, allow_nil?: false
      argument :file_name, :string, allow_nil?: false
      argument :storage_backend, :atom
      argument :storage_options, :map, default: %{}

      run {__MODULE__.Actions.StoreContent, []}
    end

    action :retrieve_content, :string do
      run {__MODULE__.Actions.RetrieveContent, []}
    end

    action :delete_content, :struct do
      run {__MODULE__.Actions.DeleteContent, []}
    end

    action :create_version, :struct do
      argument :content, :string, allow_nil?: false
      argument :version_name, :string
      argument :commit_message, :string

      run {__MODULE__.Actions.CreateVersion, []}
    end

    # Actions for scheduling Oban jobs
    action :schedule_bulk_processing, :struct do
      argument :operation, :atom, default: :process_unprocessed
      argument :batch_size, :integer, default: 50
      argument :backend, :atom

      run {__MODULE__.Actions.ScheduleBulkProcessing, []}
    end

    action :schedule_maintenance, :struct do
      argument :maintenance_type, :atom, allow_nil?: false
      argument :max_age_hours, :integer, default: 168
      argument :batch_size, :integer, default: 25

      run {__MODULE__.Actions.ScheduleMaintenance, []}
    end
  end

  policies do
    bypass AshObanInteraction do
      authorize_if always()
    end

    # Allow AshOban to trigger background jobs with preserved actor context
    # bypass AshOban.Checks.AshObanInteraction do
    #   authorize_if always()
    # end

    # Allow reading storage resources
    policy action_type(:read) do
      authorize_if always()
    end

    # Only allow creating/updating storage resources for authenticated users
    policy action_type([:create, :update]) do
      authorize_if actor_present()
    end

    # Only allow destroying storage resources for authorized users
    policy action_type(:destroy) do
      authorize_if actor_present()
    end

    # Background job actions - allow AshOban to execute with preserved actor context
    policy action([:process_storage_async, :cleanup_content_async, :create_version_async]) do
      # Allow AshOban background jobs
      authorize_if AshOban.Checks.AshObanInteraction
      # Also allow authenticated users for manual triggering
      authorize_if actor_present()
    end
  end

  validations do
    validate present([
               :locator_id,
               :file_name,
               :mime_type,
               :file_size,
               :checksum,
               :storage_backend
             ])

    validate {__MODULE__.Validations.ValidateStorageBackend, []}
    validate {__MODULE__.Validations.ValidateFileSize, []}
  end

  multitenancy do
    strategy :context
  end

  # oban do
  #   scheduled_actions do
  #     # Process unprocessed storage resources every 5 minutes
  #     schedule :process_unprocessed, "*/5 * * * *" do
  #       action :schedule_bulk_processing

  #       action_input(%{
  #         operation: :process_unprocessed,
  #         batch_size: 50
  #       })

  #       worker_module_name(__MODULE__.Process.UnprocessedWorker)
  #     end

  #     # Cleanup maintenance daily at 2 AM
  #     schedule :daily_cleanup, "0 2 * * *" do
  #       action :schedule_maintenance

  #       action_input(%{
  #         maintenance_type: :cleanup
  #       })

  #       worker_module_name(__MODULE__.Process.CleanupWorker)
  #     end

  #     # Version creation maintenance every 10 minutes
  #     schedule :version_creation, "*/10 * * * *" do
  #       action :schedule_maintenance

  #       action_input(%{
  #         maintenance_type: :version_creation
  #       })

  #       worker_module_name(__MODULE__.Process.VersionCreationWorker)
  #     end

  #     # Weekly health check on Sundays at 3 AM
  #     schedule :weekly_health_check, "0 3 * * 0" do
  #       action :schedule_maintenance

  #       action_input(%{
  #         maintenance_type: :health_check
  #       })

  #       worker_module_name(__MODULE__.Process.HealthCheckWorker)
  #     end
  #   end
  # end

  # GraphQL disabled - internal storage resource
  # graphql do
  #   type :storage_resource
  #
  #   queries do
  #     get :get_storage_resource, :read
  #     list :list_storage_resources, :list
  #   end
  #
  #   mutations do
  #     create :create_storage_resource, :create
  #     update :update_storage_resource, :update
  #     destroy :destroy_storage_resource, :destroy
  #   end
  # end

  # AshOban integration - jobs will be scheduled manually via AshOban.schedule/4
  # This provides proper actor persistence and authorization handling

  attributes do
    uuid_primary_key :id

    attribute :locator_id, :string do
      public? true
      allow_nil? false
      description "Unique identifier for locating the stored content"
    end

    attribute :file_name, :string do
      public? true
      allow_nil? false
      description "Original filename"
    end

    attribute :mime_type, :string do
      public? true
      allow_nil? false
      default "application/octet-stream"
      description "MIME type of the stored content"
    end

    attribute :file_size, :integer do
      public? true
      allow_nil? false
      constraints min: 0
      description "Size of the file in bytes"
    end

    attribute :checksum, :string do
      public? true
      allow_nil? false
      description "SHA256 checksum of the content"
    end

    attribute :version, :string do
      public? true
      allow_nil? false
      default "1"
      description "Version identifier"
    end

    attribute :storage_backend, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:git, :s3, :disk, :ram, :hybrid]
      default :hybrid
      description "Storage backend used for this resource"
    end

    attribute :storage_metadata, :map do
      public? true
      default %{}
      description "Backend-specific metadata"
    end

    attribute :is_versioned, :boolean do
      public? true
      default false
      description "Whether this resource supports versioning"
    end

    create_timestamp :created_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    # Storage resources can be referenced by multiple storage entries
    has_many :file_storages, Kyozo.Workspaces.FileStorage do
      public? true
    end

    has_many :image_storages, Kyozo.Workspaces.ImageStorage do
      public? true
    end

    # Add other storage types as they're implemented
  end

  calculations do
    calculate :storage_info, :map do
      load [:locator_id, :storage_backend, :storage_metadata, :file_size, :mime_type]

      calculation fn storage_resources, _context ->
        Enum.map(storage_resources, fn resource ->
          %{
            locator_id: resource.locator_id,
            backend: resource.storage_backend,
            size: resource.file_size,
            formatted_size: format_file_size(resource.file_size),
            mime_type: resource.mime_type,
            is_text: String.starts_with?(resource.mime_type, "text/"),
            is_image: String.starts_with?(resource.mime_type, "image/"),
            is_binary: not String.starts_with?(resource.mime_type, "text/"),
            metadata: resource.storage_metadata || %{},
            created_at: resource.created_at
          }
        end)
      end
    end

    calculate :can_retrieve, :boolean do
      load [:locator_id, :storage_backend]

      calculation fn storage_resources, _context ->
        Enum.map(storage_resources, fn resource ->
          not is_nil(resource.locator_id) and resource.storage_backend != :ram
        end)
      end
    end

    calculate :supports_versioning, :boolean do
      load [:storage_backend, :is_versioned]

      calculation fn storage_resources, _context ->
        Enum.map(storage_resources, fn resource ->
          resource.is_versioned and resource.storage_backend in [:git, :hybrid]
        end)
      end
    end
  end

  # Helper functions
  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"

  defp format_file_size(size) when size < 1024 * 1024 * 1024,
    do: "#{Float.round(size / (1024 * 1024), 1)} MB"

  defp format_file_size(size), do: "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"

  # Change modules
  defmodule Changes do
    defmodule ProcessStorage do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        cond do
          Ash.Changeset.get_argument(changeset, :upload) ->
            process_upload(changeset)

          Ash.Changeset.get_argument(changeset, :content) ->
            process_content(changeset)

          Ash.Changeset.get_argument(changeset, :locator_id) ->
            process_locator(changeset)

          true ->
            changeset
        end
      end

      defp process_upload(changeset) do
        upload = Ash.Changeset.get_argument(changeset, :upload)
        checksum = generate_checksum(upload.content)
        locator_id = Locator.generate()

        changeset
        |> Ash.Changeset.change_attribute(:locator_id, locator_id)
        |> Ash.Changeset.change_attribute(:file_name, upload.filename)
        |> Ash.Changeset.change_attribute(:mime_type, upload.mime_type)
        |> Ash.Changeset.change_attribute(:file_size, byte_size(upload.content))
        |> Ash.Changeset.change_attribute(:checksum, checksum)
      end

      defp process_content(changeset) do
        content = Ash.Changeset.get_argument(changeset, :content)
        file_name = Ash.Changeset.get_attribute(changeset, :file_name)
        mime_type = MIME.from_path(file_name) || "application/octet-stream"
        checksum = generate_checksum(content)
        locator_id = Locator.generate()

        changeset
        |> Ash.Changeset.change_attribute(:locator_id, locator_id)
        |> Ash.Changeset.change_attribute(:mime_type, mime_type)
        |> Ash.Changeset.change_attribute(:file_size, byte_size(content))
        |> Ash.Changeset.change_attribute(:checksum, checksum)
      end

      defp process_locator(changeset) do
        locator_id = Ash.Changeset.get_argument(changeset, :locator_id)
        Ash.Changeset.change_attribute(changeset, :locator_id, locator_id)
      end

      defp generate_checksum(content) do
        :crypto.hash(:sha256, content)
        |> Base.encode16(case: :lower)
      end
    end

    defmodule CreateFromContent do
      use Ash.Resource.Change

      def change(changeset, _opts, context) do
        content = Ash.Changeset.get_argument(changeset, :content)
        storage_options = Ash.Changeset.get_argument(changeset, :storage_options)

        file_name = Ash.Changeset.get_attribute(changeset, :file_name)
        storage_backend = Ash.Changeset.get_attribute(changeset, :storage_backend) || :hybrid

        # Generate basic attributes
        mime_type = MIME.from_path(file_name) || "application/octet-stream"
        checksum = generate_checksum(content)
        locator_id = Locator.generate()

        # Determine if this should be versioned based on backend
        is_versioned =
          storage_backend in [:git, :hybrid] and
            String.starts_with?(mime_type, "text/")

        # Set up the changeset with basic attributes
        changeset =
          changeset
          |> Ash.Changeset.change_attribute(:locator_id, locator_id)
          |> Ash.Changeset.change_attribute(:mime_type, mime_type)
          |> Ash.Changeset.change_attribute(:file_size, byte_size(content))
          |> Ash.Changeset.change_attribute(:checksum, checksum)
          |> Ash.Changeset.change_attribute(:is_versioned, is_versioned)

        # Store the content using the appropriate provider
        provider = get_storage_provider(storage_backend)

        case provider.write(locator_id, content, storage_options) do
          {:ok, metadata} ->
            Ash.Changeset.change_attribute(changeset, :storage_metadata, metadata)

          {:error, _reason} ->
            Ash.Changeset.add_error(changeset, "Failed to store content")
        end
      end

      defp generate_checksum(content) do
        :crypto.hash(:sha256, content)
        |> Base.encode16(case: :lower)
      end

      defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
      defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
      defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
      defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.Ram
      defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid
    end
  end

  # Action modules
  defmodule Actions do
    defmodule ScheduleBulkProcessing do
      def run(_storage_resource, input, _context) do
        operation = input.arguments.operation
        batch_size = input.arguments.batch_size
        backend = input.arguments.backend

        opts = [
          operation: operation,
          batch_size: batch_size
        ]

        opts =
          if backend do
            Keyword.put(opts, :backend, backend)
          else
            opts
          end

        case Kyozo.Storage.Workers.schedule_bulk_processing(opts) do
          {:ok, job} -> {:ok, %{job_id: job.id, operation: operation}}
          {:error, reason} -> {:error, reason}
        end
      end
    end

    defmodule ScheduleMaintenance do
      def run(_storage_resource, input, _context) do
        maintenance_type = input.arguments.maintenance_type

        case Kyozo.Storage.Workers.schedule_bulk_processing(
               operation: "schedule_maintenance",
               maintenance_type: to_string(maintenance_type),
               max_age_hours: input.arguments.max_age_hours,
               batch_size: input.arguments.batch_size
             ) do
          {:ok, job} -> {:ok, %{job_id: job.id, maintenance_type: maintenance_type}}
          {:error, reason} -> {:error, reason}
        end
      end
    end

    defmodule StoreContent do
      def run(_storage_resource, input, _context) do
        content = input.arguments.content
        file_name = input.arguments.file_name
        storage_backend = input.arguments.storage_backend || :hybrid
        storage_options = input.arguments.storage_options

        attrs = %{
          file_name: file_name,
          storage_backend: storage_backend
        }

        case Kyozo.Storage.StorageResource.create_storage_entry(attrs,
               content: content,
               storage_options: storage_options
             ) do
          {:ok, storage_resource} -> {:ok, storage_resource}
          {:error, reason} -> {:error, reason}
        end
      end
    end

    defmodule RetrieveContent do
      def run(storage_resource, _input, _context) do
        provider = get_storage_provider(storage_resource.storage_backend)

        case provider.read(storage_resource.locator_id) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, reason}
        end
      end

      defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
      defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
      defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
      defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.Ram
      defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid
    end

    defmodule DeleteContent do
      def run(storage_resource, _input, _context) do
        provider = get_storage_provider(storage_resource.storage_backend)

        case provider.delete(storage_resource.locator_id) do
          :ok -> {:ok, storage_resource}
          {:error, reason} -> {:error, reason}
        end
      end

      defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
      defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
      defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
      defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.Ram
      defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid
    end

    defmodule CreateVersion do
      def run(storage_resource, input, _context) do
        if not storage_resource.is_versioned do
          {:error, "Storage resource does not support versioning"}
        else
          content = input.arguments.content
          version_name = input.arguments.version_name || generate_version_name()
          commit_message = input.arguments.commit_message || "Update content"

          # For versioned storage (like Git), create a new version
          provider = get_storage_provider(storage_resource.storage_backend)

          if function_exported?(provider, :create_version, 3) do
            case provider.create_version(storage_resource.locator_id, content, commit_message) do
              {:ok, version_info} ->
                # Update the storage resource with new version info
                {:ok, updated_resource} =
                  Ash.update(storage_resource, %{
                    version: version_name,
                    storage_metadata:
                      Map.merge(storage_resource.storage_metadata || %{}, version_info)
                  })

                {:ok, updated_resource}

              {:error, reason} ->
                {:error, reason}
            end
          else
            {:error, "Storage backend does not support versioning"}
          end
        end
      end

      defp generate_version_name do
        DateTime.utc_now()
        |> DateTime.to_iso8601()
      end

      defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
      defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
      defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
      defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.Ram
      defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid
    end
  end

  # Helper functions for background jobs
  defp get_storage_provider(:git), do: Kyozo.Storage.Providers.Git
  defp get_storage_provider(:s3), do: Kyozo.Storage.Providers.S3
  defp get_storage_provider(:disk), do: Kyozo.Storage.Providers.Disk
  defp get_storage_provider(:ram), do: Kyozo.Storage.Providers.Ram
  defp get_storage_provider(:hybrid), do: Kyozo.Storage.Providers.Hybrid

  defp generate_version_name do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
  end

  # Validation modules
  defmodule Validations do
    defmodule ValidateContent do
      use Ash.Resource.Validation

      def validate(changeset, _opts, _context) do
        content = Ash.Changeset.get_argument(changeset, :content)
        upload = Ash.Changeset.get_argument(changeset, :upload)

        cond do
          content && byte_size(content) > 100 * 1024 * 1024 ->
            {:error, "Content too large (max 100MB)"}

          upload && byte_size(upload.content) > 100 * 1024 * 1024 ->
            {:error, "Upload too large (max 100MB)"}

          true ->
            :ok
        end
      end
    end

    defmodule ValidateStorageBackend do
      use Ash.Resource.Validation

      def validate(changeset, _opts, _context) do
        backend = Ash.Changeset.get_attribute(changeset, :storage_backend)

        if backend in [:git, :s3, :disk, :ram, :hybrid] do
          :ok
        else
          {:error, "Invalid storage backend: #{backend}"}
        end
      end
    end

    defmodule ValidateFileSize do
      use Ash.Resource.Validation

      def validate(changeset, _opts, _context) do
        file_size = Ash.Changeset.get_attribute(changeset, :file_size)

        if file_size && file_size >= 0 do
          :ok
        else
          {:error, "File size must be non-negative"}
        end
      end
    end
  end
end
