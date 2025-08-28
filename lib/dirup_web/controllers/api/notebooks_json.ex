defmodule DirupWeb.API.NotebooksJSON do
  alias Dirup.Workspaces.Notebook
  alias Dirup.Workspaces.Workspace
  alias Dirup.Accounts.Team
  alias Dirup.Workspaces.File
  alias Dirup.Workspaces.Task

  @doc """
  Renders a list of notebooks.
  """
  def index(%{notebooks: notebooks}) do
    %{data: for(notebook <- notebooks, do: data(notebook))}
  end

  @doc """
  Renders a single notebook.
  """
  def show(%{notebook: notebook}) do
    %{data: data(notebook)}
  end

  @doc """
  Renders notebook tasks.
  """
  def tasks(%{tasks: tasks, notebook: notebook}) do
    %{
      data: %{
        notebook_id: notebook.id,
        tasks: for(task <- tasks, do: task_data(task))
      }
    }
  end

  @doc """
  Renders workspace tasks.
  """
  def workspace_tasks(%{tasks: tasks, workspace_id: workspace_id}) do
    %{
      data: %{
        workspace_id: workspace_id,
        tasks: for(task <- tasks, do: task_data(task))
      }
    }
  end

  defp data(%Notebook{} = notebook) do
    %{
      id: notebook.id,
      title: notebook.title,
      content: notebook.content,
      metadata: notebook.metadata || %{},
      status: notebook.status,
      kernel_status: notebook.kernel_status,
      execution_state: notebook.execution_state || %{},
      current_task_index: notebook.current_task_index || 0,
      collaborative_mode: notebook.collaborative_mode || false,
      last_executed_at: notebook.last_executed_at,
      last_accessed_at: notebook.last_accessed_at,
      created_at: notebook.created_at,
      updated_at: notebook.updated_at,
      workspace_id: notebook.workspace_id,
      team_id: notebook.team_id,
      file_id: notebook.file_id,
      workspace: render_if_loaded(notebook.workspace, &workspace_data/1),
      team: render_if_loaded(notebook.team, &team_data/1),
      file: render_if_loaded(notebook.file, &file_data/1),
      tasks: render_if_loaded(notebook.tasks, &task_data/1)
    }
  end

  defp workspace_data(%Workspace{} = workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      description: workspace.description,
      status: workspace.status,
      storage_backend: workspace.storage_backend
    }
  end

  defp team_data(%Team{} = team) do
    %{
      id: team.id,
      name: team.name
    }
  end

  defp file_data(%File{} = file) do
    %{
      id: file.id,
      title: file.name,
      file_path: file.file_path,
      content_type: file.content_type,
      description: file.description,
      tags: file.tags || []
    }
  end

  defp task_data(%Task{} = task) do
    %{
      id: task.id,
      task_type: task.task_type,
      content: task.content,
      metadata: task.metadata || %{},
      status: task.status,
      execution_order: task.execution_order,
      execution_result: task.execution_result,
      execution_time_ms: task.execution_time_ms,
      error_message: task.error_message,
      created_at: task.created_at,
      updated_at: task.updated_at,
      notebook_id: task.notebook_id,
      workspace_id: task.workspace_id
    }
  end

  defp render_if_loaded(%Ash.NotLoaded{}, _fun), do: nil
  defp render_if_loaded(nil, _fun), do: nil
  defp render_if_loaded(data, fun) when is_list(data), do: Enum.map(data, fun)
  defp render_if_loaded(data, fun), do: fun.(data)
end
