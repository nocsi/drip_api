defmodule Dirup.Storage.Providers.S3 do
  @moduledoc """
  AWS S3-based storage provider for the Kyozo storage system.

  Provides scalable cloud storage with versioning, metadata tracking,
  and integration with AWS S3 bucket policies and lifecycle management.
  """

  require Logger

  @doc """
  Write content to S3 storage.
  """
  def write(locator_id, content, opts \\ []) when is_binary(locator_id) and is_binary(content) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    Logger.debug("Writing to S3 storage",
      locator_id: locator_id,
      bucket: bucket,
      key: key,
      size: byte_size(content)
    )

    metadata = %{
      "kyozo-locator-id" => locator_id,
      "kyozo-stored-at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "kyozo-storage-backend" => "s3"
    }

    s3_options =
      opts
      |> Keyword.get(:s3_options, [])
      |> Keyword.merge(
        content_type: get_content_type(locator_id, opts),
        metadata: metadata
      )

    case ExAws.S3.put_object(bucket, key, content, s3_options)
         |> ExAws.request() do
      {:ok, response} ->
        version_id = Map.get(response, :version_id)

        {:ok,
         %{
           locator_id: locator_id,
           size: byte_size(content),
           stored_at: DateTime.utc_now(),
           storage_backend: :s3,
           bucket: bucket,
           key: key,
           version_id: version_id,
           etag: Map.get(response, :etag)
         }}

      {:error, reason} ->
        Logger.error("Failed to write to S3 storage",
          locator_id: locator_id,
          bucket: bucket,
          key: key,
          error: reason
        )

        {:error, "Could not write to S3: #{inspect(reason)}"}
    end
  end

  @doc """
  Read content from S3 storage.
  """
  def read(locator_id, opts \\ []) when is_binary(locator_id) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    Logger.debug("Reading from S3 storage",
      locator_id: locator_id,
      bucket: bucket,
      key: key
    )

    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: content}} ->
        {:ok, content}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to read from S3 storage",
          locator_id: locator_id,
          bucket: bucket,
          key: key,
          error: reason
        )

        {:error, "Could not read from S3: #{inspect(reason)}"}
    end
  end

  @doc """
  Delete content from S3 storage.
  """
  def delete(locator_id, opts \\ []) when is_binary(locator_id) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    Logger.debug("Deleting from S3 storage",
      locator_id: locator_id,
      bucket: bucket,
      key: key
    )

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _response} ->
        :ok

      {:error, {:http_error, 404, _}} ->
        # Already deleted is OK
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete from S3 storage",
          locator_id: locator_id,
          bucket: bucket,
          key: key,
          error: reason
        )

        {:error, "Could not delete from S3: #{inspect(reason)}"}
    end
  end

  @doc """
  Create a new version of content in S3 storage.
  For S3, this leverages S3's built-in versioning if enabled.
  """
  def create_version(locator_id, content, commit_message, opts \\ []) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    Logger.debug("Creating S3 version",
      locator_id: locator_id,
      bucket: bucket,
      key: key,
      commit_message: commit_message
    )

    metadata = %{
      "kyozo-locator-id" => locator_id,
      "kyozo-stored-at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "kyozo-storage-backend" => "s3",
      "kyozo-commit-message" => commit_message,
      "kyozo-version-created-at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    s3_options =
      opts
      |> Keyword.get(:s3_options, [])
      |> Keyword.merge(
        content_type: get_content_type(locator_id, opts),
        metadata: metadata
      )

    case ExAws.S3.put_object(bucket, key, content, s3_options)
         |> ExAws.request() do
      {:ok, response} ->
        version_id = Map.get(response, :version_id, generate_version_id())

        {:ok, version_id,
         %{
           version: version_id,
           stored_at: DateTime.utc_now(),
           size: byte_size(content),
           commit_message: commit_message,
           storage_backend: :s3,
           bucket: bucket,
           key: key,
           etag: Map.get(response, :etag)
         }}

      {:error, reason} ->
        Logger.error("Failed to create S3 version",
          locator_id: locator_id,
          bucket: bucket,
          key: key,
          error: reason
        )

        {:error, "Could not create S3 version: #{inspect(reason)}"}
    end
  end

  @doc """
  List all versions for a given file in S3.
  """
  def list_versions(locator_id, opts \\ []) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    Logger.debug("Listing S3 versions",
      locator_id: locator_id,
      bucket: bucket,
      key: key
    )

    case ExAws.S3.list_object_versions(bucket, prefix: key) |> ExAws.request() do
      {:ok, %{body: %{versions: versions}}} ->
        parsed_versions =
          versions
          |> Enum.filter(&(&1.key == key))
          |> Enum.map(&parse_s3_version/1)
          |> Enum.sort_by(& &1.last_modified, {:desc, DateTime})

        {:ok, parsed_versions}

      {:ok, %{body: body}} when not is_map_key(body, :versions) ->
        # Bucket doesn't have versioning enabled
        {:ok, []}

      {:error, reason} ->
        Logger.error("Failed to list S3 versions",
          locator_id: locator_id,
          bucket: bucket,
          key: key,
          error: reason
        )

        {:error, "Could not list S3 versions: #{inspect(reason)}"}
    end
  end

  @doc """
  Get a specific version of content from S3.
  """
  def get_version(locator_id, version_id, opts \\ []) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    Logger.debug("Getting S3 version",
      locator_id: locator_id,
      bucket: bucket,
      key: key,
      version_id: version_id
    )

    case ExAws.S3.get_object(bucket, key, version_id: version_id)
         |> ExAws.request() do
      {:ok, %{body: content}} ->
        {:ok, content}

      {:error, {:http_error, 404, _}} ->
        {:error, :version_not_found}

      {:error, reason} ->
        Logger.error("Failed to get S3 version",
          locator_id: locator_id,
          bucket: bucket,
          key: key,
          version_id: version_id,
          error: reason
        )

        {:error, "Could not get S3 version: #{inspect(reason)}"}
    end
  end

  @doc """
  Check if a file exists in S3 storage.
  """
  def exists?(locator_id, opts \\ []) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
      {:ok, _} -> true
      {:error, {:http_error, 404, _}} -> false
      {:error, _} -> false
    end
  end

  @doc """
  Get file information from S3 storage.
  """
  def stat(locator_id, opts \\ []) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)

    case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
      {:ok, response} ->
        size =
          response[:headers]
          |> Enum.find(fn {k, _v} -> String.downcase(k) == "content-length" end)
          |> case do
            {_k, v} -> String.to_integer(v)
            nil -> 0
          end

        last_modified =
          response[:headers]
          |> Enum.find(fn {k, _v} -> String.downcase(k) == "last-modified" end)
          |> case do
            {_k, v} -> parse_http_date(v)
            nil -> DateTime.utc_now()
          end

        {:ok,
         %{
           size: size,
           modified_at: last_modified,
           storage_backend: :s3,
           bucket: bucket,
           key: key,
           etag: get_header_value(response[:headers], "etag"),
           content_type: get_header_value(response[:headers], "content-type")
         }}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to get S3 stat",
          locator_id: locator_id,
          bucket: bucket,
          key: key,
          error: reason
        )

        {:error, "Could not get S3 stat: #{inspect(reason)}"}
    end
  end

  @doc """
  Copy content within S3 storage.
  """
  def copy(source_locator_id, dest_locator_id, opts \\ []) do
    bucket = get_bucket(opts)
    source_key = get_s3_key(source_locator_id, opts)
    dest_key = get_s3_key(dest_locator_id, opts)

    case ExAws.S3.copy_object(bucket, dest_key, bucket, source_key)
         |> ExAws.request() do
      {:ok, _response} ->
        {:ok,
         %{
           source_locator_id: source_locator_id,
           dest_locator_id: dest_locator_id,
           copied_at: DateTime.utc_now(),
           storage_backend: :s3
         }}

      {:error, reason} ->
        {:error, "Could not copy S3 object: #{inspect(reason)}"}
    end
  end

  @doc """
  Generate a pre-signed URL for direct S3 access.
  """
  def generate_presigned_url(locator_id, opts \\ []) do
    bucket = get_bucket(opts)
    key = get_s3_key(locator_id, opts)
    method = Keyword.get(opts, :method, :get)
    # 1 hour default
    expires_in = Keyword.get(opts, :expires_in, 3600)

    try do
      case method do
        :get ->
          {:ok,
           ExAws.S3.presigned_url(ExAws.Config.new(:s3), method, bucket, key,
             expires_in: expires_in
           )}

        :put ->
          {:ok,
           ExAws.S3.presigned_url(ExAws.Config.new(:s3), method, bucket, key,
             expires_in: expires_in
           )}

        _ ->
          {:error, "Unsupported presigned URL method: #{method}"}
      end
    rescue
      exception ->
        Logger.error("Failed to generate S3 presigned URL",
          locator_id: locator_id,
          method: method,
          error: Exception.message(exception)
        )

        {:error, "Could not generate presigned URL: #{Exception.message(exception)}"}
    end
  end

  # Private helper functions

  defp get_bucket(opts) do
    case Keyword.get(opts, :bucket) do
      nil ->
        Application.get_env(:dirup, Dirup.Storage.Providers.S3, [])
        |> Keyword.get(:bucket, default_bucket())

      bucket ->
        bucket
    end
  end

  defp get_s3_key(locator_id, opts) do
    prefix = Keyword.get(opts, :key_prefix, "")

    case prefix do
      "" -> locator_id
      prefix -> Path.join(prefix, locator_id)
    end
  end

  defp get_content_type(locator_id, opts) do
    case Keyword.get(opts, :content_type) do
      nil ->
        case Path.extname(locator_id) do
          ".json" -> "application/json"
          ".html" -> "text/html"
          ".css" -> "text/css"
          ".js" -> "application/javascript"
          ".md" -> "text/markdown"
          ".txt" -> "text/plain"
          ".xml" -> "application/xml"
          ".pdf" -> "application/pdf"
          ".jpg" -> "image/jpeg"
          ".jpeg" -> "image/jpeg"
          ".png" -> "image/png"
          ".gif" -> "image/gif"
          ".svg" -> "image/svg+xml"
          _ -> "application/octet-stream"
        end

      content_type ->
        content_type
    end
  end

  defp parse_s3_version(s3_version) do
    %{
      version_id: s3_version.version_id,
      size: s3_version.size,
      last_modified: parse_iso8601_date(s3_version.last_modified),
      etag: s3_version.etag,
      storage_class: s3_version.storage_class,
      is_latest: s3_version.is_latest
    }
  end

  defp parse_iso8601_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_iso8601_date(_), do: DateTime.utc_now()

  defp parse_http_date(date_string) when is_binary(date_string) do
    # Parse HTTP date format like "Wed, 21 Oct 2015 07:28:00 GMT"
    case Timex.parse(date_string, "{RFC1123}") do
      {:ok, datetime} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  rescue
    _ -> DateTime.utc_now()
  end

  defp parse_http_date(_), do: DateTime.utc_now()

  defp get_header_value(headers, header_name) do
    headers
    |> Enum.find(fn {k, _v} -> String.downcase(k) == String.downcase(header_name) end)
    |> case do
      {_k, v} -> v
      nil -> nil
    end
  end

  defp generate_version_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp default_bucket do
    "kyozo-storage-#{Mix.env()}"
  end
end
