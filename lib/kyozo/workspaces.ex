defmodule Kyozo.Workspaces do
  use Ash.Domain, otp_app: :kyozo, extensions: [AshPhoenix.Domain]

  resources do
    resource Kyozo.Workspaces.Workspace do
      define :create_workspace
      define :list_workspaces
      define :list_active_workspaces
      define :list_archived_workspaces
      define :search_workspaces
      define :get_workspace, action: :read, get_by: :id
      define :update_workspace, action: :update_workspace
      define :archive_workspace
      define :restore_workspace
      define :change_storage_backend
      define :get_storage_info
      define :get_statistics
      define :cleanup_storage
      define :duplicate_workspace
      define :delete_workspace, action: :destroy
    end

    resource Kyozo.Workspaces.Role

    # resource Kyozo.Workspaces.Document do
    #   define :list_documents
    #   define :create_document
    #   define :get_document, action: :read, get_by: :id
    #   define :update_document, action: :update
    #   define :delete_document, action: :destroy
    #   define :duplicate_document
    # end

    resource Kyozo.Workspaces.File do
      define :list_files
      define :create_file
      define :get_file, action: :read, get_by: :id
      define :update_file, action: :update
      define :delete_file, action: :destroy
      define :duplicate_file
    end

    # Storage intermediary resources (internal implementation)
    resource Kyozo.Workspaces.FileStorage
    resource Kyozo.Workspaces.ImageStorage
    resource Kyozo.Workspaces.FileMedia
    resource Kyozo.Workspaces.FileNotebook

    resource Kyozo.Workspaces.Notebook do
      define :list_notebooks
      define :create_from_document
      define :get_notebook, action: :read, get_by: :id
      define :update_content
      define :execute_notebook
      define :destroy_notebook, action: :destroy
      define :duplicate_notebook
    end

    resource Kyozo.Workspaces.Blob do
      define :create_blob
      define :find_or_create
      define :get_blob, action: :read, get_by: :id
      define :get_blob_content, action: :get_content
      define :blob_exists?, action: :exists?, args: [:hash]
    end

    resource Kyozo.Workspaces.Task do
      define :list_tasks
      define :get_task, action: :read, get_by: :id
      define :list_notebook_tasks, args: [:notebook_id]
      define :list_workspace_tasks, args: [:workspace_id]
    end

    resource Kyozo.Workspaces.LoadEvent do
      define :list_events
      define :list_workspace_events, args: [:workspace_id]
    end

    resource Kyozo.Workspaces.TopologyDetection do
      define :analyze_workspace_topology,
        action: :analyze_workspace,
        args: [:workspace_id, :folder_path, :max_depth, :auto_create_services, :detection_mode]

      define :list_workspace_topology_detections, action: :read
      define :list_workspace_detections, action: :list_by_workspace, args: [:workspace_id]
      define :get_workspace_topology_detection, action: :read, get_by: :id
      define :complete_analysis, action: :complete_analysis
      define :retry_analysis, action: :retry_analysis
      define :delete_workspace_topology_detection, action: :destroy
    end

    resource Kyozo.Workspaces.ServiceInstance do
      define :list_service_instances
      define :create_service_instance
      define :get_service_instance, action: :read, get_by: :id
      define :update_service_instance, action: :update
      define :delete_service_instance, action: :destroy
      define :deploy_service_instance, action: :deploy
      define :start_service_instance, action: :start
      define :stop_service_instance, action: :stop
    end

    resource Kyozo.Workspaces.DeploymentEvent do
      define :list_deployment_events
      define :get_deployment_event, action: :read, get_by: :id
      define :create_deployment_event
      define :create_deployment_started
      define :create_deployment_completed
      define :create_deployment_failed
      define :create_service_scaled
    end

    resource Kyozo.Workspaces.ServiceDependency do
      define :list_service_dependencies
      define :get_service_dependency, action: :read, get_by: :id
      define :create_service_dependency
      define :update_service_dependency, action: :update
      define :delete_service_dependency, action: :destroy
    end

    resource Kyozo.Workspaces.DocumentBlobRef
  end

  @doc """
  Subscribe to workspace events for real-time updates.
  """
  def subscribe(topic) when is_binary(topic) do
    Phoenix.PubSub.subscribe(Kyozo.PubSub, "workspace:#{topic}")
  end

  def subscribe(team_id) do
    Phoenix.PubSub.subscribe(Kyozo.PubSub, "workspace:#{team_id}")
  end
end
