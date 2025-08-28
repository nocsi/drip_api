defmodule Dirup.Storage.Providers.Disk do
  @moduledoc """
  Disk-based storage provider for the Kyozo storage system.

  Stores files on the local filesystem with optional directory structure
  and provides basic file I/O operations with versioning support.
  """

  require Logger

  @doc """
  Write content to disk storage.
  """
  def write(locator_id, content, opts \\ []) when is_binary(locator_id) and is_binary(content) do
    destination = get_file_path(locator_id, opts)

    Logger.debug("Writing to disk storage", locator_id: locator_id, path: destination)

    with :ok <- ensure_directory_exists(destination),
         :ok <- File.write(destination, content) do
      {:ok,
       %{
         locator_id: locator_id,
         size: byte_size(content),
         stored_at: DateTime.utc_now(),
         storage_backend: :disk
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to write to disk storage",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not write file: #{inspect(reason)}"}
    end
  end

  @doc """
  Read content from disk storage.
  """
  def read(locator_id, opts \\ []) when is_binary(locator_id) do
    path = get_file_path(locator_id, opts)

    Logger.debug("Reading from disk storage", locator_id: locator_id, path: path)

    case File.read(path) do
      {:ok, content} ->
        {:ok, content}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to read from disk storage",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Delete content from disk storage.
  """
  def delete(locator_id, opts \\ []) when is_binary(locator_id) do
    path = get_file_path(locator_id, opts)

    Logger.debug("Deleting from disk storage", locator_id: locator_id, path: path)

    case File.rm(path) do
      :ok ->
        :ok

      # Already deleted is OK
      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete from disk storage",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not delete file: #{inspect(reason)}"}
    end
  end

  @doc """
  Create a new version of a file in disk storage.
  For disk storage, this creates a versioned copy.
  """
  def create_version(locator_id, content, commit_message, opts \\ []) do
    version_id = generate_version_id()
    version_path = get_version_path(locator_id, version_id, opts)

    Logger.debug("Creating version in disk storage",
      locator_id: locator_id,
      version_id: version_id,
      commit_message: commit_message
    )

    with :ok <- ensure_directory_exists(version_path),
         :ok <- File.write(version_path, content),
         :ok <- write_version_metadata(locator_id, version_id, commit_message, opts) do
      {:ok, version_id,
       %{
         version: version_id,
         stored_at: DateTime.utc_now(),
         size: byte_size(content),
         commit_message: commit_message
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to create version in disk storage",
          locator_id: locator_id,
          version_id: version_id,
          error: reason
        )

        {:error, "Could not create version: #{inspect(reason)}"}
    end
  end

  @doc """
  List all versions for a given file.
  """
  def list_versions(locator_id, opts \\ []) do
    versions_dir = get_versions_dir(locator_id, opts)

    case File.ls(versions_dir) do
      {:ok, files} ->
        versions =
          files
          |> Enum.filter(&String.ends_with?(&1, ".meta"))
          |> Enum.map(&Path.rootname/1)
          |> Enum.map(&load_version_metadata(locator_id, &1, opts))
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, meta} -> meta end)
          |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

        {:ok, versions}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get a specific version of a file.
  """
  def get_version(locator_id, version_id, opts \\ []) do
    version_path = get_version_path(locator_id, version_id, opts)

    case File.read(version_path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, :version_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Check if a file exists in storage.
  """
  def exists?(locator_id, opts \\ []) do
    locator_id
    |> get_file_path(opts)
    |> File.exists?()
  end

  @doc """
  Get file information without reading content.
  """
  def stat(locator_id, opts \\ []) do
    path = get_file_path(locator_id, opts)

    case File.stat(path) do
      {:ok, %File.Stat{size: size, mtime: mtime}} ->
        {:ok,
         %{
           size: size,
           modified_at: DateTime.from_unix!(mtime, :second),
           storage_backend: :disk
         }}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp get_file_path(locator_id, opts) do
    root_dir = get_config(opts, :root_dir, default_root_dir())
    Path.join(root_dir, locator_id)
  end

  defp get_versions_dir(locator_id, opts) do
    root_dir = get_config(opts, :root_dir, default_root_dir())
    Path.join([root_dir, ".versions", locator_id])
  end

  defp get_version_path(locator_id, version_id, opts) do
    versions_dir = get_versions_dir(locator_id, opts)
    Path.join(versions_dir, version_id)
  end

  defp get_version_metadata_path(locator_id, version_id, opts) do
    versions_dir = get_versions_dir(locator_id, opts)
    Path.join(versions_dir, "#{version_id}.meta")
  end

  defp write_version_metadata(locator_id, version_id, commit_message, opts) do
    metadata = %{
      version_id: version_id,
      locator_id: locator_id,
      commit_message: commit_message,
      created_at: DateTime.utc_now(),
      storage_backend: :disk
    }

    metadata_path = get_version_metadata_path(locator_id, version_id, opts)
    content = Jason.encode!(metadata)

    File.write(metadata_path, content)
  end

  defp load_version_metadata(locator_id, version_id, opts) do
    metadata_path = get_version_metadata_path(locator_id, version_id, opts)

    case File.read(metadata_path) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, metadata} -> {:ok, metadata}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_directory_exists(file_path) do
    file_path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp generate_version_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp get_config(opts, key, default) do
    case Keyword.get(opts, key) do
      nil ->
        Application.get_env(:dirup, Dirup.Storage.Providers.Disk, [])
        |> Keyword.get(key, default)

      value ->
        value
    end
  end

  defp default_root_dir do
    Path.join([System.tmp_dir(), "kyozo", "storage"])
  end
end
