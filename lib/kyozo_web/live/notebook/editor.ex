defmodule KyozoWeb.Live.Notebook.Editor do
  @moduledoc """
  Notebook editor LiveView that serves the Svelte notebook component.

  This LiveView provides the socket connection and data for the Svelte notebook editor.
  """

  use KyozoWeb, :live_view

  alias Kyozo.Workspaces.Notebook
  alias Kyozo.Workspaces.DocumentBlobRef
  alias Kyozo.Workspaces.Document
  alias Kyozo.Workspaces.Blob
  alias Kyozo.Workspaces

  on_mount {KyozoWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"id" => notebook_id}, session, socket) do
    user = socket.assigns.current_user
    csrf_token = session.get_csrf_token()


    case load_notebook_with_content(notebook_id, user) do
      {:ok, notebook, content} ->
        notebook_data = prepare_notebook_data(notebook, content, user)
        
        socket =
          socket
          |> assign(:notebook, notebook)
          |> assign(:content, content)
          |> assign(:csrf_token, csrf_token)
          |> assign(:notebook_data, notebook_data)
          |> assign(:page_title, "Notebook: #{notebook.title}")
          |> assign(:autosave_enabled, true)
          |> assign(:last_saved_at, DateTime.utc_now())

        # Subscribe to updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook_id}")
          Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook_id}:execution")
          Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook_id}:collaboration")
        end

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Notebook not found")
          |> push_navigate(to: ~p"/workspaces")

        {:ok, socket}

      {:error, :unauthorized} ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to access this notebook")
          |> push_navigate(to: ~p"/workspaces")

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # Handle events from Svelte component
  @impl true
  def handle_event("save_notebook", %{"content" => content}, socket) do
    case save_notebook_content(socket, content) do
      {:ok, updated_notebook} ->
        notebook_data = prepare_notebook_data(updated_notebook, content, socket.assigns.current_user)
        
        socket =
          socket
          |> assign(:notebook, updated_notebook)
          |> assign(:content, content)
          |> assign(:notebook_data, notebook_data)
          |> assign(:last_saved_at, DateTime.utc_now())
          |> push_event("save_success", %{saved_at: DateTime.utc_now()})
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = 
          socket
          |> put_flash(:error, "Failed to save: #{reason}")
          |> push_event("save_error", %{error: reason})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_content", %{"content" => content, "html" => html}, socket) do
    case save_notebook_content(socket, content, html) do
      {:ok, updated_notebook} ->
        notebook_data = prepare_notebook_data(updated_notebook, content, socket.assigns.current_user)
        
        socket =
          socket
          |> assign(:notebook, updated_notebook)
          |> assign(:content, content)
          |> assign(:notebook_data, notebook_data)
          |> assign(:last_saved_at, DateTime.utc_now())
          |> push_event("save_success", %{saved_at: DateTime.utc_now()})
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = 
          socket
          |> put_flash(:error, "Failed to save: #{inspect(reason)}")
          |> push_event("save_error", %{error: inspect(reason)})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("execute_task", %{"task_id" => task_id, "code" => code, "language" => language}, socket) do
    # Execute task asynchronously
    Task.start(fn ->
      case execute_task(%{id: task_id, code: code, language: language}) do
        {:ok, output} ->
          Phoenix.PubSub.broadcast(
            Kyozo.PubSub,
            "notebook:#{socket.assigns.notebook.id}:execution",
            {:task_execution_completed, task_id, output}
          )
          
        {:error, error} ->
          Phoenix.PubSub.broadcast(
            Kyozo.PubSub,
            "notebook:#{socket.assigns.notebook.id}:execution",
            {:task_execution_failed, task_id, error}
          )
      end
    end)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_collaborative_mode", %{"enabled" => enabled}, socket) do
    case Workspaces.update_notebook(socket.assigns.notebook, %{
      collaborative_mode: enabled
    }, actor: socket.assigns.current_user) do
      {:ok, updated_notebook} ->
        socket = assign(socket, :notebook, updated_notebook)
        
        if enabled do
          Phoenix.PubSub.broadcast(
            Kyozo.PubSub,
            "notebook:#{socket.assigns.notebook.id}:collaboration",
            {:user_joined, socket.assigns.current_user}
          )
        else
          Phoenix.PubSub.broadcast(
            Kyozo.PubSub,
            "notebook:#{socket.assigns.notebook.id}:collaboration",
            {:user_left, socket.assigns.current_user}
          )
        end
        
        {:noreply, socket}
        
      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to toggle collaborative mode")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("export_notebook", %{"format" => format}, socket) do
    case export_notebook(socket.assigns.notebook, format) do
      {:ok, exported_content} ->
        # Push download event to Svelte component
        socket = push_event(socket, "download_file", %{
          content: exported_content,
          filename: "#{socket.assigns.notebook.title}.#{format}",
          mime_type: get_export_mime_type(format)
        })
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = put_flash(socket, :error, "Export failed: #{reason}")
        {:noreply, socket}
    end
  end

  # PubSub message handlers
  @impl true
  def handle_info({:task_execution_started, task_id}, socket) do
    socket = push_event(socket, "task_execution_started", %{task_id: task_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:task_execution_completed, task_id, output}, socket) do
    socket = push_event(socket, "task_execution_completed", %{task_id: task_id, output: output})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:task_execution_failed, task_id, error}, socket) do
    socket = push_event(socket, "task_execution_failed", %{task_id: task_id, error: error})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_joined, user}, socket) do
    if user.id != socket.assigns.current_user.id do
      socket = push_event(socket, "user_joined", %{user: %{id: user.id, name: user.name}})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:user_left, user}, socket) do
    socket = push_event(socket, "user_left", %{user: %{id: user.id, name: user.name}})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:content_updated, content}, socket) do
    socket = push_event(socket, "content_updated", %{content: content})
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # Private helper functions

  defp load_notebook_with_content(notebook_id, user) do
    case Workspaces.get_notebook(notebook_id, actor: user) do
      {:ok, notebook} ->
        case DocumentBlobRef.get_document_content(notebook.document_id) do
          {:ok, content} ->
            {:ok, notebook, content}
          {:error, _} ->
            {:ok, notebook, ""}
        end

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, _} ->
        {:error, :unauthorized}
    end
  end

  defp save_notebook_content(socket, content, html \\ nil) do
    notebook = socket.assigns.notebook
    user = socket.assigns.current_user

    # Update document content through blob reference
    case DocumentBlobRef.update_document_content(
      notebook.document_id,
      content,
      "text/markdown"
    ) do
      {:ok, _blob_ref} ->
        # Extract tasks from content
        tasks = extract_tasks_from_content(content)
        
        # Use provided HTML or render from markdown
        rendered_html = html || case render_markdown_content(content) do
          {:ok, h} -> h
          {:error, _} -> ""
        end

        # Update notebook with new content and metadata
        notebook_attrs = %{
          extracted_tasks: tasks,
          updated_at: DateTime.utc_now()
        }

        # Add HTML content if available
        notebook_attrs = if rendered_html && String.length(rendered_html) > 0 do
          Map.put(notebook_attrs, :content_html, rendered_html)
        else
          notebook_attrs
        end

        case Workspaces.update_notebook(notebook, notebook_attrs, actor: user) do
          {:ok, updated_notebook} ->
            # Broadcast content update for collaborative editing
            Phoenix.PubSub.broadcast(
              Kyozo.PubSub,
              "notebook:#{notebook.id}",
              {:content_updated, content}
            )

            # Broadcast to collaboration channel
            Phoenix.PubSub.broadcast(
              Kyozo.PubSub,
              "notebook:#{notebook.id}:collaboration",
              {:content_saved, %{user_id: user.id, saved_at: DateTime.utc_now()}}
            )

            {:ok, updated_notebook}

          {:error, reason} ->
            {:error, "Failed to update notebook: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to save content to blob storage: #{inspect(reason)}"}
    end
  end

  defp prepare_notebook_data(notebook, content, user) do
    %{
      id: notebook.id,
      title: notebook.title,
      content: content,
      status: notebook.status || "idle",
      extracted_tasks: notebook.extracted_tasks || [],
      execution_state: notebook.execution_state || %{},
      collaborative_mode: notebook.collaborative_mode || false,
      kernel_status: notebook.kernel_status || "idle",
      environment_variables: notebook.environment_variables || %{},
      execution_timeout: notebook.execution_timeout || 300,
      created_at: notebook.created_at,
      updated_at: notebook.updated_at,
      user: %{
        id: user.id,
        name: user.name || "Unknown User"
      }
    }
  end

  defp extract_tasks_from_content(content) do
    content
    |> String.split("```")
    |> Enum.with_index()
    |> Enum.filter(fn {_block, index} -> rem(index, 2) == 1 end)
    |> Enum.map(fn {block, _index} ->
      lines = String.split(block, "\n")
      language = List.first(lines) || "text"
      code = lines |> Enum.drop(1) |> Enum.join("\n") |> String.trim()

      if executable_language?(language) and String.length(code) > 0 do
        %{
          id: generate_task_id(),
          language: language,
          code: code,
          executable: true
        }
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp executable_language?(language) do
    language in ["python", "elixir", "javascript", "typescript", "bash", "shell", "sql", "r", "julia"]
  end

  defp generate_task_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp render_markdown_content(content) do
    try do
      # Use MDEx for better markdown rendering if available
      case Application.get_env(:kyozo, :markdown_processor, :earmark) do
        :mdex ->
          case MDEx.to_html(content) do
            {:ok, html} -> {:ok, html}
            {:error, _} -> fallback_markdown_render(content)
          end
        _ ->
          fallback_markdown_render(content)
      end
    rescue
      _ -> {:error, "Failed to render markdown"}
    end
  end

  defp fallback_markdown_render(content) do
    try do
      html = Earmark.as_html!(content)
      {:ok, html}
    rescue
      _ -> {:error, "Failed to render markdown with fallback"}
    end
  end

  defp execute_task(%{language: "python", code: _code}) do
    {:ok, "Python execution not implemented yet"}
  end

  defp execute_task(%{language: "elixir", code: code}) do
    try do
      {result, _} = Code.eval_string(code)
      {:ok, inspect(result)}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp execute_task(%{language: language, code: code}) when language in ["bash", "shell"] do
    case System.cmd("bash", ["-c", code], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, _} -> {:error, error}
    end
  rescue
    _ -> {:error, "Shell execution failed"}
  end

  defp execute_task(%{language: _language, code: _code}) do
    {:error, "Language execution not supported"}
  end

  defp export_notebook(notebook, "html") do
    case DocumentBlobRef.get_document_content(notebook.document_id) do
      {:ok, content} ->
        case render_markdown_content(content) do
          {:ok, html} ->
            full_html = """
            <!DOCTYPE html>
            <html>
            <head>
              <title>#{notebook.title}</title>
              <meta charset="utf-8">
              <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 1200px; margin: 0 auto; padding: 2rem; }
                pre { background: #f8f9fa; padding: 1rem; border-radius: 8px; overflow-x: auto; border: 1px solid #e9ecef; }
                code { background: #f8f9fa; padding: 0.2em 0.4em; border-radius: 4px; font-size: 0.875em; }
                blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 1rem; color: #666; }
                h1, h2, h3 { color: #333; }
              </style>
            </head>
            <body>
              <h1>#{notebook.title}</h1>
              #{html}
            </body>
            </html>
            """

            {:ok, full_html}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp export_notebook(notebook, "md") do
    DocumentBlobRef.get_document_content(notebook.document_id)
  end

  defp export_notebook(notebook, "ipynb") do
    case DocumentBlobRef.get_document_content(notebook.document_id) do
      {:ok, content} ->
        cells = content
        |> String.split("```")
        |> Enum.with_index()
        |> Enum.map(fn {block, index} ->
          if rem(index, 2) == 0 do
            %{
              "cell_type" => "markdown",
              "metadata" => %{},
              "source" => [String.trim(block)]
            }
          else
            lines = String.split(block, "\n")
            _language = List.first(lines) || "python"
            code = lines |> Enum.drop(1) |> Enum.join("\n") |> String.trim()

            %{
              "cell_type" => "code",
              "execution_count" => nil,
              "metadata" => %{},
              "outputs" => [],
              "source" => [code]
            }
          end
        end)
        |> Enum.filter(fn cell ->
          source = cell["source"]
          source != nil and length(source) > 0 and String.trim(List.first(source)) != ""
        end)

        notebook_json = %{
          "cells" => cells,
          "metadata" => %{
            "kernelspec" => %{
              "display_name" => "Python 3",
              "language" => "python",
              "name" => "python3"
            }
          },
          "nbformat" => 4,
          "nbformat_minor" => 4
        }

        {:ok, Jason.encode!(notebook_json, pretty: true)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp export_notebook(_notebook, format) do
    {:error, "Unsupported export format: #{format}"}
  end

  defp get_export_mime_type("html"), do: "text/html"
  defp get_export_mime_type("md"), do: "text/markdown"
  defp get_export_mime_type("ipynb"), do: "application/x-ipynb+json"
  defp get_export_mime_type(_), do: "application/octet-stream"

  # Helper function to clean up task extraction
  defp cleanup_task_code(code) do
    code
    |> String.trim()
    |> String.replace(~r/^\s*```.*\n/, "")
    |> String.replace(~r/\n```\s*$/, "")
  end

  # Enhanced task ID generation
  defp generate_task_id do
    timestamp = System.system_time(:microsecond)
    random_part = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "task_#{timestamp}_#{random_part}"
  end

  # Validate executable languages
  defp executable_language?(language) do
    normalized = String.downcase(String.trim(language))
    normalized in [
      "python", "py",
      "elixir", "ex", "exs", 
      "javascript", "js",
      "typescript", "ts",
      "bash", "sh", "shell",
      "sql", "postgresql", "postgres",
      "r", "julia", "rust", "go"
    ]
  end
end
