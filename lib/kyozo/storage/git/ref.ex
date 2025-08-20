defmodule Kyozo.Storage.Git.Ref do
  @moduledoc """
  Git reference management in pure Elixir.

  Handles reading and writing Git references (branches, tags, HEAD).
  References are stored as plain text files containing SHA-1 hashes
  or symbolic references.

  ## Reference Types

  - **Direct refs** - Point directly to a commit SHA-1
  - **Symbolic refs** - Point to another reference (e.g., HEAD -> refs/heads/main)

  ## Reference Storage

  - `.git/HEAD` - Points to the current branch
  - `.git/refs/heads/` - Branch references
  - `.git/refs/tags/` - Tag references
  - `.git/refs/remotes/` - Remote tracking branches
  """

  @doc """
  Read a reference value.

  Returns the SHA-1 hash that the reference points to, following
  symbolic references if necessary.
  """
  @spec read(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def read(git_dir, ref_name) when is_binary(git_dir) and is_binary(ref_name) do
    ref_path = build_ref_path(git_dir, ref_name)

    case File.read(ref_path) do
      {:ok, content} ->
        content = String.trim(content)

        case content do
          "ref: " <> target_ref ->
            # Symbolic reference - follow it
            read(git_dir, target_ref)

          sha1 when byte_size(sha1) == 40 ->
            # Direct SHA-1 reference
            {:ok, sha1}

          _ ->
            {:error, {:invalid_ref_format, content}}
        end

      {:error, :enoent} ->
        {:error, :ref_not_found}

      error ->
        error
    end
  end

  @doc """
  Update a reference to point to a commit SHA-1.
  """
  @spec update(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def update(git_dir, ref_name, commit_sha)
      when is_binary(git_dir) and is_binary(ref_name) and is_binary(commit_sha) do
    if valid_sha1?(commit_sha) do
      ref_path = build_ref_path(git_dir, ref_name)

      with :ok <- File.mkdir_p(Path.dirname(ref_path)),
           :ok <- File.write(ref_path, commit_sha <> "\n") do
        :ok
      end
    else
      {:error, {:invalid_sha1, commit_sha}}
    end
  end

  @doc """
  Create a symbolic reference.
  """
  @spec create_symbolic(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def create_symbolic(git_dir, ref_name, target_ref)
      when is_binary(git_dir) and is_binary(ref_name) and is_binary(target_ref) do
    ref_path = build_ref_path(git_dir, ref_name)
    content = "ref: #{target_ref}\n"

    with :ok <- File.mkdir_p(Path.dirname(ref_path)),
         :ok <- File.write(ref_path, content) do
      :ok
    end
  end

  @doc """
  Delete a reference.
  """
  @spec delete(String.t(), String.t()) :: :ok | {:error, term()}
  def delete(git_dir, ref_name) when is_binary(git_dir) and is_binary(ref_name) do
    ref_path = build_ref_path(git_dir, ref_name)

    case File.rm(ref_path) do
      :ok ->
        # Try to remove parent directories if empty
        cleanup_empty_ref_dirs(Path.dirname(ref_path), git_dir)
        :ok

      {:error, :enoent} ->
        # Reference doesn't exist - that's fine
        :ok

      error ->
        error
    end
  end

  @doc """
  Check if a reference exists.
  """
  @spec exists?(String.t(), String.t()) :: boolean()
  def exists?(git_dir, ref_name) when is_binary(git_dir) and is_binary(ref_name) do
    ref_path = build_ref_path(git_dir, ref_name)
    File.exists?(ref_path)
  end

  @doc """
  List all references of a given type.

  ## Examples

      # List all branches
      list_refs(git_dir, "heads")

      # List all tags
      list_refs(git_dir, "tags")

      # List all references
      list_refs(git_dir, "")
  """
  @spec list_refs(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_refs(git_dir, ref_type) when is_binary(git_dir) and is_binary(ref_type) do
    refs_dir =
      if ref_type == "" do
        Path.join(git_dir, "refs")
      else
        Path.join([git_dir, "refs", ref_type])
      end

    case File.exists?(refs_dir) do
      true ->
        refs = find_all_refs(refs_dir, refs_dir)
        {:ok, refs}

      false ->
        {:ok, []}
    end
  end

  @doc """
  Read the HEAD reference.
  """
  @spec read_head(String.t()) :: {:ok, String.t()} | {:error, term()}
  def read_head(git_dir) when is_binary(git_dir) do
    head_path = Path.join(git_dir, "HEAD")

    case File.read(head_path) do
      {:ok, content} ->
        content = String.trim(content)

        case content do
          "ref: " <> target_ref ->
            # HEAD points to a branch - resolve it
            case read(git_dir, target_ref) do
              {:ok, sha1} -> {:ok, sha1}
              {:error, :ref_not_found} -> {:error, :detached_head_invalid}
              error -> error
            end

          sha1 when byte_size(sha1) == 40 ->
            # Detached HEAD state
            {:ok, sha1}

          _ ->
            {:error, {:invalid_head_format, content}}
        end

      {:error, :enoent} ->
        {:error, :head_not_found}

      error ->
        error
    end
  end

  @doc """
  Set HEAD to point to a branch.
  """
  @spec set_head(String.t(), String.t()) :: :ok | {:error, term()}
  def set_head(git_dir, branch_name) when is_binary(git_dir) and is_binary(branch_name) do
    head_path = Path.join(git_dir, "HEAD")
    content = "ref: refs/heads/#{branch_name}\n"

    File.write(head_path, content)
  end

  @doc """
  Set HEAD to a specific commit (detached HEAD).
  """
  @spec set_head_detached(String.t(), String.t()) :: :ok | {:error, term()}
  def set_head_detached(git_dir, commit_sha) when is_binary(git_dir) and is_binary(commit_sha) do
    if valid_sha1?(commit_sha) do
      head_path = Path.join(git_dir, "HEAD")
      File.write(head_path, commit_sha <> "\n")
    else
      {:error, {:invalid_sha1, commit_sha}}
    end
  end

  @doc """
  Get the current branch name.

  Returns {:ok, branch_name} if HEAD points to a branch,
  or {:ok, :detached} if HEAD points directly to a commit.
  """
  @spec get_current_branch(String.t()) :: {:ok, String.t() | :detached} | {:error, term()}
  def get_current_branch(git_dir) when is_binary(git_dir) do
    head_path = Path.join(git_dir, "HEAD")

    case File.read(head_path) do
      {:ok, content} ->
        content = String.trim(content)

        case content do
          "ref: refs/heads/" <> branch_name ->
            {:ok, branch_name}

          sha1 when byte_size(sha1) == 40 ->
            {:ok, :detached}

          _ ->
            {:error, {:invalid_head_format, content}}
        end

      {:error, :enoent} ->
        {:error, :head_not_found}

      error ->
        error
    end
  end

  @doc """
  Get all branches in the repository.
  """
  @spec list_branches(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_branches(git_dir) when is_binary(git_dir) do
    list_refs(git_dir, "heads")
  end

  @doc """
  Get all tags in the repository.
  """
  @spec list_tags(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_tags(git_dir) when is_binary(git_dir) do
    list_refs(git_dir, "tags")
  end

  # Private functions

  @spec build_ref_path(String.t(), String.t()) :: String.t()
  defp build_ref_path(git_dir, ref_name) do
    # Handle both full refs (refs/heads/main) and short refs (heads/main)
    ref_path =
      case ref_name do
        "refs/" <> _ -> ref_name
        path -> "refs/#{path}"
      end

    Path.join(git_dir, ref_path)
  end

  @spec valid_sha1?(String.t()) :: boolean()
  defp valid_sha1?(sha1) when is_binary(sha1) and byte_size(sha1) == 40 do
    String.match?(sha1, ~r/^[0-9a-f]{40}$/i)
  end

  defp valid_sha1?(_), do: false

  @spec find_all_refs(String.t(), String.t()) :: [String.t()]
  defp find_all_refs(current_dir, base_refs_dir) do
    case File.ls(current_dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          full_path = Path.join(current_dir, entry)

          cond do
            File.dir?(full_path) ->
              # Recursively search subdirectories
              find_all_refs(full_path, base_refs_dir)

            File.regular?(full_path) ->
              # Convert absolute path back to relative ref name
              relative_path = Path.relative_to(full_path, base_refs_dir)
              [relative_path]

            true ->
              []
          end
        end)

      {:error, _} ->
        []
    end
  end

  @spec cleanup_empty_ref_dirs(String.t(), String.t()) :: :ok
  defp cleanup_empty_ref_dirs(dir_path, git_dir) do
    refs_dir = Path.join(git_dir, "refs")

    # Don't remove the base refs directory
    if dir_path != refs_dir and String.starts_with?(dir_path, refs_dir) do
      case File.ls(dir_path) do
        {:ok, []} ->
          # Directory is empty - remove it
          _ = File.rmdir(dir_path)
          # Try to remove parent directory too
          cleanup_empty_ref_dirs(Path.dirname(dir_path), git_dir)

        _ ->
          # Directory not empty or error - stop
          :ok
      end
    else
      :ok
    end
  end
end
