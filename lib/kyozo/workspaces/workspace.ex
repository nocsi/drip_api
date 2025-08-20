defmodule Kyozo.Workspaces.Workspace do
  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :status,
             :storage_backend,
             :settings,
             :tags,
             :storage_path,
             :git_repository_url,
             :git_branch,
             :created_at,
             :updated_at,
             :archived_at
           ]}

  @moduledoc """
  Workspace resource representing a collaborative workspace container.

  A workspace is the primary organizational unit that contains documents, notebooks,
  and other files. It belongs to a team and provides a structured environment for
  collaborative work with version control, storage management, and access control.
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Kyozo.Workspaces.Storage
  alias Kyozo.Workspaces.Events

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    type "workspace"

    routes do
      base "/workspaces"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end

    # JSON-LD context metadata temporarily disabled during GraphQL cleanup
    # TODO: Re-enable JSON-LD metadata when AshJsonApi meta function is available
  end

  postgres do
    table "workspaces"
    repo Kyozo.Repo

    references do
      reference :team, on_delete: :delete, index?: true
      reference :created_by, on_delete: :nilify, index?: true
    end

    custom_indexes do
      index [:team_id, :name], unique: true
      index [:team_id, :status]
      index [:team_id, :storage_backend]
      index [:team_id, :updated_at]
      index [:team_id, :created_at]
    end
  end

  # TODO: Re-enable events after fixing AshEvents.Resource extension
  # events do
  #   event :workspace_created, Kyozo.Workspaces.Events.WorkspaceCreated
  #   event :workspace_updated, Kyozo.Workspaces.Events.WorkspaceUpdated
  #   event :workspace_deleted, Kyozo.Workspaces.Events.WorkspaceDeleted
  #   event :workspace_archived, Kyozo.Workspaces.Events.WorkspaceArchived
  #   event :workspace_restored, Kyozo.Workspaces.Events.WorkspaceRestored
  # end

  actions do
    default_accept [:name, :description, :storage_backend, :settings]
    defaults [:create, :read, :update, :destroy]

    read :list_workspaces do
      prepare build(
                load: [
                  :created_by_user,
                  :file_count,
                  :notebook_count,
                  :total_size,
                  :last_activity
                ],
                filter: [status: [:active, :archived]]
              )
    end

    read :list_active_workspaces do
      prepare build(
                filter: [status: :active],
                load: [:created_by_user, :file_count, :notebook_count, :last_activity],
                sort: [updated_at: :desc]
              )
    end

    read :list_archived_workspaces do
      prepare build(
                filter: [status: :archived],
                load: [:created_by_user, :file_count, :notebook_count],
                sort: [archived_at: :desc]
              )
    end

    read :search_workspaces do
      argument :query, :string, allow_nil?: false

      prepare build(
                filter:
                  expr(
                    contains(name, ^arg(:query)) or
                      contains(description, ^arg(:query)) or
                      contains(tags, ^arg(:query))
                  ),
                load: [:created_by_user, :file_count, :notebook_count]
              )
    end

    create :create_workspace do
      accept [:name, :description, :storage_backend, :settings, :team_id]
      argument :initialize_git, :boolean, default: true
      argument :create_readme, :boolean, default: true

      change relate_actor(:created_by)
      change set_attribute(:status, :active)
      change {Kyozo.Workspaces.Workspace.Changes.InitializeStorage, []}
      change {Kyozo.Workspaces.Workspace.Changes.CreateInitialFiles, []}

      after_action(
        {Kyozo.Workspaces.Workspace.Changes.EmitWorkspaceEvent, event: :workspace_created}
      )
    end

    create :seed_workspace do
      accept [:name, :description, :storage_backend, :settings, :team_id, :created_by_id]

      change set_attribute(:status, :active)
      change {Kyozo.Workspaces.Workspace.Changes.SeedStoragePath, []}
    end

    update :update_workspace do
      accept [:name, :description, :tags, :settings]

      change {Kyozo.Workspaces.Workspace.Changes.ValidateSettings, []}

      after_action(
        {Kyozo.Workspaces.Workspace.Changes.EmitWorkspaceEvent, event: :workspace_updated}
      )
    end

    update :archive_workspace do
      accept []

      change set_attribute(:status, :archived)
      change set_attribute(:archived_at, expr(now()))

      after_action(
        {Kyozo.Workspaces.Workspace.Changes.EmitWorkspaceEvent, event: :workspace_archived}
      )
    end

    update :restore_workspace do
      accept []

      change set_attribute(:status, :active)
      change set_attribute(:archived_at, nil)

      after_action(
        {Kyozo.Workspaces.Workspace.Changes.EmitWorkspaceEvent, event: :workspace_restored}
      )
    end

    update :change_storage_backend do
      argument :new_backend, :atom, allow_nil?: false
      argument :migrate_files, :boolean, default: true

      change {Kyozo.Workspaces.Workspace.Changes.MigrateStorage, []}

      after_action(
        {Kyozo.Workspaces.Workspace.Changes.EmitWorkspaceEvent, event: :workspace_updated}
      )
    end

    action :get_storage_info, :map do
      run {Kyozo.Workspaces.Workspace.Changes.GetStorageInfo, []}
    end

    action :get_statistics, :map do
      run {Kyozo.Workspaces.Workspace.Changes.GetWorkspaceStatistics, []}
    end

    action :cleanup_storage, :struct do
      argument :dry_run, :boolean, default: true

      run {Kyozo.Workspaces.Workspace.Changes.CleanupStorage, []}
    end

    action :duplicate_workspace, :struct do
      argument :new_name, :string, allow_nil?: true
      argument :copy_to_team_id, :uuid, allow_nil?: true
      argument :include_files, :boolean, default: true
      argument :include_nfiles, :boolean, default: true

      run {Kyozo.Workspaces.Workspace.Changes.DuplicateWorkspace, []}
    end

    destroy :soft_delete do
      accept []

      change set_attribute(:status, :deleted)
      change set_attribute(:deleted_at, expr(now()))

      after_action(
        {Kyozo.Workspaces.Workspace.Changes.EmitWorkspaceEvent, event: :workspace_deleted}
      )
    end

    destroy :hard_delete do
      accept []

      change {Kyozo.Workspaces.Workspace.Changes.DeleteStorage, []}

      after_action(
        {Kyozo.Workspaces.Workspace.Changes.EmitWorkspaceEvent, event: :workspace_deleted}
      )
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
      authorize_if relates_to_actor_via([:team, :users])
      authorize_if relates_to_actor_via(:created_by)
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:created_by)
      authorize_if expr(exists(team.users, id == ^actor(:id) and team_members.role == "admin"))
    end

    policy action([:get_storage_info, :get_statistics, :cleanup_storage, :duplicate_workspace]) do
      authorize_if relates_to_actor_via([:team, :users])
    end

    policy action(:change_storage_backend) do
      authorize_if relates_to_actor_via(:created_by)
      authorize_if expr(exists(team.users, id == ^actor(:id) and team_members.role == "admin"))
    end
  end

  pub_sub do
    module KyozoWeb.Endpoint

    publish_all :create, ["workspaces", :team_id]
    publish_all :update, ["workspaces", :team_id]
    publish_all :destroy, ["workspaces", :team_id]
  end

  preparations do
    prepare build(load: [:created_by_user])

    prepare build(filter: [deleted_at: [is_nil: true]])
  end

  changes do
    # Temporarily disabled to isolate BadFunctionError
    # change before_action({Kyozo.Workspaces.Workspace.Changes.BuildStoragePath, []}), on: [:create]
    # change before_action({Kyozo.Workspaces.Workspace.Changes.NormalizeSettings, []}), on: [:create, :update]
    change after_action({Kyozo.Workspaces.Workspace.Changes.UpdateStorageMetadata, []}),
      on: [:update]
  end

  validations do
    validate present([:name, :team_id, :storage_backend, :status])

    validate match(:name, ~r/^[a-zA-Z0-9\-_\s]+$/) do
      message "Name can only contain letters, numbers, spaces, hyphens, and underscores"
    end

    validate {Kyozo.Workspaces.Workspace.Validations.ValidateStorageBackend, []}
    validate {Kyozo.Workspaces.Workspace.Validations.ValidateSettings, []}
    validate {Kyozo.Workspaces.Workspace.Validations.UniqueNamePerTeam, []}
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
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:active, :archived, :deleted]
      default :active
    end

    attribute :storage_backend, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:git, :s3, :hybrid]
      default :hybrid
    end

    attribute :settings, :map do
      public? true
      default %{}
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    attribute :storage_path, :string do
      public? true
    end

    attribute :storage_metadata, :map do
      public? true
      default %{}
    end

    attribute :git_repository_url, :string do
      public? true
    end

    attribute :git_branch, :string do
      public? true
      default "main"
    end

    attribute :archived_at, :utc_datetime_usec do
      public? true
    end

    attribute :deleted_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    # belongs_to :team_member, Kyozo.Workspace.TeamMember do
    #   allow_nil? false
    # end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :created_by, Kyozo.Accounts.User do
      allow_nil? true
      attribute_writable? true
    end

    has_many :files, Kyozo.Workspaces.File do
      destination_attribute :workspace_id
    end

    has_many :notebooks, Kyozo.Workspaces.Notebook do
      destination_attribute :workspace_id
    end

    has_many :load_events, Kyozo.Workspaces.LoadEvent do
      description "Events generated during workspace loading"
    end
  end

  calculations do
    calculate :author, :string, expr(team_member.user.name)
    calculate :can_update, :boolean, {Kyozo.Calculations.CanPerformAction, action: :update}
    calculate :can_destroy, :boolean, {Kyozo.Calculations.CanPerformAction, action: :destroy}

    calculate :created_by_user, :string, expr(created_by.name) do
      load [:created_by]
    end

    calculate :file_count, :integer do
      calculation expr(count(files, query: [filter: [deleted_at: [is_nil: true]]]))
    end

    calculate :notebook_count, :integer do
      calculation expr(count(notebooks, query: [filter: [deleted_at: [is_nil: true]]]))
    end

    calculate :total_files, :integer do
      load [:files_count, :notebook_count]

      calculation fn workspaces, _context ->
        Enum.map(workspaces, fn workspace ->
          (workspace.files || 0) + (workspace.notebook_count || 0)
        end)
      end
    end

    calculate :total_size, :integer do
      calculation expr(
                    sum(files, field: :file_size, query: [filter: [deleted_at: [is_nil: true]]]) +
                      sum(notebooks,
                        field: :file_size,
                        query: [filter: [deleted_at: [is_nil: true]]]
                      )
                  )
    end

    calculate :last_activity, :utc_datetime_usec do
      calculation expr(
                    max([
                      max(files,
                        field: :updated_at,
                        query: [filter: [deleted_at: [is_nil: true]]]
                      ),
                      max(notebooks,
                        field: :updated_at,
                        query: [filter: [deleted_at: [is_nil: true]]]
                      ),
                      updated_at
                    ])
                  )
    end

    calculate :storage_info, :map do
      load [:storage_backend, :storage_metadata, :git_repository_url]

      calculation fn workspaces, _context ->
        Enum.map(workspaces, fn workspace ->
          %{
            backend: workspace.storage_backend,
            metadata: workspace.storage_metadata,
            git_url: workspace.git_repository_url,
            supports_versioning: workspace.storage_backend in [:git, :hybrid],
            supports_binary: workspace.storage_backend in [:s3, :hybrid]
          }
        end)
      end
    end

    calculate :is_active, :boolean, expr(status == :active)
    calculate :is_archived, :boolean, expr(status == :archived)
    calculate :is_deleted, :boolean, expr(status == :deleted)

    calculate :full_storage_path, :string do
      load [:storage_path, :team]

      calculation fn workspaces, _context ->
        Enum.map(workspaces, fn workspace ->
          if workspace.storage_path do
            workspace.storage_path
          else
            Storage.build_storage_path(workspace.team.id, workspace.name)
          end
        end)
      end
    end
  end

  # Resource-specific functions

  @doc """
  Gets the storage path for the workspace.
  """
  def storage_path(%{team_id: team_id, name: name, storage_path: nil}) do
    Storage.build_storage_path(team_id, name)
  end

  def storage_path(%{storage_path: storage_path}) when is_binary(storage_path) do
    storage_path
  end

  @doc """
  Determines if workspace supports versioning based on storage backend.
  """
  def supports_versioning?(%{storage_backend: backend}) do
    backend in [:git, :hybrid]
  end

  @doc """
  Determines if workspace supports binary files based on storage backend.
  """
  def supports_binary?(%{storage_backend: backend}) do
    backend in [:s3, :hybrid]
  end

  @doc """
  Gets the appropriate storage provider for the workspace.
  """
  def storage_provider(%{storage_backend: backend}) do
    Storage.get_provider(backend)
  end

  @doc """
  Builds default settings for a workspace.
  """
  def default_settings do
    %{
      "auto_save" => true,
      "auto_commit" => false,
      # 10MB
      "max_file_size" => 10_485_760,
      "allowed_file_types" => ["*"],
      "enable_notifications" => true,
      "enable_real_time_collaboration" => true,
      "git_auto_push" => false,
      "backup_enabled" => true,
      "backup_frequency" => "daily"
    }
  end

  @doc """
  Validates workspace settings structure.
  """
  def valid_settings?(settings) when is_map(settings) do
    required_keys = ["auto_save", "max_file_size", "allowed_file_types"]
    Enum.all?(required_keys, &Map.has_key?(settings, &1))
  end

  def valid_settings?(_), do: false

  @doc """
  Normalizes workspace name for storage path.
  """
  def normalize_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.replace(~r/[^a-zA-Z0-9\-_\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.downcase()
  end

  @doc """
  Gets workspace statistics.
  """
  def get_statistics(workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      status: workspace.status,
      created_at: workspace.created_at,
      updated_at: workspace.updated_at,
      storage_backend: workspace.storage_backend,
      total_files: Map.get(workspace, :total_files, 0),
      total_size: Map.get(workspace, :total_size, 0),
      notebook_count: Map.get(workspace, :notebook_count, 0),
      last_activity: Map.get(workspace, :last_activity, 0)
    }
  end
end
