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
      metadata =
        Storage.extract_metadata(file_path, content,
          version: upload_result.version_id || generate_version_id(),
          author: Keyword.get(options, :author, "system"),
          s3_bucket: bucket,
          s3_key: s3_key,
          etag: upload_result.etag
        )

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
      metadata_list =
        Enum.map(objects, fn object ->
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
      version_metadata =
        Enum.map(versions, fn version ->
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
  def sync(from_backend, to_backend, file_path, options) do
    require Logger

    try do
      Logger.info("Starting S3 sync operation",
        from: from_backend,
        to: to_backend,
        file_path: file_path
      )

      case {from_backend, to_backend} do
        # S3 to S3 sync (cross-region or cross-bucket)
        {:s3, :s3} ->
          sync_s3_to_s3(file_path, options)

        # S3 to other backends
        {:s3, other_backend} ->
          sync_s3_to_backend(file_path, other_backend, options)

        # Other backends to S3
        {other_backend, :s3} ->
          sync_backend_to_s3(file_path, other_backend, options)

        # Unsupported sync combination
        _ ->
          Logger.warning("Unsupported sync combination",
            from: from_backend,
            to: to_backend
          )

          {:error, :unsupported_sync_combination}
      end
    rescue
      exception ->
        Logger.error("S3 sync failed with exception",
          file_path: file_path,
          exception: Exception.message(exception)
        )

        {:error, :sync_failed}
    end
  end

  # Sync between two S3 locations (cross-region or cross-bucket)
  defp sync_s3_to_s3(file_path, options) do
    source_bucket = Keyword.get(options, :source_bucket)
    target_bucket = Keyword.get(options, :target_bucket) || source_bucket
    source_region = Keyword.get(options, :source_region, "us-east-1")
    target_region = Keyword.get(options, :target_region, "us-east-1")

    with {:ok, source_object} <- get_s3_object(source_bucket, file_path, source_region),
         {:ok, target_key} <-
           put_s3_object(target_bucket, file_path, source_object.body, target_region, options) do
      Logger.info("Successfully synced between S3 locations",
        file_path: file_path,
        source: "#{source_bucket}/#{source_region}",
        target: "#{target_bucket}/#{target_region}"
      )

      {:ok,
       %{
         source_bucket: source_bucket,
         target_bucket: target_bucket,
         source_region: source_region,
         target_region: target_region,
         etag: target_key,
         sync_timestamp: DateTime.utc_now()
       }}
    else
      {:error, reason} ->
        Logger.error("S3-to-S3 sync failed",
          file_path: file_path,
          reason: reason
        )

        {:error, reason}
    end
  end

  # Sync from S3 to another backend
  defp sync_s3_to_backend(file_path, target_backend, options) do
    bucket = get_bucket(options)
    region = Keyword.get(options, :region, "us-east-1")

    with {:ok, s3_object} <- get_s3_object(bucket, file_path, region) do
      # Use the target backend's store function
      target_options =
        Keyword.merge(options,
          source: :s3,
          source_metadata: %{
            bucket: bucket,
            region: region,
            etag: s3_object.etag,
            last_modified: s3_object.last_modified
          }
        )

      case target_backend do
        :git ->
          Kyozo.Workspaces.Storage.GitProvider.store(file_path, s3_object.body, target_options)

        :disk ->
          Kyozo.Workspaces.Storage.DiskProvider.store(file_path, s3_object.body, target_options)

        _ ->
          {:error, :unsupported_target_backend}
      end
      |> case do
        {:ok, target_metadata} ->
          Logger.info("Successfully synced from S3 to #{target_backend}",
            file_path: file_path
          )

          {:ok,
           %{
             source_metadata: %{bucket: bucket, region: region},
             target_metadata: target_metadata,
             sync_timestamp: DateTime.utc_now()
           }}

        {:error, reason} ->
          Logger.error("Failed to sync from S3 to #{target_backend}",
            file_path: file_path,
            reason: reason
          )

          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to read from S3 for sync",
          file_path: file_path,
          reason: reason
        )

        {:error, reason}
    end
  end

  # Sync from another backend to S3
  defp sync_backend_to_s3(file_path, source_backend, options) do
    # First retrieve from source backend
    source_result =
      case source_backend do
        :git ->
          Kyozo.Workspaces.Storage.GitProvider.retrieve(file_path, options)

        :disk ->
          Kyozo.Workspaces.Storage.DiskProvider.retrieve(file_path, options)

        _ ->
          {:error, :unsupported_source_backend}
      end

    case source_result do
      {:ok, content, source_metadata} ->
        # Store in S3
        s3_options =
          Keyword.merge(options,
            source_backend: source_backend,
            source_metadata: source_metadata
          )

        case store(file_path, content, s3_options) do
          {:ok, s3_metadata} ->
            Logger.info("Successfully synced from #{source_backend} to S3",
              file_path: file_path
            )

            {:ok,
             %{
               source_metadata: source_metadata,
               target_metadata: s3_metadata,
               sync_timestamp: DateTime.utc_now()
             }}

          {:error, reason} ->
            Logger.error("Failed to store in S3 during sync",
              file_path: file_path,
              reason: reason
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to retrieve from #{source_backend} for sync",
          file_path: file_path,
          reason: reason
        )

        {:error, reason}
    end
  end

  # Get S3 object with metadata
  defp get_s3_object(bucket, key, region) do
    request = ExAws.S3.get_object(bucket, key)

    case ExAws.request(request, region: region) do
      {:ok, %{body: body, headers: headers}} ->
        {:ok,
         %{
           body: body,
           etag: get_header_value(headers, "etag", ""),
           last_modified: get_header_value(headers, "last-modified", ""),
           content_type: get_header_value(headers, "content-type", "application/octet-stream")
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Put S3 object with options
  defp put_s3_object(bucket, key, content, region, options) do
    content_type = Keyword.get(options, :content_type, MIME.from_path(key))
    storage_class = Keyword.get(options, :storage_class, "STANDARD")

    put_options = [
      content_type: content_type,
      storage_class: storage_class
    ]

    # Add server-side encryption if specified
    put_options =
      case Keyword.get(options, :encryption) do
        nil -> put_options
        encryption -> put_options ++ [server_side_encryption: encryption]
      end

    request = ExAws.S3.put_object(bucket, key, content, put_options)

    case ExAws.request(request, region: region) do
      {:ok, %{headers: headers}} ->
        etag = get_header_value(headers, "etag", "")
        {:ok, etag}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper to get header value
  defp get_header_value(headers, key, default) do
    headers
    |> Enum.find_value(default, fn {header_key, value} ->
      if String.downcase(header_key) == String.downcase(key), do: value
    end)
  end

  # Private helper functions

  defp get_bucket(options) do
    bucket =
      case Keyword.get(options, :s3_bucket) do
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

    s3_key =
      Path.join([
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
    encryption_options =
      case get_s3_encryption_config() do
        nil -> []
        config -> [server_side_encryption: config.algorithm, sse_kms_key_id: config.key_id]
      end

    # Add versioning if specified
    version_options =
      case Keyword.get(options, :enable_versioning, true) do
        # S3 handles versioning automatically if enabled on bucket
        true -> []
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
        {:ok,
         %{
           etag: generate_etag(content),
           version_id: generate_version_id()
         }}
      end,
      get_object: fn bucket, key, options ->
        # Mock implementation
        {:ok,
         %{
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
        {:ok,
         %{
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
