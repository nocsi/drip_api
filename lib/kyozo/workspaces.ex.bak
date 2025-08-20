defmodule Kyozo.Workspaces do
  use Ash.Domain, otp_app: :kyozo, extensions: [AshJsonApi.Domain, AshPhoenix.Domain]

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
