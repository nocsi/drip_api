defmodule Dirup.Projects.Changes.LoadProject do
  use Ash.Resource.Change

  alias Dirup.Projects.Services.ProjectLoader

  def change(changeset, opts, context) do
    type = opts[:type] || :auto

    changeset
    |> Ash.Changeset.after_action(fn changeset, project ->
      case load_project(project, type, context) do
        {:ok, updated_project} ->
          {:ok, updated_project}

        {:error, error} ->
          # Mark project as error and continue
          project
          |> Ash.Changeset.for_update(:mark_error, %{error_message: format_error(error)})
          |> Dirup.Projects.update!()
          |> then(&{:ok, &1})
      end
    end)
  end

  defp load_project(project, type, context) do
    sequence_counter = :counters.new(1, [])

    # Log start event
    log_event(project, :started_walk, %{}, sequence_counter, context)

    case type do
      :directory ->
        load_directory_project(project, sequence_counter, context)

      :file ->
        load_file_project(project, sequence_counter, context)

      :auto ->
        if File.dir?(project.path) do
          load_directory_project(project, sequence_counter, context)
        else
          load_file_project(project, sequence_counter, context)
        end
    end
  end

  defp load_directory_project(project, sequence_counter, context) do
    options = project.options || %{}

    try do
      # Walk directory and find files
      files =
        ProjectLoader.walk_directory(
          project.path,
          skip_gitignore: Map.get(options, "skip_gitignore", false),
          ignore_patterns: Map.get(options, "ignore_file_patterns", []),
          skip_repo_lookup: Map.get(options, "skip_repo_lookup_upward", false)
        )

      # Log directory and file discoveries
      Enum.each(files, fn
        {:dir, path} ->
          log_event(project, :found_dir, %{path: path}, sequence_counter, context)

        {:file, path} ->
          log_event(project, :found_file, %{path: path}, sequence_counter, context)
      end)

      # Filter for markdown files
      markdown_files =
        files
        |> Enum.filter(fn
          {:file, path} -> ProjectLoader.is_markdown_file?(path)
          _ -> false
        end)
        |> Enum.map(fn {:file, path} -> path end)

      # Process each markdown file
      {documents, tasks} =
        process_markdown_files(project, markdown_files, sequence_counter, context)

      # Log completion
      log_event(
        project,
        :finished_walk,
        %{
          files_found: length(files),
          markdown_files: length(markdown_files),
          documents_created: length(documents),
          tasks_found: length(tasks)
        },
        sequence_counter,
        context
      )

      # Update project status
      project
      |> Ash.Changeset.for_update(:mark_loaded, %{
        document_count: length(documents),
        task_count: length(tasks)
      })
      |> Dirup.Projects.update()
    rescue
      error ->
        log_event(
          project,
          :error,
          %{
            error_message: Exception.message(error),
            stacktrace: Exception.format_stacktrace(__STACKTRACE__)
          },
          sequence_counter,
          context
        )

        {:error, error}
    end
  end

  defp load_file_project(project, sequence_counter, context) do
    try do
      if not File.exists?(project.path) do
        raise "File does not exist: #{project.path}"
      end

      if not ProjectLoader.is_markdown_file?(project.path) do
        raise "File is not a markdown file: #{project.path}"
      end

      # Log file discovery
      log_event(project, :found_file, %{path: project.path}, sequence_counter, context)

      # Process the single file
      {documents, tasks} =
        process_markdown_files(project, [project.path], sequence_counter, context)

      # Log completion
      log_event(
        project,
        :finished_walk,
        %{
          documents_created: length(documents),
          tasks_found: length(tasks)
        },
        sequence_counter,
        context
      )

      # Update project status
      project
      |> Ash.Changeset.for_update(:mark_loaded, %{
        document_count: length(documents),
        task_count: length(tasks)
      })
      |> Dirup.Projects.update()
    rescue
      error ->
        log_event(
          project,
          :error,
          %{
            error_message: Exception.message(error),
            stacktrace: Exception.format_stacktrace(__STACKTRACE__)
          },
          sequence_counter,
          context
        )

        {:error, error}
    end
  end

  defp process_markdown_files(project, file_paths, sequence_counter, context) do
    file_paths
    |> Enum.reduce({[], []}, fn file_path, {documents_acc, tasks_acc} ->
      case process_single_file(project, file_path, sequence_counter, context) do
        {:ok, document, tasks} ->
          {[document | documents_acc], tasks ++ tasks_acc}

        {:error, _error} ->
          # Error already logged, continue with other files
          {documents_acc, tasks_acc}
      end
    end)
  end

  defp process_single_file(project, file_path, sequence_counter, context) do
    relative_path = Path.relative_to(file_path, project.path)

    # Log start of document parsing
    log_event(project, :started_parsing_doc, %{path: relative_path}, sequence_counter, context)

    try do
      # Read file content
      {:ok, content} = File.read(file_path)

      # Get file stats
      {:ok, stats} = File.stat(file_path)

      # Create document
      document_attrs = %{
        path: relative_path,
        absolute_path: file_path,
        filename: Path.basename(file_path),
        name: Path.basename(file_path, Path.extname(file_path)),
        extension: Path.extname(file_path),
        content: content,
        size_bytes: stats.size,
        line_count: String.split(content, "\n") |> length(),
        modified_at: stats.mtime
      }

      {:ok, document} =
        Dirup.Projects.Document
        |> Ash.Changeset.for_create(:create, document_attrs, actor: project)
        |> Dirup.Projects.create()

      # Parse markdown to find tasks
      tasks =
        ProjectLoader.extract_tasks_from_markdown(
          content,
          project.identity_mode
        )

      # Create task records
      created_tasks =
        tasks
        |> Enum.with_index()
        |> Enum.map(fn {task_data, index} ->
          task_attrs =
            Map.merge(task_data, %{
              order_index: index,
              project_id: project.id,
              document_id: document.id
            })

          {:ok, task} =
            Dirup.Projects.Task
            |> Ash.Changeset.for_create(:create, task_attrs, actor: project)
            |> Dirup.Projects.create()

          # Log task discovery
          log_event(
            project,
            :found_task,
            %{
              path: relative_path,
              task_name: task.name,
              task_runme_id: task.runme_id,
              is_task_name_generated: task.is_name_generated
            },
            sequence_counter,
            context,
            %{
              document_id: document.id,
              task_id: task.id
            }
          )

          task
        end)

      # Update document with task count
      {:ok, updated_document} =
        document
        |> Ash.Changeset.for_update(:mark_parsed, %{
          task_count: length(created_tasks),
          metadata: %{
            tasks_found: length(created_tasks),
            languages: Enum.map(created_tasks, & &1.language) |> Enum.uniq()
          }
        })
        |> Dirup.Projects.update()

      # Log completion of document parsing
      log_event(
        project,
        :finished_parsing_doc,
        %{
          path: relative_path,
          tasks_found: length(created_tasks)
        },
        sequence_counter,
        context,
        %{document_id: document.id}
      )

      {:ok, updated_document, created_tasks}
    rescue
      error ->
        error_msg = Exception.message(error)

        log_event(
          project,
          :error,
          %{
            path: relative_path,
            error_message: error_msg,
            stage: "parsing_document"
          },
          sequence_counter,
          context
        )

        {:error, error_msg}
    end
  end

  defp log_event(project, event_type, event_data, sequence_counter, context, relations \\ %{}) do
    sequence = :counters.add(sequence_counter, 1, 1)

    attrs =
      %{
        event_type: event_type,
        event_data: event_data,
        sequence_number: sequence,
        occurred_at: DateTime.utc_now(),
        project_id: project.id
      }
      |> Map.merge(relations)
      |> Map.merge(extract_event_fields(event_type, event_data))

    Dirup.Projects.LoadEvent
    |> Ash.Changeset.for_create(:create_generic, attrs, actor: project)
    |> Dirup.Projects.create()
  end

  defp extract_event_fields(event_type, event_data) do
    case event_type do
      type when type in [:found_dir, :found_file, :started_parsing_doc, :finished_parsing_doc] ->
        %{path: Map.get(event_data, :path)}

      :found_task ->
        %{
          path: Map.get(event_data, :path),
          task_name: Map.get(event_data, :task_name),
          task_runme_id: Map.get(event_data, :task_runme_id),
          is_task_name_generated: Map.get(event_data, :is_task_name_generated, false)
        }

      :error ->
        %{
          path: Map.get(event_data, :path),
          error_message: Map.get(event_data, :error_message)
        }

      _ ->
        %{}
    end
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error) when is_exception(error), do: Exception.message(error)
  defp format_error(error), do: inspect(error)
end
