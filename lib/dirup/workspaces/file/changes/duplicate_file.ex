defmodule Dirup.Workspaces.File.Changes.DuplicateFile do
  @moduledoc """
  Change module for duplicating files within or across workspaces.
  """

  use Ash.Resource.Change

  alias Dirup.Workspaces.Storage
  alias Dirup.Workspaces.File

  @impl true
  def change(changeset, _opts, context) do
    source_file = changeset.data

    # Extract arguments
    new_name = Ash.Changeset.get_argument(changeset, :new_name)
    copy_to_workspace_id = Ash.Changeset.get_argument(changeset, :copy_to_workspace_id)
    commit_message = Ash.Changeset.get_argument(changeset, :initial_commit_message)

    # Determine target workspace
    target_workspace_id = copy_to_workspace_id || source_file.workspace_id

    # Generate new name if not provided
    duplicate_name = new_name || generate_duplicate_name(source_file.name)

    # Get content from source file
    case get_file_content(source_file) do
      {:ok, content} ->
        # Create duplicate file attributes
        duplicate_attrs = %{
          name: duplicate_name,
          file_path: generate_file_path(duplicate_name, source_file.file_path),
          content_type: source_file.content_type,
          description: source_file.description && "Copy of #{source_file.description}",
          tags: source_file.tags || [],
          workspace_id: target_workspace_id,
          team_id: source_file.team_id,
          storage_backend: source_file.storage_backend
        }

        # Create the duplicate file
        case create_duplicate_file(duplicate_attrs, content, commit_message, context) do
          {:ok, duplicate_file} ->
            # Return the duplicate file as the result
            Ash.Changeset.set_result(changeset, duplicate_file)

          {:error, error} ->
            Ash.Changeset.add_error(changeset, error)
        end

      {:error, error} ->
        Ash.Changeset.add_error(
          changeset,
          "Failed to read source file content: #{inspect(error)}"
        )
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # This change cannot be performed atomically as it involves file operations
    :not_atomic
  end

  defp generate_duplicate_name(original_name) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    # Split name and extension
    {base_name, ext} =
      case Path.extname(original_name) do
        "" -> {original_name, ""}
        extension -> {Path.rootname(original_name), extension}
      end

    cond do
      String.contains?(base_name, "Copy of") ->
        "#{base_name} (#{timestamp})#{ext}"

      true ->
        "Copy of #{base_name}#{ext}"
    end
  end

  defp generate_file_path(name, original_path) do
    # Extract directory from original path
    dir = Path.dirname(original_path)

    # Create new filename from name (already includes extension)
    safe_name =
      name
      |> String.replace(~r/[^a-zA-Z0-9\s\-_.]/, "")
      |> String.replace(~r/\s+/, "_")

    case dir do
      "." -> safe_name
      "/" -> "/#{safe_name}"
      _ -> "#{dir}/#{safe_name}"
    end
  end

  defp get_file_content(file) do
    # Get content through the primary storage resource
    case Ash.load(file, :primary_storage) do
      {:ok, %{primary_storage: storage}} when not is_nil(storage) ->
        Dirup.Storage.retrieve_content(storage)

      {:ok, _} ->
        {:error, "No primary storage found"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_duplicate_file(attrs, content, commit_message, context) do
    # Create the file using the Ash domain
    case Dirup.Workspaces.create_file(
           Map.merge(attrs, %{content: content, initial_commit_message: commit_message}),
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, file} -> {:ok, file}
      {:error, error} -> {:error, error}
    end
  end
end
