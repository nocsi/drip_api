defmodule Dirup.Storage.Git.Repository do
  @moduledoc """
  Native Git repository implementation in pure Elixir.

  This module implements Git's core functionality by directly manipulating
  Git's internal file format without external dependencies.

  ## Git Internal Structure

  - `.git/objects/` - Stores all Git objects (blobs, trees, commits)
  - `.git/refs/heads/` - Branch references
  - `.git/HEAD` - Current branch pointer
  - `.git/index` - Staging area (not implemented yet)

  ## Object Types

  - **blob** - File content
  - **tree** - Directory structure
  - **commit** - Snapshot with metadata
  - **tag** - Annotated reference (not implemented)
  """

  alias Dirup.Storage.Git.{Object, Ref, Utils}

  @default_branch "main"

  defstruct [:path, :git_dir]

  @type t() :: %__MODULE__{
          path: String.t(),
          git_dir: String.t()
        }

  @doc """
  Initialize a new Git repository or open an existing one.

  ## Examples

      iex> {:ok, repo} = Repository.init("/path/to/repo")
      {:ok, %Repository{path: "/path/to/repo", git_dir: "/path/to/repo/.git"}}
  """
  @spec init(String.t()) :: {:ok, t()} | {:error, term()}
  def init(path) when is_binary(path) do
    git_dir = Path.join(path, ".git")

    with :ok <- File.mkdir_p(path),
         :ok <- create_git_structure(git_dir) do
      repo = %__MODULE__{path: path, git_dir: git_dir}
      {:ok, repo}
    end
  end

  @doc """
  Open an existing Git repository.
  """
  @spec open(String.t()) :: {:ok, t()} | {:error, term()}
  def open(path) when is_binary(path) do
    git_dir = Path.join(path, ".git")

    if File.dir?(git_dir) do
      repo = %__MODULE__{path: path, git_dir: git_dir}
      {:ok, repo}
    else
      {:error, :not_a_git_repository}
    end
  end

  @doc """
  Write a blob object to the repository.

  Returns the SHA-1 hash of the created blob.
  """
  @spec write_blob(t(), binary()) :: {:ok, String.t()} | {:error, term()}
  def write_blob(%__MODULE__{git_dir: git_dir}, content) when is_binary(content) do
    blob_data = "blob #{byte_size(content)}\0#{content}"
    sha1 = Utils.sha1(blob_data)

    case Object.write(git_dir, sha1, blob_data) do
      :ok -> {:ok, sha1}
      error -> error
    end
  end

  @doc """
  Read a blob object from the repository.
  """
  @spec read_blob(t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def read_blob(%__MODULE__{git_dir: git_dir}, sha1) when is_binary(sha1) do
    case Object.read(git_dir, sha1) do
      {:ok, data} ->
        case parse_object(data) do
          {:blob, content} -> {:ok, content}
          {other_type, _} -> {:error, {:wrong_object_type, other_type, :blob}}
        end

      error ->
        error
    end
  end

  @doc """
  Create a tree object from a list of entries.

  ## Tree Entry Format

  Each entry is a map with:
  - `:mode` - File mode (e.g., "100644" for regular file, "040000" for directory)
  - `:name` - File/directory name
  - `:sha1` - SHA-1 hash of the object
  """
  @spec write_tree(t(), [tree_entry()]) :: {:ok, String.t()} | {:error, term()}
  def write_tree(%__MODULE__{git_dir: git_dir}, entries) when is_list(entries) do
    # Sort entries by name (required by Git spec)
    sorted_entries = Enum.sort_by(entries, & &1.name)

    tree_content =
      sorted_entries
      |> Enum.map(&format_tree_entry/1)
      |> Enum.join()

    tree_data = "tree #{byte_size(tree_content)}\0#{tree_content}"
    sha1 = Utils.sha1(tree_data)

    case Object.write(git_dir, sha1, tree_data) do
      :ok -> {:ok, sha1}
      error -> error
    end
  end

  @doc """
  Read a tree object and return its entries.
  """
  @spec read_tree(t(), String.t()) :: {:ok, [tree_entry()]} | {:error, term()}
  def read_tree(%__MODULE__{git_dir: git_dir}, sha1) when is_binary(sha1) do
    case Object.read(git_dir, sha1) do
      {:ok, data} ->
        case parse_object(data) do
          {:tree, content} -> {:ok, parse_tree_entries(content)}
          {other_type, _} -> {:error, {:wrong_object_type, other_type, :tree}}
        end

      error ->
        error
    end
  end

  @doc """
  Create a commit object.

  ## Options

  - `:author` - Author info (default: "Kyozo <kyozo@example.com>")
  - `:committer` - Committer info (default: same as author)
  - `:message` - Commit message (required)
  - `:parents` - List of parent commit SHAs (default: [])
  """
  @spec write_commit(t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def write_commit(%__MODULE__{git_dir: git_dir}, tree_sha, opts) do
    message = Keyword.fetch!(opts, :message)
    parents = Keyword.get(opts, :parents, [])
    author = Keyword.get(opts, :author, "Kyozo <kyozo@example.com>")
    committer = Keyword.get(opts, :committer, author)
    timestamp = System.os_time(:second)
    timezone = "+0000"

    parent_lines = Enum.map(parents, &"parent #{&1}\n")

    commit_content =
      [
        "tree #{tree_sha}\n",
        parent_lines,
        "author #{author} #{timestamp} #{timezone}\n",
        "committer #{committer} #{timestamp} #{timezone}\n",
        "\n",
        message,
        "\n"
      ]
      |> IO.iodata_to_binary()

    commit_data = "commit #{byte_size(commit_content)}\0#{commit_content}"
    sha1 = Utils.sha1(commit_data)

    case Object.write(git_dir, sha1, commit_data) do
      :ok -> {:ok, sha1}
      error -> error
    end
  end

  @doc """
  Read a commit object and return its metadata.
  """
  @spec read_commit(t(), String.t()) :: {:ok, commit_info()} | {:error, term()}
  def read_commit(%__MODULE__{git_dir: git_dir}, sha1) when is_binary(sha1) do
    case Object.read(git_dir, sha1) do
      {:ok, data} ->
        case parse_object(data) do
          {:commit, content} -> {:ok, parse_commit(content)}
          {other_type, _} -> {:error, {:wrong_object_type, other_type, :commit}}
        end

      error ->
        error
    end
  end

  @doc """
  Update a branch reference to point to a commit.
  """
  @spec update_ref(t(), String.t(), String.t()) :: :ok | {:error, term()}
  def update_ref(%__MODULE__{git_dir: git_dir}, branch, commit_sha) do
    Ref.update(git_dir, "heads/#{branch}", commit_sha)
  end

  @doc """
  Get the current HEAD reference.
  """
  @spec get_head(t()) :: {:ok, String.t()} | {:error, term()}
  def get_head(%__MODULE__{git_dir: git_dir}) do
    Ref.read_head(git_dir)
  end

  @doc """
  Set the HEAD to point to a branch.
  """
  @spec set_head(t(), String.t()) :: :ok | {:error, term()}
  def set_head(%__MODULE__{git_dir: git_dir}, branch) do
    Ref.set_head(git_dir, branch)
  end

  # Private functions

  defp create_git_structure(git_dir) do
    directories = [
      git_dir,
      Path.join(git_dir, "objects"),
      Path.join(git_dir, "refs"),
      Path.join(git_dir, "refs/heads"),
      Path.join(git_dir, "refs/tags")
    ]

    with :ok <- create_directories(directories),
         :ok <- File.write(Path.join(git_dir, "HEAD"), "ref: refs/heads/#{@default_branch}\n") do
      :ok
    end
  end

  defp create_directories([]), do: :ok

  defp create_directories([dir | rest]) do
    case File.mkdir_p(dir) do
      :ok -> create_directories(rest)
      error -> error
    end
  end

  defp parse_object(data) do
    case String.split(data, "\0", parts: 2) do
      [header, content] ->
        [type, _size] = String.split(header, " ", parts: 2)
        {String.to_atom(type), content}

      _ ->
        {:error, :invalid_object_format}
    end
  end

  defp format_tree_entry(%{mode: mode, name: name, sha1: sha1}) do
    # Git stores SHA-1 as 20 raw bytes, not hex
    sha_bytes = Base.decode16!(sha1, case: :lower)
    "#{mode} #{name}\0#{sha_bytes}"
  end

  defp parse_tree_entries(content) do
    parse_tree_entries(content, [])
  end

  defp parse_tree_entries("", acc), do: Enum.reverse(acc)

  defp parse_tree_entries(content, acc) when is_binary(content) do
    case String.split(content, "\0", parts: 2) do
      [mode_and_name, rest] ->
        [mode, name] = String.split(mode_and_name, " ", parts: 2)
        <<sha_bytes::binary-size(20), remaining::binary>> = rest
        sha1 = Base.encode16(sha_bytes, case: :lower)

        entry = %{mode: mode, name: name, sha1: sha1}
        parse_tree_entries(remaining, [entry | acc])

      _ ->
        # Malformed tree entry
        Enum.reverse(acc)
    end
  end

  defp parse_commit(content) do
    [header_section, message] = String.split(content, "\n\n", parts: 2)
    header_lines = String.split(header_section, "\n")

    parse_commit_headers(header_lines, %{message: String.trim(message)})
  end

  defp parse_commit_headers([], acc), do: acc

  defp parse_commit_headers([line | rest], acc) do
    case String.split(line, " ", parts: 2) do
      ["tree", sha] ->
        parse_commit_headers(rest, Map.put(acc, :tree, sha))

      ["parent", sha] ->
        parents = Map.get(acc, :parents, [])
        parse_commit_headers(rest, Map.put(acc, :parents, [sha | parents]))

      ["author", author_info] ->
        parse_commit_headers(rest, Map.put(acc, :author, parse_person_info(author_info)))

      ["committer", committer_info] ->
        parse_commit_headers(rest, Map.put(acc, :committer, parse_person_info(committer_info)))

      _ ->
        parse_commit_headers(rest, acc)
    end
  end

  defp parse_person_info(person_string) do
    # Format: "Name <email> timestamp timezone"
    case Regex.run(~r/^(.+) <(.+)> (\d+) ([\+\-]\d{4})$/, person_string) do
      [_, name, email, timestamp, timezone] ->
        %{
          name: name,
          email: email,
          timestamp: String.to_integer(timestamp),
          timezone: timezone
        }

      _ ->
        %{name: person_string, email: "", timestamp: 0, timezone: "+0000"}
    end
  end

  # Type specifications
  @type tree_entry() :: %{
          mode: String.t(),
          name: String.t(),
          sha1: String.t()
        }

  @type commit_info() :: %{
          tree: String.t(),
          parents: [String.t()],
          author: person_info(),
          committer: person_info(),
          message: String.t()
        }

  @type person_info() :: %{
          name: String.t(),
          email: String.t(),
          timestamp: integer(),
          timezone: String.t()
        }
end
