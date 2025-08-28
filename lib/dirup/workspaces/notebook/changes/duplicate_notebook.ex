defmodule Dirup.Workspaces.Notebook.Changes.DuplicateNotebook do
  @moduledoc """
  Change module for duplicating notebooks within or across workspaces.
  """

  use Ash.Resource.Change

  alias Dirup.Workspaces.Notebook

  @impl true
  def change(changeset, _opts, context) do
    source_notebook = changeset.data

    # Extract arguments
    new_title = Ash.Changeset.get_argument(changeset, :new_title)
    copy_to_workspace_id = Ash.Changeset.get_argument(changeset, :copy_to_workspace_id)

    # Determine target workspace
    target_workspace_id = copy_to_workspace_id || source_notebook.workspace_id

    # Generate new title if not provided
    duplicate_title = new_title || generate_duplicate_title(source_notebook.title)

    # Create duplicate notebook attributes
    duplicate_attrs = %{
      title: duplicate_title,
      content: source_notebook.content,
      metadata: source_notebook.metadata || %{},
      workspace_id: target_workspace_id,
      team_id: source_notebook.team_id,
      status: :draft,
      kernel_status: :idle,
      execution_state: %{},
      current_task_index: 0,
      collaborative_mode: source_notebook.collaborative_mode || false
    }

    # Create the duplicate notebook
    case create_duplicate_notebook(duplicate_attrs, context) do
      {:ok, duplicate_notebook} ->
        # Return the duplicate notebook as the result
        Ash.Changeset.set_result(changeset, duplicate_notebook)

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # This change cannot be performed atomically as it involves creating a new resource
    :not_atomic
  end

  defp generate_duplicate_title(original_title) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    cond do
      String.contains?(original_title, "Copy of") ->
        "#{original_title} (#{timestamp})"

      true ->
        "Copy of #{original_title}"
    end
  end

  defp create_duplicate_notebook(attrs, context) do
    # Create the notebook using the Ash domain
    case Dirup.Workspaces.create_from_document(
           attrs,
           actor: context.actor,
           tenant: context.tenant
         ) do
      {:ok, notebook} -> {:ok, notebook}
      {:error, error} -> {:error, error}
    end
  end
end
