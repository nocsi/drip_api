defmodule DirupWeb.Live.Workspaces.Files.Editor do
  @moduledoc """
  Document editor LiveView that serves the Svelte document component.

  This LiveView provides the socket connection and data for the Svelte document editor.
  """

  use DirupWeb, :live_view

  # alias Dirup.Workspaces.DocumentBlobRef
  alias Dirup.Workspaces

  on_mount {DirupWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"id" => document_id}, session, socket) do
    user = socket.assigns.current_user

    csrf_token = session.get_csrf_token()

    # Load document with team context
    case load_document_with_content(document_id, user) do
      {:ok, document, content} ->
        socket =
          socket
          |> assign(:document, document)
          |> assign(:csrf_token, csrf_token)
          |> assign(:content, content)
          |> assign(:document_data, prepare_document_data(document, content, user))
          |> assign(:page_title, "Editing: #{document.title}")

        # Subscribe to document updates if connected
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Dirup.PubSub, "document:#{document_id}")
          Phoenix.PubSub.subscribe(Dirup.PubSub, "document:#{document_id}:collaboration")
        end

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Document not found")
          |> push_navigate(to: ~p"/workspaces")

        {:ok, socket}

      {:error, :unauthorized} ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to edit this document")
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
  def handle_event("save_document", %{"content" => content}, socket) do
    case save_document_content(socket, content) do
      {:ok, updated_document} ->
        socket =
          socket
          |> assign(:document, updated_document)
          |> assign(:content, content)
          |> assign(
            :document_data,
            prepare_document_data(updated_document, content, socket.assigns.current_user)
          )

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to save: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_collaborative_mode", %{"enabled" => enabled}, socket) do
    # For documents, we might not have a collaborative_mode field
    # This would depend on your document schema
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_document", %{"format" => format}, socket) do
    case export_document(socket.assigns.document, format) do
      {:ok, exported_content} ->
        # Push download event to Svelte component
        socket =
          push_event(socket, "download_file", %{
            content: exported_content,
            filename: "#{socket.assigns.document.title}.#{format}",
            mime_type: get_export_mime_type(format)
          })

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Export failed: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:content_updated, content}, socket) do
    socket = push_event(socket, "content_updated", %{content: content})
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

  def handle_info(_, socket), do: {:noreply, socket}

  # Private helper functions

  defp load_document_with_content(document_id, user) do
    case Workspaces.get_document(document_id, actor: user) do
      {:ok, document} ->
        case DocumentBlobRef.get_document_content(document_id) do
          {:ok, content} ->
            {:ok, document, content}

          {:error, _} ->
            # Document exists but has no content blob, return empty content
            {:ok, document, ""}
        end

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, _} ->
        {:error, :unauthorized}
    end
  end

  defp save_document_content(socket, content) do
    document = socket.assigns.document
    user = socket.assigns.current_user

    # Update blob reference with new content
    case DocumentBlobRef.update_document_content(
           document.id,
           content,
           "text/markdown"
         ) do
      {:ok, _blob_ref} ->
        # Update document metadata
        case Workspaces.update_document(
               document,
               %{
                 updated_at: DateTime.utc_now()
               },
               actor: user
             ) do
          {:ok, updated_document} ->
            # Broadcast content update to collaborators
            Phoenix.PubSub.broadcast(
              Dirup.PubSub,
              "document:#{document.id}",
              {:content_updated, content}
            )

            {:ok, updated_document}

          {:error, reason} ->
            {:error, "Failed to update document metadata: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to save content: #{inspect(reason)}"}
    end
  end

  defp prepare_document_data(document, content, user) do
    %{
      id: document.id,
      title: document.title,
      content: content,
      content_type: document.content_type,
      description: document.description,
      tags: document.tags || [],
      created_at: document.created_at,
      updated_at: document.updated_at,
      user: %{
        id: user.id,
        name: user.name
      }
    }
  end

  defp export_document(document, "html") do
    case DocumentBlobRef.get_document_content(document.id) do
      {:ok, content} ->
        # Convert markdown to HTML
        html = Earmark.as_html!(content)

        full_html = """
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{document.title}</title>
          <meta charset="utf-8">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; }
            code { background: #f5f5f5; padding: 0.2em 0.4em; border-radius: 3px; }
            pre { background: #f5f5f5; padding: 1rem; border-radius: 5px; overflow-x: auto; }
            blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 1rem; }
          </style>
        </head>
        <body>
          #{html}
        </body>
        </html>
        """

        {:ok, full_html}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp export_document(document, "md") do
    DocumentBlobRef.get_document_content(document.id)
  end

  defp export_document(_document, format) do
    {:error, "Unsupported export format: #{format}"}
  end

  defp get_export_mime_type("html"), do: "text/html"
  defp get_export_mime_type("md"), do: "text/markdown"
  defp get_export_mime_type("pdf"), do: "application/pdf"
  defp get_export_mime_type(_), do: "application/octet-stream"
end
