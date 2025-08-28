defmodule Dirup.Workspaces.Events do
  @moduledoc """
  Event definitions for Workspace domain.

  This module defines all events that can occur within workspaces,
  including document operations, notebook activities, storage events,
  and collaboration actions.
  """

  # Document Events
  defmodule DocumentCreated do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :title,
      :content_type,
      :author_id,
      :file_path,
      :storage_backend,
      :created_at
    ]
    defstruct @enforce_keys
  end

  defmodule DocumentUpdated do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :title,
      :previous_title,
      :content_size,
      :author_id,
      :file_path,
      :storage_backend,
      :version,
      :updated_at
    ]
    defstruct @enforce_keys
  end

  defmodule DocumentDeleted do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :title,
      :author_id,
      :file_path,
      :storage_backend,
      :deleted_at
    ]
    defstruct @enforce_keys
  end

  defmodule DocumentRenamed do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :old_title,
      :new_title,
      :old_file_path,
      :new_file_path,
      :author_id,
      :renamed_at
    ]
    defstruct @enforce_keys
  end

  defmodule DocumentViewed do
    @enforce_keys [:document_id, :team_id, :workspace_id, :viewer_id, :file_path, :viewed_at]
    defstruct @enforce_keys
  end

  # Notebook Events
  defmodule NotebookCreated do
    @enforce_keys [
      :notebook_id,
      :team_id,
      :workspace_id,
      :title,
      :notebook_type,
      :kernel_type,
      :author_id,
      :file_path,
      :cell_count,
      :created_at
    ]
    defstruct @enforce_keys
  end

  defmodule NotebookUpdated do
    @enforce_keys [
      :notebook_id,
      :team_id,
      :workspace_id,
      :title,
      :author_id,
      :file_path,
      :cell_count,
      :cells_added,
      :cells_removed,
      :cells_modified,
      :version,
      :updated_at
    ]
    defstruct @enforce_keys
  end

  defmodule NotebookExecuted do
    @enforce_keys [
      :notebook_id,
      :team_id,
      :workspace_id,
      :executor_id,
      :kernel_type,
      :execution_duration_ms,
      :cells_executed,
      :successful_cells,
      :failed_cells,
      :executed_at
    ]
    defstruct @enforce_keys
  end

  defmodule NotebookCellAdded do
    @enforce_keys [
      :notebook_id,
      :team_id,
      :workspace_id,
      :cell_id,
      :cell_type,
      :cell_index,
      :author_id,
      :added_at
    ]
    defstruct @enforce_keys
  end

  defmodule NotebookCellExecuted do
    @enforce_keys [
      :notebook_id,
      :team_id,
      :workspace_id,
      :cell_id,
      :cell_type,
      :cell_index,
      :executor_id,
      :execution_duration_ms,
      :execution_status,
      :output_size,
      :executed_at
    ]
    defstruct @enforce_keys
  end

  defmodule NotebookCellDeleted do
    @enforce_keys [
      :notebook_id,
      :team_id,
      :workspace_id,
      :cell_id,
      :cell_type,
      :cell_index,
      :author_id,
      :deleted_at
    ]
    defstruct @enforce_keys
  end

  # Storage Events
  defmodule FileStored do
    @enforce_keys [
      :file_path,
      :team_id,
      :workspace_id,
      :storage_backend,
      :file_size,
      :content_type,
      :author_id,
      :version,
      :stored_at
    ]
    defstruct @enforce_keys
  end

  defmodule FileRetrieved do
    @enforce_keys [
      :file_path,
      :team_id,
      :workspace_id,
      :storage_backend,
      :retriever_id,
      :file_size,
      :version,
      :retrieved_at
    ]
    defstruct @enforce_keys
  end

  defmodule FileBackupCreated do
    @enforce_keys [
      :file_path,
      :team_id,
      :workspace_id,
      :primary_backend,
      :backup_backend,
      :file_size,
      :version,
      :backup_created_at
    ]
    defstruct @enforce_keys
  end

  defmodule FileSynced do
    @enforce_keys [
      :file_path,
      :team_id,
      :workspace_id,
      :from_backend,
      :to_backend,
      :file_size,
      :version,
      :synced_at
    ]
    defstruct @enforce_keys
  end

  defmodule StorageError do
    @enforce_keys [
      :file_path,
      :team_id,
      :workspace_id,
      :storage_backend,
      :operation,
      :error_type,
      :error_message,
      :user_id,
      :occurred_at
    ]
    defstruct @enforce_keys
  end

  # Version Control Events
  defmodule VersionCreated do
    @enforce_keys [
      :file_path,
      :team_id,
      :workspace_id,
      :version,
      :previous_version,
      :commit_message,
      :author_id,
      :file_size,
      :storage_backend,
      :created_at
    ]
    defstruct @enforce_keys
  end

  defmodule BranchCreated do
    @enforce_keys [:team_id, :workspace_id, :branch_name, :source_branch, :author_id, :created_at]
    defstruct @enforce_keys
  end

  defmodule BranchMerged do
    @enforce_keys [
      :team_id,
      :workspace_id,
      :source_branch,
      :target_branch,
      :merge_commit,
      :author_id,
      :files_changed,
      :merged_at
    ]
    defstruct @enforce_keys
  end

  # Collaboration Events
  defmodule DocumentShared do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :shared_by,
      :shared_with,
      :permission_level,
      :shared_at
    ]
    defstruct @enforce_keys
  end

  defmodule CollaborativeEdit do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :editor_id,
      :edit_type,
      :start_position,
      :end_position,
      :content_length,
      :edited_at
    ]
    defstruct @enforce_keys
  end

  defmodule DocumentLocked do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :locked_by,
      :lock_type,
      :expires_at,
      :locked_at
    ]
    defstruct @enforce_keys
  end

  defmodule DocumentUnlocked do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :unlocked_by,
      :was_locked_by,
      :lock_duration_ms,
      :unlocked_at
    ]
    defstruct @enforce_keys
  end

  # Rendering Events
  defmodule DocumentRendered do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :source_format,
      :target_format,
      :renderer_type,
      :render_duration_ms,
      :output_size,
      :rendered_by,
      :rendered_at
    ]
    defstruct @enforce_keys
  end

  defmodule RenderingFailed do
    @enforce_keys [
      :document_id,
      :team_id,
      :workspace_id,
      :source_format,
      :target_format,
      :renderer_type,
      :error_type,
      :error_message,
      :attempted_by,
      :failed_at
    ]
    defstruct @enforce_keys
  end

  # Workspace Events
  defmodule WorkspaceCreated do
    @enforce_keys [:workspace_id, :team_id, :name, :storage_backend, :created_by, :created_at]
    defstruct @enforce_keys
  end

  defmodule WorkspaceUpdated do
    @enforce_keys [:workspace_id, :team_id, :name, :updated_at]
    defstruct @enforce_keys
  end

  defmodule WorkspaceDeleted do
    @enforce_keys [:workspace_id, :team_id, :name, :deleted_at]
    defstruct @enforce_keys
  end

  defmodule WorkspaceArchived do
    @enforce_keys [:workspace_id, :team_id, :name, :archived_at]
    defstruct @enforce_keys
  end

  defmodule WorkspaceRestored do
    @enforce_keys [:workspace_id, :team_id, :name, :restored_at]
    defstruct @enforce_keys
  end

  defmodule WorkspaceActivitySummary do
    @enforce_keys [
      :team_id,
      :workspace_id,
      :period_start,
      :period_end,
      :documents_created,
      :documents_updated,
      :documents_deleted,
      :notebooks_executed,
      :storage_operations,
      :active_users,
      :total_file_size
    ]
    defstruct @enforce_keys
  end

  @doc """
  Emits a document event with common workspace context.
  """
  def emit_document_event(event_type, document, user, additional_data \\ %{}) do
    base_data = %{
      document_id: document.id,
      team_id: document.team_id,
      workspace_id: get_workspace_id(document),
      title: document.title,
      author_id: user.id,
      file_path: build_file_path(document)
    }

    event_data = Map.merge(base_data, additional_data)
    # For now, just log the event. Replace with actual event system later.
    require Logger
    Logger.info("Event #{event_type}: #{inspect(event_data)}")
  end

  @doc """
  Emits a storage event with context.
  """
  def emit_storage_event(event_type, file_path, storage_backend, user, options \\ []) do
    event_data =
      %{
        file_path: file_path,
        team_id: Keyword.fetch!(options, :team_id),
        workspace_id: Keyword.fetch!(options, :workspace_id),
        storage_backend: storage_backend,
        user_id: user.id
      }
      |> Map.merge(Enum.into(options, %{}))
      |> Map.put(event_timestamp_key(event_type), DateTime.utc_now())

    # For now, just log the event. Replace with actual event system later.
    require Logger
    Logger.info("Event #{event_type}: #{inspect(event_data)}")
  end

  @doc """
  Emits a notebook event with context.
  """
  def emit_notebook_event(event_type, notebook, user, additional_data \\ %{}) do
    base_data = %{
      notebook_id: notebook.id,
      team_id: notebook.team_id,
      workspace_id: get_workspace_id(notebook),
      title: notebook.title,
      author_id: user.id,
      file_path: build_file_path(notebook)
    }

    event_data = Map.merge(base_data, additional_data)
    # For now, just log the event. Replace with actual event system later.
    require Logger
    Logger.info("Event #{event_type}: #{inspect(event_data)}")
  end

  # Private helper functions

  defp get_workspace_id(%{workspace_id: workspace_id}), do: workspace_id
  # Fallback for team-scoped resources
  defp get_workspace_id(%{team_id: team_id}), do: team_id
  defp get_workspace_id(_), do: "unknown"

  defp build_file_path(%{title: title}), do: title
  defp build_file_path(%{file_path: file_path}), do: file_path
  defp build_file_path(_), do: "unknown"

  defp event_timestamp_key(DocumentCreated), do: :created_at
  defp event_timestamp_key(DocumentUpdated), do: :updated_at
  defp event_timestamp_key(DocumentDeleted), do: :deleted_at
  defp event_timestamp_key(DocumentViewed), do: :viewed_at
  defp event_timestamp_key(NotebookCreated), do: :created_at
  defp event_timestamp_key(NotebookExecuted), do: :executed_at
  defp event_timestamp_key(FileStored), do: :stored_at
  defp event_timestamp_key(FileRetrieved), do: :retrieved_at
  defp event_timestamp_key(_), do: :occurred_at
end
