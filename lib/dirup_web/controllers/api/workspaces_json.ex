defmodule DirupWeb.API.WorkspacesJSON do
  alias Dirup.Workspaces.Workspace
  alias Dirup.Workspaces.File
  alias Dirup.Workspaces.Notebook
  alias Dirup.Accounts.Team

  @doc """
  Renders a list of workspaces.
  """
  def index(%{workspaces: workspaces}) do
    %{data: for(workspace <- workspaces, do: data(workspace))}
  end

  @doc """
  Renders a single workspace.
  """
  def show(%{workspace: workspace}) do
    %{data: data(workspace)}
  end

  @doc """
  Renders workspace files.
  """
  def files(%{files: files}) do
    %{data: for(file <- files, do: file_data(file))}
  end

  @doc """
  Renders workspace notebooks.
  """
  def notebooks(%{notebooks: notebooks}) do
    %{data: for(notebook <- notebooks, do: notebook_data(notebook))}
  end

  @doc """
  Renders workspace statistics.
  """
  def statistics(%{statistics: stats}) do
    %{data: stats}
  end

  @doc """
  Renders workspace storage information.
  """
  def storage_info(%{storage_info: info}) do
    %{data: info}
  end

  @doc """
  Renders workspace services.
  """
  def services(%{services: services}) do
    %{data: for(service <- services, do: service_data(service))}
  end

  @doc """
  Renders a single service.
  """
  def service(%{service: service}) do
    %{data: service_data(service)}
  end

  @doc """
  Renders topology analysis results.
  """
  def topology_analysis(%{analysis: analysis}) do
    %{data: analysis_data(analysis)}
  end

  defp data(%Workspace{} = workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      description: workspace.description,
      status: workspace.status,
      storage_backend: workspace.storage_backend,
      storage_path: workspace.storage_path,
      storage_metadata: workspace.storage_metadata,
      settings: workspace.settings || %{},
      tags: workspace.tags || [],
      created_at: workspace.created_at,
      updated_at: workspace.updated_at,
      deleted_at: workspace.deleted_at,
      team_id: workspace.team_id,
      created_by_id: workspace.created_by_id,
      file_count: workspace.file_count || 0,
      notebook_count: workspace.notebook_count || 0,
      last_activity: workspace.last_activity,
      git_repository_url: workspace.git_repository_url,
      team: render_if_loaded(workspace.team, &team_data/1),
      files: render_if_loaded(workspace.files, &file_data/1),
      notebooks: render_if_loaded(workspace.notebooks, &notebook_data/1)
    }
  end

  defp file_data(%File{} = file) do
    %{
      id: file.id,
      title: file.name,
      file_path: file.file_path,
      content_type: file.content_type,
      description: file.description,
      tags: file.tags || [],
      file_size: file.file_size,
      storage_backend: file.storage_backend,
      storage_metadata: file.storage_metadata,
      version: file.version,
      checksum: file.checksum,
      is_binary: file.is_binary,
      view_count: file.view_count || 0,
      last_viewed_at: file.last_viewed_at,
      created_at: file.created_at,
      updated_at: file.updated_at,
      deleted_at: file.deleted_at,
      workspace_id: file.workspace_id,
      team_id: file.team_id
    }
  end

  defp notebook_data(%Notebook{} = notebook) do
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
      file_id: notebook.file_id
    }
  end

  defp team_data(%Team{} = team) do
    %{
      id: team.id,
      name: team.name,
      created_at: team.created_at,
      updated_at: team.updated_at
    }
  end

  defp service_data(service) do
    %{
      id: service.id,
      name: service.name,
      folder_path: service.folder_path,
      service_type: service.service_type,
      detection_confidence: service.detection_confidence,
      status: service.status,
      container_id: service.container_id,
      image_id: service.image_id,
      deployment_config: service.deployment_config || %{},
      port_mappings: service.port_mappings || %{},
      environment_variables: service.environment_variables || %{},
      resource_limits: service.resource_limits,
      created_at: service.created_at,
      updated_at: service.updated_at,
      deployed_at: service.deployed_at,
      workspace_id: service.workspace_id,
      team_id: service.team_id
    }
  end

  defp analysis_data(analysis) do
    %{
      id: analysis.id,
      folder_path: analysis.folder_path,
      detection_timestamp: analysis.detection_timestamp,
      detected_patterns: analysis.detected_patterns || %{},
      service_graph: analysis.service_graph || %{},
      recommended_services: analysis.recommended_services || [],
      confidence_scores: analysis.confidence_scores || %{},
      file_indicators: analysis.file_indicators || [],
      deployment_strategy: analysis.deployment_strategy,
      total_services_detected: analysis.total_services_detected || 0,
      analysis_metadata: analysis.analysis_metadata || %{},
      workspace_id: analysis.workspace_id,
      team_id: analysis.team_id,
      created_at: analysis.created_at,
      updated_at: analysis.updated_at
    }
  end

  defp render_if_loaded(%Ash.NotLoaded{}, _fun), do: nil
  defp render_if_loaded(nil, _fun), do: nil
  defp render_if_loaded(data, fun) when is_list(data), do: Enum.map(data, fun)
  defp render_if_loaded(data, fun), do: fun.(data)
end
