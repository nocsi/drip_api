defmodule Kyozo.Workspaces.FileStorage do
  @derive {Jason.Encoder, only: [:id, :file_id, :storage_resource_id, :relationship_type, :media_type, :is_primary, :metadata, :created_at, :updated_at]}
  
  @moduledoc """
  Document storage resource implementing the AbstractStorage pattern.
  
  This resource manages storage for workspace files, providing document-specific
  storage capabilities with support for multiple formats, versions, and backends.
  
  ## Supported MIME Types
  
  - Text documents: text/plain, text/markdown, text/html
  - Office documents: application/pdf, application/msword, application/vnd.openxmlformats-officedocument.*
  - Rich text: application/rtf
  - Code files: text/javascript, application/json, text/css, etc.
  
  ## Storage Backend Selection
  
  - Small text files (<1MB): Git for version control
  - Large documents (>1MB): S3 for scalability  
  - Frequently accessed: Disk for performance
  - Temporary/cache: RAM for speed
  """

  use Kyozo.Storage.AbstractStorage,
    media_type: :document,
    storage_backends: [:git, :s3, :disk, :hybrid, :ram],
    domain: Kyozo.Workspaces



  require Ash.Query

  postgres do
    table "file_storages"
    repo Kyozo.Repo

    references do
      reference :file, on_delete: :delete, index?: true
      reference :storage_resource, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:file_id, :storage_resource_id], unique: true
      index [:file_id, :is_primary]
      index [:file_id, :relationship_type]
      index [:storage_resource_id]
      index [:media_type, :relationship_type]
      index [:processing_status]
      index [:created_at]
    end
  end

  json_api do
    type "file_storage"

    routes do
      base "/file_storages"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  # GraphQL disabled - internal intermediary resource
  # graphql do
  #   type :file_storage
  #
  #   queries do
  #     get :get_file_storage, :read
  #     list :list_file_storages, :list_file_storages
  #   end
  #
  #   mutations do
  #     create :create_file_storage, :create_file_storage
  #     update :update_file_storage, :update_file_storage
  #     destroy :destroy_file_storage, :destroy
  #   end
  # end

  # Implement AbstractStorage callbacks
  @impl true
  def supported_mime_types do
    [
      # Text documents
      "text/plain",
      "text/markdown", 
      "text/html",
      "text/css",
      "text/javascript",
      "text/csv",
      "text/tab-separated-values",
      
      # Structured data
      "application/json",
      "application/xml",
      "text/xml",
      "application/yaml",
      "text/yaml",
      
      # Office documents
      "application/pdf",
      "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/vnd.ms-excel", 
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application/vnd.ms-powerpoint",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "application/rtf",
      
      # Code files
      "text/x-python",
      "text/x-ruby",
      "text/x-php",
      "text/x-java",
      "text/x-c",
      "text/x-cpp",
      "text/x-csharp",
      "text/x-elixir",
      "text/x-erlang",
      "text/x-go",
      "text/x-rust",
      "text/x-swift",
      "text/x-kotlin",
      "text/x-scala",
      
      # Configuration files
      "application/toml",
      "text/x-ini",
      "text/x-properties",
      "application/x-httpd-php"
    ]
  end

  @impl true 
  def default_storage_backend, do: :git

  @impl true
  def validate_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")
    
    cond do
      mime_type not in supported_mime_types() ->
        {:error, "Unsupported MIME type: #{mime_type}"}
        
      byte_size(content) > 100 * 1024 * 1024 ->
        {:error, "Document too large (max 100MB)"}
        
      String.starts_with?(mime_type, "text/") and !String.valid?(content) ->
        {:error, "Invalid text encoding"}
        
      true -> 
        :ok
    end
  end

  @impl true
  def transform_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")
    
    case mime_type do
      "text/markdown" ->
        # Extract metadata from markdown frontmatter
        {frontmatter, body} = extract_frontmatter(content)
        updated_metadata = Map.merge(metadata, %{
          frontmatter: frontmatter,
          word_count: count_words(body),
          estimated_read_time: estimate_read_time(body)
        })
        {:ok, content, updated_metadata}
        
      "text/plain" ->
        # Add basic text statistics
        updated_metadata = Map.merge(metadata, %{
          word_count: count_words(content),
          line_count: count_lines(content),
          character_count: String.length(content)
        })
        {:ok, content, updated_metadata}
        
      "application/json" ->
        # Validate and prettify JSON
        case Jason.decode(content) do
          {:ok, data} ->
            pretty_content = Jason.encode!(data, pretty: true)
            updated_metadata = Map.merge(metadata, %{
              json_valid: true,
              json_keys: extract_json_keys(data)
            })
            {:ok, pretty_content, updated_metadata}
            
          {:error, _} ->
            {:error, "Invalid JSON content"}
        end
        
      _ ->
        # No transformation needed for other types
        {:ok, content, metadata}
    end
  end

  @impl true  
  def storage_options(backend, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")
    
    base_options = %{
      mime_type: mime_type,
      media_type: :document
    }
    
    case backend do
      :git ->
        Map.merge(base_options, %{
          commit_message: "Update document content",
          branch: "main",
          enable_lfs: String.starts_with?(mime_type, "application/")
        })
        
      :s3 ->
        Map.merge(base_options, %{
          storage_class: if(String.starts_with?(mime_type, "text/"), do: "STANDARD", else: "STANDARD_IA"),
          server_side_encryption: "AES256"
        })
        
      :disk ->
        Map.merge(base_options, %{
          create_directory: true,
          sync: String.starts_with?(mime_type, "text/")
        })
        
      _ ->
        base_options
    end
  end

  @impl true
  def select_storage_backend(content, metadata) do
    file_size = byte_size(content)
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")
    
    cond do
      # Large binary documents go to S3
      file_size > 10 * 1024 * 1024 and String.starts_with?(mime_type, "application/") ->
        :s3
        
      # Small text files go to Git for version control
      file_size < 1024 * 1024 and String.starts_with?(mime_type, "text/") ->
        :git
        
      # Medium-sized documents go to disk
      file_size < 50 * 1024 * 1024 ->
        :disk
        
      # Very large files go to S3
      true ->
        :s3
    end
  end

  # Additional file-specific actions
  actions do
    # Define create action for JSON API
    create :create do
      accept [:storage_resource_id, :file_id, :relationship_type, :media_type, :is_primary, :metadata]
    end
    
    # Define update action with require_atomic? false
    update :update do
      require_atomic? false
    end
    read :by_file do
      argument :file_id, :uuid, allow_nil?: false
      
      prepare build(
        filter: [file_id: arg(:file_id)],
        load: [:storage_resource, :storage_info, :content_preview],
        sort: [is_primary: :desc, created_at: :desc]
      )
    end

    read :primary_for_file do
      argument :file_id, :uuid, allow_nil?: false
      
      prepare build(
        filter: [file_id: arg(:file_id), is_primary: true],
        load: [:storage_resource, :storage_info]
      )
    end

    create :create_file_content do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :filename, :string, allow_nil?: false
      argument :mime_type, :string
      argument :storage_backend, :atom

      change set_attribute(:is_primary, true)
      change set_attribute(:relationship_type, :primary)
      change {__MODULE__.Changes.RelateToFile, []}
    end

    create :create_file_version do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :version_name, :string, allow_nil?: false
      argument :commit_message, :string

      change set_attribute(:relationship_type, :version)
      change {__MODULE__.Changes.RelateToFile, []}
      change {__MODULE__.Changes.AddVersionMetadata, []}
    end

    update :update_file_storage do
      require_atomic? false
    end

    action :convert_format, :struct do
      argument :target_format, :string, allow_nil?: false
      argument :conversion_options, :map, default: %{}
      
      run {__MODULE__.Actions.ConvertFormat, []}
    end

    action :extract_text, :string do
      run {__MODULE__.Actions.ExtractText, []}
    end

    action :search_content, {:array, :struct} do
      argument :query, :string, allow_nil?: false
      argument :search_options, :map, default: %{}
      
      run {__MODULE__.Actions.SearchContent, []}
    end

    action :update_file_content, :struct do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :commit_message, :string, default: "Update file content"
      
      run {__MODULE__.Actions.UpdateFileContent, []}
    end
  end

  # Additional attributes for file storage
  attributes do
    # Add team_id attribute required by team relationship from base
    attribute :team_id, :uuid do
      allow_nil? false
      public? true
    end
    
    # Add user_id attribute for user relationship from base
    attribute :user_id, :uuid do
      allow_nil? true
      public? true
    end
  end

  # Additional relationships specific to files
  relationships do
    belongs_to :file, Kyozo.Workspaces.File do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end

  # File-specific calculations
  calculations do
    import Kyozo.Storage.AbstractStorage.CommonCalculations

    storage_info()
    content_preview()
    
    calculate :document_stats, :map do
      load [:metadata, :storage_resource]

      calculation fn file_storages, _context ->
        Enum.map(file_storages, fn fs ->
          metadata = fs.metadata || %{}
          storage = fs.storage_resource
          
          %{
            word_count: Map.get(metadata, "word_count", 0),
            line_count: Map.get(metadata, "line_count", 0),
            character_count: Map.get(metadata, "character_count", 0),
            estimated_read_time: Map.get(metadata, "estimated_read_time", 0),
            file_size: storage.file_size,
            last_modified: storage.updated_at,
            is_text: String.starts_with?(storage.mime_type, "text/")
          }
        end)
      end
    end

    calculate :can_edit, :boolean do
      load [:storage_resource]

      calculation fn file_storages, _context ->
        Enum.map(file_storages, fn fs ->
          storage = fs.storage_resource
          String.starts_with?(storage.mime_type, "text/") and 
          storage.storage_backend in [:git, :disk]
        end)
      end
    end

    calculate :version_info, :map do
      load [:metadata, :storage_resource]

      calculation fn file_storages, _context ->
        Enum.map(file_storages, fn fs ->
          metadata = fs.metadata || %{}
          storage = fs.storage_resource
          
          %{
            version: storage.version,
            is_versioned: storage.is_versioned,
            version_name: Map.get(metadata, "version_name"),
            commit_message: Map.get(metadata, "commit_message"),
            created_at: fs.created_at
          }
        end)
      end
    end
  end

  # File-specific validations
  validations do
    validate present([:file_id, :storage_resource_id])
    validate one_of(:relationship_type, [:primary, :version, :format, :backup, :cache])
  end

  # Private helper functions
  defp extract_frontmatter(content) do
    case String.split(content, "\n---\n", parts: 2) do
      [frontmatter_yaml, body] when frontmatter_yaml != content ->
        case YamlElixir.read_from_string(frontmatter_yaml) do
          {:ok, frontmatter} -> {frontmatter, body}
          {:error, _} -> {%{}, content}
        end
      _ ->
        {%{}, content}
    end
  end

  defp count_words(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp count_lines(text) do
    text
    |> String.split("\n")
    |> length()
  end

  defp estimate_read_time(text) do
    word_count = count_words(text)
    # Average reading speed: 200 words per minute
    max(1, div(word_count, 200))
  end

  defp extract_json_keys(data) when is_map(data) do
    Map.keys(data)
  end
  defp extract_json_keys(_), do: []

  # Change modules
  defmodule Changes do
    defmodule RelateToFile do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        file_id = Ash.Changeset.get_argument(changeset, :file_id)
        if file_id do
          Ash.Changeset.change_attribute(changeset, :file_id, file_id)
        else
          changeset
        end
      end
    end

    defmodule AddVersionMetadata do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        version_name = Ash.Changeset.get_argument(changeset, :version_name)
        commit_message = Ash.Changeset.get_argument(changeset, :commit_message)
        
        metadata = %{
          version_name: version_name,
          commit_message: commit_message,
          created_at: DateTime.utc_now()
        }
        
        Ash.Changeset.change_attribute(changeset, :metadata, metadata)
      end
    end

    defmodule CreateStorageResource do
      use Ash.Resource.Change

      def change(changeset, _opts, context) do
        content = Ash.Changeset.get_argument(changeset, :content)
        filename = Ash.Changeset.get_argument(changeset, :filename)
        mime_type = Ash.Changeset.get_argument(changeset, :mime_type)
        storage_backend = Ash.Changeset.get_argument(changeset, :storage_backend)

        if content && filename do
          case Kyozo.Storage.store_content(content, filename, 
                 backend: storage_backend || :hybrid,
                 storage_options: %{}) do
            {:ok, storage_resource} ->
              Ash.Changeset.change_attribute(changeset, :storage_resource_id, storage_resource.id)
            
            {:error, reason} ->
              Ash.Changeset.add_error(changeset, "Failed to create storage resource: #{inspect(reason)}")
          end
        else
          changeset
        end
      end
    end
  end

  # Action modules
  defmodule Actions do
    defmodule UpdateFileContent do
      # # use Ash.Resource.Action

      def run(_storage_entry, input, context) do
        file_id = input.arguments.file_id
        content = input.arguments.content
        commit_message = input.arguments.commit_message
        
        # Find current primary storage for the file
        case Kyozo.Workspaces.FileStorage
             |> Ash.Query.filter(file_id == ^file_id and is_primary == true)
             |> Ash.Query.load(:storage_resource)
             |> Ash.read_one() do
          {:ok, current_storage} when not is_nil(current_storage) ->
            # Create new version using the storage resource
            case Kyozo.Storage.create_version(current_storage.storage_resource, content, 
                   commit_message: commit_message) do
              {:ok, updated_resource} ->
                # Update the file storage metadata
                Ash.update(current_storage, %{
                  metadata: Map.merge(current_storage.metadata || %{}, %{
                    last_updated: DateTime.utc_now(),
                    commit_message: commit_message
                  })
                })
                
              {:error, reason} ->
                {:error, reason}
            end
            
          {:ok, nil} ->
            {:error, "No primary storage found for file"}
            
          {:error, reason} ->
            {:error, reason}
        end
      end
    end

    defmodule ConvertFormat do
      # use Ash.Resource.Action

      def run(file_storage, input, _context) do
        target_format = input.arguments.target_format
        conversion_options = input.arguments.conversion_options
        
        # Get the current content
        case Kyozo.Storage.retrieve_content(file_storage.storage_resource) do
          {:ok, content} ->
            # Perform format conversion (placeholder - implement actual conversion)
            converted_content = convert_content(content, target_format, conversion_options)
            
            # Store the converted content as a new format relationship
            case Kyozo.Storage.store_content(converted_content, 
                   "#{Path.rootname(file_storage.storage_resource.file_name)}.#{target_format}") do
              {:ok, new_storage_resource} ->
                # Create a new FileStorage entry for the converted format
                Ash.create(Kyozo.Workspaces.FileStorage, %{
                  file_id: file_storage.file_id,
                  storage_resource_id: new_storage_resource.id,
                  relationship_type: :format,
                  media_type: :document,
                  is_primary: false,
                  metadata: %{
                    original_format: file_storage.storage_resource.mime_type,
                    target_format: target_format,
                    conversion_options: conversion_options
                  }
                })
                
              {:error, reason} ->
                {:error, reason}
            end
            
          {:error, reason} ->
            {:error, reason}
        end
      end
      
      defp convert_content(content, target_format, _options) do
        # Placeholder implementation - add actual format conversion logic
        content
      end
    end

    defmodule ExtractText do
      # use Ash.Resource.Action

      def run(file_storage, _input, _context) do
        case Kyozo.Storage.retrieve_content(file_storage.storage_resource) do
          {:ok, content} ->
            mime_type = file_storage.storage_resource.mime_type
            extracted_text = extract_text_from_content(content, mime_type)
            {:ok, extracted_text}
            
          {:error, reason} ->
            {:error, reason}
        end
      end
      
      defp extract_text_from_content(content, mime_type) do
        case mime_type do
          "text/" <> _ -> content
          "application/json" -> content
          _ -> "Text extraction not supported for #{mime_type}"
        end
      end
    end

    defmodule SearchContent do
      # use Ash.Resource.Action

      def run(_file_storage, input, _context) do
        query = input.arguments.query
        search_options = input.arguments.search_options
        
        # Implement content search across file storages
        # This is a placeholder implementation
        {:ok, []}
      end
    end
  end

  # Helper functions removed - using direct module references in actions
end