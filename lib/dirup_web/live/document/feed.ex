defmodule DirupWeb.Live.Document.Feed do
  use DirupWeb, :live_view
  use LiveStreamAsync

  alias Dirup.Workspaces
  alias Dirup.Workspaces.Document

  @documents :documents

  def render(assigns) do
    ~H"""
    <.async_result :let={stream_key} assign={@documents}>
      <:loading>Loading documents...</:loading>
      <:failed :let={_failure}>
        There was an error loading the hotels. Please try again later.
      </:failed>
      <ul id="documents_stream" phx-update="stream">
        <li :for={{id, document} <- @streams[stream_key]} id={id}>
          {document.name}
        </li>
      </ul>
    </.async_result>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(feed_id: :documents)
      |> assign(page_title: "Documents")
      |> assign(page_description: "List of documents")
      |> assign(
        nav_items: [
          %{label: "New Document", icon: "plus", path: Routes.document_path(socket, :new)}
        ]
      )
      |> assign(:documents, [])

    {:ok,
     socket
     |> assign(@documents, AsyncResult.loading())
     # |> start_async(@documents, fn -> Document.fetch!(document) end)
     |> stream(:documents, Document.list_documents())}
  end

  # handle_async(@documents, {:ok, documents}, socket) do
  #   {:noreply, assign(socket, :documents, documents)}
  # end

  # handle_async(@documents, {:error, reason}, socket) do
  #   {:noreply,
  #    socket
  #    |> assign(@documents, AsyncResult.ok(@documents))
  #    |> stream(@documents, documents, reset: true)
  #    }
  # end

  # def handle_async(@documents, {:exit, reason}, socket) do
  #    {:noreply,
  #     update(@documents, fn async_result -> AsyncResult.failed(async_result, {:exit, reason}) end)
  #     }
  # end
end
