defmodule Kyozo.Collaboration.Presence do
  @moduledoc """
  Presence resource for tracking user awareness and activity in collaborative sessions.

  Presence tracks whether users are online, away, typing, or have left a session.
  This enables showing user activity indicators, typing notifications, and
  general awareness of who is actively participating in a collaboration session.
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Collaboration,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "collaboration_presences"
    repo Kyozo.Repo

    references do
      reference :session, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:session_id, :user_id], unique: true
      index [:session_id, :status]
      index [:session_id, :last_seen_at]
      index [:user_id, :status]
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_presences do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [last_seen_at: :desc])
    end

    read :list_session_presences do
      argument :session_id, :uuid, allow_nil?: false
      argument :active_only, :boolean, default: true

      filter expr(session_id == ^arg(:session_id))

      prepare fn query, _context ->
        if Ash.Query.get_argument(query, :active_only) do
          Ash.Query.filter(
            query,
            expr(status in [:online, :away, :typing] and last_seen_at > ago(5, :minute))
          )
        else
          query
        end
      end

      prepare build(sort: [last_seen_at: :desc])
    end

    read :list_online_users do
      argument :session_id, :uuid, allow_nil?: false

      filter expr(session_id == ^arg(:session_id) and status == :online)
      prepare build(sort: [last_seen_at: :desc])
    end

    read :get_user_presence do
      argument :session_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      filter expr(session_id == ^arg(:session_id) and user_id == ^arg(:user_id))
    end

    create :create do
      accept [
        :status,
        :user_agent,
        :ip_address,
        :client_info,
        :metadata
      ]

      change relate_actor(:session, field: :session_id)
      change relate_actor(:user, field: :user_id)

      change set_attribute(:joined_at, &DateTime.utc_now/0)
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)
    end

    update :update_status do
      accept [:status, :metadata]
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)

      change fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        case status do
          :typing ->
            Ash.Changeset.change_attribute(changeset, :last_typing_at, DateTime.utc_now())

          :away ->
            Ash.Changeset.change_attribute(changeset, :away_since, DateTime.utc_now())

          :offline ->
            Ash.Changeset.change_attribute(changeset, :left_at, DateTime.utc_now())

          _ ->
            changeset
        end
      end
    end

    update :set_online do
      change set_attribute(:status, :online)
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)
      change set_attribute(:away_since, nil)
    end

    update :set_away do
      change set_attribute(:status, :away)
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)
      change set_attribute(:away_since, &DateTime.utc_now/0)
    end

    update :set_typing do
      change set_attribute(:status, :typing)
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)
      change set_attribute(:last_typing_at, &DateTime.utc_now/0)
    end

    update :set_offline do
      change set_attribute(:status, :offline)
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)
      change set_attribute(:left_at, &DateTime.utc_now/0)
    end

    update :update_activity do
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)

      change fn changeset, _context ->
        current_status = Ash.Changeset.get_data(changeset, :status)

        # Auto-set to online if currently away and activity detected
        if current_status == :away do
          changeset
          |> Ash.Changeset.change_attribute(:status, :online)
          |> Ash.Changeset.change_attribute(:away_since, nil)
        else
          changeset
        end
      end
    end

    update :update_metadata do
      accept [:metadata]
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:session, :team])
    end

    policy action_type([:create, :update]) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if relates_to_actor_via([:session, :owner])
    end

    policy action_type(:destroy) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if relates_to_actor_via([:session, :owner])
    end
  end

  validations do
    validate present([:status, :joined_at, :last_seen_at])

    validate attribute_does_not_equal(:left_at, nil) do
      where attribute_equals(:status, :offline)
      message "Offline users must have a left_at timestamp"
    end

    validate attribute_does_not_equal(:away_since, nil) do
      where attribute_equals(:status, :away)
      message "Away users must have an away_since timestamp"
    end

    validate compare(:joined_at, less_than_or_equal_to: :last_seen_at) do
      message "Last seen time cannot be before join time"
    end

    validate compare(:joined_at, less_than_or_equal_to: :left_at) do
      where present(:left_at)
      message "Left time cannot be before join time"
    end

    validate compare(:away_since, greater_than_or_equal_to: :joined_at) do
      where present(:away_since)
      message "Away time cannot be before join time"
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:online, :away, :typing, :idle, :offline]
      default :online
      description "Current presence status of the user"
    end

    attribute :user_agent, :string do
      public? true
      description "Browser/client user agent string"
    end

    attribute :ip_address, :string do
      public? true
      description "IP address of the user's connection"
    end

    attribute :client_info, :map do
      public? true
      default %{}
      description "Information about the user's client (browser, OS, etc.)"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional presence metadata (focus state, etc.)"
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :joined_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      description "When the user joined the collaboration session"
    end

    attribute :left_at, :utc_datetime_usec do
      public? true
      description "When the user left the collaboration session"
    end

    attribute :last_seen_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      description "Last activity timestamp from this user"
    end

    attribute :away_since, :utc_datetime_usec do
      public? true
      description "When the user went away/idle"
    end

    attribute :last_typing_at, :utc_datetime_usec do
      public? true
      description "Last time the user was typing"
    end
  end

  relationships do
    belongs_to :session, Kyozo.Collaboration.Session do
      allow_nil? false
      public? true
      description "Collaboration session this presence belongs to"
    end

    belongs_to :user, Kyozo.Accounts.User do
      allow_nil? false
      public? true
      description "User this presence information is for"
    end
  end

  calculations do
    calculate :is_active, :boolean do
      description "Whether the user is actively present"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.status in [:online, :typing]))
      end
    end

    calculate :is_typing_recently, :boolean do
      description "Whether the user was typing in the last 10 seconds"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.last_typing_at do
            DateTime.diff(now, record.last_typing_at, :second) < 10
          else
            false
          end
        end)
      end
    end

    calculate :session_duration_seconds, :integer do
      description "How long the user has been in the session (seconds)"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          end_time = record.left_at || DateTime.utc_now()
          DateTime.diff(end_time, record.joined_at, :second)
        end)
      end
    end

    calculate :idle_duration_seconds, :integer do
      description "Seconds since last activity"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.last_seen_at, :second)
        end)
      end
    end

    calculate :away_duration_seconds, :integer do
      description "Seconds since going away"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.away_since do
            DateTime.diff(now, record.away_since, :second)
          else
            0
          end
        end)
      end
    end

    calculate :should_auto_away, :boolean do
      description "Whether the user should be automatically marked as away"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.status == :online do
            idle_seconds = DateTime.diff(now, record.last_seen_at, :second)
            # 5 minutes
            idle_seconds > 300
          else
            false
          end
        end)
      end
    end

    calculate :should_auto_offline, :boolean do
      description "Whether the user should be automatically marked as offline"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.status in [:away, :idle] do
            idle_seconds = DateTime.diff(now, record.last_seen_at, :second)
            # 30 minutes
            idle_seconds > 1800
          else
            false
          end
        end)
      end
    end

    calculate :display_name, :string do
      description "Display name for the user"
      load [:user]

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          if record.user do
            record.user.name || record.user.email || "Unknown User"
          else
            "Unknown User"
          end
        end)
      end
    end

    calculate :user_avatar, :string do
      description "Avatar URL for the user"
      load [:user]

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          if record.user && record.user.profile do
            Map.get(record.user.profile, :avatar_url)
          else
            nil
          end
        end)
      end
    end

    calculate :status_display, :string do
      description "Human-readable status display"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.status do
            :online -> "Online"
            :away -> "Away"
            :typing -> "Typing..."
            :idle -> "Idle"
            :offline -> "Offline"
            _ -> "Unknown"
          end
        end)
      end
    end
  end

  aggregates do
    count :session_participant_count, [:session, :presences],
      filter: expr(status in [:online, :away, :typing])

    exists :has_active_participants, [:session, :presences],
      filter: expr(status in [:online, :typing] and last_seen_at > ago(1, :minute))

    max :latest_activity, [:session, :presences], :last_seen_at

    list :active_user_ids, [:session, :presences], :user_id do
      filter expr(status in [:online, :typing])
      uniq? true
    end
  end

  identities do
    identity :unique_user_session_presence, [:session_id, :user_id] do
      message "Each user can only have one presence record per session"
    end
  end
end
