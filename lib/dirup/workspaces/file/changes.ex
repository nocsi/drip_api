defmodule Dirup.Workspaces.File.Changes do
  @moduledoc """
  Changes for File resource to handle file operations, storage integration,
  and event emission for comprehensive file lifecycle management.

  Files can be linked to specialized resources (Media, Notebook) through
  intermediary resources (FileMedia, FileNotebook) that implement storage behavior.
  """

  alias Dirup.Workspaces.Storage
  alias Dirup.Workspaces.Events
  alias Dirup.Workspaces.File
  alias Dirup.Workspaces.FileTypeMapper

  # File Path and Metadata Changes

  defmodule BuildFilePath do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :file_path) do
        nil ->
          name = Ash.Changeset.get_attribute(changeset, :name)
          content_type = Ash.Changeset.get_attribute(changeset, :content_type) || "text/plain"

          if name do
            file_path = Dirup.Workspaces.File.build_file_path(name, content_type)
            Ash.Changeset.change_attribute(changeset, :file_path, file_path)
          else
            changeset
          end

        _existing_path ->
          changeset
      end
    end
  end

  defmodule DetectBinaryContent do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      case get_content_from_args(changeset, context) do
        nil ->
          changeset

        content ->
          is_binary = Dirup.Workspaces.File.binary_content?(content)
          Ash.Changeset.change_attribute(changeset, :is_binary, is_binary)
      end
    end

    defp get_content_from_args(changeset, _context) do
      Ash.Changeset.get_argument(changeset, :content)
    end
  end

  defmodule ValidateFileSize do
    use Ash.Resource.Change

    # 100MB
    @max_file_size 100 * 1024 * 1024

    @impl true
    def change(changeset, _opts, _context) do
      case Ash.Changeset.get_argument(changeset, :content) do
        nil ->
          changeset

        content ->
          size = byte_size(content)

          if size > @max_file_size do
            Ash.Changeset.add_error(changeset,
              field: :content,
              message:
                "File size (#{format_bytes(size)}) exceeds maximum allowed size (#{format_bytes(@max_file_size)})"
            )
          else
            Ash.Changeset.change_attribute(changeset, :file_size, size)
          end
      end
    end

    defp format_bytes(bytes) when bytes >= 1024 * 1024 * 1024 do
      "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
    end

    defp format_bytes(bytes) when bytes >= 1024 * 1024 do
      "#{Float.round(bytes / (1024 * 1024), 2)} MB"
    end

    defp format_bytes(bytes) when bytes >= 1024 do
      "#{Float.round(bytes / 1024, 2)} KB"
    end

    defp format_bytes(bytes), do: "#{bytes} bytes"
  end

  # Storage Operation Changes

  defmodule CreateFileStorage do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      changeset
      |> Ash.Changeset.before_transaction(fn changeset, _context ->
        with {:ok, content} <- get_content(changeset),
             {:ok, storage_options} <- build_storage_options(changeset, context),
             {:ok, metadata} <- store_file(changeset, content, storage_options) do
          changeset
          |> Ash.Changeset.change_attribute(:storage_backend, metadata.storage_backend)
          |> Ash.Changeset.change_attribute(:storage_metadata, metadata)
          |> Ash.Changeset.change_attribute(:version, metadata.version)
          |> Ash.Changeset.change_attribute(:checksum, generate_checksum(content))
        else
          {:error, reason} ->
            Ash.Changeset.add_error(changeset,
              message: "Failed to store file: #{inspect(reason)}"
            )
        end
      end)
    end

    defp get_content(changeset) do
      case Ash.Changeset.get_argument(changeset, :content) do
        nil -> {:error, "No content provided"}
        content -> {:ok, content}
      end
    end

    defp build_storage_options(changeset, context) do
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      file_path = Ash.Changeset.get_attribute(changeset, :file_path)

      options = [
        # Using team_id as workspace_id for now
        workspace_id: team_id,
        team_id: team_id,
        author: get_actor_name(context),
        commit_message:
          Ash.Changeset.get_argument(changeset, :initial_commit_message) || "Create document"
      ]

      {:ok, options}
    end

    defp store_file(changeset, content, options) do
      file_path = Ash.Changeset.get_attribute(changeset, :file_path)
      backend = determine_backend(changeset, content)
      provider = Storage.get_provider(backend)

      provider.store(file_path, content, options)
    end

    defp determine_backend(changeset, content) do
      content_type = Ash.Changeset.get_attribute(changeset, :content_type)
      file_path = Ash.Changeset.get_attribute(changeset, :file_path)

      cond do
        byte_size(content) > 10 * 1024 * 1024 -> :s3
        String.ends_with?(file_path, [".md", ".ipynb", ".py", ".js", ".json"]) -> :git
        String.starts_with?(content_type, "text/") -> :git
        true -> :hybrid
      end
    end

    defp generate_checksum(content) do
      :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    end

    defp get_actor_name(context) do
      case Map.get(context, :actor) do
        %{name: name} -> name
        %{email: email} -> email
        _ -> "system"
      end
    end
  end

  defmodule UpdateFileStorage do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      changeset
      |> Ash.Changeset.before_transaction(fn changeset, _context ->
        with {:ok, content} <- get_update_content(changeset),
             {:ok, storage_options} <- build_storage_options(changeset, context),
             {:ok, metadata} <- update_stored_file(changeset, content, storage_options) do
          changeset
          |> Ash.Changeset.change_attribute(:storage_metadata, metadata)
          |> Ash.Changeset.change_attribute(:version, metadata.version)
          |> Ash.Changeset.change_attribute(:checksum, generate_checksum(content))
          |> Ash.Changeset.change_attribute(:file_size, byte_size(content))
        else
          {:error, reason} ->
            Ash.Changeset.add_error(changeset,
              message: "Failed to update file: #{inspect(reason)}"
            )
        end
      end)
    end

    defp get_update_content(changeset) do
      case Ash.Changeset.get_argument(changeset, :content) do
        nil -> {:error, "No content provided for update"}
        content -> {:ok, content}
      end
    end

    defp build_storage_options(changeset, context) do
      data = Ash.Changeset.get_data(changeset)

      options = [
        workspace_id: data.team_id,
        team_id: data.team_id,
        author: get_actor_name(context),
        backend: data.storage_backend,
        commit_message:
          Ash.Changeset.get_argument(changeset, :commit_message) || "Update document"
      ]

      {:ok, options}
    end

    defp update_stored_file(changeset, content, options) do
      data = Ash.Changeset.get_data(changeset)
      provider = Storage.get_provider(data.storage_backend)

      provider.store(data.file_path, content, options)
    end

    defp generate_checksum(content) do
      :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    end

    defp get_actor_name(context) do
      case Map.get(context, :actor) do
        %{name: name} -> name
        %{email: email} -> email
        _ -> "system"
      end
    end
  end

  defmodule DeleteFileStorage do
    use Ash.Resource.Change

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def change(changeset, opts, context) do
      soft_delete = Keyword.get(opts, :soft_delete, true)

      if soft_delete do
        # For soft delete, we keep the file in storage
        changeset
      else
        changeset
        |> Ash.Changeset.after_transaction(fn changeset, {:ok, deleted_record} ->
          delete_from_storage(deleted_record, context)
          {:ok, deleted_record}
        end)
      end
    end

    defp delete_from_storage(record, context) do
      options = [
        workspace_id: record.team_id,
        team_id: record.team_id,
        author: get_actor_name(context)
      ]

      provider = Storage.get_provider(record.storage_backend)

      case provider.delete(record.file_path, options) do
        :ok ->
          :ok

        {:error, reason} ->
          require Logger
          Logger.error("Failed to delete file from storage: #{inspect(reason)}")
          # Don't fail the transaction for storage deletion errors
          :ok
      end
    end

    defp get_actor_name(context) do
      case Map.get(context, :actor) do
        %{name: name} -> name
        %{email: email} -> email
        _ -> "system"
      end
    end
  end

  # File Operation Changes

  defmodule RenameFile do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      changeset
      |> Ash.Changeset.before_transaction(fn changeset, _context ->
        with {:ok, new_title} <- get_new_title(changeset),
             {:ok, new_file_path} <- build_new_file_path(changeset, new_title),
             :ok <- validate_new_path(changeset, new_file_path) do
          changeset
          |> Ash.Changeset.change_attribute(:title, new_title)
          |> Ash.Changeset.change_attribute(:file_path, new_file_path)
        else
          {:error, reason} ->
            Ash.Changeset.add_error(changeset, message: "Failed to rename: #{reason}")
        end
      end)
    end

    defp get_new_title(changeset) do
      case Ash.Changeset.get_argument(changeset, :new_title) do
        nil -> {:error, "No new title provided"}
        title -> {:ok, title}
      end
    end

    defp build_new_file_path(changeset, new_title) do
      data = Ash.Changeset.get_data(changeset)
      new_path = Dirup.Workspaces.File.build_file_path(new_title, data.content_type)
      {:ok, new_path}
    end

    defp validate_new_path(changeset, new_path) do
      data = Ash.Changeset.get_data(changeset)

      if new_path == data.file_path do
        {:error, "New path is the same as current path"}
      else
        :ok
      end
    end
  end

  defmodule ProcessFileUpload do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      case Ash.Changeset.get_argument(changeset, :file_upload) do
        nil -> changeset
        upload_map -> process_upload(changeset, upload_map)
      end
    end

    defp process_upload(changeset, %{"filename" => filename, "content" => content} = upload) do
      content_type = Map.get(upload, "content_type", MIME.from_path(filename))

      changeset
      |> Ash.Changeset.change_attribute(:title, Path.rootname(filename))
      |> Ash.Changeset.change_attribute(:content_type, content_type)
      |> Ash.Changeset.change_attribute(:file_size, byte_size(content))
      |> Ash.Changeset.set_argument(:content, content)
    end

    defp process_upload(changeset, _invalid_upload) do
      Ash.Changeset.add_error(changeset,
        field: :file_upload,
        message: "Invalid file upload format"
      )
    end
  end

  # Content and Metadata Changes

  defmodule ExtractFileMetadata do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      content = Ash.Changeset.get_argument(changeset, :content)
      file_path = Ash.Changeset.get_attribute(changeset, :file_path)

      if content && file_path do
        metadata = Storage.extract_metadata(file_path, content)

        changeset
        |> Ash.Changeset.change_attribute(:file_size, metadata.size)
        |> Ash.Changeset.change_attribute(:checksum, generate_checksum(content))
      else
        changeset
      end
    end

    defp generate_checksum(content) do
      :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    end
  end

  defmodule UpdateFileMetadata do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      case Ash.Changeset.get_argument(changeset, :content) do
        nil ->
          changeset

        content ->
          changeset
          |> Ash.Changeset.change_attribute(:file_size, byte_size(content))
          |> Ash.Changeset.change_attribute(:checksum, generate_checksum(content))
      end
    end

    defp generate_checksum(content) do
      :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    end
  end

  defmodule UpdateViewCount do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      # Only update view count for read actions
      if changeset.action.type == :read do
        data = Ash.Changeset.get_data(changeset)
        new_count = (data.view_count || 0) + 1

        changeset
        |> Ash.Changeset.change_attribute(:view_count, new_count)
        |> Ash.Changeset.change_attribute(:last_viewed_at, DateTime.utc_now())
      else
        changeset
      end
    end
  end

  defmodule ClearRenderCache do
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      # Clear render cache when document is updated
      Ash.Changeset.change_attribute(changeset, :render_cache, %{})
    end
  end

  # Event Emission Changes

  defmodule EmitFileEvent do
    use Ash.Resource.Change

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def change(changeset, opts, context) do
      event_type = Keyword.fetch!(opts, :event)

      changeset
      |> Ash.Changeset.after_transaction(fn changeset, {:ok, file} ->
        emit_event(event_type, file, context, changeset)
        {:ok, file}
      end)
    end

    defp emit_event(:file_created, file, context, _changeset) do
      additional_data = %{
        storage_backend: file.storage_backend,
        content_type: file.content_type,
        file_size: file.file_size,
        created_at: DateTime.utc_now()
      }

      Events.emit_file_event(
        Events.FileCreated,
        file,
        get_actor(context),
        additional_data
      )
    end

    defp emit_event(:file_updated, file, context, changeset) do
      previous_name = get_previous_value(changeset, :name, file.name)

      additional_data = %{
        previous_name: previous_name,
        content_size: file.file_size,
        storage_backend: file.storage_backend,
        version: file.version,
        updated_at: DateTime.utc_now()
      }

      Events.emit_file_event(
        Events.FileUpdated,
        file,
        get_actor(context),
        additional_data
      )
    end

    defp emit_event(:file_deleted, file, context, _changeset) do
      additional_data = %{
        storage_backend: file.storage_backend,
        deleted_at: DateTime.utc_now()
      }

      Events.emit_file_event(
        Events.FileDeleted,
        file,
        get_actor(context),
        additional_data
      )
    end

    defp emit_event(:file_renamed, file, context, changeset) do
      old_name = get_previous_value(changeset, :name, file.name)
      old_file_path = get_previous_value(changeset, :file_path, file.file_path)

      additional_data = %{
        old_name: old_name,
        new_name: file.name,
        old_file_path: old_file_path,
        new_file_path: file.file_path,
        renamed_at: DateTime.utc_now()
      }

      Events.emit_file_event(
        Events.FileRenamed,
        file,
        get_actor(context),
        additional_data
      )
    end

    defp emit_event(:file_viewed, file, context, _changeset) do
      additional_data = %{
        viewed_at: DateTime.utc_now()
      }

      Events.emit_file_event(
        Events.FileViewed,
        file,
        get_actor(context),
        additional_data
      )
    end

    defp get_actor(context) do
      Map.get(context, :actor, %{id: "system", name: "System"})
    end

    defp get_previous_value(changeset, field, default) do
      case Ash.Changeset.get_data(changeset) do
        %{^field => value} -> value
        _ -> default
      end
    end
  end

  # Action Implementation Changes

  defmodule RecordFileView do
    use Ash.Resource.Actions.Implementation

    @impl true
    def run(input, _opts, context) do
      document = input.resource

      # Record the view in the database
      updates = %{
        view_count: (input.view_count || 0) + 1,
        last_viewed_at: DateTime.utc_now()
      }

      case Ash.update(document, :update_metadata, updates, actor: context.actor) do
        {:ok, updated_document} -> {:ok, updated_document}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defmodule RetrieveContent do
    use Ash.Resource.Actions.Implementation

    @impl true
    def run(input, _opts, context) do
      document = input.resource
      version = input.arguments[:version]

      storage_options = [
        workspace_id: input.workspace_id,
        team_id: input.team_id,
        version: version
      ]

      provider = Storage.get_provider(input.storage_backend)

      case provider.retrieve(input.file_path, storage_options) do
        {:ok, content, _metadata} -> {:ok, content}
        {:error, reason} -> {:error, "Failed to retrieve content: #{inspect(reason)}"}
      end
    end
  end

  defmodule ListFileVersions do
    use Ash.Resource.Actions.Implementation

    @impl true
    def run(input, _opts, _context) do
      file = input.resource

      storage_options = [
        workspace_id: input.workspace_id,
        team_id: input.team_id
      ]

      provider = Storage.get_provider(input.storage_backend)

      case provider.list_versions(input.file_path, storage_options) do
        {:ok, versions} -> {:ok, versions}
        {:error, reason} -> {:error, "Failed to list versions: #{inspect(reason)}"}
      end
    end
  end

  defmodule CreateFileVersion do
    use Ash.Resource.Actions.Implementation

    @impl true
    def run(input, _opts, context) do
      file = input.resource
      content = input.arguments[:content]
      commit_message = input.arguments[:commit_message]

      storage_options = [
        workspace_id: input.workspace_id,
        team_id: input.team_id,
        author: get_actor_name(context)
      ]

      provider = Storage.get_provider(input.storage_backend)

      case provider.create_version(input.file_path, content, commit_message, storage_options) do
        {:ok, version, _metadata} -> {:ok, version}
        {:error, reason} -> {:error, "Failed to create version: #{inspect(reason)}"}
      end
    end

    defp get_actor_name(context) do
      case Map.get(context, :actor) do
        %{name: name} -> name
        %{email: email} -> email
        _ -> "system"
      end
    end
  end

  defmodule RenderFile do
    use Ash.Resource.Actions.Implementation

    @impl true
    def run(input, _opts, context) do
      file = input.resource
      target_format = input.arguments[:target_format]
      options = input.arguments[:options] || %{}

      with {:ok, content} <- get_file_content(input, context),
           {:ok, rendered} <- render_content(content, input.content_type, target_format, options) do
        # Cache the rendered result
        cache_key =
          "#{target_format}_#{:crypto.hash(:md5, inspect(options)) |> Base.encode16(case: :lower)}"

        cache_entry = %{
          content: rendered,
          rendered_at: DateTime.utc_now(),
          options: options
        }

        new_cache = Map.put(input.render_cache || %{}, cache_key, cache_entry)
        Ash.update!(input, :update_metadata, %{render_cache: new_cache}, actor: context.actor)

        {:ok, rendered}
      end
    end

    defp get_file_content(file, _context) do
      storage_options = [
        workspace_id: file.workspace_id,
        team_id: file.team_id
      ]

      provider = Storage.get_provider(file.storage_backend)

      case provider.retrieve(file.file_path, storage_options) do
        {:ok, content, _metadata} -> {:ok, content}
        {:error, reason} -> {:error, "Failed to retrieve content: #{inspect(reason)}"}
      end
    end

    defp render_content(content, source_format, target_format, _options) do
      # This would be replaced with actual rendering logic
      case {source_format, target_format} do
        {"text/markdown", :html} ->
          # Mock HTML rendering
          {:ok, "<html><body>#{content}</body></html>"}

        {"application/x-jupyter-notebook", :html} ->
          # Mock notebook rendering
          {:ok, "<html><body>Notebook: #{content}</body></html>"}

        {_, :html} ->
          # Default HTML rendering
          {:ok, "<html><body><pre>#{content}</pre></body></html>"}

        _ ->
          {:error, "Unsupported rendering: #{source_format} to #{target_format}"}
      end
    end
  end

  defmodule CreatePrimaryStorage do
    @moduledoc """
    Creates appropriate storage entry using FileTypeMapper for new files.
    This integrates with the abstract storage pattern.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      changeset
      |> Ash.Changeset.before_transaction(fn changeset, context ->
        with {:ok, content} <- get_content(changeset),
             {:ok, file_struct} <- prepare_file_struct(changeset),
             {:ok, storage_entry} <- create_storage_entry(file_struct, content, context) do
          # Store storage entry info for syncing metadata
          changeset
          |> Ash.Changeset.set_context(%{
            storage_entry: storage_entry,
            storage_content: content
          })
          |> sync_storage_metadata_to_file(storage_entry)
        else
          {:error, reason} ->
            Ash.Changeset.add_error(changeset,
              message: "Failed to create primary storage: #{inspect(reason)}"
            )
        end
      end)
    end

    defp get_content(changeset) do
      case Ash.Changeset.get_argument(changeset, :content) do
        nil -> {:error, "No content provided"}
        content when is_binary(content) -> {:ok, content}
        _ -> {:error, "Content must be binary"}
      end
    end

    defp prepare_file_struct(changeset) do
      filename = Ash.Changeset.get_attribute(changeset, :name) || "untitled"
      content_type = Ash.Changeset.get_attribute(changeset, :content_type) || "text/plain"

      # Create a temporary file struct for storage mapping
      file_struct = %File{
        name: filename,
        content_type: content_type,
        workspace_id: Ash.Changeset.get_attribute(changeset, :workspace_id),
        team_id: Ash.Changeset.get_attribute(changeset, :team_id)
      }

      {:ok, file_struct}
    end

    defp build_storage_options(changeset, context) do
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      workspace_id = Ash.Changeset.get_attribute(changeset, :workspace_id)

      storage_options = %{
        team_id: team_id,
        user_id: get_user_id(context),
        description: Ash.Changeset.get_attribute(changeset, :description),
        metadata: %{
          document_title: Ash.Changeset.get_attribute(changeset, :title),
          workspace_id: workspace_id,
          created_via: "document_creation"
        }
      }

      {:ok, storage_options}
    end

    defp create_storage_entry(file_struct, content, context) do
      # Use FileTypeMapper to create appropriate storage entry
      opts = [
        file_size: byte_size(content),
        prefer_versioning: true,
        actor: Map.get(context, :actor)
      ]

      case FileTypeMapper.create_storage_entry(file_struct, content, opts) do
        {:ok, storage_entry} -> {:ok, storage_entry}
        {:error, reason} -> {:error, reason}
      end
    end

    defp sync_storage_metadata_to_file(changeset, storage_entry) do
      # Extract metadata from storage entry's storage_resource
      storage_resource = storage_entry.storage_resource

      changeset
      |> Ash.Changeset.change_attribute(:file_size, storage_resource.file_size)
      |> Ash.Changeset.change_attribute(:checksum, storage_resource.checksum)
      |> Ash.Changeset.change_attribute(:version, storage_resource.version)
      |> Ash.Changeset.change_attribute(:storage_backend, storage_resource.storage_backend)
      |> Ash.Changeset.change_attribute(
        :storage_metadata,
        storage_resource.storage_metadata || %{}
      )
    end

    # Remove document storage relationship creation as it's handled by the storage entry itself

    defp determine_storage_backend(%{"content" => content, "filename" => filename}) do
      cond do
        String.ends_with?(filename, [".md", ".txt", ".py", ".js", ".json", ".yaml"]) -> :git
        # > 10MB
        byte_size(content) > 10 * 1024 * 1024 -> :s3
        String.valid?(content) && !String.contains?(content, <<0>>) -> :git
        true -> :s3
      end
    end

    defp determine_storage_backend(_), do: :hybrid

    defp get_user_id(%{actor: %{id: id}}), do: id
    defp get_user_id(_), do: nil
  end

  defmodule UpdatePrimaryStorage do
    @moduledoc """
    Updates content in the primary StorageResource for existing files.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, context) do
      changeset
      |> Ash.Changeset.before_transaction(fn changeset, context ->
        document = changeset.data

        with {:ok, content} <- get_update_content(changeset),
             {:ok, primary_storage} <- get_primary_storage(document),
             {:ok, updated_storage} <- update_storage_content(primary_storage, content, context) do
          # Sync updated metadata back to document
          sync_storage_metadata_to_file(changeset, updated_storage)
        else
          {:error, reason} ->
            Ash.Changeset.add_error(changeset,
              message: "Failed to update primary storage: #{inspect(reason)}"
            )
        end
      end)
    end

    defp get_update_content(changeset) do
      case Ash.Changeset.get_argument(changeset, :content) do
        nil -> {:error, "No content provided"}
        content when is_binary(content) -> {:ok, content}
        _ -> {:error, "Content must be binary"}
      end
    end

    defp get_primary_storage(file) do
      case Ash.load(file, :primary_storage) do
        {:ok, %{primary_storage: storage}} when not is_nil(storage) ->
          {:ok, storage}

        {:ok, _} ->
          {:error, "No primary storage found"}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp update_storage_content(storage, content, context) do
      file_upload = %{
        "content" => content,
        "filename" => storage.file_name,
        "content_type" => storage.mime_type
      }

      case Dirup.Storage.StorageResource.upload_new_version(
             storage.id,
             %{
               file_upload: file_upload,
               commit_message: "Document content updated"
             },
             actor: Map.get(context, :actor)
           ) do
        {:ok, updated_storage} -> {:ok, updated_storage}
        error -> error
      end
    end

    defp update_storage_entry_content(storage_entry, content, commit_message, _context) do
      # Use the storage entry's update action to update content
      module = storage_entry.__struct__

      case module.update_file_content(storage_entry, %{
             file_id: storage_entry.file_id,
             content: content,
             commit_message: commit_message
           }) do
        {:ok, result} -> {:ok, storage_entry}
        {:error, reason} -> {:error, reason}
      end
    end

    defp sync_storage_metadata_to_file(changeset, storage_entry) do
      storage_resource = storage_entry.storage_resource

      changeset
      |> Ash.Changeset.change_attribute(:file_size, storage_resource.file_size)
      |> Ash.Changeset.change_attribute(:checksum, storage_resource.checksum)
      |> Ash.Changeset.change_attribute(:version, storage_resource.version)
      |> Ash.Changeset.change_attribute(
        :storage_metadata,
        storage_resource.storage_metadata || %{}
      )
    end
  end

  defmodule SyncWithStorageMetadata do
    @moduledoc """
    Synchronizes document metadata with its primary storage resource.
    """
    use Ash.Resource.Change

    @impl true
    def change(changeset, _opts, _context) do
      changeset
      |> Ash.Changeset.after_action(fn changeset, result, _context ->
        # Sync asynchronously to avoid affecting performance
        Task.start(fn ->
          try do
            sync_file_with_primary_storage(result)
          rescue
            error ->
              require Logger
              Logger.error("Failed to sync file with primary storage: #{inspect(error)}")
          end
        end)

        {:ok, result}
      end)
    end

    defp sync_file_with_primary_storage(file) do
      case get_primary_storage(file) do
        {:ok, storage} ->
          # Check if sync is needed
          if needs_sync?(file, storage) do
            perform_sync(file, storage)
          end

        {:error, _reason} ->
          # No primary storage found, skip sync
          :ok
      end
    end

    defp get_primary_storage(file) do
      case Ash.load(file, :primary_storage) do
        {:ok, %{primary_storage: storage}} when not is_nil(storage) ->
          {:ok, storage}

        {:ok, _} ->
          {:error, "No primary storage found"}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp needs_sync?(file, storage) do
      file.file_size != storage.file_size ||
        file.checksum != storage.checksum ||
        file.version != storage.version ||
        file.content_type != storage.mime_type
    end

    defp perform_sync(file, storage) do
      # Sync storage metadata to file
      file
      |> Ash.Changeset.for_update(:update)
      |> Ash.Changeset.change_attribute(:file_size, storage.file_size)
      |> Ash.Changeset.change_attribute(:checksum, storage.checksum)
      |> Ash.Changeset.change_attribute(:version, storage.version)
      |> Ash.Changeset.change_attribute(:content_type, storage.mime_type)
      |> Ash.Changeset.change_attribute(:storage_metadata, storage.storage_metadata || %{})
      |> Dirup.Workspaces.update!()

      # Also sync file metadata to storage if needed
      if file.description && (!storage.description || storage.description != file.description) do
        storage
        |> Ash.Changeset.for_update(:update_storage_entry)
        |> Ash.Changeset.change_attribute(:description, file.description)
        |> Dirup.Storage.update!()
      end
    end

    defmodule CreateSpecializedResource do
      @moduledoc """
      Creates specialized resources (Media, Notebook) for files that support them.
      """
      use Ash.Resource.Change

      @impl true
      def change(changeset, _opts, _context) do
        changeset
        |> Ash.Changeset.after_action(fn changeset, file ->
          if Dirup.Workspaces.File.should_resolve_to_specialized?(file) do
            case create_intermediary_resource(file, changeset) do
              {:ok, _intermediary} ->
                {:ok, file}

              {:error, reason} ->
                require Logger

                Logger.warning(
                  "Failed to create specialized resource for file #{file.id}: #{inspect(reason)}"
                )

                {:ok, file}
            end
          else
            {:ok, file}
          end
        end)
      end

      defp create_intermediary_resource(file, changeset) do
        content = Ash.Changeset.get_context(changeset, :storage_content)
        intermediary_module = Dirup.Workspaces.File.get_intermediary_module(file)

        if intermediary_module && content do
          intermediary_module.create_from_file(%{
            file_id: file.id,
            content: content
          })
        else
          {:error, "No intermediary module or content available"}
        end
      end
    end

    defmodule ResolveToMedia do
      @moduledoc """
      Resolves a file to its Media representation through FileMedia intermediary.
      """
      use Ash.Resource.Actions.Implementation

      @impl true
      def run(file, input, _context) do
        force_create = input.arguments.force_create

        # Check if we already have a primary media relationship
        case Ash.load(file, :primary_file_media) do
          {:ok, %{primary_file_media: %{media: media}}}
          when not is_nil(media) and not force_create ->
            {:ok, media}

          {:ok, _} ->
            # Need to create or find the media resource
            create_or_find_media_resource(file)

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp create_or_find_media_resource(file) do
        storage_type =
          Dirup.Workspaces.FileTypeMapper.determine_storage_type(file.name, file.content_type)

        if storage_type == :image do
          # Get file content through primary storage
          case get_file_content(file) do
            {:ok, content} ->
              # Create FileMedia intermediary which will create the Media resource
              Dirup.Workspaces.FileMedia.create_from_file(%{
                file_id: file.id,
                content: content
              })

            {:error, reason} ->
              {:error, "Failed to get file content: #{inspect(reason)}"}
          end
        else
          {:error, "File is not a supported media type"}
        end
      end

      defp get_file_content(file) do
        # Get content through the primary storage resource
        case Ash.load(file, :primary_storage) do
          {:ok, %{primary_storage: storage}} when not is_nil(storage) ->
            Dirup.Storage.retrieve_content(storage)

          {:ok, _} ->
            {:error, "No primary storage found"}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end

    defmodule ResolveToNotebook do
      @moduledoc """
      Resolves a file to its Notebook representation through FileNotebook intermediary.
      """
      use Ash.Resource.Actions.Implementation

      @impl true
      def run(file, input, _context) do
        force_create = input.arguments.force_create

        # Check if we already have a primary notebook relationship
        case Ash.load(file, :primary_file_notebook) do
          {:ok, %{primary_file_notebook: %{notebook: notebook}}}
          when not is_nil(notebook) and not force_create ->
            {:ok, notebook}

          {:ok, _} ->
            # Need to create or find the notebook resource
            create_or_find_notebook_resource(file)

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp create_or_find_notebook_resource(file) do
        storage_type =
          Dirup.Workspaces.FileTypeMapper.determine_storage_type(file.name, file.content_type)

        if storage_type == :notebook do
          # Get file content through primary storage
          case get_file_content(file) do
            {:ok, content} ->
              # Create FileNotebook intermediary which will create the Notebook resource
              Dirup.Workspaces.FileNotebook.create_from_file(%{
                file_id: file.id,
                content: content
              })

            {:error, reason} ->
              {:error, "Failed to get file content: #{inspect(reason)}"}
          end
        else
          {:error, "File is not a supported notebook type"}
        end
      end

      defp get_file_content(file) do
        # Get content through the primary storage resource
        case Ash.load(file, :primary_storage) do
          {:ok, %{primary_storage: storage}} when not is_nil(storage) ->
            Dirup.Storage.retrieve_content(storage)

          {:ok, _} ->
            {:error, "No primary storage found"}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end

    defmodule GetSpecializedContent do
      @moduledoc """
      Gets the specialized content (Media or Notebook) for a file if available.
      """
      use Ash.Resource.Actions.Implementation

      @impl true
      def run(file, _input, _context) do
        storage_type =
          Dirup.Workspaces.FileTypeMapper.determine_storage_type(file.name, file.content_type)

        case storage_type do
          :image ->
            case Ash.load(file, :primary_media) do
              {:ok, %{primary_media: media}} when not is_nil(media) ->
                {:ok, %{type: :media, content: media}}

              {:ok, _} ->
                {:ok, %{type: :none, content: nil}}

              {:error, reason} ->
                {:error, reason}
            end

          :notebook ->
            case Ash.load(file, :primary_notebook) do
              {:ok, %{primary_notebook: notebook}} when not is_nil(notebook) ->
                {:ok, %{type: :notebook, content: notebook}}

              {:ok, _} ->
                {:ok, %{type: :none, content: nil}}

              {:error, reason} ->
                {:error, reason}
            end

          _ ->
            {:ok, %{type: :file, content: file}}
        end
      end
    end
  end

  # defmodule AddStorageBacking do
  #   @moduledoc """
  #   Adds an additional storage backing to a file.
  #   """
  #   # use Ash.Resource.Action

  #   @impl true
  #   def run(input, _opts, context) do
  #     document = input.__struct__.get!(input)
  #     storage_id = Ash.ActionInput.get_argument(input, :storage_id)
  #     relationship_type = Ash.ActionInput.get_argument(input, :relationship_type)

  #     case Dirup.Workspaces.FileStorage.create_file_storage(%{
  #       file_id: file.id,
  #       storage_id: storage_id,
  #       relationship_type: relationship_type
  #     }, actor: Map.get(context, :actor)) do
  #       {:ok, document_storage} ->
  #         {:ok, %{
  #           document: document,
  #           document_storage: document_storage,
  #           message: "Storage backing added successfully"
  #         }}

  #       {:error, reason} ->
  #         {:error, "Failed to add storage backing: #{inspect(reason)}"}
  #     end
  #   end
  # end

  # defmodule SwitchPrimaryStorage do
  #   @moduledoc """
  #   Switches the primary storage for a document to a different storage resource.
  #   """
  #   # use Ash.Resource.Action

  #   @impl true
  #   def run(input, _opts, context) do
  #     document = input.__struct__.get!(input)
  #     storage_id = Ash.ActionInput.get_argument(input, :storage_id)

  #     with {:ok, existing_relationship} <- find_storage_relationship(file.id, storage_id),
  #          {:ok, updated_relationship} <- set_as_primary(existing_relationship),
  #          {:ok, updated_file} <- update_file_metadata(file, updated_relationship) do

  #         {:ok, %{
  #         file: updated_file,
  #         primary_storage: updated_relationship,
  #         message: "Primary storage switched successfully"
  #       }}
  #     else
  #       {:error, :not_found} ->
  #         {:error, "Storage relationship not found for this document"}

  #       {:error, reason} ->
  #         {:error, "Failed to switch primary storage: #{inspect(reason)}"}
  #     end
  #   end

  #   defp find_storage_relationship(document_id, storage_id) do
  #     case Dirup.Workspaces.DocumentStorage.by_document_and_storage(document_id, storage_id) do
  #       {:ok, relationship} -> {:ok, relationship}
  #       _ -> {:error, :not_found}
  #     end
  #   end

  #   defp set_as_primary(relationship) do
  #     case Dirup.Workspaces.DocumentStorage.set_as_primary(relationship.id) do
  #       {:ok, updated} -> {:ok, updated}
  #       error -> error
  #     end
  #   end

  #   defp update_document_metadata(document, relationship) do
  #     # Load the storage resource to sync metadata
  #     case Dirup.Storage.get_storage(relationship.storage_id) do
  #       {:ok, storage} ->
  #         document
  #         |> Ash.Changeset.for_update(:update)
  #         |> Ash.Changeset.change_attribute(:file_size, storage.file_size)
  #         |> Ash.Changeset.change_attribute(:checksum, storage.checksum)
  #         |> Ash.Changeset.change_attribute(:version, storage.version)
  #         |> Ash.Changeset.change_attribute(:storage_backend, storage.storage_backend)
  #         |> Dirup.Workspaces.update()

  #       error ->
  #         error
  #     end
  #   end
  # end
end
