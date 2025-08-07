defmodule Kyozo.Workspaces.File do
  @derive {Jason.Encoder, only: [:id, :name, :file_path, :content_type, :description, :tags, :file_size, :storage_backend, :storage_metadata, :version, :checksum, :is_directory, :is_binary, :render_cache, :view_count, :last_viewed_at, :deleted_at, :workspace_id, :parent_file_id, :created_at, :updated_at]}

  @moduledoc """
  File resource representing generic files and folders in a workspace.

  Files can be either regular files or directories (folders), supporting
  a complete file system hierarchy with proper storage backing through
  Git/S3 storage and comprehensive event tracking for collaboration.
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, Kyozo.Workspaces.Extensions.RenderMarkdown]

  alias Kyozo.Workspaces.Storage
  alias Kyozo.Workspaces.Events
  alias Kyozo.Workspaces.File.Changes
  alias Kyozo.Workspaces.FileTypeMapper

  render_markdown do
    render_attributes content: :content_html, description: :description_html
    header_ids? true
    table_of_contents? false
    syntax_highlighting? true
    extract_tasks? true
    allowed_languages ["markdown", "html", "css", "javascript", "python", "bash", "sql"]
  end

  postgres do
    table "files"
    repo Kyozo.Repo

    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :team_member, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:team_id, :file_path], unique: true
      index [:team_id, :name]
      index [:team_id, :content_type]
      index [:team_id, :storage_backend]
      index [:team_id, :updated_at]
      index [:team_id, :is_directory]
      index [:workspace_id, :file_path], unique: true
      index [:workspace_id, :name]
      index [:workspace_id, :updated_at]
      index [:workspace_id, :parent_file_id]
      index [:parent_file_id]
    end
  end


  json_api do
    type "file"

    routes do
      base "/files"
      get :read
      index :read
    end
  end

  graphql do
    type :file

    queries do
      get :get_file, :read
      list :list_files, :read
    end
  end


  # TODO: Re-enable events after fixing AshEvents.Resource extension
  # events do
  #   event :file_created, Kyozo.Workspaces.Events.FileCreated
  #   event :file_updated, Kyozo.Workspaces.Events.FileUpdated
  #   event :file_deleted, Kyozo.Workspaces.Events.FileDeleted
  #   event :file_renamed, Kyozo.Workspaces.Events.FileRenamed
  #   event :file_viewed, Kyozo.Workspaces.Events.FileViewed
  # end

  actions do
    default_accept [:name, :content_type, :description, :tags, :is_directory, :parent_file_id]
    defaults [:read, :destroy]

    read :list_files do
      prepare build(load: [:author, :can_update, :can_destroy, :file_metadata, :storage_info, :parent, :children])
      filter expr(is_nil(deleted_at))
    end

    read :list_by_type do
      argument :content_type, :string, allow_nil?: false

      prepare build(
        filter: [content_type: arg(:content_type)],
        load: [:author, :file_metadata]
      )
    end

    read :search do
      argument :query, :string, allow_nil?: false

      prepare build(
        filter: expr(
          contains(title, ^arg(:query)) or
          contains(description, ^arg(:query)) or
          contains(tags, ^arg(:query))
        ),
        load: [:author, :file_metadata]
      )
    end

    create :create_file do
      argument :content, :string, allow_nil?: true
      argument :initial_commit_message, :string, default: "Create file"

      change relate_actor(:team_member, field: :membership_id)
      change {Changes.CreatePrimaryStorage, []}
      change {Changes.UpdateFileMetadata, []}

      after_action {Changes.EmitFileEvent, event: :file_created}
      after_action {Changes.SyncWithStorageMetadata, []}
      after_action {Changes.CreateSpecializedResource, []}
    end

    create :create_folder do
      argument :initial_commit_message, :string, default: "Create folder"

      change set_attribute(:is_directory, true)
      change set_attribute(:content_type, "application/x-directory")
      change relate_actor(:team_member, field: :membership_id)
      change {Changes.CreateFolderStructure, []}

      after_action {Changes.EmitFileEvent, event: :file_created}
    end

    create :upload_file do
      argument :file_upload, :map, allow_nil?: false
      argument :initial_commit_message, :string, default: "Upload file"

      change relate_actor(:team_member, field: :membership_id)
      change {Changes.ProcessFileUpload, []}
      # change {Changes.CreateFileStorage, []}
      change {Changes.ExtractFileMetadata, []}

      after_action {Changes.EmitFileEvent, event: :file_created}
      after_action {Changes.SyncWithPrimaryStorage, []}
    end

    update :update_content do
      argument :content, :string, allow_nil?: false
      argument :commit_message, :string, default: "Update document content"

      change {Changes.UpdatePrimaryStorage, []}
      change {Changes.UpdateFileMetadata, []}

      after_action {Changes.EmitFileEvent, event: :file_updated}
      after_action {Changes.SyncWithStorageMetadata, []}
    end

    update :rename_file do
      argument :new_name, :string, allow_nil?: false
      argument :commit_message, :string, default: "Rename file"

      change {Changes.RenameFile, []}
      change {Changes.UpdateFileMetadata, []}

      after_action {Changes.EmitFileEvent, event: :file_renamed}
      after_action {Changes.SyncWithStorageMetadata, []}
    end

    update :move_file do
      argument :new_parent_id, :uuid, allow_nil?: true
      argument :commit_message, :string, default: "Move file"

      # change {Changes.MoveFile, []}
      # change {Changes.UpdatePrimaryStorage, []}

      after_action {Changes.EmitFileEvent, event: :file_updated}
      # after_action {Changes.SyncWithPrimaryStorage, []}
    end

    update :update_metadata do
      accept [:description, :tags, :content_type]

      after_action {Changes.EmitFileEvent, event: :file_updated}
    end

    update :update do
      accept [:name, :content_type, :description, :tags]

      after_action {Changes.EmitFileEvent, event: :file_updated}
    end

    action :view_file, :struct do
      run {Changes.RecordFileView, []}

      after_action {Changes.EmitFileEvent, event: :file_viewed}
    end

    action :get_content, :string do
      argument :version, :string, allow_nil?: true

      run {Changes.RetrieveContent, []}
    end

    # action :add_storage_backing, :struct do
    #   argument :storage_id, :uuid, allow_nil?: false
    #   argument :relationship_type, :atom, default: :backup

    #   run {Changes.AddStorageBacking, []}
    # end

    # action :switch_primary_storage, :struct do
    #   argument :storage_id, :uuid, allow_nil?: false

    #   run {Changes.SwitchPrimaryStorage, []}

    #   after_action {Changes.SyncWithPrimaryStorage, []}
    # end

    action :list_versions, {:array, :map} do
      run {Changes.ListFileVersions, []}
    end

    action :render_as, :string do
      argument :target_format, :atom, allow_nil?: false
      argument :options, :map, default: %{}

      run {Changes.RenderFile, []}
    end

    action :resolve_to_media, :struct do
      argument :force_create, :boolean, default: false

      run {Changes.ResolveToMedia, []}
    end

    action :resolve_to_notebook, :struct do
      argument :force_create, :boolean, default: false

      run {Changes.ResolveToNotebook, []}
    end

    action :get_specialized_content, :map do
      run {Changes.GetSpecializedContent, []}
    end

    action :create_version, :string do
      argument :content, :string, allow_nil?: false
      argument :commit_message, :string, allow_nil?: false

      run {Changes.CreateFileVersion, []}
    end

    action :duplicate_file, :struct do
      argument :new_name, :string, allow_nil?: true
      argument :copy_to_workspace_id, :uuid, allow_nil?: true
      argument :initial_commit_message, :string, default: "Duplicate file"

      run {Changes.DuplicateFile, []}

      after_action {Changes.EmitFileEvent, event: :file_created}
      # after_action {Changes.SyncWithPrimaryStorage, []}
    end

    action :list_folder_contents, {:array, :struct} do
      argument :folder_id, :uuid, allow_nil?: true

      run {Changes.ListFolderContents, []}
    end

    destroy :soft_delete do
      accept []

      change set_attribute(:deleted_at, expr(now()))
      # change {Changes.DeleteFileStorage, soft_delete: true}

      after_action {Changes.EmitFileEvent, event: :file_deleted}
    end

    destroy :hard_delete do
      accept []

      # change {Changes.DeleteFileStorage, soft_delete: false}

      after_action {Changes.EmitFileEvent, event: :file_deleted}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:team, :users])
    end

    policy action_type(:create) do
      authorize_if actor_present()
      authorize_if relates_to_actor_via([:team, :users])
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via([:team_member, :user])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:team_member, :user])
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action([:get_content, :view_file, :list_versions]) do
      authorize_if relates_to_actor_via([:team, :users])
    end

    policy action([:render_as, :create_version, :duplicate_file, :list_folder_contents]) do
      authorize_if relates_to_actor_via([:team_member, :user])
    end
  end

  pub_sub do
    module KyozoWeb.Endpoint

    publish_all :create, ["workspace_files", :team_id]
    publish_all :update, ["workspace_files", :team_id]
    publish_all :destroy, ["workspace_files", :team_id]
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :file_path, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 1024
    end

    attribute :content_type, :string do
      allow_nil? false
      public? true
      default "text/plain"
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    attribute :file_size, :integer do
      public? true
      constraints min: 0
      default 0
    end

    attribute :storage_backend, :atom do
      public? true
      default :hybrid
    end

    attribute :storage_metadata, :map do
      public? true
      default %{}
    end

    attribute :version, :string do
      public? true
    end

    attribute :checksum, :string do
      public? true
    end

    attribute :is_directory, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :is_binary, :boolean do
      public? true
      default false
    end

   attribute :is_notebook_file, :boolean do
     public? true
     default true
   end

    attribute :render_cache, :map do
      public? true
      default %{}
    end

    attribute :view_count, :integer do
      public? true
      default 0
    end

    attribute :last_viewed_at, :utc_datetime_usec do
      public? true
    end

    attribute :deleted_at, :utc_datetime_usec do
      public? true
    end

    attribute :workspace_id, :uuid do
      public? true
      allow_nil? true
    end

    attribute :parent_file_id, :uuid do
      public? true
      allow_nil? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? true
      attribute_writable? true
    end

    belongs_to :team_member, Kyozo.Accounts.UserTeam do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end



    # Storage relationships through FileStorage join resource
    has_many :file_storages, Kyozo.Workspaces.FileStorage do
      destination_attribute :file_id
      sort created_at: :desc
      public? false  # Not exposed via GraphQL - internal storage management
    end

    has_many :image_storages, Kyozo.Workspaces.ImageStorage do
      destination_attribute :file_id
      sort created_at: :desc
      public? false  # Not exposed via GraphQL - internal storage management
    end

    # Intermediary relationships for specialized content types
    has_many :file_media, Kyozo.Workspaces.FileMedia do
      destination_attribute :file_id
      sort created_at: :desc
      public? false  # Not exposed via GraphQL - internal intermediary resource
    end

    has_many :file_notebooks, Kyozo.Workspaces.FileNotebook do
      destination_attribute :file_id
      sort created_at: :desc
      public? false  # Not exposed via GraphQL - internal intermediary resource
    end

    # Many-to-many relationships through intermediary resources
    # TODO: Uncomment when Media resource is implemented
    # many_to_many :media, Kyozo.Workspaces.Media do
    #   through Kyozo.Workspaces.FileMedia
    #   source_attribute_on_join_resource :file_id
    #   destination_attribute_on_join_resource :media_id
    # end

    many_to_many :notebooks, Kyozo.Workspaces.Notebook do
      through Kyozo.Workspaces.FileNotebook
      source_attribute_on_join_resource :file_id
      destination_attribute_on_join_resource :notebook_id
      public? true
    end

    many_to_many :storage_resources, Kyozo.Storage.StorageResource do
      through Kyozo.Workspaces.FileStorage
      source_attribute_on_join_resource :file_id
      destination_attribute_on_join_resource :storage_resource_id
      public? false  # Not exposed via GraphQL - internal storage management
    end

    has_one :primary_file_storage, Kyozo.Workspaces.FileStorage do
      destination_attribute :file_id
      filter expr(is_primary == true)
      public? false  # Not exposed via GraphQL - internal storage management
    end

    has_one :primary_image_storage, Kyozo.Workspaces.ImageStorage do
      destination_attribute :file_id
      filter expr(is_primary == true)
      public? false  # Not exposed via GraphQL - internal storage management
    end

    has_one :primary_file_media, Kyozo.Workspaces.FileMedia do
      destination_attribute :file_id
      filter expr(is_primary == true)
      public? false  # Not exposed via GraphQL - internal intermediary resource
    end

    has_one :primary_file_notebook, Kyozo.Workspaces.FileNotebook do
      destination_attribute :file_id
      filter expr(is_primary == true)
      public? false  # Not exposed via GraphQL - internal intermediary resource
    end

    has_one :primary_storage, Kyozo.Storage.StorageResource do
      manual Kyozo.Workspaces.File.Relationships.PrimaryStorage
      public? false  # Not exposed via GraphQL since StorageResource is internal
      description "Primary storage resource for this file"
    end

    # Convenience relationships to get the specialized resources directly
    # TODO: Uncomment when Media resource is implemented
    # has_one :primary_media, Kyozo.Workspaces.Media do
    #   manual Kyozo.Workspaces.File.Relationships.PrimaryMedia
    #   public? true
    #   description "Primary media resource associated with this file"
    # end

    has_one :primary_notebook, Kyozo.Workspaces.Notebook do
      manual Kyozo.Workspaces.File.Relationships.PrimaryNotebook
      public? true
    end

    # File hierarchy relationships
    belongs_to :parent, __MODULE__ do
      source_attribute :parent_file_id
      destination_attribute :id
      allow_nil? true
    end

    has_many :children, __MODULE__ do
      destination_attribute :parent_file_id
      sort [is_directory: :desc, name: :asc]
    end
  end

  calculations do
    calculate :author, :string, expr(team_member.user.name) do
      load [:team_member]
    end

    calculate :can_update, :boolean, {Kyozo.Calculations.CanPerformAction, action: :update}
    calculate :can_destroy, :boolean, {Kyozo.Calculations.CanPerformAction, action: :destroy}

    calculate :file_extension, :string, expr(
      if is_nil(file_path) do
        ""
      else
        fragment("regexp_replace(?, '^.*\\.', '')", file_path)
      end
    )

    calculate :file_metadata, :map do
      load [:primary_storage, :file_size, :version, :checksum, :storage_backend, :storage_metadata, :is_binary]

      calculation fn documents, _context ->
        Enum.map(documents, fn document ->
          # Try to get metadata from primary storage, fall back to document attributes
          if document.primary_storage do
            %{
              size: document.primary_storage.file_size,
              version: document.primary_storage.version,
              checksum: document.primary_storage.checksum,
              storage_backend: document.primary_storage.storage_backend,
              storage_metadata: document.primary_storage.storage_metadata || %{},
              is_binary: not String.starts_with?(document.primary_storage.mime_type, "text/"),
              last_modified: document.primary_storage.updated_at || document.updated_at,
              locator_id: document.primary_storage.locator_id
            }
          else
            # Fallback to document attributes for backward compatibility
            %{
              size: document.file_size,
              version: document.version,
              checksum: document.checksum,
              storage_backend: document.storage_backend,
              storage_metadata: document.storage_metadata || %{},
              is_binary: document.is_binary,
              last_modified: document.updated_at,
              locator_id: nil
            }
          end
        end)
      end
    end

    calculate :storage_info, :map do
      load [:primary_storage, :document_storages, :storage_backend, :storage_metadata]

      calculation fn documents, _context ->
        Enum.map(documents, fn document ->
          primary_backend = if document.primary_storage do
            document.primary_storage.storage_backend
          else
            document.storage_backend
          end

          %{
            backend: primary_backend,
            metadata: if document.primary_storage do
              document.primary_storage.storage_metadata || %{}
            else
              document.storage_metadata || %{}
            end,
            supports_versioning: primary_backend in [:git, :hybrid],
            supports_binary: primary_backend in [:s3, :hybrid],
            storage_count: length(document.document_storages || []),
            has_multiple_storages: length(document.document_storages || []) > 1,
            available_backends: document.document_storages
              |> Enum.map(fn ds -> ds.storage && ds.storage.storage_backend end)
              |> Enum.filter(&(&1))
              |> Enum.uniq()
          }
        end)
      end
    end

    calculate :is_text_file, :boolean do
      load [:primary_storage, :is_binary]

      calculation fn documents, _context ->
        Enum.map(documents, fn document ->
          if document.primary_storage do
            String.starts_with?(document.primary_storage.mime_type, "text/")
          else
            not document.is_binary
          end
        end)
      end
    end

    calculate :can_render, :boolean do
      load [:primary_storage, :content_type, :is_binary, :is_directory]

      calculation fn files, _context ->
        renderable_types = [
          "text/markdown", "application/x-jupyter-notebook",
          "text/html", "application/json", "text/x-python",
          "text/x-r", "text/x-julia"
        ]

        Enum.map(files, fn file ->
          # Directories can't be rendered as content
          if file.is_directory do
            false
          else
            content_type = file.content_type
            is_binary = if file.primary_storage do
              not String.starts_with?(file.primary_storage.mime_type, "text/")
            else
              file.is_binary
            end

            content_type in renderable_types and not is_binary
          end
        end)
      end
    end

    # New calculations for storage relationships
    calculate :has_primary_storage, :boolean do
      load [:primary_storage]

      calculation fn files, _context ->
        Enum.map(files, fn file ->
          not is_nil(file.primary_storage)
        end)
      end
    end

    calculate :storage_summary, :map do
      load [:file_storages, :storages]

      calculation fn files, _context ->
        Enum.map(files, fn file ->
          storages = file.file_storages || []

          %{
            total_storages: length(storages),
            relationship_types: storages |> Enum.map(& &1.relationship_type) |> Enum.uniq(),
            storage_backends: file.storages |> Enum.map(& &1.storage_backend) |> Enum.uniq(),
            total_size: file.storages |> Enum.map(& &1.file_size) |> Enum.sum(),
            has_versions: Enum.any?(storages, & &1.relationship_type == :version),
            has_backups: Enum.any?(storages, & &1.relationship_type == :backup)
          }
        end)
      end
    end

    calculate :depth, :integer do
      load [:parent]

      calculation fn files, _context ->
        Enum.map(files, fn file ->
          calculate_depth(file, 0)
        end)
      end
    end

    calculate :full_path, :string do
      load [:parent, :name]

      calculation fn files, _context ->
        Enum.map(files, fn file ->
          build_full_path(file, [])
        end)
      end
    end

    calculate :children_count, :integer do
      load [:children]

      calculation fn files, _context ->
        Enum.map(files, fn file ->
          if file.is_directory do
            length(file.children || [])
          else
            0
          end
        end)
      end
    end
  end

  validations do
    validate present([:name, :file_path, :team_id, :team_member])

    validate match(:name, ~r/^[^\/\\:*?"<>|]+$/) do
      message "Name contains invalid characters"
    end

    validate {Kyozo.Workspaces.File.Validations.ValidateFilePath, []}
    validate {Kyozo.Workspaces.File.Validations.ValidateContentType, []}
    validate {Kyozo.Workspaces.File.Validations.ValidateStorageBackend, []}
    validate {Kyozo.Workspaces.File.Validations.ValidateDirectoryConstraints, []}
    validate {Kyozo.Workspaces.File.Validations.ValidateParentDirectory, []}
  end

  changes do
    change before_action({Changes.BuildFilePath, []}), on: [:create]
    change before_action({Changes.DetectBinaryContent, []}), on: [:create, :update]
    change before_action({Changes.ValidateFileSize, []}), on: [:create, :update]

    change after_action({Changes.ClearRenderCache, []}), on: [:update]
  end

  preparations do
    prepare build(load: [:author])
  end

  # Resource-specific functions

  @doc """
  Determines the appropriate storage backend for a file.
  """
  def determine_storage_backend(file) do
    FileTypeMapper.determine_storage_backend(file.name, file.content_type, :file)
  end

  @doc """
  Determines if a file should be resolved to a specialized resource type.
  """
  def should_resolve_to_specialized?(file) do
    storage_type = FileTypeMapper.determine_storage_type(file.name, file.content_type)
    storage_type in [:image, :notebook]
  end

  @doc """
  Gets the appropriate intermediary resource module for a file.
  """
  def get_intermediary_module(file) do
    storage_type = FileTypeMapper.determine_storage_type(file.name, file.content_type)

    case storage_type do
      :image -> Kyozo.Workspaces.FileMedia
      :notebook -> Kyozo.Workspaces.FileNotebook
      _ -> nil
    end
  end

  @doc """
  Gets the full storage path for the file.
  """
  def storage_path(%{team_id: team_id, file_path: file_path}) do
    Storage.build_storage_path(team_id, file_path)
  end

  @doc """
  Checks if the file can be rendered to the target format.
  """
  def can_render_as?(%{content_type: content_type, is_binary: is_binary, is_directory: is_directory}, target_format) do
    not is_directory and not is_binary and content_type in renderable_content_types() and
    target_format in supported_render_formats(content_type)
  end

  @doc """
  Gets supported render formats for a content type.
  """
  def supported_render_formats("text/markdown"), do: [:html, :pdf, :docx]
  def supported_render_formats("application/x-jupyter-notebook"), do: [:html, :pdf, :slides]
  def supported_render_formats("text/html"), do: [:pdf, :png]
  def supported_render_formats("application/json"), do: [:html, :csv]
  def supported_render_formats("text/x-python"), do: [:html]
  def supported_render_formats(_), do: [:html]

  @doc """
  Gets all content types that support rendering.
  """
  def renderable_content_types do
    [
      "text/markdown", "application/x-jupyter-notebook",
      "text/html", "application/json", "text/x-python",
      "text/x-r", "text/x-julia"
    ]
  end

  @doc """
  Builds file path from name and content type.
  """
  def build_file_path(name, content_type, is_directory \\ false) do
    if is_directory do
      # Directories don't have extensions
      name
      |> String.replace(~r/[^a-zA-Z0-9\-_\s]/, "")
      |> String.replace(~r/\s+/, "_")
      |> String.downcase()
    else
      extension = case content_type do
        "text/markdown" -> ".md"
        "application/x-jupyter-notebook" -> ".ipynb"
        "text/html" -> ".html"
        "application/json" -> ".json"
        "text/x-python" -> ".py"
        "text/x-r" -> ".R"
        "text/x-julia" -> ".jl"
        "text/x-sql" -> ".sql"
        "application/javascript" -> ".js"
        "text/css" -> ".css"
        _ -> ".txt"
      end

      sanitized_name = name
      |> String.replace(~r/[^a-zA-Z0-9\-_\s]/, "")
      |> String.replace(~r/\s+/, "_")
      |> String.downcase()

      sanitized_name <> extension
    end
  end

  @doc """
  Checks if content appears to be binary.
  """
  def binary_content?(content) when is_binary(content) do
    # Simple heuristic: check for null bytes and non-printable characters
    String.contains?(content, <<0>>) or
    String.length(content) != String.length(String.printable(content))
  end

  def binary_content?(_), do: false

  # Private helper functions for calculations
  defp calculate_depth(file, current_depth) do
    if file.parent do
      calculate_depth(file.parent, current_depth + 1)
    else
      current_depth
    end
  end

  defp build_full_path(file, path_parts) do
    parts = [file.name | path_parts]

    if file.parent do
      build_full_path(file.parent, parts)
    else
      "/" <> Enum.join(parts, "/")
    end
  end
end
