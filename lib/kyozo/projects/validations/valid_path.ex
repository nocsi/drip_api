defmodule Kyozo.Projects.Validations.ValidPath do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    path = Ash.Changeset.get_attribute(changeset, :path)
    
    if path do
      validate_path(path)
    else
      :ok
    end
  end

  defp validate_path(path) do
    cond do
      # Check if path is empty or just whitespace
      String.trim(path) == "" ->
        {:error, field: :path, message: "Path cannot be empty"}

      # Check if path exists
      not File.exists?(path) ->
        {:error, field: :path, message: "Path does not exist"}

      # Check if path is readable
      not File.exists?(path) or not readable?(path) ->
        {:error, field: :path, message: "Path is not readable"}

      # Check for dangerous paths
      dangerous_path?(path) ->
        {:error, field: :path, message: "Path is not allowed for security reasons"}

      # All checks passed
      true ->
        :ok
    end
  end

  defp readable?(path) do
    case File.stat(path) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp dangerous_path?(path) do
    # Normalize the path to check for dangerous patterns
    normalized = Path.expand(path)
    
    dangerous_patterns = [
      "/etc/",
      "/usr/bin/",
      "/usr/sbin/",
      "/sbin/",
      "/bin/",
      "/root/",
      "/boot/",
      "/sys/",
      "/proc/",
      "/dev/"
    ]
    
    # Check if path starts with any dangerous system directories
    Enum.any?(dangerous_patterns, fn pattern ->
      String.starts_with?(normalized, pattern)
    end) or
    # Check for path traversal attempts
    String.contains?(path, "..") or
    # Check for absolute paths outside of allowed areas (basic protection)
    (Path.type(path) == :absolute and not allowed_absolute_path?(normalized))
  end

  defp allowed_absolute_path?(path) do
    # Allow paths in common safe directories
    allowed_prefixes = [
      "/home/",
      "/Users/",
      "/tmp/",
      "/var/tmp/",
      System.get_env("HOME", ""),
      System.tmp_dir()
    ]
    
    Enum.any?(allowed_prefixes, fn prefix ->
      prefix != "" and String.starts_with?(path, prefix)
    end)
  end
end