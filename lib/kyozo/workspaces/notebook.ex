defmodule Kyozo.Workspaces.Notebook do
  @derive {Jason.Encoder, only: [:id, :title, :content, :content_html, :status, :execution_state, :extracted_tasks, :execution_order, :current_task_index, :total_execution_time, :last_executed_at, :execution_count, :auto_save_enabled, :collaborative_mode, :kernel_status, :environment_variables, :execution_timeout, :render_cache, :metadata, :created_at, :updated_at, :last_accessed_at]}

  @moduledoc """
  Notebook resource representing a rendered, interactive version of markdown documents.

  Notebooks are created from Documents with .md or .livemd extensions and provide:
  - Rendered HTML content with syntax highlighting
  - Extracted executable code blocks as tasks
  - Interactive execution environment
  - Real-time collaboration features
  - Execution history and state management
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, Kyozo.Workspaces.Extensions.RenderMarkdown]

  alias Kyozo.Workspaces.Notebook.Changes

  render_markdown do
    render_attributes content: :content_html
    header_ids? true
    table_of_contents? true
    syntax_highlighting? true
    extract_tasks? true
    allowed_languages ["elixir", "python", "javascript", "typescript", "bash", "shell", "sql", "r", "julia"]
  end

  postgres do
    table "notebooks"
    repo Kyozo.Repo

    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:file_id], unique: true
      index [:workspace_id, :status]
      index [:workspace_id, :updated_at]
      index [:team_id, :status]
    end
  end

  json_api do
    type "notebook"

    routes do
      base "/notebooks"
      get :read
      index :read
      post :create_from_document
      patch :update_content
      delete :destroy
    end
  end

  graphql do
    type :notebook

    queries do
      list :list_notebooks, :read
      get :get_notebook, :read
    end

    mutations do
      create :create_notebook, :create_from_document
      update :update_notebook, :update_content
      destroy :destroy_notebook, :destroy
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      description "Title of the notebook (derived from document)"
    end

    attribute :file_path, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 1024
    end

    attribute :content, :string do
      public? true
      description "Original markdown content from the document"
    end

    attribute :content_html, :string do
      public? true
      description "Rendered HTML content with syntax highlighting"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :ready, :running, :completed, :error, :archived]
      description "Current status of the notebook"
    end

    attribute :execution_state, :map do
      public? true
      default %{}
      description "Current execution state including task statuses and outputs"
    end

    attribute :cells, {:array, :map} do
      public? true
      default []
      description "Tasks extracted from markdown code blocks"
    end

    attribute :extracted_tasks, {:array, :map} do
      public? true
      default []
      description "Tasks extracted from markdown code blocks"
    end

    attribute :execution_order, {:array, :string} do
      public? true
      default []
      description "Order in which tasks should be executed"
    end

    attribute :current_task_index, :integer do
      public? true
      default 0
      description "Index of currently executing or next task to execute"
    end

    attribute :total_execution_time, :integer do
      public? true
      default 0
      description "Total execution time across all tasks in milliseconds"
    end

    attribute :last_executed_at, :utc_datetime_usec do
      public? true
      description "When the notebook was last executed"
    end

    attribute :execution_count, :integer do
      allow_nil? false
      public? true
      default 0
      description "Number of times this notebook has been executed"
    end

    attribute :auto_save_enabled, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether to automatically save execution results"
    end

    attribute :collaborative_mode, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether collaborative editing is enabled"
    end

    attribute :kernel_status, :atom do
      public? true
      constraints one_of: [:idle, :busy, :starting, :dead, :unknown]
      default :idle
      description "Status of the execution kernel"
    end

    attribute :environment_variables, :map do
      public? true
      default %{}
      description "Environment variables for task execution"
    end

    attribute :execution_timeout, :integer do
      public? true
      default 300
      description "Default timeout for task execution in seconds"
    end

    attribute :render_cache, :map do
      public? true
      default %{}
      description "Cache of rendered content for performance"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional metadata for the notebook"
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :last_accessed_at, :utc_datetime_usec do
      public? true
      description "When the notebook was last accessed"
    end
  end

  relationships do
    belongs_to :file, Kyozo.Workspaces.File do
      allow_nil? false
      public? true
      description "Source file this notebook is rendered from"
    end

    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? false
      public? true
      description "Workspace this notebook belongs to"
    end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      public? true
      description "Team that owns this notebook"
    end

    has_many :tasks, Kyozo.Workspaces.Task do
      destination_attribute :notebook_id
      description "Executable tasks extracted from this notebook"
    end


  end

  actions do
    defaults [:read, :destroy]

    read :list_notebooks do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [updated_at: :desc])
    end

    read :list_by_workspace do
      argument :workspace_id, :uuid do
        allow_nil? false
      end

      filter expr(workspace_id == ^arg(:workspace_id))
      prepare build(sort: [updated_at: :desc], load: [:document, :tasks])
    end

    read :list_by_status do
      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:draft, :ready, :running, :completed, :error, :archived]
      end

      filter expr(status == ^arg(:status))
      prepare build(sort: [updated_at: :desc])
    end

    read :list_executable do
      filter expr(status in [:ready, :completed])
      prepare build(sort: [last_executed_at: :desc], load: [:tasks])
    end

    create :create_from_document do
      argument :file_id, :uuid do
        allow_nil? false
      end

      change relate_actor(:workspace, field: :workspace_id)
      change relate_actor(:team, field: :team_id)
      change {Changes.CreateFromDocument, []}
      change {Changes.ExtractTasks, []}
      change set_attribute(:status, :ready)
    end

    update :update_content do
      accept [:content, :title, :metadata]

      change {Changes.RenderContent, []}
      change {Changes.ExtractTasks, []}
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :execute_notebook do
      argument :environment_variables, :map, default: %{}
      argument :timeout_seconds, :integer, default: 300

      change set_attribute(:status, :running)
      change set_attribute(:kernel_status, :busy)
      change {Changes.ExecuteAllTasks, []}
      change {Changes.UpdateExecutionState, []}
      change set_attribute(:last_executed_at, &DateTime.utc_now/0)
    end

    update :execute_task do
      argument :task_id, :string do
        allow_nil? false
      end
      argument :environment_variables, :map, default: %{}

      change {Changes.ExecuteSingleTask, []}
      change {Changes.UpdateExecutionState, []}
    end

    update :stop_execution do
      change set_attribute(:status, :ready)
      change set_attribute(:kernel_status, :idle)
      change {Changes.StopAllTasks, []}
    end

    update :reset_execution do
      change set_attribute(:status, :ready)
      change set_attribute(:kernel_status, :idle)
      change set_attribute(:execution_state, %{})
      change set_attribute(:current_task_index, 0)
      change {Changes.ResetAllTasks, []}
    end

    update :update_execution_state do
      accept [:execution_state, :current_task_index, :kernel_status]
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :toggle_collaborative_mode do
      change {Changes.ToggleCollaborativeMode, []}
    end

    update :update_access_time do
      change set_attribute(:last_accessed_at, &DateTime.utc_now/0)
    end

    action :duplicate_notebook, :struct do
      argument :new_title, :string, allow_nil?: true
      argument :copy_to_workspace_id, :uuid, allow_nil?: true

      run {Changes.DuplicateNotebook, []}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :members, :user])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :members, :user])
    end

    policy action(:execute_notebook) do
      authorize_if relates_to_actor_via([:workspace, :members, :user])
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  preparations do
    prepare build(load: [:document, :workspace]) do
      on [:read]
    end
  end

  calculations do
    calculate :is_executable, :boolean do
      description "Whether this notebook can be executed"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          record.status in [:ready, :completed] and
          not Enum.empty?(record.extracted_tasks || [])
        end)
      end
    end

    calculate :execution_progress, :decimal do
      description "Percentage of tasks completed in current execution"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          tasks = record.extracted_tasks || []
          execution_state = record.execution_state || %{}

          if Enum.empty?(tasks) do
            Decimal.new("0.0")
          else
            completed_count =
              Enum.count(tasks, fn task ->
                task_id = task["id"] || task[:id]
                case Map.get(execution_state, task_id) do
                  %{"status" => "completed"} -> true
                  %{status: :completed} -> true
                  _ -> false
                end
              end)

            (completed_count / length(tasks) * 100)
            |> Decimal.from_float()
            |> Decimal.round(1)
          end
        end)
      end
    end

    calculate :task_count, :integer do
      description "Number of executable tasks in this notebook"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          length(record.extracted_tasks || [])
        end)
      end
    end

    calculate :last_execution_status, :atom do
      description "Status of the last execution"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          execution_state = record.execution_state || %{}

          case Map.get(execution_state, "last_execution") do
            %{"status" => status} when status in ["success", "error", "timeout"] ->
              String.to_atom(status)
            %{status: status} when status in [:success, :error, :timeout] ->
              status
            _ ->
              :unknown
          end
        end)
      end
    end

    calculate :estimated_execution_time, :integer do
      description "Estimated total execution time in seconds"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          tasks = record.extracted_tasks || []

          # Rough estimation based on task complexity
          Enum.reduce(tasks, 0, fn task, acc ->
            code = task["code"] || task[:code] || ""
            language = task["language"] || task[:language] || ""

            base_time = case language do
              lang when lang in ["python", "r", "julia"] -> 5
              lang when lang in ["javascript", "typescript"] -> 3
              lang when lang in ["bash", "shell"] -> 2
              lang when lang in ["elixir"] -> 4
              _ -> 3
            end

            # Adjust based on code length
            line_count = length(String.split(code, "\n"))
            complexity_multiplier = cond do
              line_count > 50 -> 3
              line_count > 20 -> 2
              line_count > 10 -> 1.5
              true -> 1
            end

            acc + (base_time * complexity_multiplier) |> trunc()
          end)
        end)
      end
    end

    calculate :document_path, :string do
      description "Path of the source document"
      load [:document]

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.document do
            nil -> nil
            document -> document.file_path
          end
        end)
      end
    end

    calculate :is_markdown_notebook, :boolean do
      description "Whether this is a markdown-based notebook"
      load [:document]

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.document do
            nil -> false
            document ->
              path = document.file_path || ""
              String.ends_with?(path, ".md") or String.ends_with?(path, ".livemd")
          end
        end)
      end
    end
  end

  aggregates do
    count :total_tasks, :tasks
    max :last_task_execution, :tasks, :last_executed_at
  end

  identities do
    identity :unique_file_notebook, [:file_id] do
      message "A notebook already exists for this document"
    end
  end

  validations do
    validate present([:title, :file_id, :workspace_id, :team_id])

    validate compare(:execution_timeout, greater_than: 0) do
      where present(:execution_timeout)
      message "Execution timeout must be positive"
    end

    validate compare(:current_task_index, greater_than_or_equal_to: 0) do
      message "Current task index must be non-negative"
    end

    validate {Changes.ValidateDocumentType, []}
  end

  # Helper functions for working with notebooks

  @doc """
  Determines if a document can be rendered as a notebook based on its file extension.
  """
  def renderable_as_notebook?(file_path) when is_binary(file_path) do
    String.ends_with?(file_path, [".md", ".livemd"])
  end

  def renderable_as_notebook?(_), do: false

  @doc """
  Extracts the notebook type from a file path.
  """
  def notebook_type_from_path(file_path) when is_binary(file_path) do
    cond do
      String.ends_with?(file_path, ".livemd") -> :livebook
      String.ends_with?(file_path, ".md") -> :markdown
      true -> :unknown
    end
  end

  @doc """
  Gets the appropriate execution environment for a notebook type.
  """
  def execution_environment(:livebook), do: :elixir
  def execution_environment(:markdown), do: :mixed
  def execution_environment(_), do: :unknown

  @doc """
  Validates that extracted tasks have the required structure.
  """
  def valid_task_structure?(%{"language" => _, "code" => _, "id" => _}), do: true
  def valid_task_structure?(%{language: _, code: _, id: _}), do: true
  def valid_task_structure?(_), do: false

  @doc """
  Creates an empty execution state for a notebook.
  """
  def empty_execution_state do
    %{
      "status" => "ready",
      "started_at" => nil,
      "completed_at" => nil,
      "tasks" => %{},
      "environment" => %{},
      "last_execution" => nil
    }
  end

  @doc """
  Updates execution state for a specific task.
  """
  def update_task_execution_state(execution_state, task_id, task_status, output \\ nil) do
    task_state = %{
      "status" => to_string(task_status),
      "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "output" => output
    }

    execution_state
    |> put_in(["tasks", task_id], task_state)
    |> put_in(["last_execution"], %{
      "task_id" => task_id,
      "status" => to_string(task_status),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Checks if a notebook is currently executing.
  """
  def executing?(notebook) do
    notebook.status == :running and notebook.kernel_status == :busy
  end

  @doc """
  Gets the next task to execute based on execution order and current state.
  """
  def next_task_to_execute(notebook) do
    tasks = notebook.extracted_tasks || []
    execution_state = notebook.execution_state || %{}

    Enum.find(tasks, fn task ->
      task_id = task["id"] || task[:id]
      case Map.get(execution_state, task_id) do
        %{"status" => status} when status in ["completed", "error"] -> false
        %{status: status} when status in [:completed, :error] -> false
        _ -> true
      end
    end)
  end
end


defmodule Kyozo.Workspaces.Notebook.Cell.Config do
  use Ash.TypedStruct

  typed_struct do
    field :column, :integer, allow_nil?: true
    field :disabled, :boolean, allow_nil?: false
    field :hide_code, :boolean, allow_nil?: true
  end
end

defmodule Kyozo.Workspaces.Notebook.Cell do
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  attributes do
    attribute :id, :uuid, primary_key?: true, allow_nil?: false, default: &Kyozo.Workspaces.Notebook.Cell.generate_id/0
    attribute :code, :string, public?: true
    attribute :code_hash, :string, public?: true
    attribute :name, :string, public?: true
    attribute :config, Kyozo.Workspaces.Notebook.Cell.Config, public?: true
  end

  def generate_id do
    Ash.UUID.generate()
  end
end
