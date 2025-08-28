defmodule Dirup.Collaboration.Session do
  @moduledoc """
  Collaboration session resource for managing real-time collaborative editing.

  A session represents an active collaborative editing context for a document,
  notebook, or file. It tracks participants, manages operational transform state,
  and coordinates real-time updates between users.
  """

  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Collaboration,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "collaboration_sessions"
    repo Dirup.Repo

    identity_wheres_to_sql unique_active_resource: "status IN ('active', 'paused')"

    references do
      reference :owner, on_delete: :delete
      reference :team, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_sessions do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [last_activity_at: :desc])
    end

    read :list_active_sessions do
      filter expr(status == :active)
      prepare build(sort: [last_activity_at: :desc])
    end

    read :get_by_resource do
      argument :resource_type, :atom, allow_nil?: false
      argument :resource_id, :uuid, allow_nil?: false

      filter expr(
               resource_type == ^arg(:resource_type) and
                 resource_id == ^arg(:resource_id) and
                 status in [:active, :paused]
             )
    end

    create :create do
      accept [:resource_type, :resource_id, :title, :max_participants, :settings, :metadata]

      change relate_actor(:owner)
      change relate_actor(:team, field: :team_id)

      change set_attribute(:participants_count, 1)
      change set_attribute(:status, :active)
    end

    update :add_participant do
      change increment(:participants_count, amount: 1)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :remove_participant do
      change increment(:participants_count, amount: -1)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :increment_version do
      change increment(:document_version, amount: 1)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :update_content_state do
      accept [:content_state]
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :update_settings do
      accept [:settings]
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :pause_session do
      change set_attribute(:status, :paused)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :resume_session do
      change set_attribute(:status, :active)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :end_session do
      change set_attribute(:status, :ended)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :touch_activity do
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:team)
    end

    policy action_type([:create, :update]) do
      authorize_if relates_to_actor_via(:team)
    end

    policy action_type(:destroy) do
      authorize_if expr(owner_id == ^actor(:id))
      authorize_if relates_to_actor_via(:team)
    end
  end

  validations do
    validate present([:resource_type, :resource_id, :title, :status])

    validate numericality(:participants_count, greater_than_or_equal_to: 0)
    validate numericality(:document_version, greater_than_or_equal_to: 0)

    validate numericality(:max_participants, greater_than: 0) do
      where present(:max_participants)
    end

    validate compare(:participants_count, less_than_or_equal_to: :max_participants) do
      where present(:max_participants)
      message "Participants count cannot exceed maximum"
    end

    validate attribute_does_not_equal(:ended_at, nil) do
      where attribute_equals(:status, :ended)
      message "Ended sessions must have an end timestamp"
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :resource_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:document, :notebook, :file]
      description "Type of resource being collaboratively edited"
    end

    attribute :resource_id, :uuid do
      allow_nil? false
      public? true
      description "ID of the resource being edited"
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      description "Human-readable title for the session"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:active, :paused, :ended]
      default :active
      description "Current status of the collaboration session"
    end

    attribute :document_version, :integer do
      allow_nil? false
      public? true
      default 0
      description "Current version number for operational transform"
    end

    attribute :content_state, :map do
      public? true
      default %{}
      description "Current collaborative state of the content"
    end

    attribute :participants_count, :integer do
      allow_nil? false
      public? true
      default 0
      description "Number of active participants"
    end

    attribute :max_participants, :integer do
      public? true
      default 50
      description "Maximum allowed participants"
    end

    attribute :settings, :map do
      public? true

      default %{
        "auto_save_interval" => 5000,
        "cursor_timeout" => 30000,
        "operation_batch_size" => 10,
        "enable_live_cursors" => true,
        "enable_user_awareness" => true,
        "conflict_resolution_strategy" => "last_write_wins"
      }

      description "Session configuration settings"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional session metadata"
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :started_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
      description "When the collaboration session started"
    end

    attribute :ended_at, :utc_datetime_usec do
      public? true
      description "When the collaboration session ended"
    end

    attribute :last_activity_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
      description "Last activity timestamp in the session"
    end
  end

  relationships do
    belongs_to :owner, Dirup.Accounts.User do
      allow_nil? false
      public? true
      description "User who created the collaboration session"
    end

    belongs_to :team, Dirup.Accounts.Team do
      allow_nil? false
      public? true
      description "Team that owns this collaboration session"
    end

    has_many :operations, Dirup.Collaboration.Operation do
      description "Operations performed in this session"
    end

    has_many :cursors, Dirup.Collaboration.Cursor do
      description "Active cursors in this session"
    end

    has_many :presences, Dirup.Collaboration.Presence do
      description "User presence information for this session"
    end
  end

  calculations do
    calculate :is_active, :boolean do
      description "Whether the session is currently active"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.status == :active))
      end
    end

    calculate :duration_seconds, :integer do
      description "Duration of the session in seconds"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          end_time = record.ended_at || DateTime.utc_now()
          DateTime.diff(end_time, record.started_at, :second)
        end)
      end
    end

    calculate :is_full, :boolean do
      description "Whether the session has reached max participants"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          record.max_participants && record.participants_count >= record.max_participants
        end)
      end
    end

    calculate :inactivity_seconds, :integer do
      description "Seconds since last activity"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.last_activity_at, :second)
        end)
      end
    end
  end

  aggregates do
    count :operations_count, :operations
    count :active_cursors_count, :cursors, filter: expr(is_active == true)
    count :active_presences_count, :presences, filter: expr(status == :online)

    max :latest_operation_timestamp, :operations, :created_at

    first :oldest_operation, :operations, :created_at do
      sort created_at: :asc
    end

    list :participant_ids, :presences, :user_id do
      filter expr(status in [:online, :away])
      uniq? true
    end
  end

  identities do
    identity :unique_active_resource, [:resource_type, :resource_id, :status] do
      where expr(status in [:active, :paused])
      message "Only one active collaboration session allowed per resource"
    end
  end
end
