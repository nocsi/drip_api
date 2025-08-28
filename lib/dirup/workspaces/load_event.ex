defmodule Dirup.Workspaces.LoadEvent do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "load_event"

    routes do
      base "/load_events"
      get :read
      index :read
    end
  end

  postgres do
    table "workspace_load_events"
    repo Dirup.Repo

    references do
      reference :workspace, on_delete: :delete
      reference :notebook, on_delete: :delete
      reference :task, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_events do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [sequence_number: :asc, occurred_at: :asc])
    end

    read :list_workspace_events do
      argument :workspace_id, :uuid do
        allow_nil? false
      end

      filter expr(workspace_id == ^arg(:workspace_id))
      prepare build(sort: [sequence_number: :asc])
    end

    read :list_error_events do
      filter expr(event_type == :error)
      prepare build(sort: [occurred_at: :desc])
    end

    read :list_events_by_type do
      argument :event_type, :atom do
        allow_nil? false

        constraints one_of: [
                      :unspecified,
                      :started_walk,
                      :found_dir,
                      :found_file,
                      :finished_walk,
                      :started_parsing_doc,
                      :finished_parsing_doc,
                      :found_task,
                      :error
                    ]
      end

      filter expr(event_type == ^arg(:event_type))
      prepare build(sort: [occurred_at: :asc])
    end

    create :log_started_walk do
      accept [:sequence_number, :processing_time_ms, :event_data]

      change set_attribute(:event_type, :started_walk)
      change relate_actor(:workspace, field: :workspace_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :log_found_dir do
      accept [:path, :sequence_number, :processing_time_ms, :event_data]

      change set_attribute(:event_type, :found_dir)
      change relate_actor(:workspace, field: :workspace_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :log_found_file do
      accept [:path, :sequence_number, :processing_time_ms, :event_data]

      change set_attribute(:event_type, :found_file)
      change relate_actor(:workspace, field: :workspace_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :log_finished_walk do
      accept [:sequence_number, :processing_time_ms, :event_data]

      change set_attribute(:event_type, :finished_walk)
      change relate_actor(:workspace, field: :workspace_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :log_started_parsing_doc do
      accept [:path, :sequence_number, :processing_time_ms, :event_data]

      change set_attribute(:event_type, :started_parsing_doc)
      change relate_actor(:workspace, field: :workspace_id)
      change relate_actor(:notebook, field: :notebook_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :log_finished_parsing_doc do
      accept [:path, :sequence_number, :processing_time_ms, :event_data]

      change set_attribute(:event_type, :finished_parsing_doc)
      change relate_actor(:workspace, field: :workspace_id)
      change relate_actor(:notebook, field: :notebook_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :log_found_task do
      accept [
        :path,
        :task_name,
        :task_workspace_id,
        :is_task_name_generated,
        :sequence_number,
        :processing_time_ms,
        :event_data
      ]

      change set_attribute(:event_type, :found_task)
      change relate_actor(:workspace, field: :workspace_id)
      change relate_actor(:notebook, field: :notebook_id)
      change relate_actor(:task, field: :task_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :log_error do
      accept [:path, :error_message, :sequence_number, :processing_time_ms, :event_data]

      change set_attribute(:event_type, :error)
      change relate_actor(:workspace, field: :workspace_id)
      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end

    create :create_generic do
      accept [
        :event_type,
        :event_data,
        :path,
        :error_message,
        :task_name,
        :task_workspace_id,
        :is_task_name_generated,
        :sequence_number,
        :processing_time_ms,
        :occurred_at
      ]

      change relate_actor(:workspace, field: :workspace_id)

      change fn changeset, _context ->
        if is_nil(Ash.Changeset.get_attribute(changeset, :occurred_at)) do
          Ash.Changeset.change_attribute(changeset, :occurred_at, DateTime.utc_now())
        else
          changeset
        end
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :user])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :user])
    end
  end

  preparations do
    prepare build(load: [:workspace]) do
      on [:read]
    end
  end

  validations do
    validate present([:event_type, :sequence_number])

    validate compare(:sequence_number, greater_than_or_equal_to: 0) do
      message "Sequence number must be non-negative"
    end

    validate present(:error_message) do
      where attribute_equals(:event_type, :error)
      message "Error message is required for error events"
    end

    validate present(:path) do
      where attribute_in(:event_type, [
              :found_dir,
              :found_file,
              :started_parsing_doc,
              :finished_parsing_doc
            ])

      message "Path is required for file/directory events"
    end

    validate present(:task_name) do
      where attribute_equals(:event_type, :found_task)
      message "Task name is required for found_task events"
    end
  end

  # GraphQL configuration removed during GraphQL cleanup

  attributes do
    uuid_v7_primary_key :id

    attribute :event_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :unspecified,
                    :started_walk,
                    :found_dir,
                    :found_file,
                    :finished_walk,
                    :started_parsing_doc,
                    :finished_parsing_doc,
                    :found_task,
                    :error
                  ]

      description "Type of the loading event"
    end

    attribute :event_data, :map do
      public? true
      default %{}
      description "Event-specific data payload"
    end

    attribute :path, :string do
      public? true
      description "File or directory path related to this event"
    end

    attribute :error_message, :string do
      public? true
      description "Error message if event_type is :error"
    end

    attribute :task_name, :string do
      public? true
      description "Task name if event_type is :found_task"
    end

    attribute :task_workspace_id, :string do
      public? true
      description "Task workspace ID if event_type is :found_task"
    end

    attribute :is_task_name_generated, :boolean do
      public? true
      description "Whether task name was generated if event_type is :found_task"
    end

    attribute :processing_time_ms, :integer do
      public? true
      description "Processing time for this event in milliseconds"
    end

    attribute :sequence_number, :integer do
      allow_nil? false
      public? true
      default 0
      description "Order of this event within the workspace loading sequence"
    end

    create_timestamp :occurred_at, writable?: true

    update_timestamp :updated_at
  end

  relationships do
    belongs_to :workspace, Dirup.Workspaces.Workspace do
      allow_nil? false
      public? true
      description "Workspace this event belongs to"
    end

    belongs_to :notebook, Dirup.Workspaces.Notebook do
      public? true
      description "Notebook related to this event (for parsing events)"
    end

    belongs_to :task, Dirup.Workspaces.Task do
      public? true
      description "Task related to this event (for found_task events)"
    end
  end

  calculations do
    calculate :is_error, :boolean do
      description "Whether this is an error event"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.event_type == :error))
      end
    end

    calculate :is_task_event, :boolean do
      description "Whether this event is related to a task"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.event_type == :found_task))
      end
    end

    calculate :is_file_event, :boolean do
      description "Whether this event is related to file operations"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          record.event_type in [:found_file, :started_parsing_doc, :finished_parsing_doc]
        end)
      end
    end

    calculate :event_category, :atom do
      description "Category of the event"
      constraints one_of: [:walk, :parse, :task, :error, :other]

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.event_type do
            type when type in [:started_walk, :found_dir, :found_file, :finished_walk] -> :walk
            type when type in [:started_parsing_doc, :finished_parsing_doc] -> :parse
            :found_task -> :task
            :error -> :error
            _ -> :other
          end
        end)
      end
    end

    calculate :formatted_event_data, :string do
      description "Human-readable representation of event data"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.event_type do
            :found_task ->
              "Found task: #{record.task_name}#{if record.is_task_name_generated, do: " (generated)", else: ""}"

            :found_file ->
              "Found file: #{record.path}"

            :found_dir ->
              "Found directory: #{record.path}"

            :error ->
              "Error: #{record.error_message}"

            :started_parsing_doc ->
              "Started parsing: #{record.path}"

            :finished_parsing_doc ->
              "Finished parsing: #{record.path}"

            :started_walk ->
              "Started walking workspace"

            :finished_walk ->
              "Finished walking workspace"

            _ ->
              "#{record.event_type}"
          end
        end)
      end
    end
  end

  aggregates do
    count :events_count, :workspace
  end

  identities do
    identity :unique_workspace_sequence, [:workspace_id, :sequence_number] do
      message "An event with this sequence number already exists for this workspace"
    end
  end
end
