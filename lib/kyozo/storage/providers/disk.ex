defmodule Kyozo.Storage.Storages.Disk do
  @moduledoc """
  Disk-based storage provider for the Kyozo storage system.
  
  Stores files on the local filesystem with optional directory structure
  and provides basic file I/O operations.
  """
  
  alias Kyozo.Storage.{Storage, Upload}

  @behaviour Storage

  @impl Storage
  def stream!(id, opts \\ []) do
    opts
    |> path_in_root(id)
    |> File.stream!(Keyword.get(opts, :stream_opts, []))
  end

  @impl Storage
  def put(upload, opts \\ []) do
    with path <- Path.join(opts[:prefix] || "/", Upload.name(upload)),
         destination <- path_in_root(opts, path),
         true <-
           !File.exists?(destination) || opts[:force] ||
             {:error, "File already exists at upload destination"},
         {:ok, contents} <- Upload.contents(upload) do
      create_path!(destination)

      File.write!(destination, contents)

      {:ok, path}
    end
    |> case do
      {:error, error} -> {:error, "Could not store file: #{error}"}
      success_tuple -> success_tuple
    end
  end

  @impl Storage
  def delete(id, opts \\ []) when is_binary(id) do
    path_in_root(opts, id)
    |> File.rm()
    |> case do
      :ok -> :ok
      {:error, error} -> {:error, "Could not remove file: #{error}"}
    end
  end

  @impl Storage
  def read(id, opts \\ []), do: path_in_root(opts, id) |> File.read()

  @doc """
  Writes content directly to disk storage.
  """
  def write(id, content, opts \\ []) when is_binary(id) and is_binary(content) do
    destination = path_in_root(opts, id)
    
    with :ok <- create_path!(destination),
         :ok <- File.write(destination, content) do
      {:ok, id}
    else
      {:error, reason} -> {:error, "Could not write file: #{reason}"}
    end
  end

  @doc """
  Creates a new version of a file (for disk storage, this just overwrites).
  """
  def create_version(id, content, _commit_message, opts \\ []) do
    case write(id, content, opts) do
      {:ok, _} -> {:ok, generate_version_id(), %{version: generate_version_id(), stored_at: DateTime.utc_now()}}
      error -> error
    end
  end

  defp config(opts, key) do
    Application.fetch_env!(:kyozo, __MODULE__)
    |> Keyword.merge(opts)
    |> Keyword.fetch!(key)
  end

  defp path_in_root(opts, path) do
    config(opts, :root_dir)
    |> Path.join(path)
  end

  defp create_path!(path) do
    path 
    |> Path.dirname() 
    |> File.mkdir_p!()
    :ok
  end

  defp generate_version_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end