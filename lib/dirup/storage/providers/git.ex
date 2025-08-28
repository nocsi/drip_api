defmodule Dirup.Storage.Providers.Git do
  @moduledoc """
  Git-based storage provider for the Kyozo storage system.

  Provides file storage with full Git version control capabilities,
  including branching, merging, and commit history tracking.
  """

  require Logger

  @doc """
  Write content to Git storage with automatic commit.
  """
  def write(locator_id, content, opts \\ []) when is_binary(locator_id) and is_binary(content) do
    repo_path = get_repo_path(opts)
    file_path = Path.join(repo_path, locator_id)

    Logger.debug("Writing to Git storage", locator_id: locator_id, repo: repo_path)

    with :ok <- ensure_git_repo(repo_path),
         :ok <- ensure_directory_exists(file_path),
         :ok <- File.write(file_path, content),
         :ok <- git_add(repo_path, locator_id),
         {:ok, commit_hash} <- git_commit(repo_path, "Update #{locator_id}", opts) do
      {:ok,
       %{
         locator_id: locator_id,
         size: byte_size(content),
         stored_at: DateTime.utc_now(),
         storage_backend: :git,
         commit_hash: commit_hash
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to write to Git storage",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not write file: #{inspect(reason)}"}
    end
  end

  @doc """
  Read content from Git storage (current HEAD).
  """
  def read(locator_id, opts \\ []) when is_binary(locator_id) do
    repo_path = get_repo_path(opts)
    file_path = Path.join(repo_path, locator_id)

    Logger.debug("Reading from Git storage", locator_id: locator_id, repo: repo_path)

    case File.read(file_path) do
      {:ok, content} ->
        {:ok, content}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to read from Git storage",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Delete content from Git storage with commit.
  """
  def delete(locator_id, opts \\ []) when is_binary(locator_id) do
    repo_path = get_repo_path(opts)
    file_path = Path.join(repo_path, locator_id)

    Logger.debug("Deleting from Git storage", locator_id: locator_id, repo: repo_path)

    with :ok <- File.rm(file_path),
         :ok <- git_add(repo_path, locator_id),
         {:ok, _commit_hash} <- git_commit(repo_path, "Delete #{locator_id}", opts) do
      :ok
    else
      # File already deleted is OK
      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete from Git storage",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not delete file: #{inspect(reason)}"}
    end
  end

  @doc """
  Create a new version (commit) of a file in Git storage.
  """
  def create_version(locator_id, content, commit_message, opts \\ []) do
    repo_path = get_repo_path(opts)
    file_path = Path.join(repo_path, locator_id)

    Logger.debug("Creating Git version",
      locator_id: locator_id,
      commit_message: commit_message
    )

    with :ok <- ensure_git_repo(repo_path),
         :ok <- ensure_directory_exists(file_path),
         :ok <- File.write(file_path, content),
         :ok <- git_add(repo_path, locator_id),
         {:ok, commit_hash} <- git_commit(repo_path, commit_message, opts) do
      {:ok, commit_hash,
       %{
         version: commit_hash,
         stored_at: DateTime.utc_now(),
         size: byte_size(content),
         commit_message: commit_message,
         storage_backend: :git
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to create Git version",
          locator_id: locator_id,
          error: reason
        )

        {:error, "Could not create version: #{inspect(reason)}"}
    end
  end

  @doc """
  List all versions (commits) for a given file.
  """
  def list_versions(locator_id, opts \\ []) do
    repo_path = get_repo_path(opts)

    case git_log(repo_path, locator_id, opts) do
      {:ok, commits} ->
        versions =
          commits
          |> Enum.map(&parse_commit_info/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, info} -> info end)

        {:ok, versions}

      {:error, reason} ->
        Logger.error("Failed to list Git versions",
          locator_id: locator_id,
          error: reason
        )

        {:error, reason}
    end
  end

  @doc """
  Get a specific version (commit) of a file.
  """
  def get_version(locator_id, commit_hash, opts \\ []) do
    repo_path = get_repo_path(opts)

    case git_show(repo_path, commit_hash, locator_id) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Check if a file exists in Git storage.
  """
  def exists?(locator_id, opts \\ []) do
    repo_path = get_repo_path(opts)
    file_path = Path.join(repo_path, locator_id)
    File.exists?(file_path)
  end

  @doc """
  Get file information from Git storage.
  """
  def stat(locator_id, opts \\ []) do
    repo_path = get_repo_path(opts)
    file_path = Path.join(repo_path, locator_id)

    case File.stat(file_path) do
      {:ok, %File.Stat{size: size, mtime: mtime}} ->
        with {:ok, [latest_commit | _]} <- git_log(repo_path, locator_id, limit: 1),
             {:ok, commit_info} <- parse_commit_info(latest_commit) do
          {:ok,
           %{
             size: size,
             modified_at: DateTime.from_unix!(mtime, :second),
             storage_backend: :git,
             latest_commit: commit_info.hash,
             commit_message: commit_info.message
           }}
        else
          _ ->
            {:ok,
             %{
               size: size,
               modified_at: DateTime.from_unix!(mtime, :second),
               storage_backend: :git
             }}
        end

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Create a new branch in the Git repository.
  """
  def create_branch(branch_name, opts \\ []) do
    repo_path = get_repo_path(opts)

    case git_command(repo_path, ["checkout", "-b", branch_name]) do
      {_output, 0} -> :ok
      {error, _code} -> {:error, "Failed to create branch: #{error}"}
    end
  end

  @doc """
  Switch to a different branch.
  """
  def checkout_branch(branch_name, opts \\ []) do
    repo_path = get_repo_path(opts)

    case git_command(repo_path, ["checkout", branch_name]) do
      {_output, 0} -> :ok
      {error, _code} -> {:error, "Failed to checkout branch: #{error}"}
    end
  end

  @doc """
  List all branches in the repository.
  """
  def list_branches(opts \\ []) do
    repo_path = get_repo_path(opts)

    case git_command(repo_path, ["branch", "--format=%(refname:short)"]) do
      {output, 0} ->
        branches =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.filter(&(&1 != ""))

        {:ok, branches}

      {error, _code} ->
        {:error, "Failed to list branches: #{error}"}
    end
  end

  # Private helper functions

  defp ensure_git_repo(repo_path) do
    git_dir = Path.join(repo_path, ".git")

    if File.exists?(git_dir) do
      :ok
    else
      case File.mkdir_p(repo_path) do
        :ok -> git_init(repo_path)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp git_init(repo_path) do
    case git_command(repo_path, ["init"]) do
      {_output, 0} ->
        # Configure basic Git settings
        git_command(repo_path, ["config", "user.name", get_git_user_name()])
        git_command(repo_path, ["config", "user.email", get_git_user_email()])
        :ok

      {error, _code} ->
        {:error, "Failed to initialize Git repo: #{error}"}
    end
  end

  defp git_add(repo_path, file_path) do
    case git_command(repo_path, ["add", file_path]) do
      {_output, 0} -> :ok
      {error, _code} -> {:error, "Git add failed: #{error}"}
    end
  end

  defp git_commit(repo_path, message, opts \\ []) do
    author = get_commit_author(opts)

    git_args = ["commit", "-m", message]
    git_args = if author, do: git_args ++ ["--author", author], else: git_args

    case git_command(repo_path, git_args) do
      {_output, 0} ->
        # Get the commit hash
        case git_command(repo_path, ["rev-parse", "HEAD"]) do
          {hash, 0} -> {:ok, String.trim(hash)}
          {error, _code} -> {:error, "Failed to get commit hash: #{error}"}
        end

      {error, _code} ->
        {:error, "Git commit failed: #{error}"}
    end
  end

  defp git_log(repo_path, file_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    format = "--pretty=format:%H|%an|%ae|%ad|%s"

    git_args = ["log", "--date=iso", format, "-#{limit}", "--", file_path]

    case git_command(repo_path, git_args) do
      {output, 0} ->
        commits =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.filter(&(&1 != ""))

        {:ok, commits}

      {error, _code} ->
        {:error, "Git log failed: #{error}"}
    end
  end

  defp git_show(repo_path, commit_hash, file_path) do
    case git_command(repo_path, ["show", "#{commit_hash}:#{file_path}"]) do
      {content, 0} -> {:ok, content}
      {error, _code} -> {:error, "Git show failed: #{error}"}
    end
  end

  defp git_command(repo_path, args) do
    System.cmd("git", args, cd: repo_path, stderr_to_stdout: true)
  rescue
    e in ErlangError ->
      {:error, "Git command failed: #{Exception.message(e)}"}
  end

  defp parse_commit_info(commit_line) do
    case String.split(commit_line, "|", parts: 5) do
      [hash, author_name, author_email, date, message] ->
        with {:ok, parsed_date, _} <- DateTime.from_iso8601(date) do
          {:ok,
           %{
             hash: hash,
             author_name: author_name,
             author_email: author_email,
             date: parsed_date,
             message: message
           }}
        else
          _ -> {:error, :invalid_date}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp ensure_directory_exists(file_path) do
    file_path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp get_repo_path(opts) do
    case Keyword.get(opts, :repo_path) do
      nil ->
        Application.get_env(:dirup, Dirup.Storage.Providers.Git, [])
        |> Keyword.get(:repo_path, default_repo_path())

      path ->
        path
    end
  end

  defp default_repo_path do
    Path.join([System.tmp_dir(), "kyozo", "git_storage"])
  end

  defp get_git_user_name do
    System.get_env("GIT_USER_NAME") || "Kyozo System"
  end

  defp get_git_user_email do
    System.get_env("GIT_USER_EMAIL") || "system@kyozo.io"
  end

  defp get_commit_author(opts) do
    case {Keyword.get(opts, :author_name), Keyword.get(opts, :author_email)} do
      {nil, nil} -> nil
      {name, nil} -> "#{name} <#{get_git_user_email()}>"
      {nil, email} -> "#{get_git_user_name()} <#{email}>"
      {name, email} -> "#{name} <#{email}>"
    end
  end
end
