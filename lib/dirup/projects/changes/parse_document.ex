defmodule Dirup.Projects.Changes.ParseDocument do
  use Ash.Resource.Change

  alias Dirup.Projects.Services.ProjectLoader

  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      # Set status to parsing
      Ash.Changeset.change_attribute(changeset, :status, :parsing)
    end)
    |> Ash.Changeset.after_action(fn changeset, document ->
      case parse_document_content(document) do
        {:ok, updated_document} ->
          {:ok, updated_document}

        {:error, error} ->
          # Mark document as error and continue
          document
          |> Ash.Changeset.for_update(:mark_error, %{error_message: format_error(error)})
          |> Dirup.Projects.update!()
          |> then(&{:ok, &1})
      end
    end)
  end

  defp parse_document_content(document) do
    try do
      content = document.content || ""

      if String.trim(content) == "" do
        # Empty document, mark as parsed with no tasks
        document
        |> Ash.Changeset.for_update(:mark_parsed, %{
          parsed_content: %{type: "empty", blocks: []},
          task_count: 0,
          metadata: %{empty: true}
        })
        |> Dirup.Projects.update()
      else
        # Parse markdown content
        parsed_content = ProjectLoader.parse_markdown_content(content)

        # Extract tasks from the parsed content
        tasks =
          ProjectLoader.extract_tasks_from_markdown(
            content,
            document.project.identity_mode || :unspecified
          )

        # Create task records
        created_tasks = create_tasks_for_document(document, tasks)

        # Calculate document statistics
        word_count = content |> String.split(~r/\s+/) |> length()
        line_count = content |> String.split("\n") |> length()

        # Prepare metadata
        metadata = %{
          word_count: word_count,
          line_count: line_count,
          tasks_found: length(created_tasks),
          languages:
            Enum.map(created_tasks, & &1.language) |> Enum.uniq() |> Enum.reject(&is_nil/1),
          has_code_blocks: length(created_tasks) > 0,
          parsed_at: DateTime.utc_now()
        }

        # Update document with parsed information
        document
        |> Ash.Changeset.for_update(:mark_parsed, %{
          parsed_content: parsed_content,
          task_count: length(created_tasks),
          metadata: metadata,
          line_count: line_count
        })
        |> Dirup.Projects.update()
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp create_tasks_for_document(document, tasks) do
    tasks
    |> Enum.with_index()
    |> Enum.map(fn {task_data, index} ->
      task_attrs =
        Map.merge(task_data, %{
          order_index: index,
          project_id: document.project_id,
          document_id: document.id
        })

      case Dirup.Projects.Task
           |> Ash.Changeset.for_create(:create, task_attrs, actor: document.project_id)
           |> Dirup.Projects.create() do
        {:ok, task} -> task
        {:error, _error} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error) when is_exception(error), do: Exception.message(error)
  defp format_error(error), do: inspect(error)
end
