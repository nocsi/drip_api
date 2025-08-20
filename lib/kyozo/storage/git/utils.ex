defmodule Kyozo.Storage.Git.Utils do
  @moduledoc """
  Utility functions for Git operations.

  Provides helper functions for common Git operations like SHA-1 hashing,
  path manipulation, and object validation.
  """

  @doc """
  Calculate SHA-1 hash of binary data.

  Returns the SHA-1 hash as a lowercase hex string.
  """
  @spec sha1(binary()) :: String.t()
  def sha1(data) when is_binary(data) do
    :crypto.hash(:sha, data)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Validate a SHA-1 hash string.

  Returns true if the string is a valid 40-character hex SHA-1 hash.
  """
  @spec valid_sha1?(String.t()) :: boolean()
  def valid_sha1?(sha1) when is_binary(sha1) and byte_size(sha1) == 40 do
    String.match?(sha1, ~r/^[0-9a-f]{40}$/i)
  end

  def valid_sha1?(_), do: false

  @doc """
  Generate a short SHA-1 prefix for display.

  Returns the first 7 characters of the SHA-1 hash.
  """
  @spec short_sha(String.t()) :: String.t()
  def short_sha(sha1) when is_binary(sha1) and byte_size(sha1) >= 7 do
    String.slice(sha1, 0, 7)
  end

  def short_sha(sha1) when is_binary(sha1) do
    sha1
  end

  @doc """
  Normalize a file path for Git operations.

  Removes leading slashes and converts backslashes to forward slashes.
  """
  @spec normalize_path(String.t()) :: String.t()
  def normalize_path(path) when is_binary(path) do
    path
    |> String.replace("\\", "/")
    |> String.trim_leading("/")
  end

  @doc """
  Split a path into directory components.

  Returns a list of directory parts, useful for building tree structures.
  """
  @spec path_parts(String.t()) :: [String.t()]
  def path_parts(path) when is_binary(path) do
    path
    |> normalize_path()
    |> String.split("/", trim: true)
  end

  @doc """
  Join path components with forward slashes.
  """
  @spec join_path([String.t()]) :: String.t()
  def join_path(parts) when is_list(parts) do
    Enum.join(parts, "/")
  end

  @doc """
  Get the parent directory of a path.

  Returns an empty string if the path has no parent.
  """
  @spec parent_dir(String.t()) :: String.t()
  def parent_dir(path) when is_binary(path) do
    case path_parts(path) do
      [] -> ""
      [_single] -> ""
      parts -> parts |> Enum.drop(-1) |> join_path()
    end
  end

  @doc """
  Get the filename from a path.
  """
  @spec filename(String.t()) :: String.t()
  def filename(path) when is_binary(path) do
    case path_parts(path) do
      [] -> ""
      parts -> List.last(parts)
    end
  end

  @doc """
  Generate a timestamp string for Git commits.

  Returns Unix timestamp as string.
  """
  @spec timestamp() :: String.t()
  def timestamp do
    System.os_time(:second) |> Integer.to_string()
  end

  @doc """
  Generate a timezone string for Git commits.

  Returns the local timezone offset in Git format (e.g., "+0000", "-0800").
  """
  @spec timezone() :: String.t()
  def timezone do
    # Simple implementation - always return UTC
    # In a real implementation, you'd calculate the actual timezone
    "+0000"
  end

  @doc """
  Parse a Git person string (author/committer).

  Parses strings like "Name <email> timestamp timezone".
  """
  @spec parse_person(String.t()) :: %{
          name: String.t(),
          email: String.t(),
          timestamp: integer(),
          timezone: String.t()
        }
  def parse_person(person_string) when is_binary(person_string) do
    case Regex.run(~r/^(.+) <(.+?)> (\d+) ([\+\-]\d{4})$/, person_string) do
      [_, name, email, timestamp, timezone] ->
        %{
          name: name,
          email: email,
          timestamp: String.to_integer(timestamp),
          timezone: timezone
        }

      _ ->
        %{
          name: person_string,
          email: "",
          timestamp: 0,
          timezone: "+0000"
        }
    end
  end

  @doc """
  Format a Git person string from components.
  """
  @spec format_person(String.t(), String.t(), integer(), String.t()) :: String.t()
  def format_person(name, email, timestamp, timezone)
      when is_binary(name) and is_binary(email) and is_integer(timestamp) and is_binary(timezone) do
    "#{name} <#{email}> #{timestamp} #{timezone}"
  end

  @doc """
  Format a Git person string with current timestamp.
  """
  @spec format_person(String.t(), String.t()) :: String.t()
  def format_person(name, email) when is_binary(name) and is_binary(email) do
    format_person(name, email, System.os_time(:second), timezone())
  end

  @doc """
  Validate a Git object type.
  """
  @spec valid_object_type?(atom()) :: boolean()
  def valid_object_type?(:blob), do: true
  def valid_object_type?(:tree), do: true
  def valid_object_type?(:commit), do: true
  def valid_object_type?(:tag), do: true
  def valid_object_type?(_), do: false

  @doc """
  Validate a file mode for Git tree entries.
  """
  @spec valid_file_mode?(String.t()) :: boolean()
  # Regular file
  def valid_file_mode?("100644"), do: true
  # Executable file
  def valid_file_mode?("100755"), do: true
  # Symbolic link
  def valid_file_mode?("120000"), do: true
  # Directory
  def valid_file_mode?("040000"), do: true
  # Git submodule
  def valid_file_mode?("160000"), do: true
  def valid_file_mode?(_), do: false

  @doc """
  Get the default file mode for content.

  Returns "100644" for regular files or "040000" for directories.
  """
  @spec default_file_mode(boolean()) :: String.t()
  def default_file_mode(is_directory) do
    if is_directory, do: "040000", else: "100644"
  end

  @doc """
  Check if a file mode represents a directory.
  """
  @spec directory_mode?(String.t()) :: boolean()
  def directory_mode?("040000"), do: true
  def directory_mode?(_), do: false

  @doc """
  Generate a random hex string for temporary operations.
  """
  @spec random_hex(integer()) :: String.t()
  def random_hex(byte_count \\ 8) when is_integer(byte_count) and byte_count > 0 do
    :crypto.strong_rand_bytes(byte_count)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Safe string comparison that's resistant to timing attacks.
  """
  @spec secure_compare(String.t(), String.t()) :: boolean()
  def secure_compare(a, b) when is_binary(a) and is_binary(b) do
    if byte_size(a) != byte_size(b) do
      false
    else
      :crypto.hash_equals(a, b)
    end
  end

  @doc """
  Escape a string for safe use in Git commit messages.
  """
  @spec escape_commit_message(String.t()) :: String.t()
  def escape_commit_message(message) when is_binary(message) do
    message
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.trim()
  end

  @doc """
  Calculate the size of content in bytes.
  """
  @spec content_size(binary()) :: integer()
  def content_size(content) when is_binary(content) do
    byte_size(content)
  end

  @doc """
  Check if content appears to be binary.

  Uses a simple heuristic: if content contains null bytes, it's likely binary.
  """
  @spec binary_content?(binary()) :: boolean()
  def binary_content?(content) when is_binary(content) do
    String.contains?(content, "\0")
  end

  @doc """
  Truncate content for display purposes.
  """
  @spec truncate_content(binary(), integer()) :: binary()
  def truncate_content(content, max_length \\ 100)
      when is_binary(content) and is_integer(max_length) and max_length > 0 do
    if byte_size(content) <= max_length do
      content
    else
      binary_part(content, 0, max_length - 3) <> "..."
    end
  end
end
