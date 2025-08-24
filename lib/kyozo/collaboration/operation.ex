defmodule Kyozo.Collaboration.Operation do
  @moduledoc """
  Operation resource for operational transformation in collaborative editing.

  Operations represent atomic changes to a document that can be applied, transformed,
  and synchronized across multiple clients in real-time. This supports conflict-free
  collaborative editing using operational transformation algorithms.
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Collaboration,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "collaboration_operations"
    repo Kyozo.Repo

    references do
      reference :session, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:session_id, :version]
      index [:session_id, :created_at]
      index [:session_id, :user_id, :created_at]
      index [:operation_type, :created_at]
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_operations do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [version: :asc])
    end

    read :list_session_operations do
      argument :session_id, :uuid, allow_nil?: false
      argument :since_version, :integer, default: 0

      filter expr(
               session_id == ^arg(:session_id) and
                 version > ^arg(:since_version)
             )

      prepare build(sort: [version: :asc])
    end

    read :list_user_operations do
      argument :session_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      argument :since_version, :integer, default: 0

      filter expr(
               session_id == ^arg(:session_id) and
                 user_id == ^arg(:user_id) and
                 version > ^arg(:since_version)
             )

      prepare build(sort: [version: :asc])
    end

    read :get_operation_range do
      argument :session_id, :uuid, allow_nil?: false
      argument :start_version, :integer, allow_nil?: false
      argument :end_version, :integer, allow_nil?: false

      filter expr(
               session_id == ^arg(:session_id) and
                 version >= ^arg(:start_version) and
                 version <= ^arg(:end_version)
             )

      prepare build(sort: [version: :asc])
    end

    create :create do
      accept [
        :operation_type,
        :operation_data,
        :version,
        :position,
        :length,
        :content,
        :metadata,
        :client_id
      ]

      change relate_actor(:session, field: :session_id)
      change relate_actor(:user, field: :user_id)

      change fn changeset, _context ->
        # Auto-increment version if not provided
        if !Ash.Changeset.get_attribute(changeset, :version) do
          session_id = Ash.Changeset.get_attribute(changeset, :session_id)

          if session_id do
            case Kyozo.Collaboration.get_session(session_id) do
              {:ok, session} ->
                next_version = session.document_version + 1
                Ash.Changeset.change_attribute(changeset, :version, next_version)

              _ ->
                changeset
            end
          else
            changeset
          end
        else
          changeset
        end
      end

      # Validate operation data based on type
      change {__MODULE__.Changes.ValidateOperationData, []}
    end

    update :apply_transformation do
      accept [:operation_data, :transformed_position, :transformed_length]
      change set_attribute(:is_transformed, true)
    end

    update :mark_applied do
      change set_attribute(:status, :applied)
      change set_attribute(:applied_at, &DateTime.utc_now/0)
    end

    update :mark_rejected do
      accept [:rejection_reason]
      change set_attribute(:status, :rejected)
      change set_attribute(:rejected_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:session, :team])
    end

    policy action_type([:create, :update]) do
      authorize_if relates_to_actor_via([:session, :team])
    end

    policy action_type(:destroy) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if relates_to_actor_via([:session, :owner])
    end
  end

  validations do
    validate present([:operation_type, :version, :status])

    validate numericality(:version, greater_than: 0)

    validate numericality(:position, greater_than_or_equal_to: 0) do
      where present(:position)
    end

    validate numericality(:length, greater_than_or_equal_to: 0) do
      where present(:length)
    end

    # Validate operation_data structure based on operation_type
    validate {__MODULE__.Validations.ValidateOperationData, []}

    # Ensure content is provided for insert operations
    validate present(:content) do
      where attribute_equals(:operation_type, :insert)
    end

    # Ensure position and length for delete operations
    validate present([:position, :length]) do
      where attribute_equals(:operation_type, :delete)
    end

    # Ensure position is provided for retain operations
    validate present(:position) do
      where attribute_equals(:operation_type, :retain)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :operation_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:insert, :delete, :retain, :format, :cursor_move, :selection_change]
      description "Type of operation being performed"
    end

    attribute :operation_data, :map do
      allow_nil? false
      public? true
      description "Structured data for the operation"
    end

    attribute :version, :integer do
      allow_nil? false
      public? true
      description "Version number for operational transformation ordering"
    end

    attribute :position, :integer do
      public? true
      description "Character position where operation begins"
    end

    attribute :length, :integer do
      public? true
      description "Length of content affected by operation"
    end

    attribute :content, :string do
      public? true
      description "Text content for insert operations"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :applied, :rejected, :transformed]
      default :pending
      description "Current status of the operation"
    end

    attribute :is_transformed, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether this operation has been transformed"
    end

    attribute :transformed_position, :integer do
      public? true
      description "Position after transformation"
    end

    attribute :transformed_length, :integer do
      public? true
      description "Length after transformation"
    end

    attribute :client_id, :string do
      public? true
      description "Client identifier that created this operation"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional operation metadata"
    end

    attribute :rejection_reason, :string do
      public? true
      description "Reason for operation rejection"
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :applied_at, :utc_datetime_usec do
      public? true
      description "When the operation was successfully applied"
    end

    attribute :rejected_at, :utc_datetime_usec do
      public? true
      description "When the operation was rejected"
    end
  end

  relationships do
    belongs_to :session, Kyozo.Collaboration.Session do
      allow_nil? false
      public? true
      description "Collaboration session this operation belongs to"
    end

    belongs_to :user, Kyozo.Accounts.User do
      allow_nil? false
      public? true
      description "User who created this operation"
    end
  end

  calculations do
    calculate :is_text_operation, :boolean do
      description "Whether this is a text editing operation"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.operation_type in [:insert, :delete, :retain]))
      end
    end

    calculate :is_formatting_operation, :boolean do
      description "Whether this is a formatting operation"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.operation_type == :format))
      end
    end

    calculate :is_cursor_operation, :boolean do
      description "Whether this is a cursor or selection operation"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.operation_type in [:cursor_move, :selection_change]))
      end
    end

    calculate :operation_size, :integer do
      description "Size impact of the operation"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.operation_type do
            :insert -> String.length(record.content || "")
            :delete -> -(record.length || 0)
            _ -> 0
          end
        end)
      end
    end
  end

  aggregates do
    count :concurrent_operations, [:session, :operations],
      filter: expr(version == parent(version) and id != parent(id))

    exists :has_conflicts, [:session, :operations],
      filter:
        expr(
          version == parent(version) and
            id != parent(id) and
            operation_type in [:insert, :delete] and
            parent(operation_type) in [:insert, :delete]
        )
  end

  identities do
    identity :unique_session_version, [:session_id, :version] do
      message "Each version number must be unique within a session"
    end
  end

  defmodule Changes do
    defmodule ValidateOperationData do
      @moduledoc """
      Change module to validate operation data structure based on operation type.
      """
      use Ash.Resource.Change

      @impl true
      def change(changeset, _opts, _context) do
        operation_type = Ash.Changeset.get_attribute(changeset, :operation_type)
        operation_data = Ash.Changeset.get_attribute(changeset, :operation_data)

        case validate_operation_data(operation_type, operation_data) do
          :ok ->
            changeset

          {:error, message} ->
            Ash.Changeset.add_error(changeset, field: :operation_data, message: message)
        end
      end

      defp validate_operation_data(:insert, data) when is_map(data) do
        required_keys = ["position", "content"]

        case Enum.all?(required_keys, &Map.has_key?(data, &1)) do
          true -> :ok
          false -> {:error, "Insert operations require position and content"}
        end
      end

      defp validate_operation_data(:delete, data) when is_map(data) do
        required_keys = ["position", "length"]

        case Enum.all?(required_keys, &Map.has_key?(data, &1)) do
          true -> :ok
          false -> {:error, "Delete operations require position and length"}
        end
      end

      defp validate_operation_data(:retain, data) when is_map(data) do
        required_keys = ["position"]

        case Enum.all?(required_keys, &Map.has_key?(data, &1)) do
          true -> :ok
          false -> {:error, "Retain operations require position"}
        end
      end

      defp validate_operation_data(:format, data) when is_map(data) do
        required_keys = ["position", "length", "attributes"]

        case Enum.all?(required_keys, &Map.has_key?(data, &1)) do
          true -> :ok
          false -> {:error, "Format operations require position, length, and attributes"}
        end
      end

      defp validate_operation_data(:cursor_move, data) when is_map(data) do
        required_keys = ["position"]

        case Enum.all?(required_keys, &Map.has_key?(data, &1)) do
          true -> :ok
          false -> {:error, "Cursor move operations require position"}
        end
      end

      defp validate_operation_data(:selection_change, data) when is_map(data) do
        required_keys = ["start", "end"]

        case Enum.all?(required_keys, &Map.has_key?(data, &1)) do
          true -> :ok
          false -> {:error, "Selection change operations require start and end"}
        end
      end

      defp validate_operation_data(_type, _data) do
        {:error, "Invalid operation type or data structure"}
      end
    end
  end

  defmodule Validations do
    defmodule ValidateOperationData do
      @moduledoc """
      Validation to ensure operation_data matches operation_type requirements.
      """
      use Ash.Resource.Validation

      @impl true
      def validate(changeset, _opts, _context) do
        operation_type = Ash.Changeset.get_attribute(changeset, :operation_type)
        operation_data = Ash.Changeset.get_attribute(changeset, :operation_data)

        case validate_data_structure(operation_type, operation_data) do
          :ok ->
            :ok

          {:error, message} ->
            {:error, message}
        end
      end

      defp validate_data_structure(type, data) when is_map(data) do
        case type do
          :insert ->
            validate_required_keys(data, ["position", "content"])

          :delete ->
            validate_required_keys(data, ["position", "length"])

          :retain ->
            validate_required_keys(data, ["position"])

          :format ->
            validate_required_keys(data, ["position", "length", "attributes"])

          :cursor_move ->
            validate_required_keys(data, ["position"])

          :selection_change ->
            validate_required_keys(data, ["start", "end"])

          _ ->
            {:error, "Unknown operation type"}
        end
      end

      defp validate_data_structure(_type, _data) do
        {:error, "Operation data must be a map"}
      end

      defp validate_required_keys(data, required_keys) do
        missing_keys = Enum.filter(required_keys, fn key -> !Map.has_key?(data, key) end)

        case missing_keys do
          [] -> :ok
          keys -> {:error, "Missing required keys: #{Enum.join(keys, ", ")}"}
        end
      end
    end
  end
end
