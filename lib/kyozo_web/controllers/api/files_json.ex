defmodule KyozoWeb.API.FilesJSON do
  alias Kyozo.Workspaces.File
  alias Kyozo.Workspaces.Workspace
  alias Kyozo.Accounts.Team
  alias Kyozo.Workspaces.Task

  @doc """
  Renders a list of documents.
  """
  def index(%{files: files}) do
    %{data: for(file <- files, do: data(file))}
  end

  @doc """
  Renders a single document.
  """
  def show(%{file: file}) do
    %{data: data(file)}
  end

  @doc """
  Renders file content.
  """
  def content(%{content: content, file: file}) do
    %{
      data: %{
        id: file.id,
        content: content,
        content_type: file.content_type,
        updated_at: file.updated_at
      }
    }
  end

  @doc """
  Renders file versions.
  """
  def versions(%{versions: versions, file: file}) do
    %{
      data: %{
        file_id: file.id,
        versions: versions
      }
    }
  end

  @doc """
  Renders rendered content.
  """
  def rendered_content(%{content: content, format: format, file: file}) do
    %{
      data: %{
        file_id: file.id,
        content: content,
        format: format,
        rendered_at: DateTime.utc_now()
      }
    }
  end

  defp data(%File{} = file) do
    %{
      id: file.id,
      title: file.name,
      file_path: file.file_path,
      content_type: file.content_type,
      description: file.description,
      tags: file.tags || [],
      file_size: file.file_size,
      storage_backend: file.storage_backend,
      storage_metadata: file.storage_metadata || %{},
      version: file.version,
      checksum: file.checksum,
      is_binary: file.is_binary || false,
      render_cache: file.render_cache,
      view_count: file.view_count || 0,
      last_viewed_at: file.last_viewed_at,
      created_at: file.created_at,
      updated_at: file.updated_at,
      deleted_at: file.deleted_at,
      workspace_id: file.workspace_id,
      team_id: file.team_id,
      membership_id: file.team_member_id,
      workspace: render_if_loaded(file.workspace, &workspace_data/1),
      team: render_if_loaded(file.team, &team_data/1)
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

  defp render_if_loaded(%Ash.NotLoaded{}, _fun), do: nil
  defp render_if_loaded(nil, _fun), do: nil
  defp render_if_loaded(data, fun) when is_list(data), do: Enum.map(data, fun)
  defp render_if_loaded(data, fun), do: fun.(data)
end
