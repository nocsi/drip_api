defmodule Kyozo.Workspaces.Storage do
  @moduledoc """
  Storage behavior for Workspace files with support for Git repositories and S3 backends.

  This module defines the contract for storing, retrieving, and managing workspace files
  across different storage backends while maintaining version control and metadata.
  """

  alias Kyozo.Workspaces.File
  alias Kyozo.Workspaces.Notebook

  @type storage_backend :: :git | :s3 | :hybrid
  @type file_path :: String.t()
  @type content :: binary()
  @type metadata :: %{
    required(:mime_type) => String.t(),
    required(:size) => non_neg_integer(),
    required(:last_modified) => DateTime.t(),
    required(:version) => String.t(),
    required(:author) => String.t(),
    optional(atom()) => any()
  }

  @type storage_options :: [
    backend: storage_backend(),
    workspace_id: String.t(),
    team_id: String.t(),
    branch: String.t(),
    commit_message: String.t(),
    author: String.t()
  ] | [{atom(), any()}]

  @doc """
  Stores a file in the workspace storage backend.

  ## Options
  - `:backend` - Storage backend to use (:git, :s3, :hybrid)
  - `:workspace_id` - Workspace identifier
  - `:team_id` - Team identifier for multi-tenancy
  - `:branch` - Git branch (for git backend)
  - `:commit_message` - Commit message (for git backend)
  - `:author` - Author information
  """
  @callback store(file_path, content, storage_options) ::
    {:ok, metadata} | {:error, reason :: any()}

  @doc """
  Retrieves a file from the workspace storage backend.
  """
  @callback retrieve(file_path, storage_options) ::
    {:ok, content, metadata} | {:error, reason :: any()}

  @doc """
  Deletes a file from the workspace storage backend.
  """
  @callback delete(file_path, storage_options) ::
    :ok | {:error, reason :: any()}

  @doc """
  Lists files in a directory path.
  """
  @callback list(directory_path :: file_path, storage_options) ::
    {:ok, [metadata]} | {:error, reason :: any()}

  @doc """
  Checks if a file exists in the storage backend.
  """
  @callback exists?(file_path, storage_options) ::
    boolean()

  @doc """
  Gets file metadata without retrieving content.
  """
  @callback get_metadata(file_path, storage_options) ::
    {:ok, metadata} | {:error, reason :: any()}

  @doc """
  Creates a new version/commit of the file (for versioned backends).
  """
  @callback create_version(file_path, content, commit_message :: String.t(), storage_options) ::
    {:ok, version :: String.t(), metadata} | {:error, reason :: any()}

  @doc """
  Lists all versions of a file (for versioned backends).
  """
  @callback list_versions(file_path, storage_options) ::
    {:ok, [metadata]} | {:error, reason :: any()}

  @doc """
  Retrieves a specific version of a file.
  """
  @callback retrieve_version(file_path, version :: String.t(), storage_options) ::
    {:ok, content, metadata} | {:error, reason :: any()}

  @doc """
  Synchronizes files between different storage backends.
  """
  @callback sync(from_backend :: storage_backend(), to_backend :: storage_backend(), file_path, storage_options) ::
    {:ok, metadata} | {:error, reason :: any()}

  # Default implementation helper functions

  @doc """
  Determines the appropriate storage backend based on file type and workspace configuration.
  """
  def determine_backend(%File{} = file, options \\ []) do
    cond do
      String.ends_with?(file.name, [".md", ".ipynb", ".py", ".js", ".ts"]) ->
        Keyword.get(options, :prefer_git, true) && :git || :hybrid

      String.ends_with?(file.name, [".jpg", ".png", ".pdf", ".zip"]) ->
        :s3

      true ->
        Keyword.get(options, :default_backend, :hybrid)
    end
  end

  def determine_backend(%Notebook{}, _options), do: :git

  @doc """
  Builds storage path for a workspace.
  """
  def build_workspace_storage_path(team_id, workspace_name) do
    normalized_name = String.downcase(workspace_name)
    |> String.replace(~r/[^a-z0-9\-_]/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
    
    Path.join(["teams", team_id, "workspaces", normalized_name])
    |> Path.expand()
    |> ensure_safe_path()
  end

  @doc """
  Builds storage path for a workspace file.
  """
  def build_storage_path(workspace_id, file_path) do
    Path.join(["workspaces", workspace_id, file_path])
    |> Path.expand()
    |> ensure_safe_path()
  end

  @doc """
  Legacy function that determines workspace vs file path based on arguments.
  """
  def build_storage_path(team_id, workspace_name) when is_binary(team_id) and is_binary(workspace_name) do
    # If workspace_name contains path separators, treat as file path
    if String.contains?(workspace_name, "/") do
      build_storage_path(team_id, workspace_name)
    else
      # Otherwise treat as workspace name
      build_workspace_storage_path(team_id, workspace_name)
    end
  end

  @doc """
  Validates file path to prevent directory traversal attacks.
  """
  def ensure_safe_path(path) do
    normalized = Path.expand(path)

    if String.contains?(normalized, "..") do
      raise ArgumentError, "Invalid file path: #{path}"
    end

    normalized
  end

  @doc """
  Extracts metadata from file content and path.
  """
  def extract_metadata(file_path, content, options \\ []) do
    %{
      mime_type: MIME.from_path(file_path),
      size: byte_size(content),
      last_modified: DateTime.utc_now(),
      version: Keyword.get(options, :version, "1"),
      author: Keyword.get(options, :author, "system"),
      file_extension: Path.extname(file_path),
      file_name: Path.basename(file_path),
      directory: Path.dirname(file_path)
    }
  end

  @doc """
  Validates storage options.
  """
  def validate_options(options) do
    required_keys = [:workspace_id, :team_id]

    case Enum.find(required_keys, &(not Keyword.has_key?(options, &1))) do
      nil -> :ok
      missing_key -> {:error, "Missing required option: #{missing_key}"}
    end
  end

  @doc """
  Gets the configured storage provider for a backend.
  """
  def get_provider(backend) do
    case backend do
      :git -> Kyozo.Workspaces.Storage.GitProvider
      :s3 -> Kyozo.Workspaces.Storage.S3Provider
      :hybrid -> Kyozo.Workspaces.Storage.HybridProvider
      _ -> raise ArgumentError, "Unknown storage backend: #{backend}"
    end
  end

  @doc """
  Stores a document using the appropriate backend.
  """
  def store_file(%File{} = file, content, options \\ []) do
    backend = determine_backend(file, options)
    provider = get_provider(backend)

    file_path = build_storage_path(
      Keyword.fetch!(options, :workspace_id),
      file.name
    )

    storage_options = Keyword.merge(options, backend: backend)

    with :ok <- validate_options(storage_options) do
      provider.store(file_path, content, storage_options)
    end
  end

  @doc """
  Retrieves a document using the appropriate backend.
  """
  def retrieve_file(%File{} = file, options \\ []) do
    backend = determine_backend(file, options)
    provider = get_provider(backend)

    file_path = build_storage_path(
      Keyword.fetch!(options, :workspace_id),
      file.name
    )

    storage_options = Keyword.merge(options, backend: backend)

    with :ok <- validate_options(storage_options) do
      provider.retrieve(file_path, storage_options)
    end
  end

  @doc """
  Creates a backup across multiple storage backends.
  """
  def create_backup(file_path, content, options \\ []) do
    primary_backend = Keyword.get(options, :primary_backend, :git)
    backup_backend = Keyword.get(options, :backup_backend, :s3)

    with {:ok, primary_metadata} <- get_provider(primary_backend).store(file_path, content, options),
         {:ok, backup_metadata} <- get_provider(backup_backend).store(file_path, content, options) do
      {:ok, %{primary: primary_metadata, backup: backup_metadata}}
    end
  end
end
