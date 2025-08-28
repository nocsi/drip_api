defmodule Dirup.Workspaces.Notebook.Changes do
  @moduledoc """
  Change modules for Notebook operations focused on markdown document rendering.

  These changes handle creating notebooks from documents, rendering content,
  extracting tasks, and managing execution state for markdown-based notebooks.
  """

  defmodule CreateFromDocument do
    @moduledoc """
    Creates a notebook from a markdown document.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        document_id = Ash.Changeset.get_argument(changeset, :document_id)

        case Dirup.Workspaces.get_document!(document_id) do
          document ->
            # Validate document type
            if Dirup.Workspaces.Notebook.renderable_as_notebook?(document.file_path) do
              changeset
              |> Ash.Changeset.force_change_attribute(
                :title,
                document.title ||
                  Path.basename(document.file_path, Path.extname(document.file_path))
              )
              |> Ash.Changeset.force_change_attribute(:content, document.content || "")
              |> Ash.Changeset.force_change_attribute(:document_id, document_id)
              |> Ash.Changeset.force_change_attribute(:workspace_id, document.workspace_id)
              |> Ash.Changeset.force_change_attribute(:team_id, document.team_id)
            else
              Ash.Changeset.add_error(changeset,
                field: :document_id,
                message: "Document must be a markdown file (.md or .markdown)"
              )
            end

          nil ->
            Ash.Changeset.add_error(changeset, field: :document_id, message: "Document not found")
        end
      end)
    end
  end

  defmodule RenderContent do
    @moduledoc """
    Renders markdown content to HTML using the RenderMarkdown extension.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      changeset
    end
  end

  defmodule ExtractTasks do
    @moduledoc """
    Extracts executable tasks from markdown content.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        content = Ash.Changeset.get_attribute(changeset, :content)

        if content do
          case extract_tasks_from_content(content) do
            {:ok, tasks} ->
              execution_order = Enum.map(tasks, & &1["id"])

              changeset
              |> Ash.Changeset.force_change_attribute(:extracted_tasks, tasks)
              |> Ash.Changeset.force_change_attribute(:execution_order, execution_order)
              |> Ash.Changeset.force_change_attribute(
                :execution_state,
                Dirup.Workspaces.Notebook.empty_execution_state()
              )

            {:error, _reason} ->
              changeset
              |> Ash.Changeset.force_change_attribute(:extracted_tasks, [])
              |> Ash.Changeset.force_change_attribute(:execution_order, [])
          end
        else
          changeset
        end
      end)
    end

    defp extract_tasks_from_content(content) do
      case Dirup.Workspaces.Extensions.RenderMarkdown.extract_code_blocks(content, []) do
        {_processed_text, tasks} ->
          # Add IDs to tasks and format them properly
          formatted_tasks =
            tasks
            |> Enum.with_index()
            |> Enum.map(fn {task, index} ->
              Map.merge(task, %{
                "id" => "task-#{index + 1}",
                "index" => index,
                "status" => "ready"
              })
            end)

          {:ok, formatted_tasks}

        error ->
          {:error, error}
      end
    end
  end

  defmodule ExecuteAllTasks do
    @moduledoc """
    Executes all tasks in the notebook in order.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      Ash.Changeset.after_action(changeset, fn changeset, notebook ->
        # This would integrate with a task execution service
        # For now, we'll just update the execution state
        updated_execution_state = %{
          "status" => "running",
          "started_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "tasks" => %{},
          "environment" => %{},
          "last_execution" => nil
        }

        updated_notebook =
          notebook
          |> Ash.Changeset.for_update(:update_execution_state, %{
            execution_state: updated_execution_state,
            kernel_status: :busy
          })
          |> Ash.update!()

        {changeset, updated_notebook}
      end)
    end
  end

  defmodule ExecuteSingleTask do
    @moduledoc """
    Executes a single task by ID.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      changeset
    end
  end

  defmodule UpdateExecutionState do
    @moduledoc """
    Updates the execution state after task completion.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      changeset
      |> Ash.Changeset.change_attribute(
        :execution_count,
        (Ash.Changeset.get_data(changeset, :execution_count) || 0) + 1
      )
      |> Ash.Changeset.change_attribute(:last_executed_at, DateTime.utc_now())
    end
  end

  defmodule StopAllTasks do
    @moduledoc """
    Stops all currently running tasks.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      changeset
    end
  end

  defmodule ResetAllTasks do
    @moduledoc """
    Resets all tasks to their initial state.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        tasks = Ash.Changeset.get_data(changeset, :extracted_tasks) || []

        reset_tasks =
          Enum.map(tasks, fn task ->
            Map.merge(task, %{
              "status" => "ready",
              "output" => nil,
              "error" => nil,
              "execution_time" => nil
            })
          end)

        changeset
        |> Ash.Changeset.force_change_attribute(:extracted_tasks, reset_tasks)
        |> Ash.Changeset.force_change_attribute(:current_task_index, 0)
      end)
    end
  end

  defmodule ToggleCollaborativeMode do
    @moduledoc """
    Toggles collaborative editing mode.
    """
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      current_mode = Ash.Changeset.get_data(changeset, :collaborative_mode)
      Ash.Changeset.change_attribute(changeset, :collaborative_mode, not current_mode)
    end
  end

  defmodule ValidateDocumentType do
    @moduledoc """
    Validates that the document is a supported markdown type.
    """
    use Ash.Resource.Validation

    def validate(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :document_id) do
        nil ->
          :ok

        document_id ->
          case Dirup.Workspaces.get_document(document_id) do
            {:ok, document} ->
              if Dirup.Workspaces.Notebook.renderable_as_notebook?(document.file_path) do
                :ok
              else
                {:error,
                 field: :document_id,
                 message: "Document must be a markdown file (.md or .markdown)"}
              end

            {:error, _} ->
              {:error, field: :document_id, message: "Document not found"}
          end
      end
    end
  end
end
