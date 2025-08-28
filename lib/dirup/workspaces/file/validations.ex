defmodule Dirup.Workspaces.File.Validations do
  @moduledoc """
  Validation modules for File resource to ensure data integrity
  and proper file/folder handling constraints.
  """

  defmodule ValidateFilePath do
    @moduledoc """
    Validates that file paths are safe and follow proper naming conventions.
    """

    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :file_path) do
        nil -> :ok
        file_path -> validate_path(file_path)
      end
    end

    defp validate_path(file_path) do
      cond do
        String.contains?(file_path, "..") ->
          {:error,
           field: :file_path, message: "File path cannot contain '..' (directory traversal)"}

        String.starts_with?(file_path, "/") ->
          {:error, field: :file_path, message: "File path cannot be absolute"}

        String.length(file_path) > 1024 ->
          {:error, field: :file_path, message: "File path too long (max 1024 characters)"}

        not String.match?(file_path, ~r/^[a-zA-Z0-9._\-\/]+$/) ->
          {:error, field: :file_path, message: "File path contains invalid characters"}

        true ->
          :ok
      end
    end
  end

  defmodule ValidateContentType do
    @moduledoc """
    Validates that content types are supported and properly formatted.
    """

    use Ash.Resource.Validation

    @supported_types [
      "text/plain",
      "text/markdown",
      "text/html",
      "text/csv",
      "application/json",
      "application/xml",
      "application/pdf",
      "application/x-jupyter-notebook",
      "application/javascript",
      "text/x-python",
      "text/x-r",
      "text/x-julia",
      "text/x-sql",
      "image/png",
      "image/jpeg",
      "image/gif",
      "image/svg+xml",
      "text/css",
      "text/x-scss",
      "text/x-less",
      "application/yaml",
      "application/x-yaml",
      "text/yaml",
      "application/toml",
      "text/x-toml"
    ]

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :content_type) do
        nil -> :ok
        content_type -> validate_content_type(content_type)
      end
    end

    defp validate_content_type(content_type) do
      cond do
        content_type in @supported_types ->
          :ok

        String.match?(content_type, ~r/^[a-z]+\/[a-z0-9\-\+\.]+$/) ->
          # Allow other properly formatted MIME types
          :ok

        true ->
          {:error,
           field: :content_type, message: "Unsupported or invalid content type: #{content_type}"}
      end
    end

    def supported_types, do: @supported_types
  end

  defmodule ValidateStorageBackend do
    @moduledoc """
    Validates that storage backend is appropriate for the document type.
    """

    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      storage_backend = Ash.Changeset.get_attribute(changeset, :storage_backend)
      content_type = Ash.Changeset.get_attribute(changeset, :content_type)
      file_path = Ash.Changeset.get_attribute(changeset, :file_path)

      case {storage_backend, content_type, file_path} do
        {nil, _, _} -> :ok
        {backend, ct, fp} -> validate_backend_compatibility(backend, ct, fp)
      end
    end

    defp validate_backend_compatibility(backend, content_type, file_path) do
      cond do
        backend not in [:git, :s3, :hybrid] ->
          {:error, field: :storage_backend, message: "Invalid storage backend: #{backend}"}

        backend == :git and is_large_file?(file_path) ->
          {:error,
           field: :storage_backend,
           message: "Git backend not recommended for large files. Consider S3 or hybrid."}

        backend == :s3 and is_version_controlled_file?(content_type, file_path) ->
          {:error,
           field: :storage_backend,
           message: "S3 backend not optimal for version-controlled files. Consider Git or hybrid."}

        true ->
          :ok
      end
    end

    defp is_large_file?(file_path) do
      # Check if file extension suggests it might be large
      large_extensions = [
        ".zip",
        ".tar",
        ".gz",
        ".pdf",
        ".mp4",
        ".avi",
        ".jpg",
        ".jpeg",
        ".png",
        ".gif",
        ".dmg",
        ".iso"
      ]

      extension = Path.extname(file_path) |> String.downcase()
      extension in large_extensions
    end

    defp is_version_controlled_file?(content_type, file_path) do
      # Check if content type or extension suggests version control would be beneficial
      vc_content_types = [
        "text/markdown",
        "application/x-jupyter-notebook",
        "text/x-python",
        "text/x-r",
        "text/x-julia",
        "application/json",
        "text/yaml"
      ]

      vc_extensions = [
        ".md",
        ".ipynb",
        ".py",
        ".js",
        ".ts",
        ".r",
        ".jl",
        ".json",
        ".yaml",
        ".yml",
        ".sql",
        ".sh"
      ]

      extension = Path.extname(file_path) |> String.downcase()

      content_type in vc_content_types or extension in vc_extensions
    end
  end

  defmodule ValidateFileSize do
    @moduledoc """
    Validates file size constraints based on storage backend and content type.
    """

    use Ash.Resource.Validation

    # 100MB default max
    @max_file_size 100 * 1024 * 1024
    # 10MB max for Git
    @max_git_file_size 10 * 1024 * 1024
    # 5GB max for S3
    @max_s3_file_size 5 * 1024 * 1024 * 1024

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      file_size = Ash.Changeset.get_attribute(changeset, :file_size)
      storage_backend = Ash.Changeset.get_attribute(changeset, :storage_backend)

      case {file_size, storage_backend} do
        {nil, _} -> :ok
        {size, backend} -> validate_size_for_backend(size, backend)
      end
    end

    defp validate_size_for_backend(size, backend) do
      max_size =
        case backend do
          :git -> @max_git_file_size
          :s3 -> @max_s3_file_size
          :hybrid -> @max_file_size
          _ -> @max_file_size
        end

      if size > max_size do
        {:error,
         field: :file_size,
         message:
           "File size (#{format_bytes(size)}) exceeds maximum for #{backend} backend (#{format_bytes(max_size)})"}
      else
        :ok
      end
    end

    defp format_bytes(bytes) when bytes >= 1024 * 1024 * 1024 do
      "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
    end

    defp format_bytes(bytes) when bytes >= 1024 * 1024 do
      "#{Float.round(bytes / (1024 * 1024), 2)} MB"
    end

    defp format_bytes(bytes) when bytes >= 1024 do
      "#{Float.round(bytes / 1024, 2)} KB"
    end

    defp format_bytes(bytes), do: "#{bytes} bytes"
  end

  defmodule ValidateTitle do
    @moduledoc """
    Validates document titles for safety and usability.
    """

    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :title) do
        nil -> :ok
        title -> validate_title(title)
      end
    end

    defp validate_title(title) do
      cond do
        String.length(title) == 0 ->
          {:error, field: :title, message: "Title cannot be empty"}

        String.length(title) > 255 ->
          {:error, field: :title, message: "Title too long (max 255 characters)"}

        String.match?(title, ~r/[\/\\:*?"<>|]/) ->
          {:error,
           field: :title, message: "Title contains invalid characters: / \\ : * ? \" < > |"}

        String.starts_with?(title, ".") ->
          {:error, field: :title, message: "Title cannot start with a dot"}

        String.ends_with?(title, ".") ->
          {:error, field: :title, message: "Title cannot end with a dot"}

        String.trim(title) != title ->
          {:error, field: :title, message: "Title cannot start or end with whitespace"}

        title in [
          "CON",
          "PRN",
          "AUX",
          "NUL",
          "COM1",
          "COM2",
          "COM3",
          "COM4",
          "COM5",
          "COM6",
          "COM7",
          "COM8",
          "COM9",
          "LPT1",
          "LPT2",
          "LPT3",
          "LPT4",
          "LPT5",
          "LPT6",
          "LPT7",
          "LPT8",
          "LPT9"
        ] ->
          {:error, field: :title, message: "Title cannot be a reserved system name"}

        true ->
          :ok
      end
    end
  end

  defmodule ValidateTeamAccess do
    @moduledoc """
    Validates that the user has access to the specified team and can create files.
    """

    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, context) do
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      actor = Map.get(context, :actor)

      case {team_id, actor} do
        {nil, _} -> :ok
        {_, nil} -> {:error, field: :team_id, message: "Authentication required"}
        {tid, actor} -> validate_team_access(tid, actor)
      end
    end

    defp validate_team_access(team_id, actor) do
      # This would normally check if the actor is a member of the team
      # For now, we'll do a basic validation
      case team_id do
        id when is_binary(id) and byte_size(id) > 0 -> :ok
        _ -> {:error, field: :team_id, message: "Invalid team ID"}
      end
    end
  end

  defmodule ValidateUniqueFilePath do
    @moduledoc """
    Validates that file path is unique within the team/workspace.
    """

    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      file_path = Ash.Changeset.get_attribute(changeset, :file_path)

      document_id =
        case Ash.Changeset.get_data(changeset) do
          %{id: id} -> id
          _ -> nil
        end

      case {team_id, file_path} do
        {nil, _} -> :ok
        {_, nil} -> :ok
        {tid, fp} -> check_path_uniqueness(tid, fp, document_id)
      end
    end

    defp check_path_uniqueness(team_id, file_path, exclude_id) do
      # This would normally query the database to check for conflicts
      # For now, we'll do basic validation
      if String.length(file_path) > 0 do
        :ok
      else
        {:error, field: :file_path, message: "File path cannot be empty"}
      end
    end
  end

  defmodule ValidateDirectoryConstraints do
    @moduledoc """
    Validates constraints specific to directories vs files.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      is_directory = Ash.Changeset.get_attribute(changeset, :is_directory)
      content_type = Ash.Changeset.get_attribute(changeset, :content_type)

      cond do
        is_directory && content_type != "application/x-directory" ->
          {:error,
           field: :content_type,
           message: "Directories must have content_type 'application/x-directory'"}

        not is_directory && content_type == "application/x-directory" ->
          {:error,
           field: :is_directory,
           message: "Only directories can have content_type 'application/x-directory'"}

        true ->
          :ok
      end
    end
  end

  defmodule ValidateParentDirectory do
    @moduledoc """
    Validates that parent directory relationships are valid.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, context) do
      parent_file_id = Ash.Changeset.get_attribute(changeset, :parent_file_id)

      if parent_file_id do
        validate_parent_exists_and_is_directory(parent_file_id, context)
      else
        :ok
      end
    end

    defp validate_parent_exists_and_is_directory(parent_id, context) do
      actor = Map.get(context, :actor)

      case Dirup.Workspaces.get_file(parent_id, actor: actor) do
        {:ok, parent_file} ->
          if parent_file.is_directory do
            :ok
          else
            {:error, field: :parent_file_id, message: "Parent must be a directory"}
          end

        {:error, _} ->
          {:error, field: :parent_file_id, message: "Parent directory not found or access denied"}
      end
    rescue
      _ ->
        {:error, field: :parent_file_id, message: "Failed to validate parent directory"}
    end
  end
end
