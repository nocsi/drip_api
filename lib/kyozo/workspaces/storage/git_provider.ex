defmodule Kyozo.Workspaces.Storage.GitProvider do
  @moduledoc """
  Git-based storage provider for workspace files.

  This provider manages files in Git repositories, providing version control,
  branching, and collaboration features for workspace documents and notebooks.
  """

  @behaviour Kyozo.Workspaces.Storage

  alias Kyozo.Workspaces.Storage

  require Logger

  @default_branch "main"
  @git_config %{
    "user.name" => "Kyozo Workspace",
    "user.email" => "workspace@kyozo.dev"
  }

  @impl true
  def store(file_path, content, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, repo_path} <- get_or_create_repo(options),
         :ok <- ensure_branch(repo_path, get_branch(options)),
         :ok <- write_file(repo_path, file_path, content),
         {:ok, commit_sha} <- commit_changes(repo_path, file_path, options) do
      metadata =
        Storage.extract_metadata(file_path, content,
          version: commit_sha,
          author: Keyword.get(options, :author, "system"),
          repository: repo_path
        )

      {:ok, metadata}
    end
  end

  @impl true
  def retrieve(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, repo_path} <- get_repo_path(options),
         {:ok, content} <- read_file(repo_path, file_path, get_version(options)) do
      metadata = get_file_metadata(repo_path, file_path, options)
      {:ok, content, metadata}
    end
  end

  @impl true
  def delete(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, repo_path} <- get_repo_path(options),
         :ok <- remove_file(repo_path, file_path),
         {:ok, _commit_sha} <- commit_deletion(repo_path, file_path, options) do
      :ok
    end
  end

  @impl true
  def list(directory_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, repo_path} <- get_repo_path(options) do
      full_path = Path.join(repo_path, directory_path)

      case File.ls(full_path) do
        {:ok, files} ->
          metadata_list =
            Enum.map(files, fn file ->
              file_path = Path.join(directory_path, file)
              get_file_metadata(repo_path, file_path, options)
            end)

          {:ok, metadata_list}

        {:error, reason} ->
          {:error, "Failed to list directory: #{reason}"}
      end
    end
  end

  @impl true
  def exists?(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, repo_path} <- get_repo_path(options) do
      full_path = Path.join(repo_path, file_path)
      File.exists?(full_path)
    else
      _ -> false
    end
  end

  @impl true
  def get_metadata(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, repo_path} <- get_repo_path(options) do
      metadata = get_file_metadata(repo_path, file_path, options)
      {:ok, metadata}
    end
  end

  @impl true
  def create_version(file_path, content, commit_message, options) do
    options_with_message = Keyword.put(options, :commit_message, commit_message)

    case store(file_path, content, options_with_message) do
      {:ok, metadata} ->
        {:ok, metadata.version, metadata}

      error ->
        error
    end
  end

  @impl true
  def list_versions(file_path, options) do
    with :ok <- Storage.validate_options(options),
         {:ok, repo_path} <- get_repo_path(options),
         {:ok, commits} <- get_file_history(repo_path, file_path) do
      versions =
        Enum.map(commits, fn commit ->
          %{
            version: commit.sha,
            author: commit.author,
            commit_message: commit.message,
            last_modified: commit.timestamp,
            mime_type: MIME.from_path(file_path),
            file_name: Path.basename(file_path)
          }
        end)

      {:ok, versions}
    end
  end

  @impl true
  def retrieve_version(file_path, version, options) do
    options_with_version = Keyword.put(options, :version, version)
    retrieve(file_path, options_with_version)
  end

  @impl true
  def sync(from_backend, to_backend, file_path, options) do
    require Logger

    try do
      Logger.info("Starting Git sync operation",
        from: from_backend,
        to: to_backend,
        file_path: file_path
      )

      case {from_backend, to_backend} do
        # Git to Git sync (different repositories)
        {:git, :git} ->
          sync_git_to_git(file_path, options)

        # Git to other backends
        {:git, other_backend} ->
          sync_git_to_backend(file_path, other_backend, options)

        # Other backends to Git
        {other_backend, :git} ->
          sync_backend_to_git(file_path, other_backend, options)

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
        Logger.error("Git sync failed with exception",
          file_path: file_path,
          exception: Exception.message(exception)
        )

        {:error, :sync_failed}
    end
  end

  # Sync between two Git repositories
  defp sync_git_to_git(file_path, options) do
    source_repo = Keyword.get(options, :source_repo)
    target_repo = Keyword.get(options, :target_repo)
    branch = get_branch(options)

    with {:ok, source_path} <- get_repo_path(Keyword.put(options, :repo_path, source_repo)),
         {:ok, target_path} <- get_repo_path(Keyword.put(options, :repo_path, target_repo)),
         {:ok, content, metadata} <- read_file(source_path, file_path, nil),
         :ok <- ensure_branch(target_path, branch),
         :ok <- write_file(target_path, file_path, content),
         {:ok, commit_sha} <-
           commit_changes(
             target_path,
             file_path,
             Keyword.merge(options, commit_message: "Sync from #{source_repo}")
           ) do
      Logger.info("Successfully synced between Git repositories",
        file_path: file_path,
        source: source_repo,
        target: target_repo,
        commit: commit_sha
      )

      {:ok,
       %{
         commit_sha: commit_sha,
         source_metadata: metadata,
         sync_timestamp: DateTime.utc_now()
       }}
    else
      {:error, reason} ->
        Logger.error("Git-to-Git sync failed",
          file_path: file_path,
          reason: reason
        )

        {:error, reason}
    end
  end

  # Sync from Git to another backend
  defp sync_git_to_backend(file_path, target_backend, options) do
    with {:ok, repo_path} <- get_repo_path(options),
         {:ok, content, git_metadata} <- read_file(repo_path, file_path, nil) do
      # Use the target backend's store function
      target_options =
        Keyword.merge(options,
          source: :git,
          source_metadata: git_metadata
        )

      case target_backend do
        :s3 ->
          Kyozo.Workspaces.Storage.S3Provider.store(file_path, content, target_options)

        :disk ->
          Kyozo.Workspaces.Storage.DiskProvider.store(file_path, content, target_options)

        _ ->
          {:error, :unsupported_target_backend}
      end
      |> case do
        {:ok, target_metadata} ->
          Logger.info("Successfully synced from Git to #{target_backend}",
            file_path: file_path
          )

          {:ok,
           %{
             source_metadata: git_metadata,
             target_metadata: target_metadata,
             sync_timestamp: DateTime.utc_now()
           }}

        {:error, reason} ->
          Logger.error("Failed to sync from Git to #{target_backend}",
            file_path: file_path,
            reason: reason
          )

          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to read from Git for sync",
          file_path: file_path,
          reason: reason
        )

        {:error, reason}
    end
  end

  # Sync from another backend to Git
  defp sync_backend_to_git(file_path, source_backend, options) do
    # First retrieve from source backend
    source_result =
      case source_backend do
        :s3 ->
          Kyozo.Workspaces.Storage.S3Provider.retrieve(file_path, options)

        :disk ->
          Kyozo.Workspaces.Storage.DiskProvider.retrieve(file_path, options)

        _ ->
          {:error, :unsupported_source_backend}
      end

    case source_result do
      {:ok, content, source_metadata} ->
        # Store in Git
        git_options =
          Keyword.merge(options,
            commit_message: "Sync from #{source_backend}",
            author: Keyword.get(options, :author, "system"),
            source_backend: source_backend,
            source_metadata: source_metadata
          )

        case store(file_path, content, git_options) do
          {:ok, git_metadata} ->
            Logger.info("Successfully synced from #{source_backend} to Git",
              file_path: file_path
            )

            {:ok,
             %{
               source_metadata: source_metadata,
               target_metadata: git_metadata,
               sync_timestamp: DateTime.utc_now()
             }}

          {:error, reason} ->
            Logger.error("Failed to store in Git during sync",
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

  # Private helper functions

  defp get_repo_path(options) do
    workspace_id = Keyword.fetch!(options, :workspace_id)
    team_id = Keyword.fetch!(options, :team_id)

    repo_path =
      Path.join([
        get_git_root(),
        "teams",
        to_string(team_id),
        "workspaces",
        to_string(workspace_id)
      ])

    {:ok, repo_path}
  end

  defp get_or_create_repo(options) do
    with {:ok, repo_path} <- get_repo_path(options) do
      if File.exists?(Path.join(repo_path, ".git")) do
        {:ok, repo_path}
      else
        init_repository(repo_path)
      end
    end
  end

  defp init_repository(repo_path) do
    with :ok <- File.mkdir_p(repo_path),
         {_, 0} <- System.cmd("git", ["init"], cd: repo_path),
         :ok <- configure_git(repo_path),
         :ok <- create_initial_commit(repo_path) do
      Logger.info("Initialized git repository at #{repo_path}")
      {:ok, repo_path}
    else
      {output, exit_code} ->
        Logger.error("Failed to initialize git repository: #{output}")
        {:error, "Git init failed with exit code #{exit_code}"}

      error ->
        Logger.error("Failed to create repository directory: #{inspect(error)}")
        {:error, "Failed to create repository"}
    end
  end

  defp configure_git(repo_path) do
    Enum.reduce_while(@git_config, :ok, fn {key, value}, _acc ->
      case System.cmd("git", ["config", key, value], cd: repo_path) do
        {_, 0} -> {:cont, :ok}
        {output, _} -> {:halt, {:error, "Git config failed: #{output}"}}
      end
    end)
  end

  defp create_initial_commit(repo_path) do
    readme_content = """
    # Kyozo Workspace

    This workspace is managed by Kyozo and uses Git for version control.

    Created at: #{DateTime.utc_now()}
    """

    readme_path = Path.join(repo_path, "README.md")

    with :ok <- File.write(readme_path, readme_content),
         {_, 0} <- System.cmd("git", ["add", "README.md"], cd: repo_path),
         {_, 0} <- System.cmd("git", ["commit", "-m", "Initial commit"], cd: repo_path) do
      :ok
    else
      {output, _} -> {:error, "Failed to create initial commit: #{output}"}
      error -> error
    end
  end

  defp ensure_branch(repo_path, branch) do
    case System.cmd("git", ["checkout", branch], cd: repo_path, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {_output, _} ->
        # Branch doesn't exist, create it
        case System.cmd("git", ["checkout", "-b", branch], cd: repo_path) do
          {_, 0} -> :ok
          {output, _} -> {:error, "Failed to create branch #{branch}: #{output}"}
        end
    end
  end

  defp write_file(repo_path, file_path, content) do
    full_path = Path.join(repo_path, file_path)

    with :ok <- File.mkdir_p(Path.dirname(full_path)),
         :ok <- File.write(full_path, content) do
      :ok
    else
      error ->
        Logger.error("Failed to write file #{file_path}: #{inspect(error)}")
        {:error, "Failed to write file"}
    end
  end

  defp read_file(repo_path, file_path, version \\ nil) do
    if version do
      read_file_at_version(repo_path, file_path, version)
    else
      full_path = Path.join(repo_path, file_path)
      File.read(full_path)
    end
  end

  defp read_file_at_version(repo_path, file_path, version) do
    git_path = "#{version}:#{file_path}"

    case System.cmd("git", ["show", git_path], cd: repo_path, stderr_to_stdout: true) do
      {content, 0} -> {:ok, content}
      {error, _} -> {:error, "Failed to read file at version: #{error}"}
    end
  end

  defp commit_changes(repo_path, file_path, options) do
    commit_message = get_commit_message(file_path, options)
    author = Keyword.get(options, :author, "system")

    with {_, 0} <- System.cmd("git", ["add", file_path], cd: repo_path),
         {_, 0} <-
           System.cmd(
             "git",
             ["commit", "-m", commit_message, "--author", "#{author} <#{author}@kyozo.dev>"],
             cd: repo_path
           ),
         {:ok, commit_sha} <- get_latest_commit_sha(repo_path) do
      Logger.info("Committed changes to #{file_path} with SHA: #{commit_sha}")
      {:ok, commit_sha}
    else
      {output, exit_code} ->
        if String.contains?(output, "nothing to commit") do
          get_latest_commit_sha(repo_path)
        else
          Logger.error("Git commit failed: #{output}")
          {:error, "Git commit failed with exit code #{exit_code}"}
        end

      error ->
        error
    end
  end

  defp commit_deletion(repo_path, file_path, options) do
    commit_message = "Delete #{file_path}"
    author = Keyword.get(options, :author, "system")

    with {_, 0} <- System.cmd("git", ["rm", file_path], cd: repo_path),
         {_, 0} <-
           System.cmd(
             "git",
             ["commit", "-m", commit_message, "--author", "#{author} <#{author}@kyozo.dev>"],
             cd: repo_path
           ),
         {:ok, commit_sha} <- get_latest_commit_sha(repo_path) do
      {:ok, commit_sha}
    else
      {output, _} -> {:error, "Failed to commit deletion: #{output}"}
      error -> error
    end
  end

  defp remove_file(repo_path, file_path) do
    full_path = Path.join(repo_path, file_path)

    case File.rm(full_path) do
      :ok -> :ok
      # File already doesn't exist
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  defp get_latest_commit_sha(repo_path) do
    case System.cmd("git", ["rev-parse", "HEAD"], cd: repo_path) do
      {sha, 0} -> {:ok, String.trim(sha)}
      {error, _} -> {:error, "Failed to get commit SHA: #{error}"}
    end
  end

  defp get_file_history(repo_path, file_path) do
    case System.cmd("git", ["log", "--format=%H|%an|%s|%ct", "--", file_path], cd: repo_path) do
      {output, 0} ->
        commits =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&parse_commit_line/1)

        {:ok, commits}

      {error, _} ->
        {:error, "Failed to get file history: #{error}"}
    end
  end

  defp parse_commit_line(line) do
    [sha, author, message, timestamp] = String.split(line, "|", parts: 4)

    %{
      sha: sha,
      author: author,
      message: message,
      timestamp: DateTime.from_unix!(String.to_integer(timestamp))
    }
  end

  defp get_file_metadata(repo_path, file_path, options) do
    full_path = Path.join(repo_path, file_path)

    base_metadata = %{
      mime_type: MIME.from_path(file_path),
      file_name: Path.basename(file_path),
      directory: Path.dirname(file_path),
      repository: repo_path
    }

    case File.stat(full_path) do
      {:ok, stat} ->
        Map.merge(base_metadata, %{
          size: stat.size,
          last_modified: DateTime.from_naive!(stat.mtime, "Etc/UTC")
        })

      {:error, _} ->
        base_metadata
    end
    |> Map.merge(%{
      version: get_version(options) || get_latest_commit_for_file(repo_path, file_path),
      author: Keyword.get(options, :author, "unknown")
    })
  end

  defp get_latest_commit_for_file(repo_path, file_path) do
    case System.cmd("git", ["log", "-1", "--format=%H", "--", file_path], cd: repo_path) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  end

  # Option helpers

  defp get_branch(options), do: Keyword.get(options, :branch, @default_branch)
  defp get_version(options), do: Keyword.get(options, :version)

  defp get_commit_message(file_path, options) do
    case Keyword.get(options, :commit_message) do
      nil -> "Update #{file_path}"
      message -> message
    end
  end

  defp get_git_root do
    Application.get_env(:kyozo, :git_storage_root, Path.join([System.tmp_dir!(), "kyozo", "git"]))
  end
end
