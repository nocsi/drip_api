defmodule Dirup.Workspaces.FileNotebook do
  @derive {Jason.Encoder,
           only: [
             :id,
             :file_id,
             :notebook_id,
             :storage_resource_id,
             :relationship_type,
             :is_primary,
             :metadata,
             :created_at,
             :updated_at
           ]}

  @moduledoc """
  Intermediary resource that links Files to Notebook resources through storage behavior.

  This resource acts as a bridge between the generic File entity and specialized Notebook
  resources, implementing the abstract storage pattern to handle notebook-specific content
  processing, cell execution, and format conversion.

  ## Key Features

  - **Storage Implementation**: Implements AbstractStorage for notebook content
  - **Content Resolution**: Resolves file content into Notebook resources
  - **Format Processing**: Handles Jupyter notebook (.ipynb) format processing
  - **Cell Management**: Manages notebook cells, execution state, and outputs
  - **Multi-format Support**: .ipynb, .md (with metadata), .py (with cell markers)

  ## Relationship Flow

  File -> FileNotebook (storage behavior) -> Notebook (specialized resource)

  ## Storage Backend Selection

  - Notebook files: Git backend for version control and collaboration
  - Large notebooks with outputs: Hybrid (Git + S3 for outputs)
  - Temporary execution states: RAM for quick access
  - Archived notebooks: S3 for long-term storage
  """

  use Dirup.Storage.AbstractStorage,
    media_type: :notebook,
    storage_backends: [:git, :disk, :hybrid, :ram],
    domain: Dirup.Workspaces

  require Ash.Query

  postgres do
    table "file_notebooks"
    repo Dirup.Repo

    references do
      reference :file, on_delete: :delete, index?: true
      reference :notebook, on_delete: :delete, index?: true
      reference :storage_resource, on_delete: :delete, index?: true
    end

    custom_indexes do
      # index [:file_id, :notebook_id], unique: true
      index [:file_id, :is_primary]
      index [:file_id, :relationship_type]
      # index [:notebook_id]
      # index [:storage_resource_id]
      index [:relationship_type]
      index [:created_at]
    end
  end

  json_api do
    type "file_notebook"

    routes do
      base "/file_notebooks"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  # Additional attributes for file notebook
  attributes do
    # Add team_id attribute required by team relationship from base
    attribute :team_id, :uuid do
      allow_nil? false
      public? true
    end

    # Add user_id attribute for user relationship from base
    attribute :user_id, :uuid do
      allow_nil? true
      public? true
    end
  end

  # Implement AbstractStorage callbacks
  @impl true
  def supported_mime_types do
    [
      # Jupyter notebook format
      "application/x-ipynb+json",
      # fallback for .ipynb files
      "application/json",

      # Markdown with notebook metadata
      "text/markdown",
      "text/x-markdown",

      # Python files with cell markers
      "text/x-python",
      "application/x-python-code",

      # R notebooks
      "text/x-r",
      "application/x-r",

      # Julia notebooks
      "text/x-julia",
      "application/x-julia",

      # Scala notebooks
      "text/x-scala",
      "application/x-scala",

      # Plain text notebooks
      "text/plain"
    ]
  end

  @impl true
  def default_storage_backend, do: :git

  @impl true
  def validate_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    cond do
      mime_type not in supported_mime_types() ->
        {:error, "Unsupported notebook MIME type: #{mime_type}"}

      byte_size(content) > 100 * 1024 * 1024 ->
        {:error, "Notebook too large (max 100MB)"}

      String.starts_with?(mime_type, "application/x-ipynb") and
          not valid_jupyter_notebook?(content) ->
        {:error, "Invalid Jupyter notebook format"}

      String.starts_with?(mime_type, "text/") and not String.valid?(content) ->
        {:error, "Invalid text encoding"}

      true ->
        :ok
    end
  end

  @impl true
  def transform_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    case mime_type do
      "application/x-ipynb+json" ->
        case parse_jupyter_notebook(content) do
          {:ok, notebook_data} ->
            updated_metadata =
              Map.merge(metadata, %{
                notebook_format: "jupyter",
                kernel_spec: notebook_data.kernel_spec,
                language: notebook_data.language,
                cell_count: length(notebook_data.cells),
                has_outputs: has_cell_outputs?(notebook_data.cells),
                execution_count: get_max_execution_count(notebook_data.cells),
                notebook_version: notebook_data.nbformat,
                metadata_hash: generate_metadata_hash(notebook_data.metadata)
              })

            {:ok, content, updated_metadata}

          {:error, reason} ->
            {:error, "Failed to parse Jupyter notebook: #{reason}"}
        end

      "text/markdown" ->
        case extract_notebook_metadata_from_markdown(content) do
          {:ok, nb_metadata} ->
            updated_metadata =
              Map.merge(metadata, %{
                notebook_format: "markdown",
                language: nb_metadata.language,
                cell_count: nb_metadata.cell_count,
                has_code_cells: nb_metadata.has_code_cells,
                word_count: count_words(content),
                estimated_read_time: estimate_read_time(content)
              })

            {:ok, content, updated_metadata}

          {:error, _} ->
            # Fallback to regular markdown processing
            updated_metadata =
              Map.merge(metadata, %{
                notebook_format: "markdown",
                language: "markdown",
                word_count: count_words(content),
                estimated_read_time: estimate_read_time(content)
              })

            {:ok, content, updated_metadata}
        end

      "text/x-python" ->
        cell_info = analyze_python_cells(content)

        updated_metadata =
          Map.merge(metadata, %{
            notebook_format: "python",
            language: "python",
            cell_count: cell_info.cell_count,
            function_count: cell_info.function_count,
            import_count: cell_info.import_count,
            line_count: count_lines(content)
          })

        {:ok, content, updated_metadata}

      _ ->
        # Basic text processing for other formats
        updated_metadata =
          Map.merge(metadata, %{
            notebook_format: "text",
            language: detect_language_from_mime(mime_type),
            line_count: count_lines(content),
            character_count: String.length(content)
          })

        {:ok, content, updated_metadata}
    end
  end

  @impl true
  def storage_options(backend, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    base_options = %{
      mime_type: mime_type,
      media_type: :notebook
    }

    case backend do
      :git ->
        Map.merge(base_options, %{
          commit_message: "Update notebook content",
          branch: "main",
          enable_lfs: has_large_outputs?(metadata),
          ignore_outputs: should_ignore_outputs?(metadata)
        })

      :hybrid ->
        Map.merge(base_options, %{
          primary_backend: :git,
          secondary_backend: :s3,
          # Store outputs separately in S3
          split_outputs: true,
          version_control: true
        })

      :s3 ->
        Map.merge(base_options, %{
          storage_class: "STANDARD",
          server_side_encryption: "AES256",
          versioning: true
        })

      :disk ->
        Map.merge(base_options, %{
          create_directory: true,
          sync: true,
          backup: true
        })

      _ ->
        base_options
    end
  end

  @impl true
  def select_storage_backend(content, metadata) do
    file_size = byte_size(content)
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")
    has_outputs = Map.get(metadata, :has_outputs, false)

    cond do
      # Large notebooks with outputs use hybrid storage
      file_size > 10 * 1024 * 1024 or has_outputs ->
        :hybrid

      # Jupyter notebooks prefer Git for version control
      String.contains?(mime_type, "ipynb") ->
        :git

      # Python/R/Julia notebooks prefer Git
      mime_type in ["text/x-python", "text/x-r", "text/x-julia"] ->
        :git

      # Large files go to S3
      file_size > 50 * 1024 * 1024 ->
        :s3

      # Default to Git for version control
      true ->
        :git
    end
  end

  # Relationships
  relationships do
    belongs_to :file, Dirup.Workspaces.File do
      allow_nil? false
      attribute_writable? true
      public? true
    end

    belongs_to :notebook, Dirup.Workspaces.Notebook do
      allow_nil? true
      attribute_writable? true
      public? true
    end
  end

  # FileNotebook-specific actions
  actions do
    # Define create action for JSON API
    create :create do
      accept [
        # :storage_resource_id,
        :file_id,
        :notebook_id,
        :relationship_type,
        :media_type,
        :is_primary,
        :metadata
      ]
    end

    # Define update action with require_atomic? false
    update :update do
      require_atomic? false
    end

    read :by_file do
      argument :file_id, :uuid, allow_nil?: false

      prepare build(
                filter: [file_id: arg(:file_id)],
                load: [:storage_resource, :notebook, :storage_info],
                sort: [is_primary: :desc, created_at: :desc]
              )
    end

    read :primary_for_file do
      argument :file_id, :uuid, allow_nil?: false

      prepare build(
                filter: [file_id: arg(:file_id), is_primary: true],
                load: [:storage_resource, :notebook, :storage_info]
              )
    end

    create :create_from_file do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :storage_backend, :atom
      argument :notebook_format, :string, default: "jupyter"

      change set_attribute(:is_primary, true)
      change set_attribute(:relationship_type, :primary)
      change {__MODULE__.Changes.CreateFromFile, []}
      change {__MODULE__.Changes.CreateNotebookResource, []}
    end

    create :create_checkpoint do
      argument :file_id, :uuid, allow_nil?: false
      argument :checkpoint_name, :string, allow_nil?: false
      argument :include_outputs, :boolean, default: true

      change set_attribute(:relationship_type, :checkpoint)
      change {__MODULE__.Changes.CreateCheckpoint, []}
    end

    action :execute_cells, :map do
      argument :cell_ids, {:array, :string}
      argument :kernel_name, :string
      argument :execution_timeout, :integer, default: 30

      run {__MODULE__.Actions.ExecuteCells, []}
    end

    action :clear_outputs, :struct do
      run {__MODULE__.Actions.ClearOutputs, []}
    end

    action :convert_format, :struct do
      argument :target_format, :string, allow_nil?: false
      argument :include_outputs, :boolean, default: true
      argument :template, :string

      run {__MODULE__.Actions.ConvertFormat, []}
    end

    action :extract_code, :string do
      argument :language, :string
      argument :include_markdown, :boolean, default: false

      run {__MODULE__.Actions.ExtractCode, []}
    end

    action :analyze_dependencies, {:array, :string} do
      run {__MODULE__.Actions.AnalyzeDependencies, []}
    end

    action :validate_notebook, :map do
      run {__MODULE__.Actions.ValidateNotebook, []}
    end
  end

  # FileNotebook-specific calculations
  calculations do
    import Dirup.Storage.AbstractStorage.CommonCalculations

    storage_info()
    content_preview()

    calculate :notebook_stats, :map do
      load [:metadata, :storage_resource]

      calculation fn file_notebooks, _context ->
        Enum.map(file_notebooks, fn fn_entry ->
          metadata = fn_entry.metadata || %{}
          storage = fn_entry.storage_resource

          %{
            format: Map.get(metadata, "notebook_format", "unknown"),
            language: Map.get(metadata, "language", "unknown"),
            cell_count: Map.get(metadata, "cell_count", 0),
            execution_count: Map.get(metadata, "execution_count", 0),
            has_outputs: Map.get(metadata, "has_outputs", false),
            file_size: storage.file_size,
            last_modified: storage.updated_at,
            kernel_spec: Map.get(metadata, "kernel_spec", %{})
          }
        end)
      end
    end

    calculate :execution_info, :map do
      load [:metadata]

      calculation fn file_notebooks, _context ->
        Enum.map(file_notebooks, fn fn_entry ->
          metadata = fn_entry.metadata || %{}

          %{
            is_executable: fn_entry.relationship_type == :primary,
            last_execution: Map.get(metadata, "last_execution"),
            execution_status: Map.get(metadata, "execution_status", "idle"),
            kernel_status: Map.get(metadata, "kernel_status", "unknown"),
            has_pending_cells: Map.get(metadata, "has_pending_cells", false)
          }
        end)
      end
    end

    calculate :dependency_info, :map do
      load [:metadata]

      calculation fn file_notebooks, _context ->
        Enum.map(file_notebooks, fn fn_entry ->
          metadata = fn_entry.metadata || %{}

          %{
            imports: Map.get(metadata, "imports", []),
            requirements: Map.get(metadata, "requirements", []),
            environment: Map.get(metadata, "environment", %{}),
            dependencies_resolved: Map.get(metadata, "dependencies_resolved", false)
          }
        end)
      end
    end
  end

  # FileNotebook-specific validations
  validations do
    validate present([:file_id, :storage_resource_id])
    validate one_of(:relationship_type, [:primary, :checkpoint, :version, :backup, :cache])
    validate {__MODULE__.Validations.ValidateNotebookFormat, []}
  end

  # Private helper functions
  defp valid_jupyter_notebook?(content) do
    case Jason.decode(content) do
      {:ok, %{"cells" => _, "metadata" => _, "nbformat" => _}} -> true
      _ -> false
    end
  end

  defp parse_jupyter_notebook(content) do
    case Jason.decode(content) do
      {:ok, notebook} ->
        {:ok,
         %{
           cells: notebook["cells"] || [],
           metadata: notebook["metadata"] || %{},
           kernel_spec: get_kernel_spec(notebook),
           language: get_notebook_language(notebook),
           nbformat: notebook["nbformat"] || 4
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_kernel_spec(notebook) do
    get_in(notebook, ["metadata", "kernelspec"]) || %{}
  end

  defp get_notebook_language(notebook) do
    get_in(notebook, ["metadata", "language_info", "name"]) ||
      get_in(notebook, ["metadata", "kernelspec", "language"]) ||
      "unknown"
  end

  defp has_cell_outputs?(cells) do
    Enum.any?(cells, fn cell ->
      case cell["outputs"] do
        nil -> false
        [] -> false
        _ -> true
      end
    end)
  end

  defp get_max_execution_count(cells) do
    cells
    |> Enum.map(fn cell -> cell["execution_count"] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
  end

  defp generate_metadata_hash(metadata) do
    metadata
    |> Jason.encode!()
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16(case: :lower)
  end

  defp extract_notebook_metadata_from_markdown(content) do
    # Look for YAML frontmatter or notebook-style metadata
    case String.split(content, "\n---\n", parts: 2) do
      [frontmatter, _body] ->
        case YamlElixir.read_from_string(frontmatter) do
          {:ok, metadata} ->
            {:ok,
             %{
               language: metadata["language"] || "markdown",
               cell_count: count_markdown_cells(content),
               has_code_cells: has_markdown_code_blocks?(content)
             }}

          {:error, reason} ->
            {:error, reason}
        end

      _ ->
        {:ok,
         %{
           language: "markdown",
           cell_count: count_markdown_cells(content),
           has_code_cells: has_markdown_code_blocks?(content)
         }}
    end
  end

  defp analyze_python_cells(content) do
    lines = String.split(content, "\n")

    %{
      cell_count: count_python_cells(lines),
      function_count: count_python_functions(lines),
      import_count: count_python_imports(lines)
    }
  end

  defp count_words(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp count_lines(text) do
    text
    |> String.split("\n")
    |> length()
  end

  defp estimate_read_time(text) do
    word_count = count_words(text)
    # Average reading speed: 200 words per minute
    max(1, div(word_count, 200))
  end

  defp detect_language_from_mime("text/x-python"), do: "python"
  defp detect_language_from_mime("text/x-r"), do: "r"
  defp detect_language_from_mime("text/x-julia"), do: "julia"
  defp detect_language_from_mime("text/x-scala"), do: "scala"
  defp detect_language_from_mime(_), do: "unknown"

  defp has_large_outputs?(metadata) do
    Map.get(metadata, :has_outputs, false) and
      Map.get(metadata, :file_size, 0) > 5 * 1024 * 1024
  end

  defp should_ignore_outputs?(metadata) do
    # Ignore outputs for version control if they're large or binary
    has_large_outputs?(metadata)
  end

  defp count_markdown_cells(content) do
    # Count markdown sections/cells
    content
    |> String.split(~r/^\#{1,6}\s+/m)
    |> length()
  end

  defp has_markdown_code_blocks?(content) do
    String.contains?(content, "```")
  end

  defp count_python_cells(lines) do
    # Count cells marked with # %% or similar markers
    Enum.count(lines, fn line ->
      String.starts_with?(String.trim(line), ["# %%", "#%%", "# <codecell>"])
    end)
  end

  defp count_python_functions(lines) do
    Enum.count(lines, fn line ->
      String.trim(line) |> String.starts_with?("def ")
    end)
  end

  defp count_python_imports(lines) do
    Enum.count(lines, fn line ->
      trimmed = String.trim(line)
      String.starts_with?(trimmed, ["import ", "from "]) and String.contains?(trimmed, "import")
    end)
  end

  # Change modules
  defmodule Changes do
    defmodule CreateFromFile do
      use Ash.Resource.Change

      def change(changeset, _opts, context) do
        file_id = Ash.Changeset.get_argument(changeset, :file_id)
        content = Ash.Changeset.get_argument(changeset, :content)
        storage_backend = Ash.Changeset.get_argument(changeset, :storage_backend)
        notebook_format = Ash.Changeset.get_argument(changeset, :notebook_format)

        if file_id && content do
          # Get the file to determine filename and mime type
          case Ash.get(Dirup.Workspaces.File, file_id) do
            {:ok, file} ->
              # Create storage resource
              case Dirup.Storage.store_content(content, file.name,
                     backend: storage_backend || :git,
                     storage_options: %{notebook_format: notebook_format}
                   ) do
                {:ok, storage_resource} ->
                  changeset
                  |> Ash.Changeset.change_attribute(:file_id, file_id)
                  |> Ash.Changeset.change_attribute(:storage_resource_id, storage_resource.id)

                {:error, reason} ->
                  Ash.Changeset.add_error(
                    changeset,
                    "Failed to store notebook content: #{inspect(reason)}"
                  )
              end

            {:error, _reason} ->
              Ash.Changeset.add_error(changeset, "File not found")
          end
        else
          changeset
        end
      end
    end

    defmodule CreateNotebookResource do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        changeset
        |> Ash.Changeset.after_action(fn changeset, file_notebook ->
          # Create the corresponding Notebook resource
          case create_notebook_from_file_notebook(file_notebook) do
            {:ok, notebook} ->
              # Update the file_notebook to reference the notebook
              Ash.update(file_notebook, %{notebook_id: notebook.id})

            {:error, reason} ->
              require Logger
              Logger.warning("Failed to create Notebook resource: #{inspect(reason)}")
              {:ok, file_notebook}
          end
        end)
      end

      defp create_notebook_from_file_notebook(file_notebook) do
        # This would create a Notebook resource based on the file_notebook
        # Implementation depends on your Notebook resource structure
        # Placeholder
        {:ok, %{id: Ash.UUID.generate()}}
      end
    end

    defmodule CreateCheckpoint do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        checkpoint_name = Ash.Changeset.get_argument(changeset, :checkpoint_name)
        include_outputs = Ash.Changeset.get_argument(changeset, :include_outputs)

        # Create checkpoint metadata
        checkpoint_metadata = %{
          checkpoint_name: checkpoint_name,
          include_outputs: include_outputs,
          created_at: DateTime.utc_now()
        }

        changeset
        |> Ash.Changeset.change_attribute(:metadata, checkpoint_metadata)
      end
    end
  end

  # Action modules
  defmodule Actions do
    defmodule ExecuteCells do
      # # use Ash.Resource.Action

      def run(file_notebook, input, _context) do
        cell_ids = input.arguments.cell_ids
        kernel_name = input.arguments.kernel_name
        execution_timeout = input.arguments.execution_timeout

        # Execute notebook cells
        # Implementation depends on notebook execution engine
        execution_results = %{
          executed_cells: length(cell_ids),
          execution_time: 1.5,
          status: "completed",
          outputs: []
        }

        {:ok, execution_results}
      end
    end

    defmodule ClearOutputs do
      # use Ash.Resource.Action

      def run(file_notebook, _input, _context) do
        # Clear all outputs from notebook content
        # Implementation depends on notebook format
        {:ok, file_notebook}
      end
    end

    defmodule ConvertFormat do
      # use Ash.Resource.Action

      def run(file_notebook, input, _context) do
        target_format = input.arguments.target_format
        include_outputs = input.arguments.include_outputs
        template = input.arguments.template

        # Convert notebook to target format
        # Implementation depends on conversion tools (nbconvert, etc.)
        {:ok, file_notebook}
      end
    end

    defmodule ExtractCode do
      # use Ash.Resource.Action

      def run(file_notebook, input, _context) do
        language = input.arguments.language
        include_markdown = input.arguments.include_markdown

        # Extract code cells from notebook
        # Implementation depends on notebook parsing
        extracted_code = "# Extracted code placeholder"

        {:ok, extracted_code}
      end
    end

    defmodule AnalyzeDependencies do
      # use Ash.Resource.Action

      def run(file_notebook, _input, _context) do
        # Analyze notebook dependencies
        # Implementation depends on language-specific analysis
        dependencies = ["numpy", "pandas", "matplotlib"]

        {:ok, dependencies}
      end
    end

    defmodule ValidateNotebook do
      # use Ash.Resource.Action

      def run(file_notebook, _input, _context) do
        # Validate notebook structure and content
        # Implementation depends on validation requirements
        validation_results = %{
          is_valid: true,
          warnings: [],
          errors: [],
          suggestions: []
        }

        {:ok, validation_results}
      end
    end
  end

  # Validation modules
  defmodule Validations do
    defmodule ValidateNotebookFormat do
      use Ash.Resource.Validation

      def validate(changeset, _opts, _context) do
        # Validate that the content is a valid notebook format
        # Implementation depends on actual validation needs
        :ok
      end
    end
  end
end
