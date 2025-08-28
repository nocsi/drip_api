defmodule Dirup.Workspaces.Workspace.Changes.DuplicateWorkspace do
  @moduledoc """
  Change module for duplicating workspaces within or across teams.
  Includes options to copy documents and notebooks.
  """

  use Ash.Resource.Change

  alias Dirup.Workspaces.Workspace

  @impl true
  def change(changeset, _opts, context) do
    source_workspace = changeset.data

    # Extract arguments
    new_name = Ash.Changeset.get_argument(changeset, :new_name)
    copy_to_team_id = Ash.Changeset.get_argument(changeset, :copy_to_team_id)
    include_documents = Ash.Changeset.get_argument(changeset, :include_documents)
    include_notebooks = Ash.Changeset.get_argument(changeset, :include_notebooks)

    # Determine target team
    target_team_id = copy_to_team_id || source_workspace.team_id

    # Generate new name if not provided
    duplicate_name = new_name || generate_duplicate_name(source_workspace.name)

    # Create duplicate workspace attributes
    duplicate_attrs = %{
      name: duplicate_name,
      description: source_workspace.description && "Copy of #{source_workspace.description}",
      storage_backend: source_workspace.storage_backend,
      settings: source_workspace.settings || %{},
      tags: source_workspace.tags || [],
      team_id: target_team_id,
      status: :active
    }

    # Create the duplicate workspace
    case create_duplicate_workspace(duplicate_attrs, context) do
      {:ok, duplicate_workspace} ->
        # Copy documents and notebooks if requested
        copy_tasks = []

        if include_documents do
          copy_tasks = copy_tasks ++ [{:documents, source_workspace.id, duplicate_workspace.id}]
        end

        if include_notebooks do
          copy_tasks = copy_tasks ++ [{:notebooks, source_workspace.id, duplicate_workspace.id}]
        end

        # Execute copy tasks
        case execute_copy_tasks(copy_tasks, context) do
          :ok ->
            # Return the duplicate workspace as the result
            Ash.Changeset.set_result(changeset, duplicate_workspace)

          {:error, error} ->
            # If copying fails, we should clean up the created workspace
            clean_up_workspace(duplicate_workspace, context)

            Ash.Changeset.add_error(
              changeset,
              "Failed to copy workspace content: #{inspect(error)}"
            )
        end

      {:error, error} ->
        Ash.Changeset.add_error(
          changeset,
          "Failed to create duplicate workspace: #{inspect(error)}"
        )
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # This change cannot be performed atomically as it involves creating multiple resources
    :not_atomic
  end

  defp generate_duplicate_name(original_name) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    cond do
      String.contains?(original_name, "Copy of") ->
        "#{original_name} (#{timestamp})"

      true ->
        "Copy of #{original_name}"
    end
  end

  defp create_duplicate_workspace(attrs, context) do
    # Create the workspace using the Ash domain
    case Dirup.Workspaces.create_workspace(
           attrs,
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, workspace} -> {:ok, workspace}
      {:error, error} -> {:error, error}
    end
  end

  defp execute_copy_tasks([], _context), do: :ok

  defp execute_copy_tasks([{type, source_workspace_id, target_workspace_id} | rest], context) do
    case copy_workspace_content(type, source_workspace_id, target_workspace_id, context) do
      :ok -> execute_copy_tasks(rest, context)
      {:error, error} -> {:error, error}
    end
  end

  defp copy_workspace_content(:documents, source_workspace_id, target_workspace_id, context) do
    # Get all documents from source workspace
    case Dirup.Workspaces.list_documents(
           query: [filter: [workspace_id: source_workspace_id]],
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, documents} ->
        copy_documents(documents, target_workspace_id, context)

      {:error, error} ->
        {:error, "Failed to list source documents: #{inspect(error)}"}
    end
  end

  defp copy_workspace_content(:notebooks, source_workspace_id, target_workspace_id, context) do
    # Get all notebooks from source workspace
    case Dirup.Workspaces.list_notebooks(
           query: [filter: [workspace_id: source_workspace_id]],
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, notebooks} ->
        copy_notebooks(notebooks, target_workspace_id, context)

      {:error, error} ->
        {:error, "Failed to list source notebooks: #{inspect(error)}"}
    end
  end

  defp copy_documents([], _target_workspace_id, _context), do: :ok

  defp copy_documents([document | rest], target_workspace_id, context) do
    case Dirup.Workspaces.duplicate_document(
           document,
           new_title: nil,
           copy_to_workspace_id: target_workspace_id,
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, _duplicate_document} ->
        copy_documents(rest, target_workspace_id, context)

      {:error, error} ->
        {:error, "Failed to duplicate document #{document.title}: #{inspect(error)}"}
    end
  end

  defp copy_notebooks([], _target_workspace_id, _context), do: :ok

  defp copy_notebooks([notebook | rest], target_workspace_id, context) do
    case Dirup.Workspaces.duplicate_notebook(
           notebook,
           new_title: nil,
           copy_to_workspace_id: target_workspace_id,
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, _duplicate_notebook} ->
        copy_notebooks(rest, target_workspace_id, context)

      {:error, error} ->
        {:error, "Failed to duplicate notebook #{notebook.title}: #{inspect(error)}"}
    end
  end

  defp clean_up_workspace(workspace, context) do
    # Attempt to delete the workspace if copying failed
    case Dirup.Workspaces.delete_workspace(
           workspace.id,
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, _} -> :ok
      # We tried our best to clean up
      {:error, _} -> :error
    end
  end
end
