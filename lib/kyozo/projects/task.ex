defmodule Kyozo.Projects.Task do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Projects,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "project_tasks"
    repo Kyozo.Repo

    references do
      reference :project, on_delete: :delete
      reference :document, on_delete: :delete
    end

    identity_wheres_to_sql [
      unique_document_runme_id: "runme_id IS NOT NULL"
    ]
  end

  json_api do
    type "task"
    
    routes do
      base "/tasks"
      get :read
      index :read
    end
  end

  json_api do
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :runme_id, :string do
      public? true
      description "Unique identifier from runme parsing"
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Name of the task/code block"
    end

    attribute :is_name_generated, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether the task name was auto-generated"
    end

    attribute :language, :string do
      public? true
      description "Programming language of the code block (e.g., python, javascript, shell)"
    end

    attribute :code, :string do
      allow_nil? false
      public? true
      description "The executable code content"
    end

    attribute :description, :string do
      public? true
      description "Optional description or documentation for the task"
    end

    attribute :line_start, :integer do
      public? true
      description "Starting line number in the document"
    end

    attribute :line_end, :integer do
      public? true
      description "Ending line number in the document"
    end

    attribute :order_index, :integer do
      allow_nil? false
      public? true
      default 0
      description "Order of this task within the document"
    end

    attribute :execution_count, :integer do
      allow_nil? false
      public? true
      default 0
      description "Number of times this task has been executed"
    end

    attribute :last_execution_status, :atom do
      public? true
      constraints one_of: [:success, :error, :timeout, :cancelled]
      description "Status of the last execution"
    end

    attribute :last_execution_output, :string do
      public? true
      description "Output from the last execution"
    end

    attribute :last_execution_error, :string do
      public? true
      description "Error message from the last execution"
    end

    attribute :execution_time_ms, :integer do
      public? true
      description "Duration of last execution in milliseconds"
    end

    attribute :is_executable, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether this task can be executed"
    end

    attribute :requires_input, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether this task requires user input"
    end

    attribute :dependencies, {:array, :string} do
      public? true
      default []
      description "List of task IDs or names that this task depends on"
    end

    attribute :environment_variables, :map do
      public? true
      default %{}
      description "Environment variables required for execution"
    end

    attribute :working_directory, :string do
      public? true
      description "Working directory for task execution"
    end

    attribute :timeout_seconds, :integer do
      public? true
      default 30
      description "Execution timeout in seconds"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional metadata for the task"
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :last_executed_at, :utc_datetime_usec do
      public? true
      description "When this task was last executed"
    end
  end

  relationships do
    belongs_to :project, Kyozo.Projects.Project do
      allow_nil? false
      public? true
      description "Project this task belongs to"
    end

    belongs_to :document, Kyozo.Projects.Document do
      allow_nil? false
      public? true
      description "Document containing this task"
    end

    has_many :load_events, Kyozo.Projects.LoadEvent do
      description "Events related to this task"
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_tasks do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [order_index: :asc, created_at: :asc])
    end

    read :list_document_tasks do
      argument :document_id, :uuid do
        allow_nil? false
      end

      filter expr(document_id == ^arg(:document_id))
      prepare build(sort: [order_index: :asc])
    end

    read :list_project_tasks do
      argument :project_id, :uuid do
        allow_nil? false
      end

      filter expr(project_id == ^arg(:project_id))
      prepare build(sort: [order_index: :asc], load: [:document])
    end

    read :executable_tasks_only do
      filter expr(is_executable == true)
      prepare build(sort: [order_index: :asc])
    end

    create :create do
      accept [
        :runme_id, :name, :is_name_generated, :language, :code, :description,
        :line_start, :line_end, :order_index, :is_executable, :requires_input,
        :dependencies, :environment_variables, :working_directory, :timeout_seconds,
        :metadata
      ]
      
      change relate_actor(:project, field: :project_id)
      change relate_actor(:document, field: :document_id)
      
      change fn changeset, _context ->
        # Auto-generate name if not provided
        if is_nil(Ash.Changeset.get_attribute(changeset, :name)) do
          language = Ash.Changeset.get_attribute(changeset, :language) || "code"
          order = Ash.Changeset.get_attribute(changeset, :order_index) || 1
          generated_name = "#{String.capitalize(language)} Task #{order}"
          
          changeset
          |> Ash.Changeset.change_attribute(:name, generated_name)
          |> Ash.Changeset.change_attribute(:is_name_generated, true)
        else
          changeset
        end
      end
    end

    update :update_execution_result do
      accept [
        :execution_count, :last_execution_status, :last_execution_output,
        :last_execution_error, :execution_time_ms, :last_executed_at
      ]
      
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:last_executed_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:execution_count, 
          (Ash.Changeset.get_attribute(changeset, :execution_count) || 0) + 1)
      end
    end

    update :mark_successful_execution do
      argument :output, :string
      argument :execution_time_ms, :integer

      change fn changeset, _context ->
        output = Ash.Changeset.get_argument(changeset, :output)
        time_ms = Ash.Changeset.get_argument(changeset, :execution_time_ms)
        
        changeset
        |> Ash.Changeset.change_attribute(:last_execution_status, :success)
        |> Ash.Changeset.change_attribute(:last_execution_output, output)
        |> Ash.Changeset.change_attribute(:last_execution_error, nil)
        |> Ash.Changeset.change_attribute(:execution_time_ms, time_ms)
        |> Ash.Changeset.change_attribute(:last_executed_at, DateTime.utc_now())
      end

      change fn changeset, _context ->
        current_count = Ash.Changeset.get_data(changeset, :execution_count) || 0
        Ash.Changeset.change_attribute(changeset, :execution_count, current_count + 1)
      end

      require_atomic? false
    end

    update :mark_failed_execution do
      argument :error, :string
      argument :execution_time_ms, :integer, allow_nil?: true

      change fn changeset, _context ->
        error = Ash.Changeset.get_argument(changeset, :error)
        time_ms = Ash.Changeset.get_argument(changeset, :execution_time_ms)
        
        changeset
        |> Ash.Changeset.change_attribute(:last_execution_status, :error)
        |> Ash.Changeset.change_attribute(:last_execution_output, nil)
        |> Ash.Changeset.change_attribute(:last_execution_error, error)
        |> Ash.Changeset.change_attribute(:execution_time_ms, time_ms)
        |> Ash.Changeset.change_attribute(:last_executed_at, DateTime.utc_now())
      end

      change fn changeset, _context ->
        current_count = Ash.Changeset.get_data(changeset, :execution_count) || 0
        Ash.Changeset.change_attribute(changeset, :execution_count, current_count + 1)
      end

      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:project, :user])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:project, :user])
    end
  end

  calculations do
    calculate :has_been_executed, :boolean do
      description "Whether this task has been executed at least once"
      
      calculation fn records, _opts ->
        Enum.map(records, &(&1.execution_count > 0))
      end
    end

    calculate :last_execution_successful, :boolean do
      description "Whether the last execution was successful"
      
      calculation fn records, _opts ->
        Enum.map(records, &(&1.last_execution_status == :success))
      end
    end

    calculate :estimated_complexity, :atom do
      description "Estimated complexity based on code length and language"
      constraints one_of: [:simple, :medium, :complex]
      
      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          code_length = String.length(record.code || "")
          line_count = String.split(record.code || "", "\n") |> length()
          
          cond do
            code_length < 100 and line_count < 10 -> :simple
            code_length < 500 and line_count < 50 -> :medium
            true -> :complex
          end
        end)
      end
    end

    calculate :full_path, :string do
      description "Full path including document path and task name"
      load [:document]
      
      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          if record.document do
            "#{record.document.path}##{record.name}"
          else
            record.name
          end
        end)
      end
    end

    calculate :line_count, :integer do
      description "Number of lines in the code block"
      
      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          if record.code do
            String.split(record.code, "\n") |> length()
          else
            0
          end
        end)
      end
    end
  end

  aggregates do
    count :total_executions, :project
  end

  identities do
    identity :unique_document_runme_id, [:document_id, :runme_id] do
      where expr(not is_nil(runme_id))
      message "A task with this runme_id already exists in the document"
    end

    identity :unique_document_order, [:document_id, :order_index] do
      message "A task with this order already exists in the document"
    end
  end

  validations do
    validate present([:name, :code, :order_index, :is_executable])
    
    validate compare(:line_end, greater_than_or_equal_to: :line_start) do
      where [present(:line_start), present(:line_end)]
      message "End line must be greater than or equal to start line"
    end

    validate compare(:order_index, greater_than_or_equal_to: 0) do
      message "Order index must be non-negative"
    end

    validate compare(:timeout_seconds, greater_than: 0) do
      where present(:timeout_seconds)
      message "Timeout must be positive"
    end

    validate match(:language, ~r/^[a-zA-Z0-9_-]+$/) do
      where present(:language)
      message "Language must contain only alphanumeric characters, underscores, and hyphens"
    end
  end
end