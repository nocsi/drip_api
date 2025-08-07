defmodule Kyozo.Workspaces.Storage.HybridProvider do
  @moduledoc """
  Hybrid storage provider that combines Git and S3 backends.
  
  This provider intelligently routes files to the most appropriate backend:
  - Text files, notebooks, and code files go to Git for version control
  - Binary files, images, and large assets go to S3 for scalable storage
  - Provides unified interface while leveraging strengths of each backend
  """

  @behaviour Kyozo.Workspaces.Storage

  alias Kyozo.Workspaces.Storage
  alias Kyozo.Workspaces.Storage.GitProvider
  alias Kyozo.Workspaces.Storage.S3Provider

  require Logger

  # File types that should use Git (text-based, version-controlled)
  @git_extensions [".md", ".ipynb", ".py", ".js", ".ts", ".jsx", ".tsx", ".json", 
                   ".yaml", ".yml", ".toml", ".txt", ".sql", ".ex", ".exs", 
                   ".rs", ".go", ".java", ".cpp", ".c", ".h", ".css", ".scss", 
                   ".less", ".html", ".xml", ".csv", ".r", ".R", ".jl", ".sh"]

  # File types that should use S3 (binary, large files)
  @s3_extensions [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".svg", ".ico",
                  ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
                  ".zip", ".tar", ".gz", ".7z", ".rar", ".mp4", ".avi", ".mov",
                  ".mp3", ".wav", ".flac", ".ogg", ".woff", ".woff2", ".ttf",
                  ".otf", ".eot", ".dmg", ".iso", ".exe", ".msi", ".deb", ".rpm"]

  # Maximum file size for Git storage (in bytes) - 10MB
  @max_git_file_size 10 * 1024 * 1024

  @impl true
  def store(file_path, content, options) do
    backend = determine_backend(file_path, content, options)
    provider = get_provider(backend)
    
    Logger.info("Storing #{file_path} using #{backend} backend")
    
    case provider.store(file_path, content, options) do
      {:ok, metadata} ->
        # Add backend information to metadata
        enhanced_metadata = Map.put(metadata, :storage_backend, backend)
        
        # If using Git, create S3 backup for large files
        if backend == :git and should_backup_to_s3?(file_path, content) do
          create_s3_backup(file_path, content, options, enhanced_metadata)
        else
          {:ok, enhanced_metadata}
        end
      
      error ->
        error
    end
  end

  @impl true
  def retrieve(file_path, options) do
    # Try to determine backend from options or file characteristics
    backend = case Keyword.get(options, :preferred_backend) do
      nil -> determine_backend_for_retrieval(file_path, options)
      backend -> backend
    end
    
    provider = get_provider(backend)
    
    case provider.retrieve(file_path, options) do
      {:ok, content, metadata} ->
        enhanced_metadata = Map.put(metadata, :storage_backend, backend)
        {:ok, content, enhanced_metadata}
      
      {:error, _reason} when backend == :git ->
        # Fallback to S3 if Git retrieval fails
        Logger.info("Git retrieval failed for #{file_path}, trying S3 fallback")
        fallback_retrieve(file_path, options, :s3)
      
      {:error, _reason} when backend == :s3 ->
        # Fallback to Git if S3 retrieval fails
        Logger.info("S3 retrieval failed for #{file_path}, trying Git fallback")
        fallback_retrieve(file_path, options, :git)
      
      error ->
        error
    end
  end

  @impl true
  def delete(file_path, options) do
    # Try to delete from both backends to ensure complete removal
    git_result = GitProvider.delete(file_path, options)
    s3_result = S3Provider.delete(file_path, options)
    
    case {git_result, s3_result} do
      {:ok, :ok} -> :ok
      {:ok, {:error, _}} -> :ok  # Deleted from Git successfully
      {{:error, _}, :ok} -> :ok  # Deleted from S3 successfully
      {{:error, git_error}, {:error, s3_error}} ->
        Logger.error("Failed to delete #{file_path} from both backends. Git: #{inspect(git_error)}, S3: #{inspect(s3_error)}")
        {:error, "Failed to delete from both backends"}
    end
  end

  @impl true
  def list(directory_path, options) do
    # List from both backends and merge results
    with {:ok, git_files} <- safe_list(GitProvider, directory_path, options),
         {:ok, s3_files} <- safe_list(S3Provider, directory_path, options) do
      
      # Merge and deduplicate files
      all_files = git_files ++ s3_files
      unique_files = deduplicate_file_list(all_files)
      
      {:ok, unique_files}
    else
      error -> error
    end
  end

  @impl true
  def exists?(file_path, options) do
    GitProvider.exists?(file_path, options) or S3Provider.exists?(file_path, options)
  end

  @impl true
  def get_metadata(file_path, options) do
    # Try Git first, then S3
    case GitProvider.get_metadata(file_path, options) do
      {:ok, metadata} ->
        {:ok, Map.put(metadata, :storage_backend, :git)}
      
      {:error, _} ->
        case S3Provider.get_metadata(file_path, options) do
          {:ok, metadata} ->
            {:ok, Map.put(metadata, :storage_backend, :s3)}
          
          error ->
            error
        end
    end
  end

  @impl true
  def create_version(file_path, content, commit_message, options) do
    backend = determine_backend(file_path, content, options)
    provider = get_provider(backend)
    
    case provider.create_version(file_path, content, commit_message, options) do
      {:ok, version, metadata} ->
        enhanced_metadata = Map.put(metadata, :storage_backend, backend)
        {:ok, version, enhanced_metadata}
      
      error ->
        error
    end
  end

  @impl true
  def list_versions(file_path, options) do
    # Try Git first (better versioning), then S3
    case GitProvider.list_versions(file_path, options) do
      {:ok, versions} ->
        enhanced_versions = Enum.map(versions, &Map.put(&1, :storage_backend, :git))
        {:ok, enhanced_versions}
      
      {:error, _} ->
        case S3Provider.list_versions(file_path, options) do
          {:ok, versions} ->
            enhanced_versions = Enum.map(versions, &Map.put(&1, :storage_backend, :s3))
            {:ok, enhanced_versions}
          
          error ->
            error
        end
    end
  end

  @impl true
  def retrieve_version(file_path, version, options) do
    # Try to determine which backend has this version
    case GitProvider.retrieve_version(file_path, version, options) do
      {:ok, content, metadata} ->
        enhanced_metadata = Map.put(metadata, :storage_backend, :git)
        {:ok, content, enhanced_metadata}
      
      {:error, _} ->
        case S3Provider.retrieve_version(file_path, version, options) do
          {:ok, content, metadata} ->
            enhanced_metadata = Map.put(metadata, :storage_backend, :s3)
            {:ok, content, enhanced_metadata}
          
          error ->
            error
        end
    end
  end

  @impl true
  def sync(from_backend, to_backend, file_path, options) do
    from_provider = get_provider(from_backend)
    to_provider = get_provider(to_backend)
    
    with {:ok, content, metadata} <- from_provider.retrieve(file_path, options),
         {:ok, sync_metadata} <- to_provider.store(file_path, content, options) do
      
      sync_result = %{
        from_backend: from_backend,
        to_backend: to_backend,
        from_metadata: metadata,
        to_metadata: sync_metadata,
        synced_at: DateTime.utc_now()
      }
      
      {:ok, sync_result}
    end
  end

  # Private helper functions

  defp determine_backend(file_path, content, options) do
    cond do
      # Check explicit backend preference
      Keyword.has_key?(options, :force_backend) ->
        Keyword.get(options, :force_backend)
      
      # Check file size - large files go to S3
      byte_size(content) > @max_git_file_size ->
        :s3
      
      # Check file extension
      is_git_file?(file_path) ->
        :git
      
      is_s3_file?(file_path) ->
        :s3
      
      # Check content type for text vs binary
      is_text_content?(content) ->
        :git
      
      # Default to S3 for unknown binary files
      true ->
        :s3
    end
  end

  defp determine_backend_for_retrieval(file_path, options) do
    cond do
      Keyword.has_key?(options, :preferred_backend) ->
        Keyword.get(options, :preferred_backend)
      
      is_git_file?(file_path) ->
        :git
      
      is_s3_file?(file_path) ->
        :s3
      
      true ->
        :git  # Default to Git for retrieval attempts
    end
  end

  defp is_git_file?(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    extension in @git_extensions
  end

  defp is_s3_file?(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    extension in @s3_extensions
  end

  defp is_text_content?(content) do
    # Simple heuristic: check if content is valid UTF-8 and doesn't contain null bytes
    String.valid?(content) and not String.contains?(content, <<0>>)
  end

  defp should_backup_to_s3?(file_path, content) do
    # Create S3 backup for large Git files or important documents
    byte_size(content) > 1024 * 1024 or  # Files larger than 1MB
    Path.extname(file_path) in [".ipynb", ".md"] or  # Important document types
    String.contains?(file_path, "README")  # Important documentation
  end

  defp create_s3_backup(file_path, content, options, git_metadata) do
    backup_path = "backups/git/" <> file_path
    
    case S3Provider.store(backup_path, content, options) do
      {:ok, s3_metadata} ->
        enhanced_metadata = Map.merge(git_metadata, %{
          backup_backend: :s3,
          backup_metadata: s3_metadata,
          backup_created_at: DateTime.utc_now()
        })
        {:ok, enhanced_metadata}
      
      {:error, reason} ->
        Logger.warn("Failed to create S3 backup for #{file_path}: #{inspect(reason)}")
        {:ok, git_metadata}  # Return original metadata, backup failure is not critical
    end
  end

  defp fallback_retrieve(file_path, options, fallback_backend) do
    fallback_provider = get_provider(fallback_backend)
    
    case fallback_provider.retrieve(file_path, options) do
      {:ok, content, metadata} ->
        enhanced_metadata = Map.merge(metadata, %{
          storage_backend: fallback_backend,
          retrieved_via_fallback: true
        })
        {:ok, content, enhanced_metadata}
      
      error ->
        error
    end
  end

  defp safe_list(provider, directory_path, options) do
    case provider.list(directory_path, options) do
      {:ok, files} -> {:ok, files}
      {:error, _reason} -> {:ok, []}  # Return empty list if one backend fails
    end
  end

  defp deduplicate_file_list(files) do
    files
    |> Enum.group_by(fn metadata -> metadata.file_name end)
    |> Enum.map(fn {_file_name, duplicates} ->
      # Prefer Git metadata over S3 for duplicates
      Enum.find(duplicates, fn metadata -> 
        Map.get(metadata, :storage_backend) == :git 
      end) || List.first(duplicates)
    end)
  end

  defp get_provider(:git), do: GitProvider
  defp get_provider(:s3), do: S3Provider
  defp get_provider(backend), do: raise(ArgumentError, "Unknown backend: #{backend}")
end