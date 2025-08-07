defmodule Kyozo.Projects.Validations.ValidDocumentPath do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    path = Ash.Changeset.get_attribute(changeset, :path)
    absolute_path = Ash.Changeset.get_attribute(changeset, :absolute_path)
    
    with :ok <- validate_path_not_empty(path),
         :ok <- validate_absolute_path_not_empty(absolute_path),
         :ok <- validate_absolute_path_exists(absolute_path),
         :ok <- validate_absolute_path_readable(absolute_path),
         :ok <- validate_is_file(absolute_path),
         :ok <- validate_file_size(absolute_path),
         :ok <- validate_path_safety(path, absolute_path) do
      :ok
    else
      error -> error
    end
  end

  defp validate_path_not_empty(path) do
    if path && String.trim(path) != "" do
      :ok
    else
      {:error, field: :path, message: "Document path cannot be empty"}
    end
  end

  defp validate_absolute_path_not_empty(absolute_path) do
    if absolute_path && String.trim(absolute_path) != "" do
      :ok
    else
      {:error, field: :absolute_path, message: "Absolute path cannot be empty"}
    end
  end

  defp validate_absolute_path_exists(absolute_path) do
    if File.exists?(absolute_path) do
      :ok
    else
      {:error, field: :absolute_path, message: "Document file does not exist"}
    end
  end

  defp validate_absolute_path_readable(absolute_path) do
    case File.stat(absolute_path) do
      {:ok, _stat} -> 
        case File.read(absolute_path) do
          {:ok, _content} -> :ok
          {:error, :eacces} -> {:error, field: :absolute_path, message: "Document file is not readable (permission denied)"}
          {:error, reason} -> {:error, field: :absolute_path, message: "Cannot read document file: #{reason}"}
        end
      {:error, reason} -> 
        {:error, field: :absolute_path, message: "Cannot access document file: #{reason}"}
    end
  end

  defp validate_is_file(absolute_path) do
    case File.stat(absolute_path) do
      {:ok, %File.Stat{type: :regular}} -> :ok
      {:ok, %File.Stat{type: :directory}} -> {:error, field: :absolute_path, message: "Path points to a directory, not a file"}
      {:ok, %File.Stat{type: type}} -> {:error, field: :absolute_path, message: "Path points to a #{type}, not a regular file"}
      {:error, reason} -> {:error, field: :absolute_path, message: "Cannot determine file type: #{reason}"}
    end
  end

  defp validate_file_size(absolute_path) do
    case File.stat(absolute_path) do
      {:ok, %File.Stat{size: size}} -> 
        max_size = 50 * 1024 * 1024  # 50MB limit
        if size <= max_size do
          :ok
        else
          size_mb = Float.round(size / (1024 * 1024), 2)
          {:error, field: :absolute_path, message: "Document file is too large (#{size_mb}MB). Maximum allowed size is 50MB"}
        end
      {:error, reason} -> 
        {:error, field: :absolute_path, message: "Cannot check file size: #{reason}"}
    end
  end

  defp validate_path_safety(path, absolute_path) do
    with :ok <- validate_no_path_traversal(path),
         :ok <- validate_safe_absolute_path(absolute_path),
         :ok <- validate_allowed_extension(absolute_path) do
      :ok
    else
      error -> error
    end
  end

  defp validate_no_path_traversal(path) do
    if String.contains?(path, "..") do
      {:error, field: :path, message: "Path traversal attempts (..) are not allowed"}
    else
      :ok
    end
  end

  defp validate_safe_absolute_path(absolute_path) do
    normalized = Path.expand(absolute_path)
    
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
    
    if Enum.any?(dangerous_patterns, &String.starts_with?(normalized, &1)) do
      {:error, field: :absolute_path, message: "Access to system directories is not allowed"}
    else
      :ok
    end
  end

  defp validate_allowed_extension(absolute_path) do
    extension = Path.extname(absolute_path) |> String.downcase()
    
    allowed_extensions = [
      ".md", ".markdown", ".mdown", ".mkd", ".mkdn",  # Markdown files
      ".txt", ".text",                                # Text files
      ".rst",                                         # reStructuredText
      ".org",                                         # Org mode
      ".asciidoc", ".adoc",                          # AsciiDoc
      ".ipynb",                                       # Jupyter notebooks
      ".qmd", ".rmd"                                  # Quarto/R Markdown
    ]
    
    if extension in allowed_extensions do
      :ok
    else
      {:error, field: :absolute_path, message: "File type '#{extension}' is not supported. Allowed types: #{Enum.join(allowed_extensions, ", ")}"}
    end
  end
end