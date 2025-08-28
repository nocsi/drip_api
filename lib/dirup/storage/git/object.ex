defmodule Dirup.Storage.Git.Object do
  @moduledoc """
  Git object storage implementation.

  Handles reading and writing Git objects to the `.git/objects/` directory.
  Git objects are stored as zlib-compressed data with a two-level directory
  structure based on the SHA-1 hash.

  ## Storage Format

  Objects are stored at `.git/objects/XX/YYYYYY...` where:
  - XX is the first two characters of the SHA-1 hash
  - YYYYYY... is the remaining 38 characters

  The content is zlib-compressed and follows Git's object format:
  `<type> <size>\0<content>`
  """

  @doc """
  Write a Git object to the objects directory.

  The data should already be in Git object format with header.
  """
  @spec write(String.t(), String.t(), binary()) :: :ok | {:error, term()}
  def write(git_dir, sha1, data)
      when is_binary(git_dir) and is_binary(sha1) and is_binary(data) do
    object_path = build_object_path(git_dir, sha1)

    # Don't write if object already exists
    if File.exists?(object_path) do
      :ok
    else
      compressed_data = :zlib.compress(data)

      with :ok <- File.mkdir_p(Path.dirname(object_path)),
           :ok <- File.write(object_path, compressed_data) do
        :ok
      end
    end
  end

  @doc """
  Read a Git object from the objects directory.

  Returns the uncompressed object data including the Git header.
  """
  @spec read(String.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def read(git_dir, sha1) when is_binary(git_dir) and is_binary(sha1) do
    object_path = build_object_path(git_dir, sha1)

    case File.read(object_path) do
      {:ok, compressed_data} ->
        try do
          uncompressed_data = :zlib.uncompress(compressed_data)
          {:ok, uncompressed_data}
        rescue
          error ->
            {:error, {:decompression_failed, error}}
        end

      {:error, :enoent} ->
        {:error, :object_not_found}

      error ->
        error
    end
  end

  @doc """
  Check if an object exists in the repository.
  """
  @spec exists?(String.t(), String.t()) :: boolean()
  def exists?(git_dir, sha1) when is_binary(git_dir) and is_binary(sha1) do
    object_path = build_object_path(git_dir, sha1)
    File.exists?(object_path)
  end

  @doc """
  List all objects in the repository.

  Returns a list of SHA-1 hashes.
  """
  @spec list_all(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_all(git_dir) when is_binary(git_dir) do
    objects_dir = Path.join(git_dir, "objects")

    case File.ls(objects_dir) do
      {:ok, subdirs} ->
        objects =
          subdirs
          # Only two-character subdirs
          |> Enum.filter(&(String.length(&1) == 2))
          |> Enum.flat_map(fn subdir ->
            subdir_path = Path.join([objects_dir, subdir])

            case File.ls(subdir_path) do
              {:ok, files} ->
                files
                # Only 38-character filenames
                |> Enum.filter(&(String.length(&1) == 38))
                |> Enum.map(&(subdir <> &1))

              {:error, _} ->
                []
            end
          end)

        {:ok, objects}

      error ->
        error
    end
  end

  @doc """
  Get object type and size without reading the full content.

  Reads just the header to determine the object type and size.
  """
  @spec get_object_info(String.t(), String.t()) :: {:ok, {atom(), integer()}} | {:error, term()}
  def get_object_info(git_dir, sha1) when is_binary(git_dir) and is_binary(sha1) do
    case read(git_dir, sha1) do
      {:ok, data} ->
        case String.split(data, "\0", parts: 2) do
          [header, _content] ->
            case String.split(header, " ", parts: 2) do
              [type_str, size_str] ->
                type = String.to_atom(type_str)
                size = String.to_integer(size_str)
                {:ok, {type, size}}

              _ ->
                {:error, :invalid_object_header}
            end

          _ ->
            {:error, :invalid_object_format}
        end

      error ->
        error
    end
  end

  @doc """
  Remove an object from the repository.

  Use with caution - this permanently deletes the object.
  """
  @spec delete(String.t(), String.t()) :: :ok | {:error, term()}
  def delete(git_dir, sha1) when is_binary(git_dir) and is_binary(sha1) do
    object_path = build_object_path(git_dir, sha1)

    case File.rm(object_path) do
      :ok ->
        # Try to remove the parent directory if it's empty
        parent_dir = Path.dirname(object_path)
        # Ignore errors
        _ = File.rmdir(parent_dir)
        :ok

      error ->
        error
    end
  end

  @doc """
  Get statistics about the objects directory.
  """
  @spec get_stats(String.t()) :: {:ok, map()} | {:error, term()}
  def get_stats(git_dir) when is_binary(git_dir) do
    case list_all(git_dir) do
      {:ok, objects} ->
        # Count objects by type
        type_counts =
          objects
          |> Enum.reduce(%{}, fn sha1, acc ->
            case get_object_info(git_dir, sha1) do
              {:ok, {type, _size}} ->
                Map.update(acc, type, 1, &(&1 + 1))

              {:error, _} ->
                acc
            end
          end)

        stats = %{
          total_objects: length(objects),
          object_types: type_counts,
          objects_directory: Path.join(git_dir, "objects")
        }

        {:ok, stats}

      error ->
        error
    end
  end

  # Private functions

  @spec build_object_path(String.t(), String.t()) :: String.t()
  defp build_object_path(git_dir, sha1) when byte_size(sha1) >= 2 do
    <<prefix::binary-size(2), suffix::binary>> = sha1
    Path.join([git_dir, "objects", prefix, suffix])
  end
end
