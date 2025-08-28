defmodule Dirup.Projects.Project do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Projects,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "project"

    routes do
      base "/projects"
      get :read
      index :read
      post :load_directory, route: "/load_directory"
      post :load_file, route: "/load_file"
      delete :destroy
    end
  end

  postgres do
    table "projects"
    repo Dirup.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_projects do
      pagination offset?: true, keyset?: true, countable: true
      prepare build(sort: [created_at: :desc])
    end

    create :load_directory do
      description "Load a project from a directory"

      argument :path, :string do
        allow_nil? false
        description "Path to directory containing the project"
      end

      argument :skip_gitignore, :boolean do
        default false
        description "If true, .gitignore file is ignored"
      end

      argument :ignore_file_patterns, {:array, :string} do
        default []
        description "List of file patterns to ignore (gitignore syntax)"
      end

      argument :skip_repo_lookup_upward, :boolean do
        default false
        description "If true, disables looking up for .git folder in parent directories"
      end

      argument :identity, :atom do
        constraints one_of: [:unspecified, :all, :document, :cell]
        default :unspecified
        description "Controls if unique identifiers are inserted"
      end

      change set_attribute(:type, :directory)
      change relate_actor(:user)

      change fn changeset, _context ->
        path = Ash.Changeset.get_argument(changeset, :path)
        name = Path.basename(path)

        options = %{
          skip_gitignore: Ash.Changeset.get_argument(changeset, :skip_gitignore),
          ignore_file_patterns: Ash.Changeset.get_argument(changeset, :ignore_file_patterns),
          skip_repo_lookup_upward: Ash.Changeset.get_argument(changeset, :skip_repo_lookup_upward)
        }

        changeset
        |> Ash.Changeset.change_attribute(:path, path)
        |> Ash.Changeset.change_attribute(:name, name)
        |> Ash.Changeset.change_attribute(
          :identity_mode,
          Ash.Changeset.get_argument(changeset, :identity)
        )
        |> Ash.Changeset.change_attribute(:options, options)
      end

      change {Dirup.Projects.Changes.LoadProject, type: :directory}
    end

    create :load_file do
      description "Load a project from a single file"

      argument :path, :string do
        allow_nil? false
        description "Path to the file"
      end

      argument :identity, :atom do
        constraints one_of: [:unspecified, :all, :document, :cell]
        default :unspecified
        description "Controls if unique identifiers are inserted"
      end

      change set_attribute(:type, :file)
      change relate_actor(:user)

      change fn changeset, _context ->
        path = Ash.Changeset.get_argument(changeset, :path)
        name = Path.basename(path, Path.extname(path))

        changeset
        |> Ash.Changeset.change_attribute(:path, path)
        |> Ash.Changeset.change_attribute(:name, name)
        |> Ash.Changeset.change_attribute(
          :identity_mode,
          Ash.Changeset.get_argument(changeset, :identity)
        )
        |> Ash.Changeset.change_attribute(:options, %{})
      end

      change {Dirup.Projects.Changes.LoadProject, type: :file}
    end

    # Generic load action that can handle both directory and file
    create :load_project do
      description "Load a project (auto-detects directory vs file)"

      argument :path, :string do
        allow_nil? false
        description "Path to directory or file"
      end

      argument :options, :map do
        default %{}
        description "Loading options (directory-specific options ignored for files)"
      end

      argument :identity, :atom do
        constraints one_of: [:unspecified, :all, :document, :cell]
        default :unspecified
        description "Controls if unique identifiers are inserted"
      end

      change relate_actor(:user)

      change fn changeset, _context ->
        path = Ash.Changeset.get_argument(changeset, :path)
        name = Path.basename(path)
        options = Ash.Changeset.get_argument(changeset, :options)

        # Determine if path is directory or file
        type = if File.dir?(path), do: :directory, else: :file

        changeset
        |> Ash.Changeset.change_attribute(:path, path)
        |> Ash.Changeset.change_attribute(:name, name)
        |> Ash.Changeset.change_attribute(:type, type)
        |> Ash.Changeset.change_attribute(
          :identity_mode,
          Ash.Changeset.get_argument(changeset, :identity)
        )
        |> Ash.Changeset.change_attribute(:options, options)
      end

      change {Dirup.Projects.Changes.LoadProject, type: :auto}
    end

    update :mark_loaded do
      accept [:document_count, :task_count]

      change set_attribute(:status, :loaded)
      require_atomic? false
    end

    update :mark_error do
      accept [:error_message]

      change set_attribute(:status, :error)
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  validations do
    validate present([:path, :name, :type, :status, :identity_mode])

    validate {Dirup.Projects.Validations.ValidPath, []} do
      where changing(:path)
      message "Path must be a valid file or directory path"
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :path, :string do
      allow_nil? false
      public? true
      description "The root path of the project"
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:directory, :file]
      default :directory
      description "Whether this project was loaded from a directory or single file"
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      description "The project name (derived from path)"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:loading, :loaded, :error]
      default :loading
      description "Current loading status of the project"
    end

    attribute :identity_mode, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:unspecified, :all, :document, :cell]
      default :unspecified
      description "Controls if unique identifiers are inserted if not present"
    end

    attribute :options, :map do
      allow_nil? false
      public? true
      default %{}
      description "Project-specific loading options"
    end

    attribute :error_message, :string do
      public? true
      description "Error message if loading failed"
    end

    attribute :document_count, :integer do
      public? true
      default 0
      description "Number of documents found in project"
    end

    attribute :task_count, :integer do
      public? true
      default 0
      description "Number of tasks found in project"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Dirup.Accounts.User do
      allow_nil? false
      description "User who created/loaded this project"
    end

    has_many :documents, Dirup.Projects.Document do
      description "Documents found in this project"
    end

    has_many :tasks, Dirup.Projects.Task do
      description "All tasks across all documents in this project"
    end

    has_many :load_events, Dirup.Projects.LoadEvent do
      description "Events generated during project loading"
    end
  end

  calculations do
    calculate :loading_progress, :float do
      description "Loading progress as a percentage (0.0 to 1.0)"

      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.status do
            :loaded -> 1.0
            :error -> 0.0
            # Could be more sophisticated based on events
            :loading -> 0.5
          end
        end)
      end
    end

    calculate :has_errors, :boolean do
      description "Whether this project has any loading errors"

      calculation fn records, _opts ->
        Enum.map(records, &(&1.status == :error))
      end
    end
  end

  aggregates do
    count :documents_count, :documents
    count :tasks_count, :tasks
    count :events_count, :load_events

    exists :has_documents, :documents
    exists :has_tasks, :tasks
  end

  identities do
    identity :unique_user_path, [:user_id, :path] do
      message "You already have a project loaded from this path"
    end
  end
end
