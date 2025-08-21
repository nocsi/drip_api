defmodule Kyozo.Storage.AbstractStorage do
  @moduledoc """
  Abstract storage resource base that provides common storage functionality
  across different media types and use cases.

  This module defines the base behavior and attributes for all storage-backed
  resources in Kyozo, implementing the Entrepôt pattern with media type
  awareness and flexible storage backend support.

  ## Usage

  Resources that need storage backing should use this module and implement
  the required callbacks:

      defmodule MyApp.MediaResource do
        use Kyozo.Storage.AbstractStorage,
          media_type: :document,
          storage_backends: [:disk, :s3, :git]

        # Implement required callbacks
        @impl true
        def supported_mime_types, do: ["text/plain", "text/markdown"]

        @impl true
        def default_storage_backend, do: :git

        @impl true
        def validate_content(content, metadata), do: :ok
      end

  ## Media Types

  - `:document` - Text documents, PDFs, presentations
  - `:image` - Photos, graphics, icons
  - `:video` - Video files, animations
  - `:audio` - Music, podcasts, voice recordings
  - `:data` - Structured data, databases, logs
  - `:code` - Source code, scripts, configurations
  - `:archive` - Compressed files, packages
  - `:generic` - Any other file type

  ## Storage Backends

  Different media types optimize for different storage backends:

  - `:disk` - Fast local access, good for frequently accessed files
  - `:s3` - Scalable cloud storage, good for large media files
  - `:git` - Version controlled, excellent for text documents/code
  - `:hybrid` - Intelligent routing based on content type and size
  - `:ram` - Ultra-fast temporary storage
  """

  alias Kyozo.Storage.{Locator, Upload, StorageResource}

  @type media_type :: :document | :image | :video | :audio | :data | :code | :archive | :generic
  @type storage_backend :: :disk | :s3 | :git | :hybrid | :ram
  @type mime_type :: String.t()
  @type content :: binary()
  @type metadata :: map()
  @type validation_result :: :ok | {:error, String.t()}

  @doc """
  Returns the list of MIME types supported by this storage resource.
  """
  @callback supported_mime_types() :: [mime_type()]

  @doc """
  Returns the default storage backend for this media type.
  """
  @callback default_storage_backend() :: storage_backend()

  @doc """
  Validates content before storage.
  """
  @callback validate_content(content(), metadata()) :: validation_result()

  @doc """
  Transforms content before storage (optional).
  For example, compressing images or extracting metadata.
  """
  @callback transform_content(content(), metadata()) ::
              {:ok, content(), metadata()} | {:error, String.t()}

  @doc """
  Returns storage-specific options for the given backend.
  """
  @callback storage_options(storage_backend(), metadata()) :: map()

  @doc """
  Determines the optimal storage backend for given content and metadata.
  """
  @callback select_storage_backend(content(), metadata()) :: storage_backend()

  @optional_callbacks [transform_content: 2, storage_options: 2, select_storage_backend: 2]

  defmacro __using__(opts) do
    media_type = Keyword.get(opts, :media_type, :generic)
    storage_backends = Keyword.get(opts, :storage_backends, [:disk, :s3, :hybrid])
    domain = Keyword.get(opts, :domain, Kyozo.Storage)

    quote do
      @behaviour Kyozo.Storage.AbstractStorage

      @media_type unquote(media_type)
      @storage_backends unquote(storage_backends)

      use Ash.Resource,
        otp_app: :kyozo,
        domain: unquote(domain),
        authorizers: [Ash.Policy.Authorizer],
        notifiers: [Ash.Notifier.PubSub],
        data_layer: AshPostgres.DataLayer,
        extensions: [AshJsonApi.Resource]

      alias Kyozo.Storage.{AbstractStorage, StorageResource, Locator, Upload}

      # Import common storage functionality
      import Kyozo.Storage.AbstractStorage.CommonActions
      import Kyozo.Storage.AbstractStorage.CommonPolicies
      import Kyozo.Storage.AbstractStorage.CommonCalculations
      import Kyozo.Storage.AbstractStorage.CommonValidations

      # Default implementations that can be overridden
      def transform_content(content, metadata), do: {:ok, content, metadata}

      def storage_options(_backend, _metadata), do: %{}

      def select_storage_backend(content, metadata) do
        # Simple heuristic: large files go to S3, text to git, others to disk
        file_size = byte_size(content)
        mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

        cond do
          file_size > 100 * 1024 * 1024 and :s3 in @storage_backends -> :s3
          String.starts_with?(mime_type, "text/") and :git in @storage_backends -> :git
          :disk in @storage_backends -> :disk
          true -> default_storage_backend()
        end
      end

      defoverridable transform_content: 2, storage_options: 2, select_storage_backend: 2

      # Standard storage resource attributes
      unquote(Kyozo.Storage.AbstractStorage.base_attributes())

      # Standard storage resource relationships
      unquote(Kyozo.Storage.AbstractStorage.base_relationships())

      # Standard storage actions
      unquote(Kyozo.Storage.AbstractStorage.base_actions())

      # Standard storage policies
      unquote(Kyozo.Storage.AbstractStorage.base_policies())
    end
  end

  def base_attributes do
    quote do
      attributes do
        # uuid_primary_key :id
        uuid_v7_primary_key :id

        attribute :storage_resource_id, :uuid do
          allow_nil? false
          public? true
          description "Reference to the underlying StorageResource"
        end

        attribute :relationship_type, :atom do
          allow_nil? false
          public? true
          default :primary

          constraints one_of: [
                        :primary,
                        :version,
                        :format,
                        :backup,
                        :cache,
                        :attachment,
                        :thumbnail
                      ]

          description "Type of relationship to the parent resource"
        end

        attribute :media_type, :atom do
          allow_nil? false
          public? true
          default @media_type

          constraints one_of: [
                        :document,
                        :image,
                        :video,
                        :audio,
                        :data,
                        :code,
                        :archive,
                        :generic
                      ]

          description "Media type category"
        end

        attribute :is_primary, :boolean do
          allow_nil? false
          public? true
          default false
          description "Whether this is the primary storage for the resource"
        end

        attribute :priority, :integer do
          public? true
          default 100
          constraints min: 0, max: 1000
          description "Priority for storage selection (lower = higher priority)"
        end

        attribute :metadata, :map do
          public? true
          default %{}
          description "Media-specific metadata and processing information"
        end

        attribute :processing_status, :atom do
          public? true
          default :ready
          constraints one_of: [:pending, :processing, :ready, :failed, :expired]
          description "Status of any background processing"
        end

        attribute :processing_error, :string do
          public? true
          description "Error message if processing failed"
        end

        attribute :expires_at, :utc_datetime_usec do
          public? true
          description "When this storage entry expires (for temporary/cache entries)"
        end

        create_timestamp :created_at
        update_timestamp :updated_at
      end
    end
  end

  def base_relationships do
    quote do
      relationships do
        belongs_to :storage_resource, Kyozo.Storage.StorageResource do
          allow_nil? false
          attribute_writable? true
          public? true
        end

        # Team relationship for multitenancy (inherited from StorageResource)
        belongs_to :team, Kyozo.Accounts.Team do
          allow_nil? false
          define_attribute? false
          source_attribute :team_id
          destination_attribute :id
        end

        # User relationship (inherited from StorageResource)
        belongs_to :user, Kyozo.Accounts.User do
          allow_nil? true
          define_attribute? false
          source_attribute :user_id
          destination_attribute :id
        end
      end
    end
  end

  def base_actions do
    quote do
      actions do
        default_accept [
          :relationship_type,
          :metadata,
          :priority,
          :processing_status,
          :processing_error,
          :expires_at
        ]

        defaults [:read, :destroy]

        read :list_by_media_type do
          prepare build(
                    filter: [media_type: @media_type],
                    load: [:storage_resource, :storage_info, :content_preview]
                  )
        end

        read :by_relationship_type do
          argument :relationship_type, :atom, allow_nil?: false

          prepare build(
                    filter: [relationship_type: arg(:relationship_type)],
                    load: [:storage_resource, :storage_info]
                  )
        end

        read :primary_storage do
          prepare build(
                    filter: [is_primary: true],
                    load: [:storage_resource, :storage_info]
                  )
        end

        create :create_from_content do
          argument :content, :string, allow_nil?: false
          argument :filename, :string, allow_nil?: false
          argument :mime_type, :string
          argument :storage_backend, :atom
          argument :processing_options, :map, default: %{}

          change {Kyozo.Storage.AbstractStorage.Changes.ProcessContent, media_type: @media_type}

          change {Kyozo.Storage.AbstractStorage.Changes.CreateStorageResource,
                  backends: @storage_backends}

          change {Kyozo.Storage.AbstractStorage.Changes.SetupRelationship, []}
        end

        create :create_from_upload do
          argument :upload, :map, allow_nil?: false
          argument :storage_backend, :atom
          argument :processing_options, :map, default: %{}

          change {Kyozo.Storage.AbstractStorage.Changes.ProcessUpload, media_type: @media_type}

          change {Kyozo.Storage.AbstractStorage.Changes.CreateStorageResource,
                  backends: @storage_backends}

          change {Kyozo.Storage.AbstractStorage.Changes.SetupRelationship, []}
        end

        create :create_from_locator do
          argument :locator, :map, allow_nil?: false
          argument :relationship_type, :atom, default: :primary

          change {Kyozo.Storage.AbstractStorage.Changes.CreateFromLocator,
                  media_type: @media_type}
        end

        update :update_metadata do
          accept [:metadata, :priority, :processing_status, :processing_error]
          require_atomic? false
        end

        update :set_as_primary do
          accept []

          change set_attribute(:is_primary, true)
          change set_attribute(:relationship_type, :primary)
          change {Kyozo.Storage.AbstractStorage.Changes.ClearOtherPrimary, []}
        end

        action :get_content, :map do
          run {Kyozo.Storage.AbstractStorage.Actions.GetContent, []}
        end

        action :duplicate_to_backend, :struct do
          argument :target_backend, :atom, allow_nil?: false
          argument :relationship_type, :atom, default: :backup

          run {Kyozo.Storage.AbstractStorage.Actions.DuplicateToBackend, media_type: @media_type}
        end

        action :process_content, :struct do
          argument :processing_options, :map, default: %{}

          run {Kyozo.Storage.AbstractStorage.Actions.ProcessContent, media_type: @media_type}
        end

        action :cleanup_expired, {:array, :struct} do
          run {Kyozo.Storage.AbstractStorage.Actions.CleanupExpired, []}
        end
      end
    end
  end

  def base_policies do
    quote do
      policies do
        # Inherit team-based access from the storage resource
        policy action_type(:read) do
          authorize_if relates_to_actor_via([:storage_resource, :team, :users])
        end

        policy action_type(:create) do
          authorize_if actor_present()
        end

        policy action_type(:update) do
          authorize_if relates_to_actor_via([:storage_resource, :user])
          authorize_if relates_to_actor_via([:storage_resource, :team, :users])
        end

        policy action_type(:destroy) do
          authorize_if relates_to_actor_via([:storage_resource, :user])
          authorize_if actor_attribute_equals(:role, "admin")
        end

        policy action([:get_content, :duplicate_to_backend, :process_content]) do
          authorize_if relates_to_actor_via([:storage_resource, :team, :users])
        end
      end
    end
  end

  # Common calculations available to all storage resources
  defmodule CommonCalculations do
    def storage_info do
      quote do
        calculate :storage_info, :map do
          load [:storage_resource]

          calculation fn entries, _context ->
            Enum.map(entries, fn entry ->
              storage = entry.storage_resource

              %{
                backend: storage.storage_backend,
                file_size: storage.file_size,
                mime_type: storage.mime_type,
                checksum: storage.checksum,
                version: storage.version,
                is_versioned: storage.is_versioned,
                locator_id: storage.locator_id,
                last_accessed: storage.last_accessed_at,
                media_type: entry.media_type,
                processing_status: entry.processing_status
              }
            end)
          end
        end
      end
    end

    def content_preview do
      quote do
        calculate :content_preview, :map do
          load [:storage_resource, :metadata]

          calculation fn entries, _context ->
            Enum.map(entries, fn entry ->
              storage = entry.storage_resource
              metadata = entry.metadata || %{}

              %{
                filename: storage.file_name,
                size_human: format_file_size(storage.file_size),
                mime_type: storage.mime_type,
                media_category: categorize_media_type(storage.mime_type),
                thumbnail_url: Map.get(metadata, "thumbnail_url"),
                preview_available: can_preview?(storage.mime_type),
                download_url: "/storage/#{storage.locator_id}/download"
              }
            end)
          end
        end
      end
    end

    defp format_file_size(size) when size < 1024, do: "#{size} B"
    defp format_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"

    defp format_file_size(size) when size < 1024 * 1024 * 1024,
      do: "#{Float.round(size / (1024 * 1024), 1)} MB"

    defp format_file_size(size), do: "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"

    defp categorize_media_type(mime_type) do
      cond do
        String.starts_with?(mime_type, "image/") -> "image"
        String.starts_with?(mime_type, "video/") -> "video"
        String.starts_with?(mime_type, "audio/") -> "audio"
        String.starts_with?(mime_type, "text/") -> "document"
        mime_type in ~w[application/pdf application/msword] -> "document"
        true -> "file"
      end
    end

    defp can_preview?(mime_type) do
      mime_type in ~w[
        text/plain text/markdown text/html
        image/jpeg image/png image/gif image/webp
        application/pdf
      ]
    end
  end

  # Common actions available to all storage resources
  defmodule CommonActions do
    def get_content do
      quote do
        def handle_get_content(storage_entry, _context) do
          case Ash.load(storage_entry, :storage_resource) do
            {:ok, loaded_entry} ->
              storage = loaded_entry.storage_resource
              locator = StorageResource.to_locator(storage)
              provider = StorageResource.get_storage_provider(storage.storage_backend)

              case provider.read(locator.id) do
                {:ok, content} ->
                  # Update access tracking
                  Ash.update(storage, %{
                    access_count: storage.access_count + 1,
                    last_accessed_at: DateTime.utc_now()
                  })

                  {:ok,
                   %{
                     content: content,
                     metadata: Map.merge(storage.metadata || %{}, loaded_entry.metadata || %{}),
                     mime_type: storage.mime_type,
                     filename: storage.file_name
                   }}

                {:error, reason} ->
                  {:error, "Failed to read content: #{reason}"}
              end

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end
  end

  # Common policies for all storage resources
  defmodule CommonPolicies do
    # Policies are defined in base_policies/0 above
  end

  # Common validations for all storage resources
  defmodule CommonValidations do
    def validate_media_type do
      quote do
        validate {Kyozo.Storage.AbstractStorage.Validations.ValidateMediaType,
                  media_type: @media_type}
      end
    end

    def validate_storage_backend do
      quote do
        validate {Kyozo.Storage.AbstractStorage.Validations.ValidateStorageBackend,
                  backends: @storage_backends}
      end
    end
  end

  # Change modules for common storage operations
  defmodule Changes do
    defmodule ProcessContent do
      use Ash.Resource.Change

      def change(changeset, opts, context) do
        media_type = Keyword.get(opts, :media_type, :generic)
        content = Ash.Changeset.get_argument(changeset, :content)
        filename = Ash.Changeset.get_argument(changeset, :filename)
        mime_type = Ash.Changeset.get_argument(changeset, :mime_type) || guess_mime_type(filename)

        metadata = %{
          original_filename: filename,
          mime_type: mime_type,
          media_type: media_type
        }

        # Validate content using the callback
        resource = changeset.resource

        case resource.validate_content(content, metadata) do
          :ok ->
            # Transform content if needed
            case resource.transform_content(content, metadata) do
              {:ok, transformed_content, updated_metadata} ->
                changeset
                |> Ash.Changeset.set_context(%{
                  processed_content: transformed_content,
                  processed_metadata: updated_metadata
                })

              {:error, reason} ->
                Ash.Changeset.add_error(changeset, field: :content, message: reason)
            end

          {:error, reason} ->
            Ash.Changeset.add_error(changeset, field: :content, message: reason)
        end
      end

      defp guess_mime_type(filename) do
        case Path.extname(filename) do
          ".txt" -> "text/plain"
          ".md" -> "text/markdown"
          ".html" -> "text/html"
          ".json" -> "application/json"
          ".pdf" -> "application/pdf"
          ".jpg" -> "image/jpeg"
          ".jpeg" -> "image/jpeg"
          ".png" -> "image/png"
          ".gif" -> "image/gif"
          _ -> "application/octet-stream"
        end
      end
    end

    defmodule CreateStorageResource do
      use Ash.Resource.Change

      def change(changeset, opts, context) do
        backends = Keyword.get(opts, :backends, [:disk])
        processed_content = Ash.Changeset.get_context(changeset, :processed_content)
        processed_metadata = Ash.Changeset.get_context(changeset, :processed_metadata)

        if processed_content do
          # Select storage backend
          resource = changeset.resource

          storage_backend =
            case Ash.Changeset.get_argument(changeset, :storage_backend) do
              nil -> resource.select_storage_backend(processed_content, processed_metadata)
              backend -> backend
            end

          # Create upload structure
          upload = %Upload{
            content: processed_content,
            filename: processed_metadata.original_filename,
            content_type: processed_metadata.mime_type
          }

          # Create storage resource
          case Ash.create(
                 StorageResource,
                 %{
                   file_upload: upload,
                   storage_backend: storage_backend,
                   storage_options: resource.storage_options(storage_backend, processed_metadata)
                 },
                 action: :create_storage_entry
               ) do
            {:ok, storage_resource} ->
              Ash.Changeset.change_attribute(changeset, :storage_resource_id, storage_resource.id)

            {:error, reason} ->
              Ash.Changeset.add_error(changeset,
                field: :storage_resource_id,
                message: "Failed to create storage: #{inspect(reason)}"
              )
          end
        else
          changeset
        end
      end
    end

    defmodule SetupRelationship do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        # Set media type from module
        changeset
        |> Ash.Changeset.change_attribute(:media_type, changeset.resource.__media_type__())
      end
    end

    defmodule ProcessUpload do
      use Ash.Resource.Change

      def change(changeset, opts, _context) do
        media_type = Keyword.get(opts, :media_type, :generic)
        upload = Ash.Changeset.get_argument(changeset, :upload)

        if upload do
          changeset
          |> Ash.Changeset.change_attribute(
            :mime_type,
            upload.content_type || "application/octet-stream"
          )
          |> Ash.Changeset.change_attribute(:metadata, %{
            "original_filename" => upload.filename,
            "upload_path" => upload.path
          })
        else
          changeset
        end
      end
    end

    defmodule CreateFromLocator do
      use Ash.Resource.Change

      def change(changeset, opts, _context) do
        media_type = Keyword.get(opts, :media_type, :generic)
        locator = Ash.Changeset.get_argument(changeset, :locator)

        if locator do
          changeset
          |> Ash.Changeset.change_attribute(:storage_resource_id, locator.storage_resource_id)
          |> Ash.Changeset.change_attribute(
            :relationship_type,
            Ash.Changeset.get_argument(changeset, :relationship_type) || :primary
          )
        else
          changeset
        end
      end
    end

    defmodule ClearOtherPrimary do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        changeset
        |> Ash.Changeset.after_action(fn changeset, result ->
          # Clear other primary flags for the same parent resource
          # This would need to be implemented based on the specific parent relationship
          {:ok, result}
        end)
      end
    end
  end

  defmodule Actions do
    defmodule GetContent do
      # # use Ash.Resource.Action

      def run(storage_entry, _input, context) do
        CommonActions.handle_get_content(storage_entry, context)
      end
    end

    defmodule DuplicateToBackend do
      def run(storage_entry, input, _context) do
        target_backend = input.arguments.target_backend
        relationship_type = input.arguments.relationship_type || :backup

        # This would need to implement the actual duplication logic
        # For now, return the original entry
        {:ok, storage_entry}
      end
    end

    defmodule ProcessContent do
      def run(storage_entry, input, _context) do
        processing_options = input.arguments.processing_options || %{}

        # This would need to implement the actual processing logic
        # For now, return the original entry
        {:ok, storage_entry}
      end
    end

    defmodule CleanupExpired do
      def run(_storage_entry, _input, _context) do
        # This would need to implement the actual cleanup logic
        # For now, return an empty list
        {:ok, []}
      end
    end
  end

  defmodule Validations do
    defmodule ValidateMediaType do
      use Ash.Resource.Validation

      def validate(changeset, opts, _context) do
        expected_media_type = Keyword.get(opts, :media_type)
        actual_media_type = Ash.Changeset.get_attribute(changeset, :media_type)

        if actual_media_type == expected_media_type do
          :ok
        else
          {:error,
           field: :media_type,
           message: "Expected media type #{expected_media_type}, got #{actual_media_type}"}
        end
      end
    end

    defmodule ValidateStorageBackend do
      use Ash.Resource.Validation

      def validate(changeset, opts, _context) do
        allowed_backends = Keyword.get(opts, :backends, [])

        case Ash.Changeset.get_attribute(changeset, :storage_resource_id) do
          # Will be validated elsewhere
          nil ->
            :ok

          storage_id ->
            # Load storage resource and check backend
            case Ash.get(StorageResource, storage_id) do
              {:ok, storage} ->
                if storage.storage_backend in allowed_backends do
                  :ok
                else
                  {:error,
                   field: :storage_resource_id,
                   message:
                     "Storage backend #{storage.storage_backend} not allowed for this media type"}
                end

              {:error, _} ->
                {:error, field: :storage_resource_id, message: "Invalid storage resource"}
            end
        end
      end
    end
  end
end
