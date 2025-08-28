defmodule Dirup.Collaboration.Cursor do
  @moduledoc """
  Cursor resource for tracking live cursor positions in collaborative editing.

  Cursors represent the real-time position and selection state of users
  in a collaborative editing session. This enables showing other users'
  cursor positions and selections as they edit.
  """

  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Collaboration,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "collaboration_cursors"
    repo Dirup.Repo

    references do
      reference :session, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:session_id, :user_id], unique: true
      index [:session_id, :is_active]
      index [:session_id, :updated_at]
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_cursors do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [updated_at: :desc])
    end

    read :list_session_cursors do
      argument :session_id, :uuid, allow_nil?: false
      argument :active_only, :boolean, default: true

      filter expr(session_id == ^arg(:session_id))

      prepare fn query, _context ->
        if Ash.Query.get_argument(query, :active_only) do
          Ash.Query.filter(query, expr(is_active == true and updated_at > ago(30, :second)))
        else
          query
        end
      end

      prepare build(sort: [updated_at: :desc])
    end

    read :get_user_cursor do
      argument :session_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      filter expr(session_id == ^arg(:session_id) and user_id == ^arg(:user_id))
    end

    create :create do
      accept [
        :position,
        :selection_start,
        :selection_end,
        :selection_direction,
        :cursor_color,
        :metadata
      ]

      change relate_actor(:session, field: :session_id)
      change relate_actor(:user, field: :user_id)

      change set_attribute(:is_active, true)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)

      # Auto-assign cursor color if not provided
      change fn changeset, _context ->
        if !Ash.Changeset.get_attribute(changeset, :cursor_color) do
          user_id = Ash.Changeset.get_attribute(changeset, :user_id)
          color = generate_cursor_color(user_id)
          Ash.Changeset.change_attribute(changeset, :cursor_color, color)
        else
          changeset
        end
      end
    end

    update :update_position do
      accept [
        :position,
        :selection_start,
        :selection_end,
        :selection_direction,
        :metadata
      ]

      change set_attribute(:is_active, true)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :update_selection do
      accept [:selection_start, :selection_end, :selection_direction]

      change set_attribute(:is_active, true)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :set_inactive do
      change set_attribute(:is_active, false)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :set_active do
      change set_attribute(:is_active, true)
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :update_metadata do
      accept [:metadata]
      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
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
    validate numericality(:position, greater_than_or_equal_to: 0) do
      where present(:position)
    end

    validate numericality(:selection_start, greater_than_or_equal_to: 0) do
      where present(:selection_start)
    end

    validate numericality(:selection_end, greater_than_or_equal_to: 0) do
      where present(:selection_end)
    end

    validate compare(:selection_start, less_than_or_equal_to: :selection_end) do
      where present([:selection_start, :selection_end])
      message "Selection start must be less than or equal to selection end"
    end

    validate match(:cursor_color, ~r/^#[0-9A-Fa-f]{6}$/) do
      where present(:cursor_color)
      message "Cursor color must be a valid hex color"
    end

    validate attribute_in(:selection_direction, [:forward, :backward, :none]) do
      where present(:selection_direction)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :position, :integer do
      allow_nil? false
      public? true
      default 0
      description "Current cursor position in the document"
    end

    attribute :selection_start, :integer do
      public? true
      description "Start position of current selection"
    end

    attribute :selection_end, :integer do
      public? true
      description "End position of current selection"
    end

    attribute :selection_direction, :atom do
      public? true
      constraints one_of: [:forward, :backward, :none]
      default :none
      description "Direction of the selection"
    end

    attribute :cursor_color, :string do
      public? true
      description "Color to display this cursor (hex format)"
    end

    attribute :is_active, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether the cursor is currently active"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional cursor metadata (e.g., typing indicator)"
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :last_activity_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
      description "Last time this cursor was updated"
    end
  end

  relationships do
    belongs_to :session, Dirup.Collaboration.Session do
      allow_nil? false
      public? true
      description "Collaboration session this cursor belongs to"
    end

    belongs_to :user, Dirup.Accounts.User do
      allow_nil? false
      public? true
      description "User who owns this cursor"
    end
  end

  calculations do
    calculate :has_selection, :boolean do
      description "Whether the cursor has an active selection"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          record.selection_start != nil and
            record.selection_end != nil and
            record.selection_start != record.selection_end
        end)
      end
    end

    calculate :selection_length, :integer do
      description "Length of the current selection"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          if record.selection_start && record.selection_end do
            abs(record.selection_end - record.selection_start)
          else
            0
          end
        end)
      end
    end

    calculate :is_typing, :boolean do
      description "Whether the user appears to be actively typing"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.last_activity_at do
            diff_seconds = DateTime.diff(now, record.last_activity_at, :second)
            diff_seconds < 5 and Map.get(record.metadata || %{}, "typing", false)
          else
            false
          end
        end)
      end
    end

    calculate :inactivity_seconds, :integer do
      description "Seconds since last cursor activity"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.last_activity_at, :second)
        end)
      end
    end

    calculate :is_stale, :boolean do
      description "Whether the cursor should be considered stale"

      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          diff_seconds = DateTime.diff(now, record.last_activity_at, :second)
          diff_seconds > 30 or not record.is_active
        end)
      end
    end
  end

  aggregates do
    exists :has_recent_activity, [:session, :cursors],
      filter: expr(updated_at > ago(5, :second) and is_active == true)
  end

  identities do
    identity :unique_user_session_cursor, [:session_id, :user_id] do
      message "Each user can only have one cursor per session"
    end
  end

  # Helper function to generate consistent cursor colors for users
  defp generate_cursor_color(user_id) when is_binary(user_id) do
    # Generate a consistent color based on user_id hash
    hash = :crypto.hash(:md5, user_id) |> Base.encode16() |> String.downcase()

    # Take first 6 characters for hex color
    color_hex = String.slice(hash, 0, 6)

    # Ensure it's a valid hex color and not too dark/light
    case Integer.parse(color_hex, 16) do
      {color_int, ""} ->
        # Adjust brightness to ensure good visibility
        adjusted_color = adjust_color_brightness(color_int)
        ("#" <> Integer.to_string(adjusted_color, 16)) |> String.pad_leading(7, "#0")

      _ ->
        # Fallback colors
        fallback_colors = [
          "#3B82F6",
          "#EF4444",
          "#10B981",
          "#F59E0B",
          "#8B5CF6",
          "#EC4899",
          "#06B6D4",
          "#84CC16"
        ]

        hash_index = rem(:erlang.phash2(user_id), length(fallback_colors))
        Enum.at(fallback_colors, hash_index)
    end
  end

  defp generate_cursor_color(_user_id), do: "#3B82F6"

  # Adjust color brightness to ensure good visibility
  defp adjust_color_brightness(color_int) do
    # Extract RGB components
    r = div(color_int, 65536) |> rem(256)
    g = div(color_int, 256) |> rem(256)
    b = rem(color_int, 256)

    # Calculate luminance
    luminance = 0.299 * r + 0.587 * g + 0.114 * b

    cond do
      # Too dark - lighten it
      luminance < 80 ->
        r_new = min(255, r + 100)
        g_new = min(255, g + 100)
        b_new = min(255, b + 100)
        r_new * 65536 + g_new * 256 + b_new

      # Too light - darken it
      luminance > 200 ->
        r_new = max(0, r - 100)
        g_new = max(0, g - 100)
        b_new = max(0, b - 100)
        r_new * 65536 + g_new * 256 + b_new

      # Good brightness
      true ->
        color_int
    end
  end
end
