defmodule Dirup.Workspaces.File.Relationships.PrimaryNotebook do
  @moduledoc """
  Manual relationship to get the primary Notebook resource for a file.

  This relationship finds the Notebook resource that has a primary FileNotebook
  relationship with the file, providing direct access to the specialized
  notebook content without going through the intermediary.
  """

  use Ash.Resource.ManualRelationship
  require Ash.Query

  alias Dirup.Workspaces.{FileNotebook, Notebook}

  @impl true
  def load(files, _opts, _context) do
    file_ids = Enum.map(files, & &1.id)

    # Get all file notebook relationships for these files
    all_file_notebooks =
      FileNotebook
      |> Ash.Query.filter(file_id in ^file_ids and is_primary == true)
      |> Dirup.Workspaces.read!()

    # Get the notebook IDs from the file_notebook relationships
    notebook_ids =
      all_file_notebooks
      |> Enum.map(& &1.notebook_id)
      |> Enum.reject(&is_nil/1)

    # Load the Notebook resources
    notebook_resources =
      if length(notebook_ids) > 0 do
        Notebook
        |> Ash.Query.filter(id in ^notebook_ids)
        |> Dirup.Workspaces.read!()
      else
        []
      end

    # Create notebook lookup map
    notebook_lookup = Enum.into(notebook_resources, %{}, fn n -> {n.id, n} end)

    # Group by file_id and extract the notebook resource
    notebooks_by_file =
      all_file_notebooks
      |> Enum.group_by(& &1.file_id)
      |> Enum.map(fn {file_id, file_notebook_list} ->
        # Should only be one primary file_notebook per file
        primary_file_notebook = List.first(file_notebook_list)

        notebook =
          primary_file_notebook && primary_file_notebook.notebook_id &&
            Map.get(notebook_lookup, primary_file_notebook.notebook_id)

        {file_id, notebook}
      end)
      |> Enum.into(%{})

    {:ok, notebooks_by_file}
  end
end
