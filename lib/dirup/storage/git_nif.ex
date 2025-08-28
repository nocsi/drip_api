defmodule Dirup.Storage.GitNif do
  @moduledoc """
  Native Elixir Git operations implementation.

  This module provides all the Git functionality previously implemented in Rust,
  but using pure Elixir for better maintainability and zero external dependencies.

  All operations work directly with Git's internal file format without calling
  external processes or depending on system git installation.
  """

  alias Dirup.Storage.Git.{Repository, Utils}
  require Logger

  @doc """
  Ensure a Git repository exists at the given path.
  Creates one if it doesn't exist.
  """
  @spec ensure_repository(String.t()) :: {:ok, String.t()} | {:error, term()}
  def ensure_repository(repo_path) when is_binary(repo_path) do
    case Repository.open(repo_path) do
      {:ok, _repo} ->
        {:ok, repo_path}

      {:error, :not_a_git_repository} ->
        case Repository.init(repo_path) do
          {:ok, _repo} ->
            Logger.debug("Initialized Git repository at #{repo_path}")
            {:ok, repo_path}

          error ->
            Logger.error("Failed to initialize repository at #{repo_path}: #{inspect(error)}")
            error
        end

      error ->
        Logger.error("Repository error at #{repo_path}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Read file content from the Git repository.
  Returns the content of the file at the specified path.
  """
  @spec read_file_content(String.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def read_file_content(repo_path, file_path)
      when is_binary(repo_path) and is_binary(file_path) do
    with {:ok, repo} <- Repository.open(repo_path),
         {:ok, head_sha} <- Repository.get_head(repo),
         {:ok, commit_info} <- Repository.read_commit(repo, head_sha),
         {:ok, content} <- read_file_from_tree(repo, commit_info.tree, file_path) do
      {:ok, content}
    else
      {:error, :head_not_found} ->
        {:error, :empty_repository}

      {:error, :ref_not_found} ->
        {:error, :empty_repository}

      error ->
        Logger.debug("Failed to read file #{file_path} from #{repo_path}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Write content to a file and commit it to the repository.
  """
  @spec write_and_commit_file(String.t(), String.t(), binary(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def write_and_commit_file(repo_path, file_path, content, opts \\ []) do
    commit_message = Keyword.get(opts, :commit_message, "Update #{file_path}")
    author_name = Keyword.get(opts, :author_name, "Kyozo")
    author_email = Keyword.get(opts, :author_email, "kyozo@example.com")

    with {:ok, repo} <- ensure_repository_opened(repo_path),
         {:ok, blob_sha} <- Repository.write_blob(repo, content),
         {:ok, tree_sha} <- create_tree_with_file(repo, file_path, blob_sha),
         {:ok, parents} <- get_parent_commits(repo),
         {:ok, commit_sha} <-
           create_commit(repo, tree_sha, commit_message, author_name, author_email, parents),
         :ok <- update_branch(repo, commit_sha) do
      Logger.debug("Committed file #{file_path} to #{repo_path}: #{Utils.short_sha(commit_sha)}")
      {:ok, commit_sha}
    else
      error ->
        Logger.error("Failed to write and commit #{file_path} to #{repo_path}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Delete a file from the repository and commit the change.
  """
  @spec delete_and_commit_file(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def delete_and_commit_file(repo_path, file_path, opts \\ []) do
    commit_message = Keyword.get(opts, :commit_message, "Delete #{file_path}")
    author_name = Keyword.get(opts, :author_name, "Kyozo")
    author_email = Keyword.get(opts, :author_email, "kyozo@example.com")

    with {:ok, repo} <- Repository.open(repo_path),
         {:ok, tree_sha} <- create_tree_without_file(repo, file_path),
         {:ok, parents} <- get_parent_commits(repo),
         {:ok, commit_sha} <-
           create_commit(repo, tree_sha, commit_message, author_name, author_email, parents),
         :ok <- update_branch(repo, commit_sha) do
      Logger.debug("Deleted file #{file_path} from #{repo_path}: #{Utils.short_sha(commit_sha)}")
      {:ok, commit_sha}
    else
      error ->
        Logger.error("Failed to delete #{file_path} from #{repo_path}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Check if a file exists in the repository.
  """
  @spec file_exists?(String.t(), String.t()) :: boolean()
  def file_exists?(repo_path, file_path) do
    case read_file_content(repo_path, file_path) do
      {:ok, _content} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Create a new version of a file with metadata.
  """
  @spec create_version(String.t(), String.t(), binary(), map()) ::
          {:ok, String.t(), map()} | {:error, term()}
  def create_version(repo_path, file_path, content, version_info) do
    commit_message = Map.get(version_info, :message, "Create version of #{file_path}")
    author_name = Map.get(version_info, :author_name, "Kyozo")
    author_email = Map.get(version_info, :author_email, "kyozo@example.com")

    opts = [
      commit_message: commit_message,
      author_name: author_name,
      author_email: author_email
    ]

    case write_and_commit_file(repo_path, file_path, content, opts) do
      {:ok, commit_sha} ->
        metadata = %{
          commit_sha: commit_sha,
          short_sha: Utils.short_sha(commit_sha),
          author: "#{author_name} <#{author_email}>",
          message: commit_message,
          timestamp: System.os_time(:second),
          file_path: file_path,
          content_size: byte_size(content)
        }

        {:ok, commit_sha, metadata}

      error ->
        error
    end
  end

  @doc """
  List all files in the repository.
  """
  @spec list_repository_files(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_repository_files(repo_path, prefix \\ "") do
    with {:ok, repo} <- Repository.open(repo_path),
         {:ok, head_sha} <- Repository.get_head(repo),
         {:ok, commit_info} <- Repository.read_commit(repo, head_sha),
         {:ok, files} <- list_files_in_tree(repo, commit_info.tree, prefix) do
      {:ok, files}
    else
      {:error, :head_not_found} -> {:ok, []}
      {:error, :ref_not_found} -> {:ok, []}
      error -> error
    end
  end

  @doc """
  Get commit history for a file.
  """
  @spec get_commit_history(String.t(), String.t(), integer()) ::
          {:ok, [map()]} | {:error, term()}
  def get_commit_history(repo_path, file_path, limit \\ 10) do
    with {:ok, repo} <- Repository.open(repo_path),
         {:ok, head_sha} <- Repository.get_head(repo),
         {:ok, commits} <- walk_commit_history(repo, head_sha, file_path, limit) do
      {:ok, commits}
    else
      {:error, :head_not_found} -> {:ok, []}
      {:error, :ref_not_found} -> {:ok, []}
      error -> error
    end
  end

  @doc """
  Get repository statistics.
  """
  @spec get_repository_stats(String.t()) :: {:ok, map()} | {:error, term()}
  def get_repository_stats(repo_path) do
    with {:ok, repo} <- Repository.open(repo_path),
         {:ok, object_stats} <- get_object_statistics(repo),
         {:ok, ref_stats} <- get_ref_statistics(repo) do
      stats = %{
        "path" => repo_path,
        "objects" => object_stats["total_objects"],
        "commits" => Map.get(object_stats["object_types"], :commit, 0),
        "files" => Map.get(object_stats["object_types"], :blob, 0),
        "branches" => length(ref_stats["branches"]),
        "tags" => length(ref_stats["tags"]),
        "storage_size" => calculate_repository_size(repo_path)
      }

      {:ok, stats}
    else
      error ->
        Logger.error("Failed to get repository stats for #{repo_path}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Validate a repository structure.
  """
  @spec validate_repository(String.t()) :: :ok | {:error, term()}
  def validate_repository(repo_path) do
    case Repository.open(repo_path) do
      {:ok, _repo} -> :ok
      {:error, :not_a_git_repository} -> {:error, :not_git_repo}
      error -> error
    end
  end

  # Private helper functions

  defp ensure_repository_opened(repo_path) do
    case ensure_repository(repo_path) do
      {:ok, _path} -> Repository.open(repo_path)
      error -> error
    end
  end

  defp read_file_from_tree(repo, tree_sha, file_path) do
    path_parts = Utils.path_parts(file_path)
    read_file_from_tree_recursive(repo, tree_sha, path_parts)
  end

  defp read_file_from_tree_recursive(_repo, blob_sha, []) do
    # We've reached the file - blob_sha should be a blob
    {:error, :invalid_path}
  end

  defp read_file_from_tree_recursive(repo, tree_sha, [filename]) do
    # Last component - should be a file
    case Repository.read_tree(repo, tree_sha) do
      {:ok, entries} ->
        case Enum.find(entries, &(&1.name == filename)) do
          %{sha1: blob_sha, mode: mode} when mode != "040000" ->
            Repository.read_blob(repo, blob_sha)

          %{mode: "040000"} ->
            {:error, :is_directory}

          nil ->
            {:error, :file_not_found}
        end

      error ->
        error
    end
  end

  defp read_file_from_tree_recursive(repo, tree_sha, [dirname | rest]) do
    # Intermediate component - should be a directory
    case Repository.read_tree(repo, tree_sha) do
      {:ok, entries} ->
        case Enum.find(entries, &(&1.name == dirname and &1.mode == "040000")) do
          %{sha1: subtree_sha} ->
            read_file_from_tree_recursive(repo, subtree_sha, rest)

          nil ->
            {:error, :path_not_found}
        end

      error ->
        error
    end
  end

  defp create_tree_with_file(repo, file_path, blob_sha) do
    # Get current tree if repository has commits
    case get_current_tree_entries(repo) do
      {:ok, current_entries} ->
        updated_entries = update_tree_entries(current_entries, file_path, blob_sha)
        create_tree_from_flat_entries(repo, updated_entries)

      {:error, :empty_repository} ->
        # First commit - create tree with just this file
        entries = [{file_path, blob_sha, "100644"}]
        create_tree_from_flat_entries(repo, entries)

      error ->
        error
    end
  end

  defp create_tree_without_file(repo, file_path) do
    case get_current_tree_entries(repo) do
      {:ok, current_entries} ->
        filtered_entries =
          Enum.reject(current_entries, fn {path, _sha, _mode} ->
            path == file_path
          end)

        create_tree_from_flat_entries(repo, filtered_entries)

      error ->
        error
    end
  end

  defp get_current_tree_entries(repo) do
    case Repository.get_head(repo) do
      {:ok, head_sha} ->
        case Repository.read_commit(repo, head_sha) do
          {:ok, commit_info} ->
            flatten_tree_entries(repo, commit_info.tree, "")

          error ->
            error
        end

      {:error, :head_not_found} ->
        {:error, :empty_repository}

      {:error, :ref_not_found} ->
        {:error, :empty_repository}

      error ->
        error
    end
  end

  defp flatten_tree_entries(repo, tree_sha, prefix) do
    case Repository.read_tree(repo, tree_sha) do
      {:ok, entries} ->
        flat_entries =
          Enum.flat_map(entries, fn entry ->
            full_path = if prefix == "", do: entry.name, else: "#{prefix}/#{entry.name}"

            case entry.mode do
              "040000" ->
                # Directory - recurse
                case flatten_tree_entries(repo, entry.sha1, full_path) do
                  {:ok, sub_entries} -> sub_entries
                  {:error, _} -> []
                end

              _ ->
                # File
                [{full_path, entry.sha1, entry.mode}]
            end
          end)

        {:ok, flat_entries}

      error ->
        error
    end
  end

  defp update_tree_entries(entries, file_path, blob_sha) do
    # Remove existing entry for this path and add new one
    entries
    |> Enum.reject(fn {path, _sha, _mode} -> path == file_path end)
    |> Kernel.++([{file_path, blob_sha, "100644"}])
  end

  defp create_tree_from_flat_entries(repo, flat_entries) do
    # Group entries by directory structure and create nested trees
    tree_structure = build_tree_structure(flat_entries)
    create_tree_recursive(repo, tree_structure)
  end

  defp build_tree_structure(flat_entries) do
    Enum.reduce(flat_entries, %{}, fn {path, sha, mode}, acc ->
      path_parts = Utils.path_parts(path)
      insert_into_tree_structure(acc, path_parts, sha, mode)
    end)
  end

  defp insert_into_tree_structure(tree, [filename], sha, mode) do
    Map.put(tree, filename, {sha, mode})
  end

  defp insert_into_tree_structure(tree, [dirname | rest], sha, mode) do
    subtree = Map.get(tree, dirname, %{})
    updated_subtree = insert_into_tree_structure(subtree, rest, sha, mode)
    Map.put(tree, dirname, updated_subtree)
  end

  defp create_tree_recursive(repo, tree_structure) do
    entries =
      Enum.map(tree_structure, fn
        {name, {sha, mode}} ->
          # File entry
          %{name: name, sha1: sha, mode: mode}

        {name, subtree} when is_map(subtree) ->
          # Directory entry
          case create_tree_recursive(repo, subtree) do
            {:ok, subtree_sha} ->
              %{name: name, sha1: subtree_sha, mode: "040000"}

            {:error, _} ->
              nil
          end
      end)
      |> Enum.reject(&is_nil/1)

    Repository.write_tree(repo, entries)
  end

  defp get_parent_commits(repo) do
    case Repository.get_head(repo) do
      {:ok, head_sha} -> {:ok, [head_sha]}
      {:error, :head_not_found} -> {:ok, []}
      {:error, :ref_not_found} -> {:ok, []}
      error -> error
    end
  end

  defp create_commit(repo, tree_sha, message, author_name, author_email, parents) do
    author = Utils.format_person(author_name, author_email)

    opts = [
      message: message,
      parents: parents,
      author: author,
      committer: author
    ]

    Repository.write_commit(repo, tree_sha, opts)
  end

  defp update_branch(repo, commit_sha) do
    case Repository.get_current_branch(git_dir_from_repo(repo)) do
      {:ok, branch} when is_binary(branch) ->
        Repository.update_ref(repo, branch, commit_sha)

      {:ok, :detached} ->
        # In detached HEAD state - update HEAD directly
        Repository.set_head_detached(git_dir_from_repo(repo), commit_sha)

      {:error, :head_not_found} ->
        # No HEAD yet - set up main branch
        with :ok <- Repository.update_ref(repo, "main", commit_sha),
             :ok <- Repository.set_head(repo, "main") do
          :ok
        end

      error ->
        error
    end
  end

  defp git_dir_from_repo(%Repository{git_dir: git_dir}), do: git_dir

  defp list_files_in_tree(repo, tree_sha, prefix) do
    case flatten_tree_entries(repo, tree_sha, "") do
      {:ok, entries} ->
        files =
          entries
          |> Enum.filter(fn {path, _sha, mode} ->
            mode != "040000" and String.starts_with?(path, prefix)
          end)
          |> Enum.map(fn {path, _sha, _mode} -> path end)

        {:ok, files}

      error ->
        error
    end
  end

  defp walk_commit_history(repo, commit_sha, _file_path, limit) do
    # Simplified version - just get the commit info
    case Repository.read_commit(repo, commit_sha) do
      {:ok, commit_info} ->
        commit_data = %{
          "sha" => commit_sha,
          "message" => commit_info.message,
          "author" => commit_info.author,
          "committer" => commit_info.committer
        }

        if limit > 1 and length(commit_info.parents) > 0 do
          # Could implement full history walking here
          {:ok, [commit_data]}
        else
          {:ok, [commit_data]}
        end

      error ->
        error
    end
  end

  defp get_object_statistics(repo) do
    git_dir = git_dir_from_repo(repo)

    case Dirup.Storage.Git.Object.get_stats(git_dir) do
      {:ok, stats} -> {:ok, stats}
      error -> error
    end
  end

  defp get_ref_statistics(repo) do
    git_dir = git_dir_from_repo(repo)

    with {:ok, branches} <- Dirup.Storage.Git.Ref.list_branches(git_dir),
         {:ok, tags} <- Dirup.Storage.Git.Ref.list_tags(git_dir) do
      {:ok, %{"branches" => branches, "tags" => tags}}
    end
  end

  defp calculate_repository_size(repo_path) do
    git_dir = Path.join(repo_path, ".git")

    case File.du(git_dir) do
      {:ok, size} -> size
      {:error, _} -> 0
    end
  rescue
    _ -> 0
  end
end
