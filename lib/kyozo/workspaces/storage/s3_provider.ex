defmodule Kyozo.Workspaces.Storage.S3Provider do
  @moduledoc """
  S3-based storage provider for workspace files.
  
  This provider manages files in AWS S3 or S3-compatible storage,
  providing scalable object storage for workspace documents, notebooks,
  and binary assets.
  """

  @behaviour Kyozo.Workspaces.Storage

  alias Kyozo.Workspaces.Storage

  require Logger

  @impl true
  def store(file_path, content, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, bucket} <- get_bucket(options),
         {:ok, s3_key} <- build_s3_key(file_path, options),
         {:ok, upload_result} <- upload_to_s3(bucket, s3_key, content, options) do
      
      metadata = Storage.extract_metadata(file_path, content, [
        version: upload_result.version_id || generate_version_id(),
        author: Keyword.get(options, :author, "system"),
        s3_bucket: bucket,
        s3_key: s3_key,
        etag: upload_result.etag
      ])
      
      {:ok, metadata}
    end
  end

  @impl true
  def retrieve(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, bucket} <- get_bucket(options),
         {:ok, s3_key} <- build_s3_key(file_path, options),
         {:ok, s3_object} <- download_from_s3(bucket, s3_key, options) do
      
      metadata = %{
        mime_type: s3_object.content_type || MIME.from_path(file_path),
        size: s3_object.content_length || byte_size(s3_object.body),
        last_modified: s3_object.last_modified || DateTime.utc_now(),
        version: s3_object.version_id || "latest",
        author: get_object_metadata(s3_object, "author", "unknown"),
        s3_bucket: bucket,
        s3_key: s3_key,
        etag: s3_object.etag,
        file_name: Path.basename(file_path),
        directory: Path.dirname(file_path)
      }
      
      {:ok, s3_object.body, metadata}
    end
  end

  @impl true
  def delete(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, bucket} <- get_bucket(options),
         {:ok, s3_key} <- build_s3_key(file_path, options),
         {:ok, _delete_result} <- delete_from_s3(bucket, s3_key, options) do
      :ok
    end
  end

  @impl true
  def list(directory_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, bucket} <- get_bucket(options),
         {:ok, prefix} <- build_s3_key(directory_path, options),
         {:ok, objects} <- list_s3_objects(bucket, prefix, options) do
      
      metadata_list = Enum.map(objects, fn object ->
        %{
          mime_type: object.content_type || MIME.from_path(object.key),
          size: object.size,
          last_modified: object.last_modified,
          version: object.version_id || "latest",
          s3_bucket: bucket,
          s3_key: object.key,
          etag: object.etag,
          file_name: Path.basename(object.key),
          directory: Path.dirname(object.key),
          author: get_object_metadata(object, "author", "unknown")
        }
      end)
      
      {:ok, metadata_list}
    end
  end

  @impl true
  def exists?(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, bucket} <- get_bucket(options),
         {:ok, s3_key} <- build_s3_key(file_path, options) do
      
      case head_s3_object(bucket, s3_key, options) do
        {:ok, _metadata} -> true
        {:error, _} -> false
      end
    else
      _ -> false
    end
  end

  @impl true
  def get_metadata(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, bucket} <- get_bucket(options),
         {:ok, s3_key} <- build_s3_key(file_path, options),
         {:ok, s3_metadata} <- head_s3_object(bucket, s3_key, options) do
      
      metadata = %{
        mime_type: s3_metadata.content_type || MIME.from_path(file_path),
        size: s3_metadata.content_length,
        last_modified: s3_metadata.last_modified,
        version: s3_metadata.version_id || "latest",
        s3_bucket: bucket,
        s3_key: s3_key,
        etag: s3_metadata.etag,
        file_name: Path.basename(file_path),
        directory: Path.dirname(file_path),
        author: get_object_metadata(s3_metadata, "author", "unknown")
      }
      
      {:ok, metadata}
    end
  end

  @impl true
  def create_version(file_path, content, _commit_message, options) do
    # S3 handles versioning automatically if enabled on the bucket
    case store(file_path, content, options) do
      {:ok, metadata} ->
        {:ok, metadata.version, metadata}
      error ->
        error
    end
  end

  @impl true
  def list_versions(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, bucket} <- get_bucket(options),
         {:ok, s3_key} <- build_s3_key(file_path, options),
         {:ok, versions} <- list_s3_object_versions(bucket, s3_key, options) do
      
      version_metadata = Enum.map(versions, fn version ->
        %{
          version: version.version_id,
          last_modified: version.last_modified,
          size: version.size,
          etag: version.etag,
          mime_type: MIME.from_path(file_path),
          file_name: Path.basename(file_path),
          s3_bucket: bucket,
          s3_key: s3_key,
          is_latest: version.is_latest || false
        }
      end)
      
      {:ok, version_metadata}
    end
  end

  @impl true
  def retrieve_version(file_path, version, options) do
    options_with_version = Keyword.put(options, :version_id, version)
    retrieve(file_path, options_with_version)
  end

  @impl true
  def sync(_from_backend, _to_backend, _file_path, _options) do
    # S3 sync would involve cross-region replication or sync to another storage
    {:error, "S3 sync not yet implemented"}
  end

  # Private helper functions

  defp get_bucket(options) do
    bucket = case Keyword.get(options, :s3_bucket) do
      nil ->
        team_id = Keyword.fetch!(options, :team_id)
        "kyozo-workspace-#{team_id}"
      
      bucket_name ->
        bucket_name
    end
    
    {:ok, bucket}
  end

  defp build_s3_key(file_path, options) do
    workspace_id = Keyword.fetch!(options, :workspace_id)
    team_id = Keyword.fetch!(options, :team_id)
    
    s3_key = Path.join([
      "teams",
      to_string(team_id),
      "workspaces", 
      to_string(workspace_id),
      file_path
    ])
    
    {:ok, s3_key}
  end

  defp upload_to_s3(bucket, s3_key, content, options) do
    s3_options = build_s3_upload_options(s3_key, content, options)
    
    case get_s3_client().put_object(bucket, s3_key, content, s3_options) do
      {:ok, result} ->
        Logger.info("Uploaded #{s3_key} to S3 bucket #{bucket}")
        {:ok, result}
      
      {:error, reason} ->
        Logger.error("Failed to upload #{s3_key} to S3: #{inspect(reason)}")
        {:error, "S3 upload failed: #{inspect(reason)}"}
    end
  end

  defp download_from_s3(bucket, s3_key, options) do
    s3_options = build_s3_download_options(options)
    
    case get_s3_client().get_object(bucket, s3_key, s3_options) do
      {:ok, s3_object} ->
        {:ok, s3_object}
      
      {:error, {:http_error, 404, _}} ->
        {:error, "File not found: #{s3_key}"}
      
      {:error, reason} ->
        Logger.error("Failed to download #{s3_key} from S3: #{inspect(reason)}")
        {:error, "S3 download failed: #{inspect(reason)}"}
    end
  end

  defp delete_from_s3(bucket, s3_key, options) do
    s3_options = build_s3_delete_options(options)
    
    case get_s3_client().delete_object(bucket, s3_key, s3_options) do
      {:ok, result} ->
        Logger.info("Deleted #{s3_key} from S3 bucket #{bucket}")
        {:ok, result}
      
      {:error, reason} ->
        Logger.error("Failed to delete #{s3_key} from S3: #{inspect(reason)}")
        {:error, "S3 delete failed: #{inspect(reason)}"}
    end
  end

  defp list_s3_objects(bucket, prefix, options) do
    s3_options = [
      prefix: prefix,
      max_keys: Keyword.get(options, :max_keys, 1000)
    ]
    
    case get_s3_client().list_objects_v2(bucket, s3_options) do
      {:ok, result} ->
        objects = result.contents || []
        {:ok, objects}
      
      {:error, reason} ->
        Logger.error("Failed to list objects in S3: #{inspect(reason)}")
        {:error, "S3 list failed: #{inspect(reason)}"}
    end
  end

  defp head_s3_object(bucket, s3_key, options) do
    s3_options = build_s3_head_options(options)
    
    case get_s3_client().head_object(bucket, s3_key, s3_options) do
      {:ok, metadata} ->
        {:ok, metadata}
      
      {:error, {:http_error, 404, _}} ->
        {:error, "File not found: #{s3_key}"}
      
      {:error, reason} ->
        {:error, "S3 head failed: #{inspect(reason)}"}
    end
  end

  defp list_s3_object_versions(bucket, s3_key, _options) do
    s3_options = [prefix: s3_key]
    
    case get_s3_client().list_object_versions(bucket, s3_options) do
      {:ok, result} ->
        versions = result.versions || []
        {:ok, versions}
      
      {:error, reason} ->
        Logger.error("Failed to list object versions in S3: #{inspect(reason)}")
        {:error, "S3 list versions failed: #{inspect(reason)}"}
    end
  end

  # S3 options builders

  defp build_s3_upload_options(s3_key, content, options) do
    base_options = [
      content_type: MIME.from_path(s3_key),
      metadata: %{
        "author" => Keyword.get(options, :author, "system"),
        "workspace-id" => to_string(Keyword.fetch!(options, :workspace_id)),
        "team-id" => to_string(Keyword.fetch!(options, :team_id)),
        "uploaded-at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    ]
    
    # Add server-side encryption if configured
    encryption_options = case get_s3_encryption_config() do
      nil -> []
      config -> [server_side_encryption: config.algorithm, sse_kms_key_id: config.key_id]
    end
    
    # Add versioning if specified
    version_options = case Keyword.get(options, :enable_versioning, true) do
      true -> []  # S3 handles versioning automatically if enabled on bucket
      false -> []
    end
    
    base_options ++ encryption_options ++ version_options
  end

  defp build_s3_download_options(options) do
    base_options = []
    
    # Add version ID if specified
    case Keyword.get(options, :version_id) do
      nil -> base_options
      version_id -> [version_id: version_id] ++ base_options
    end
  end

  defp build_s3_delete_options(options) do
    base_options = []
    
    # Add version ID if specified (for versioned deletes)
    case Keyword.get(options, :version_id) do
      nil -> base_options
      version_id -> [version_id: version_id] ++ base_options
    end
  end

  defp build_s3_head_options(options) do
    base_options = []
    
    # Add version ID if specified
    case Keyword.get(options, :version_id) do
      nil -> base_options
      version_id -> [version_id: version_id] ++ base_options
    end
  end

  # Helper functions

  defp get_s3_client do
    # This would be replaced with actual S3 client (ExAws, etc.)
    # For now, return a mock client structure
    %{
      put_object: fn bucket, key, content, options ->
        # Mock implementation
        {:ok, %{
          etag: generate_etag(content),
          version_id: generate_version_id()
        }}
      end,
      get_object: fn bucket, key, options ->
        # Mock implementation
        {:ok, %{
          body: "mock content",
          content_type: MIME.from_path(key),
          content_length: 12,
          last_modified: DateTime.utc_now(),
          etag: "mock-etag",
          version_id: "mock-version"
        }}
      end,
      delete_object: fn bucket, key, options ->
        {:ok, %{delete_marker: false}}
      end,
      list_objects_v2: fn bucket, options ->
        {:ok, %{contents: []}}
      end,
      head_object: fn bucket, key, options ->
        {:ok, %{
          content_type: MIME.from_path(key),
          content_length: 0,
          last_modified: DateTime.utc_now(),
          etag: "mock-etag",
          version_id: "mock-version"
        }}
      end,
      list_object_versions: fn bucket, options ->
        {:ok, %{versions: []}}
      end
    }
  end

  defp get_object_metadata(s3_object, key, default) do
    case Map.get(s3_object, :metadata) do
      nil -> default
      metadata -> Map.get(metadata, key, default)
    end
  end

  defp generate_etag(content) do
    :crypto.hash(:md5, content)
    |> Base.encode16(case: :lower)
  end

  defp generate_version_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64(padding: false)
  end

  defp get_s3_encryption_config do
    Application.get_env(:kyozo, :s3_encryption, nil)
  end
end