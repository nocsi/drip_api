defmodule Dirup.Projects.Document do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Projects,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "document"

    routes do
      base "/documents"
      get :read
      index :read
    end
  end

  postgres do
    table "project_documents"
    repo Dirup.Repo

    references do
      reference :project, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_documents do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [created_at: :desc])
    end

    read :list_project_documents do
      argument :project_id, :uuid do
        allow_nil? false
      end

      filter expr(project_id == ^arg(:project_id))
      prepare build(sort: [path: :asc])
    end

    create :create do
      accept [
        :path,
        :absolute_path,
        :filename,
        :name,
        :extension,
        :content,
        :size_bytes,
        :line_count,
        :modified_at,
        :metadata
      ]

      change relate_actor(:project, field: :project_id)

      change fn changeset, _context ->
        if path = Ash.Changeset.get_attribute(changeset, :path) do
          filename = Path.basename(path)
          name = Path.basename(path, Path.extname(path))
          extension = Path.extname(path)

          changeset
          |> Ash.Changeset.change_attribute(:filename, filename)
          |> Ash.Changeset.change_attribute(:name, name)
          |> Ash.Changeset.change_attribute(:extension, extension)
        else
          changeset
        end
      end

      change {Dirup.Projects.Changes.ParseDocument, []}
    end

    update :update_content do
      accept [:content, :modified_at]

      change set_attribute(:status, :pending)
      change {Dirup.Projects.Changes.ParseDocument, []}
    end

    update :mark_parsed do
      accept [:parsed_content, :task_count, :metadata]

      change set_attribute(:status, :parsed)
      change set_attribute(:parsed_at, &DateTime.utc_now/0)
    end

    update :mark_error do
      accept [:error_message]

      change set_attribute(:status, :error)
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

  validations do
    validate present([:path, :absolute_path, :filename, :name, :status])

    validate {Dirup.Projects.Validations.ValidDocumentPath, []} do
      where [changing(:path), changing(:absolute_path)]
      message "Document path must be valid and readable"
    end

    validate match(:extension, ~r/^\.[a-zA-Z0-9]+$/) do
      where present(:extension)
      message "Extension must start with a dot and contain only alphanumeric characters"
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :path, :string do
      allow_nil? false
      public? true
      description "Path to the document relative to project root"
    end

    attribute :absolute_path, :string do
      allow_nil? false
      public? true
      description "Absolute filesystem path to the document"
    end

    attribute :filename, :string do
      allow_nil? false
      public? true
      description "Name of the file including extension"
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Document name without extension"
    end

    attribute :extension, :string do
      allow_nil? false
      public? true
      default ".md"
      description "File extension"
    end

    attribute :content, :string do
      public? true
      description "Raw markdown content of the document"
    end

    attribute :parsed_content, :map do
      public? true
      description "Parsed markdown structure (AST or similar)"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :parsing, :parsed, :error]
      default :pending
      description "Current parsing status of the document"
    end

    attribute :error_message, :string do
      public? true
      description "Error message if parsing failed"
    end

    attribute :size_bytes, :integer do
      public? true
      description "File size in bytes"
    end

    attribute :line_count, :integer do
      public? true
      description "Number of lines in the document"
    end

    attribute :task_count, :integer do
      public? true
      default 0
      description "Number of executable tasks found in this document"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional metadata extracted from document"
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :parsed_at, :utc_datetime_usec do
      public? true
      description "When the document was last parsed"
    end

    attribute :modified_at, :utc_datetime_usec do
      public? true
      description "File modification time"
    end
  end

  relationships do
    belongs_to :project, Dirup.Projects.Project do
      allow_nil? false
      public? true
      description "Project this document belongs to"
    end

    has_many :tasks, Dirup.Projects.Task do
      description "Executable tasks found in this document"
    end

    has_many :load_events, Dirup.Projects.LoadEvent do
      description "Events related to loading/parsing this document"
    end
  end

  calculations do
    calculate :is_markdown, :boolean do
      description "Whether this document is a markdown file"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          record.extension in [".md", ".markdown", ".mdown", ".mkd"]
        end)
      end
    end

    calculate :relative_path, :string do
      description "Path relative to project root"
      load [:project, :path]

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          if record.project && record.project.path do
            Path.relative_to(record.absolute_path, record.project.path)
          else
            record.path
          end
        end)
      end
    end

    calculate :word_count, :integer do
      description "Approximate word count in the document"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          if record.content do
            record.content
            |> String.split(~r/\s+/)
            |> length()
          else
            0
          end
        end)
      end
    end

    calculate :has_tasks, :boolean do
      description "Whether this document contains executable tasks"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.task_count > 0))
      end
    end
  end

  aggregates do
    count :tasks_count, :tasks

    exists :has_executable_tasks, :tasks

    first :first_task, :tasks, :name do
      sort created_at: :asc
    end

    list :task_languages, :tasks, :language do
      uniq? true
    end
  end

  identities do
    identity :unique_project_path, [:project_id, :path] do
      message "A document with this path already exists in the project"
    end
  end
end
