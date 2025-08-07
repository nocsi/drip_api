defmodule Kyozo.Workspaces.FileTypeMapper do
  @moduledoc """
  File type mapping system that routes files to appropriate storage implementations.
  
  This module provides intelligent mapping between file types, MIME types, and storage
  implementations, ensuring that each file type gets stored using the most appropriate
  storage backend and processing pipeline.
  
  ## Supported Storage Types
  
  - **FileStorage**: General documents, text files, code files
  - **ImageStorage**: Images with automatic processing and thumbnails
  - **VideoStorage**: Video files with transcoding support (future)
  - **AudioStorage**: Audio files with format conversion (future)
  - **ArchiveStorage**: Compressed archives and packages (future)
  
  ## Backend Selection Logic
  
  - Text files and code → Git backend for version control
  - Images → S3/Disk backend with processing pipeline
  - Large binaries → S3 backend for scalability
  - Frequently accessed → Disk backend for performance
  - Temporary files → RAM backend for speed
  """

  alias Kyozo.Workspaces.{File, FileStorage, ImageStorage}
  alias Kyozo.Storage.StorageResource

  @type storage_type :: :file | :image | :video | :audio | :archive
  @type storage_backend :: :git | :s3 | :disk | :ram | :hybrid
  @type mime_type :: String.t()
  @type file_extension :: String.t()
  @type storage_config :: %{
    storage_type: storage_type(),
    storage_backend: storage_backend(),
    storage_module: module(),
    processing_options: map()
  }

  # File type to storage type mappings
  @file_type_mappings %{
    # Text and document files
    "text/plain" => :file,
    "text/markdown" => :file,
    "text/html" => :file,
    "text/css" => :file,
    "text/javascript" => :file,
    "text/csv" => :file,
    "text/tab-separated-values" => :file,
    "text/xml" => :file,
    "application/xml" => :file,
    "application/json" => :file,
    "application/yaml" => :file,
    "text/yaml" => :file,
    
    # Office documents
    "application/pdf" => :file,
    "application/msword" => :file,
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => :file,
    "application/vnd.ms-excel" => :file,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => :file,
    "application/vnd.ms-powerpoint" => :file,
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" => :file,
    "application/rtf" => :file,
    
    # Code files
    "text/x-python" => :file,
    "text/x-ruby" => :file,
    "text/x-php" => :file,
    "text/x-java" => :file,
    "text/x-c" => :file,
    "text/x-cpp" => :file,
    "text/x-csharp" => :file,
    "text/x-elixir" => :file,
    "text/x-erlang" => :file,
    "text/x-go" => :file,
    "text/x-rust" => :file,
    "text/x-swift" => :file,
    "text/x-kotlin" => :file,
    "text/x-scala" => :file,
    
    # Configuration files
    "application/toml" => :file,
    "text/x-ini" => :file,
    "text/x-properties" => :file,
    
    # Image files
    "image/jpeg" => :image,
    "image/jpg" => :image,
    "image/png" => :image,
    "image/gif" => :image,
    "image/webp" => :image,
    "image/bmp" => :image,
    "image/tiff" => :image,
    "image/svg+xml" => :image,
    "image/x-icon" => :image,
    "image/vnd.microsoft.icon" => :image,
    "image/heic" => :image,
    "image/heif" => :image,
    "image/avif" => :image,
    
    # Video files (future implementation)
    "video/mp4" => :video,
    "video/webm" => :video,
    "video/ogg" => :video,
    "video/avi" => :video,
    "video/quicktime" => :video,
    "video/x-msvideo" => :video,
    
    # Audio files (future implementation)
    "audio/mpeg" => :audio,
    "audio/mp4" => :audio,
    "audio/ogg" => :audio,
    "audio/wav" => :audio,
    "audio/webm" => :audio,
    "audio/flac" => :audio,
    
    # Archive files (future implementation)
    "application/zip" => :archive,
    "application/x-tar" => :archive,
    "application/gzip" => :archive,
    "application/x-7z-compressed" => :archive,
    "application/x-rar-compressed" => :archive
  }

  # Extension-based mappings (fallback when MIME type detection fails)
  @extension_mappings %{
    # Text and documents
    ".txt" => :file,
    ".md" => :file,
    ".markdown" => :file,
    ".html" => :file,
    ".htm" => :file,
    ".css" => :file,
    ".js" => :file,
    ".ts" => :file,
    ".json" => :file,
    ".xml" => :file,
    ".yaml" => :file,
    ".yml" => :file,
    ".toml" => :file,
    ".ini" => :file,
    ".conf" => :file,
    ".config" => :file,
    ".csv" => :file,
    ".tsv" => :file,
    
    # Code files
    ".py" => :file,
    ".rb" => :file,
    ".php" => :file,
    ".java" => :file,
    ".c" => :file,
    ".cpp" => :file,
    ".cc" => :file,
    ".cxx" => :file,
    ".h" => :file,
    ".hpp" => :file,
    ".cs" => :file,
    ".ex" => :file,
    ".exs" => :file,
    ".erl" => :file,
    ".hrl" => :file,
    ".go" => :file,
    ".rs" => :file,
    ".swift" => :file,
    ".kt" => :file,
    ".scala" => :file,
    ".sh" => :file,
    ".bash" => :file,
    ".zsh" => :file,
    ".fish" => :file,
    ".dockerfile" => :file,
    ".sql" => :file,
    ".r" => :file,
    ".m" => :file,
    ".mm" => :file,
    ".pl" => :file,
    ".pm" => :file,
    ".lua" => :file,
    ".vim" => :file,
    ".vimrc" => :file,
    
    # Office documents
    ".pdf" => :file,
    ".doc" => :file,
    ".docx" => :file,
    ".xls" => :file,
    ".xlsx" => :file,
    ".ppt" => :file,
    ".pptx" => :file,
    ".rtf" => :file,
    ".odt" => :file,
    ".ods" => :file,
    ".odp" => :file,
    
    # Images
    ".jpg" => :image,
    ".jpeg" => :image,
    ".png" => :image,
    ".gif" => :image,
    ".webp" => :image,
    ".bmp" => :image,
    ".tiff" => :image,
    ".svg" => :image,
    ".ico" => :image,
    ".heic" => :image,
    ".heif" => :image,
    ".avif" => :image,
    
    # Video
    ".mp4" => :video,
    ".webm" => :video,
    ".ogv" => :video,
    ".avi" => :video,
    ".mov" => :video,
    ".wmv" => :video,
    ".flv" => :video,
    ".mkv" => :video,
    
    # Audio
    ".mp3" => :audio,
    ".m4a" => :audio,
    ".ogg" => :audio,
    ".wav" => :audio,
    ".flac" => :audio,
    ".aac" => :audio,
    ".wma" => :audio,
    
    # Notebooks
    ".ipynb" => :notebook,
    ".rmd" => :notebook,
    ".qmd" => :notebook,
    
    # Archives
    ".zip" => :archive,
    ".tar" => :archive,
    ".gz" => :archive,
    ".7z" => :archive,
    ".rar" => :archive,
    ".bz2" => :archive,
    ".xz" => :archive
  }

  # Storage module mappings
  @storage_modules %{
    file: FileStorage,
    image: ImageStorage,
    notebook: FileNotebook
    # video: VideoStorage,      # Future implementation
    # audio: AudioStorage,      # Future implementation  
    # archive: ArchiveStorage   # Future implementation
  }

  @doc """
  Determines the appropriate storage configuration for a file.
  
  ## Examples
  
      iex> determine_storage_config("document.md", "text/markdown")
      %{
        storage_type: :file,
        storage_backend: :git,
        storage_module: Kyozo.Workspaces.FileStorage,
        processing_options: %{enable_versioning: true}
      }
      
      iex> determine_storage_config("photo.jpg", "image/jpeg")
      %{
        storage_type: :image,
        storage_backend: :s3,
        storage_module: Kyozo.Workspaces.ImageStorage,
        processing_options: %{generate_thumbnails: true}
      }
  """
  @spec determine_storage_config(String.t(), mime_type(), keyword()) :: storage_config()
  def determine_storage_config(filename, mime_type, opts \\ []) do
    storage_type = determine_storage_type(filename, mime_type)
    storage_backend = determine_storage_backend(filename, mime_type, storage_type, opts)
    storage_module = Map.get(@storage_modules, storage_type)
    processing_options = determine_processing_options(storage_type, storage_backend, opts)

    %{
      storage_type: storage_type,
      storage_backend: storage_backend,
      storage_module: storage_module,
      processing_options: processing_options
    }
  end

  @doc """
  Determines the storage type based on file name and MIME type.
  """
  @spec determine_storage_type(String.t(), mime_type()) :: storage_type()
  def determine_storage_type(filename, mime_type) do
    # First try MIME type mapping
    case Map.get(@file_type_mappings, mime_type) do
      nil ->
        # Fall back to extension mapping
        extension = filename |> Path.extname() |> String.downcase()
        Map.get(@extension_mappings, extension, :file)
      
      storage_type ->
        storage_type
    end
  end

  @doc """
  Determines the optimal storage backend for a file.
  """
  @spec determine_storage_backend(String.t(), mime_type(), storage_type(), keyword()) :: storage_backend()
  def determine_storage_backend(filename, mime_type, storage_type, opts \\ []) do
    file_size = Keyword.get(opts, :file_size, 0)
    prefer_versioning = Keyword.get(opts, :prefer_versioning, false)
    override_backend = Keyword.get(opts, :backend)

    # Return override if specified
    if override_backend do
      override_backend
    else
      case storage_type do
        :file ->
          determine_file_backend(filename, mime_type, file_size, prefer_versioning)
        
        :image ->
          determine_image_backend(filename, mime_type, file_size)
        
        :video ->
          determine_video_backend(filename, mime_type, file_size)
        
        :notebook ->
          determine_notebook_backend(filename, mime_type, file_size)
        
        :audio ->
          determine_audio_backend(filename, mime_type, file_size)
        
        :archive ->
          determine_archive_backend(filename, mime_type, file_size)
        
        _ ->
          :hybrid
      end
    end
  end

  @doc """
  Creates a storage entry for a file using the appropriate storage implementation.
  """
  @spec create_storage_entry(File.t(), binary(), keyword()) :: 
    {:ok, FileStorage.t() | ImageStorage.t()} | {:error, any()}
  def create_storage_entry(%File{} = file, content, opts \\ []) do
    config = determine_storage_config(file.name, file.content_type, 
                                    Keyword.put(opts, :file_size, byte_size(content)))
    
    case config.storage_module do
      nil ->
        {:error, "No storage module available for storage type: #{config.storage_type}"}
      
      storage_module ->
        # Create the storage entry using the appropriate action
        case config.storage_type do
          :file ->
            FileStorage.create_file_content(%{
              file_id: file.id,
              content: content,
              filename: file.name,
              mime_type: file.content_type,
              storage_backend: config.storage_backend
            })
          
          :image ->
            Kyozo.Workspaces.FileMedia.create_from_file(%{
              file_id: file.id,
              content: content,
              storage_backend: config.storage_backend
            })
          
          :notebook ->
            Kyozo.Workspaces.FileNotebook.create_from_file(%{
              file_id: file.id,
              content: content,
              storage_backend: config.storage_backend
            })
          
          _ ->
            {:error, "Unsupported storage type: #{config.storage_type}"}
        end
    end
  end

  @doc """
  Gets all supported MIME types across all storage implementations.
  """
  @spec supported_mime_types() :: [mime_type()]
  def supported_mime_types do
    Map.keys(@file_type_mappings)
  end

  @doc """
  Gets all supported file extensions across all storage implementations.
  """
  @spec supported_extensions() :: [file_extension()]
  def supported_extensions do
    Map.keys(@extension_mappings)
  end

  @doc """
  Checks if a file type is supported by any storage implementation.
  """
  @spec supported?(String.t(), mime_type()) :: boolean()
  def supported?(filename, mime_type) do
    storage_type = determine_storage_type(filename, mime_type)
    Map.has_key?(@storage_modules, storage_type)
  end

  @doc """
  Gets storage statistics grouped by storage type and backend.
  """
  @spec get_storage_statistics() :: {:ok, map()} | {:error, any()}
  def get_storage_statistics do
    # This would aggregate statistics from all storage implementations
    # Implementation depends on the specific storage modules
    {:ok, %{}}
  end

  # Private helper functions

  defp determine_file_backend(filename, mime_type, file_size, prefer_versioning) do
    cond do
      # Code files and small text files prefer Git for versioning
      prefer_versioning or is_code_file?(filename) or 
      (String.starts_with?(mime_type, "text/") and file_size < 1024 * 1024) ->
        :git
      
      # Large documents go to S3
      file_size > 10 * 1024 * 1024 ->
        :s3
      
      # Medium files go to disk
      file_size < 50 * 1024 * 1024 ->
        :disk
      
      # Default to hybrid for intelligent selection
      true ->
        :hybrid
    end
  end

  defp determine_image_backend(_filename, _mime_type, file_size) do
    cond do
      # Large images go to S3
      file_size > 5 * 1024 * 1024 ->
        :s3
      
      # Medium images go to disk with processing
      file_size > 100 * 1024 ->
        :disk
      
      # Small images can use hybrid
      true ->
        :hybrid
    end
  end

  defp determine_notebook_backend(filename, mime_type, file_size) do
    cond do
      # Jupyter notebooks with outputs prefer hybrid (Git + S3 for outputs)
      String.ends_with?(filename, ".ipynb") and file_size > 1024 * 1024 ->
        :hybrid
      
      # Small notebooks prefer Git for version control
      file_size < 5 * 1024 * 1024 ->
        :git
      
      # Large notebooks go to hybrid
      true ->
        :hybrid
    end
  end

  defp determine_video_backend(_filename, _mime_type, file_size) do
    # Videos are typically large and benefit from S3's streaming capabilities
    if file_size > 100 * 1024 * 1024 do
      :s3
    else
      :disk
    end
  end

  defp determine_audio_backend(_filename, _mime_type, file_size) do
    # Audio files are medium-sized, disk is usually sufficient
    if file_size > 50 * 1024 * 1024 do
      :s3
    else
      :disk
    end
  end

  defp determine_archive_backend(_filename, _mime_type, file_size) do
    # Archives can be large and are accessed infrequently
    if file_size > 10 * 1024 * 1024 do
      :s3
    else
      :disk
    end
  end

  defp determine_processing_options(:file, backend, _opts) do
    %{
      enable_versioning: backend in [:git, :hybrid],
      extract_metadata: true,
      validate_encoding: true
    }
  end

  defp determine_processing_options(:image, backend, _opts) do
    %{
      generate_thumbnails: true,
      extract_exif: true,
      optimize_storage: backend in [:s3, :disk],
      allowed_formats: ["jpeg", "png", "webp", "gif"]
    }
  end

  defp determine_processing_options(:notebook, backend, _opts) do
    %{
      enable_versioning: backend in [:git, :hybrid],
      extract_metadata: true,
      parse_cells: true,
      track_execution: true,
      clear_outputs_on_save: backend == :git
    }
  end

  defp determine_processing_options(:video, backend, _opts) do
    %{
      generate_thumbnails: true,
      extract_metadata: true,
      transcode: backend == :s3,
      streaming_optimized: true
    }
  end

  defp determine_processing_options(:audio, backend, _opts) do
    %{
      extract_metadata: true,
      normalize_audio: false,
      generate_waveform: backend == :disk
    }
  end

  defp determine_processing_options(:archive, _backend, _opts) do
    %{
      scan_contents: true,
      extract_file_list: true,
      validate_integrity: true
    }
  end

  defp determine_processing_options(_, _, _), do: %{}

  defp is_code_file?(filename) do
    extension = filename |> Path.extname() |> String.downcase()
    
    extension in [
      ".ex", ".exs", ".py", ".js", ".ts", ".rb", ".go", 
      ".rs", ".java", ".c", ".cpp", ".h", ".hpp",
      ".php", ".html", ".css", ".scss", ".sql",
      ".sh", ".bash", ".zsh", ".fish", ".dockerfile",
      ".yaml", ".yml", ".json", ".toml", ".ini"
    ]
  end
end