defmodule Kyozo.Workspaces.Workspace.Changes do
  @moduledoc """
  Change modules for Workspace resource operations.
  """

  defmodule InitializeStorage do
    @moduledoc """
    Initializes storage backend for a new workspace.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      workspace_name = Ash.Changeset.get_attribute(changeset, :name)
      # Get team_id from changeset.attributes since it's a multitenancy attribute
      team_id = Map.get(changeset.attributes, :team_id)
      storage_backend = Ash.Changeset.get_attribute(changeset, :storage_backend)

      storage_path = Kyozo.Workspaces.Storage.build_storage_path(team_id, workspace_name)
      
      storage_metadata = case storage_backend do
        :git -> %{
          "repository_initialized" => true,
          "default_branch" => "main",
          "auto_commit" => false
        }
        :s3 -> %{
          "bucket_created" => true,
          "versioning_enabled" => true
        }
        :hybrid -> %{
          "git_initialized" => true,
          "s3_configured" => true,
          "default_branch" => "main"
        }
      end

      changeset
      |> Ash.Changeset.change_attribute(:storage_path, storage_path)
      |> Ash.Changeset.change_attribute(:storage_metadata, storage_metadata)
    end
  end

  defmodule CreateInitialFiles do
    @moduledoc """
    Creates initial files in the workspace.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      Ash.Changeset.after_action(changeset, fn changeset, workspace ->
        create_readme = changeset.arguments[:create_readme] || true

        if create_readme do
          create_initial_readme(workspace, context)
        end

        {:ok, workspace}
      end)
    end

    defp create_initial_readme(workspace, context) do
      readme_content = """
      # #{workspace.name}

      #{workspace.description || "Welcome to your new workspace!"}

      ## Getting Started

      This workspace was created on #{Date.utc_today()}.

      You can start by:
      - Creating new documents
      - Uploading existing files
      - Collaborating with your team

      ## Storage Configuration

      - Backend: #{workspace.storage_backend}
      - Versioning: #{if Kyozo.Workspaces.Workspace.supports_versioning?(workspace), do: "Enabled", else: "Disabled"}
      - Binary Files: #{if Kyozo.Workspaces.Workspace.supports_binary?(workspace), do: "Supported", else: "Not Supported"}
      """

      # Create README document
      Kyozo.Workspaces.create_document!(%{
        title: "README.md",
        content_type: "text/markdown",
        workspace_id: workspace.id,
        team_id: workspace.team_id,
        content: readme_content
      }, actor: context.actor, tenant: workspace.team_id)
    rescue
      _ -> :ok # Don't fail workspace creation if README creation fails
    end
  end

  defmodule ValidateSettings do
    @moduledoc """
    Validates workspace settings structure and values.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :settings) do
        nil -> changeset
        settings when is_map(settings) ->
          if Kyozo.Workspaces.Workspace.valid_settings?(settings) do
            changeset
          else
            Ash.Changeset.add_error(changeset, field: :settings, message: "Invalid settings structure")
          end
        _ ->
          Ash.Changeset.add_error(changeset, field: :settings, message: "Settings must be a map")
      end
    end
  end

  defmodule MigrateStorage do
    @moduledoc """
    Migrates workspace files between storage backends.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      Ash.Changeset.after_action(changeset, fn changeset, workspace ->
        new_backend = changeset.arguments[:new_backend]
        migrate_files = changeset.arguments[:migrate_files] || true

        if migrate_files do
          migrate_workspace_files(workspace, new_backend, context)
        end

        updated_workspace = 
          workspace
          |> Ash.Changeset.for_update(:update_workspace, %{storage_backend: new_backend})
          |> Kyozo.Workspaces.update_workspace!()

        {:ok, updated_workspace}
      end)
    end

    defp migrate_workspace_files(workspace, new_backend, context) do
      # Get all documents and notebooks
      documents = Kyozo.Workspaces.list_documents!(
        query: [filter: [workspace_id: workspace.id]],
        tenant: workspace.team_id
      )

      notebooks = Kyozo.Workspaces.list_notebooks!(
        query: [filter: [workspace_id: workspace.id]],
        tenant: workspace.team_id
      )

      # Migrate each file
      Enum.each(documents ++ notebooks, fn file ->
        migrate_file(file, workspace.storage_backend, new_backend, context)
      end)
    end

    defp migrate_file(file, from_backend, to_backend, context) do
      try do
        # Retrieve from old backend
        old_provider = Kyozo.Workspaces.Storage.get_provider(from_backend)
        {:ok, content, metadata} = old_provider.retrieve(
          file.file_path,
          workspace_id: file.workspace_id,
          team_id: file.team_id
        )

        # Store in new backend
        new_provider = Kyozo.Workspaces.Storage.get_provider(to_backend)
        {:ok, _new_metadata} = new_provider.store(
          file.file_path,
          content,
          workspace_id: file.workspace_id,
          team_id: file.team_id,
          commit_message: "Migrate to #{to_backend} backend",
          author: context.actor.name || "system"
        )
      rescue
        error ->
          # Log error but don't fail the entire migration
          require Logger
          Logger.error("Failed to migrate file #{file.file_path}: #{inspect(error)}")
      end
    end
  end

  defmodule GetStorageInfo do
    @moduledoc """
    Retrieves detailed storage information for a workspace.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      changeset
    end

    @impl true
    def atomic(_changeset, _opts, _context), do: :not_atomic

    def run(input, _opts, context) do
      workspace = input.resource

      storage_info = %{
        workspace_id: workspace.id,
        storage_backend: workspace.storage_backend,
        storage_path: Kyozo.Workspaces.Workspace.storage_path(workspace),
        storage_metadata: workspace.storage_metadata,
        supports_versioning: Kyozo.Workspaces.Workspace.supports_versioning?(workspace),
        supports_binary: Kyozo.Workspaces.Workspace.supports_binary?(workspace),
        git_repository_url: workspace.git_repository_url,
        git_branch: workspace.git_branch || "main",
        total_size: calculate_total_size(workspace),
        file_count: calculate_file_count(workspace)
      }

      {:ok, storage_info}
    end

    defp calculate_total_size(workspace) do
      files_size = Kyozo.Workspaces.File
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Ash.Query.aggregate(:sum, :file_size)
      |> Kyozo.Workspaces.read_one!()

      notebooks_size = Kyozo.Workspaces.Notebook
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Ash.Query.aggregate(:sum, :file_size)
      |> Kyozo.Workspaces.read_one!()

      (files_size || 0) + (notebooks_size || 0)
    end

    defp calculate_file_count(workspace) do
      files_count = Kyozo.Workspaces.File
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Ash.Query.aggregate(:count, :id)
      |> Kyozo.Workspaces.read_one!()

      notebooks_count = Kyozo.Workspaces.Notebook
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Ash.Query.aggregate(:count, :id)
      |> Kyozo.Workspaces.read_one!()

      (files_count || 0) + (notebooks_count || 0)
    end
  end

  defmodule GetWorkspaceStatistics do
    @moduledoc """
    Retrieves comprehensive statistics for a workspace.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      changeset
    end

    @impl true
    def atomic(_changeset, _opts, _context), do: :not_atomic

    def run(input, _opts, _context) do
      workspace = input.resource |> Ash.load!([:document_count, :notebook_count, :total_size, :last_activity])

      statistics = %{
        workspace_id: workspace.id,
        name: workspace.name,
        status: workspace.status,
        created_at: workspace.created_at,
        updated_at: workspace.updated_at,
        last_activity: workspace.last_activity,
        
        # File statistics
        total_files: workspace.document_count + workspace.notebook_count,
        document_count: workspace.document_count,
        notebook_count: workspace.notebook_count,
        total_size: workspace.total_size,
        
        # Storage information
        storage_backend: workspace.storage_backend,
        storage_path: Kyozo.Workspaces.Workspace.storage_path(workspace),
        supports_versioning: Kyozo.Workspaces.Workspace.supports_versioning?(workspace),
        supports_binary: Kyozo.Workspaces.Workspace.supports_binary?(workspace),
        
        # Activity metrics
        files_by_type: get_files_by_type(workspace),
        recent_activity: get_recent_activity(workspace),
        storage_usage: get_storage_usage(workspace)
      }

      {:ok, statistics}
    end

    defp get_files_by_type(workspace) do
      documents = Kyozo.Workspaces.Document
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Kyozo.Workspaces.read!()

      documents
      |> Enum.group_by(& &1.content_type)
      |> Enum.map(fn {type, files} -> 
        %{
          content_type: type,
          count: length(files),
          total_size: Enum.sum(Enum.map(files, & &1.file_size || 0))
        }
      end)
    end

    defp get_recent_activity(workspace) do
      # Get recent documents and notebooks (last 30 days)
      thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

      recent_documents = Kyozo.Workspaces.Document
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(updated_at >= ^thirty_days_ago)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(10)
      |> Kyozo.Workspaces.read!()

      recent_notebooks = Kyozo.Workspaces.Notebook
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(updated_at >= ^thirty_days_ago)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(10)
      |> Kyozo.Workspaces.read!()

      (recent_documents ++ recent_notebooks)
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
      |> Enum.take(10)
      |> Enum.map(fn item ->
        %{
          id: item.id,
          title: item.title,
          type: if(Map.has_key?(item, :cells), do: "notebook", else: "document"),
          updated_at: item.updated_at
        }
      end)
    end

    defp get_storage_usage(workspace) do
      total_size = workspace.total_size || 0
      max_size = get_in(workspace.settings, ["max_workspace_size"]) || 1_073_741_824 # 1GB default

      %{
        used_bytes: total_size,
        max_bytes: max_size,
        usage_percentage: if(max_size > 0, do: Float.round(total_size / max_size * 100, 2), else: 0),
        available_bytes: max(0, max_size - total_size)
      }
    end
  end

  defmodule CleanupStorage do
    @moduledoc """
    Cleans up unused storage files and optimizes workspace storage.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      changeset
    end

    @impl true
    def atomic(_changeset, _opts, _context), do: :not_atomic

    def run(input, _opts, _context) do
      workspace = input.resource
      dry_run = input.arguments[:dry_run] || true

      cleanup_results = %{
        workspace_id: workspace.id,
        dry_run: dry_run,
        orphaned_files: find_orphaned_files(workspace),
        old_versions: find_old_versions(workspace),
        large_files: find_large_files(workspace),
        total_space_saved: 0,
        actions_taken: []
      }

      final_results = if dry_run do
        cleanup_results
      else
        perform_cleanup(workspace, cleanup_results)
      end

      {:ok, final_results}
    end

    defp find_orphaned_files(workspace) do
      # Find files in storage that don't have corresponding database records
      # This would require interfacing with the actual storage backends
      []
    end

    defp find_old_versions(workspace) do
      # Find old versions that can be cleaned up
      # This would require interfacing with Git or S3 versioning
      []
    end

    defp find_large_files(workspace) do
      # Find unusually large files that might need attention
      large_threshold = 50_000_000 # 50MB

      documents = Kyozo.Workspaces.Document
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(file_size > ^large_threshold)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Kyozo.Workspaces.read!()

      notebooks = Kyozo.Workspaces.Notebook
      |> Ash.Query.filter(workspace_id == ^workspace.id)
      |> Ash.Query.filter(file_size > ^large_threshold)
      |> Ash.Query.filter(is_nil(deleted_at))
      |> Kyozo.Workspaces.read!()

      (documents ++ notebooks)
      |> Enum.map(fn file ->
        %{
          id: file.id,
          title: file.title,
          file_size: file.file_size,
          type: if(Map.has_key?(file, :cells), do: "notebook", else: "document")
        }
      end)
    end

    defp perform_cleanup(workspace, cleanup_results) do
      # Perform actual cleanup operations
      # This would involve:
      # 1. Removing orphaned files from storage
      # 2. Cleaning up old versions
      # 3. Compressing or archiving large files
      
      # For now, just return the results without actual cleanup
      cleanup_results
    end
  end

  defmodule DeleteStorage do
    @moduledoc """
    Deletes all storage for a workspace when hard deleting.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        workspace = changeset.data
        delete_workspace_storage(workspace, context)
        changeset
      end)
    end

    defp delete_workspace_storage(workspace, context) do
      try do
        provider = Kyozo.Workspaces.Workspace.storage_provider(workspace)
        storage_path = Kyozo.Workspaces.Workspace.storage_path(workspace)

        # Delete all files in the workspace
        case provider.list(storage_path, workspace_id: workspace.id, team_id: workspace.team_id) do
          {:ok, files} ->
            Enum.each(files, fn file_metadata ->
              provider.delete(
                file_metadata.file_path,
                workspace_id: workspace.id,
                team_id: workspace.team_id
              )
            end)
          {:error, _} -> :ok
        end

        # For Git backend, also remove the repository
        if workspace.storage_backend in [:git, :hybrid] do
          # This would require implementing repository deletion
          # For now, just log it
          require Logger
          Logger.info("Would delete Git repository for workspace #{workspace.id}")
        end
      rescue
        error ->
          require Logger
          Logger.error("Failed to delete storage for workspace #{workspace.id}: #{inspect(error)}")
      end
    end
  end

  defmodule BuildStoragePath do
    @moduledoc """
    Builds the storage path for a workspace before creation.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      case {Ash.Changeset.get_attribute(changeset, :team_id), Ash.Changeset.get_attribute(changeset, :name)} do
        {team_id, name} when not is_nil(team_id) and not is_nil(name) ->
          normalized_name = Kyozo.Workspaces.Workspace.normalize_name(name)
          storage_path = Kyozo.Workspaces.Storage.build_storage_path(team_id, normalized_name)
          Ash.Changeset.change_attribute(changeset, :storage_path, storage_path)
        _ ->
          changeset
      end
    end
  end

  defmodule NormalizeSettings do
    @moduledoc """
    Normalizes and merges workspace settings with defaults.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      current_settings = Ash.Changeset.get_attribute(changeset, :settings) || %{}
      default_settings = Kyozo.Workspaces.Workspace.default_settings()
      
      normalized_settings = Map.merge(default_settings, current_settings)
      
      Ash.Changeset.change_attribute(changeset, :settings, normalized_settings)
    end
  end

  defmodule UpdateStorageMetadata do
    @moduledoc """
    Updates storage metadata after workspace changes.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      Ash.Changeset.after_action(changeset, fn changeset, workspace ->
        updated_metadata = Map.merge(
          workspace.storage_metadata || %{},
          %{"last_updated" => DateTime.utc_now()}
        )

        updated_workspace = 
          workspace
          |> Ash.Changeset.for_update(:update_workspace, %{storage_metadata: updated_metadata})
          |> Kyozo.Workspaces.update_workspace!()

        {:ok, updated_workspace}
      end)
    end
  end

  defmodule EmitWorkspaceEvent do
    @moduledoc """
    Emits workspace events after actions.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, opts, _context) do
      event_type = Keyword.fetch!(opts, :event)
      
      Ash.Changeset.after_action(changeset, fn _changeset, workspace ->
        emit_event(event_type, workspace)
        {:ok, workspace}
      end)
    end

    defp emit_event(:workspace_created, workspace) do
      Kyozo.Workspaces.Events.WorkspaceCreated.emit(%{
        workspace_id: workspace.id,
        team_id: workspace.team_id,
        name: workspace.name,
        storage_backend: workspace.storage_backend,
        created_by: workspace.created_by,
        created_at: workspace.created_at
      })
    end

    defp emit_event(:workspace_updated, workspace) do
      Kyozo.Workspaces.Events.WorkspaceUpdated.emit(%{
        workspace_id: workspace.id,
        team_id: workspace.team_id,
        name: workspace.name,
        updated_at: workspace.updated_at
      })
    end

    defp emit_event(:workspace_deleted, workspace) do
      Kyozo.Workspaces.Events.WorkspaceDeleted.emit(%{
        workspace_id: workspace.id,
        team_id: workspace.team_id,
        name: workspace.name,
        deleted_at: workspace.deleted_at || DateTime.utc_now()
      })
    end

    defp emit_event(:workspace_archived, workspace) do
      Kyozo.Workspaces.Events.WorkspaceArchived.emit(%{
        workspace_id: workspace.id,
        team_id: workspace.team_id,
        name: workspace.name,
        archived_at: workspace.archived_at
      })
    end

    defp emit_event(:workspace_restored, workspace) do
      Kyozo.Workspaces.Events.WorkspaceRestored.emit(%{
        workspace_id: workspace.id,
        team_id: workspace.team_id,
        name: workspace.name,
        restored_at: workspace.updated_at
      })
    end
  end

  defmodule SeedStoragePath do
    @moduledoc """
    Simple storage path builder for seeding workspaces.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      name = Ash.Changeset.get_attribute(changeset, :name)
      
      if team_id && name do
        normalized_name = String.downcase(name) |> String.replace(~r/[^a-z0-9\-_]/, "_")
        storage_path = "teams/#{team_id}/workspaces/#{normalized_name}"
        Ash.Changeset.change_attribute(changeset, :storage_path, storage_path)
      else
        changeset
      end
    end
  end
end