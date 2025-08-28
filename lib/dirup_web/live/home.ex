defmodule DirupWeb.Live.Home do
  use DirupWeb, :live_view

  on_mount {DirupWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("content_changed", %{"content" => content}, socket) do
    # This is called by the LiveViewTiptapExtension when content changes
    socket =
      socket
      |> assign(:content, content)
      # You can update these from the extension
      |> assign(:editor_content, %{word_count: 0, character_count: 0})

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_sample", _params, socket) do
    sample_content = %{
      "type" => "doc",
      "content" => [
        %{
          "type" => "heading",
          "attrs" => %{"level" => 1},
          "content" => [%{"type" => "text", "text" => "Welcome to TipTap with LiveView!"}]
        },
        %{
          "type" => "paragraph",
          "content" => [
            %{
              "type" => "text",
              "text" => "This editor is integrated with Phoenix LiveView using the "
            },
            %{
              "type" => "text",
              "marks" => [%{"type" => "bold"}],
              "text" => "LiveViewTiptapExtension"
            },
            %{"type" => "text", "text" => " from the elim library."}
          ]
        }
      ]
    }

    socket = assign(socket, :content, sample_content)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_content", _params, socket) do
    empty_content = %{"type" => "doc", "content" => []}

    socket =
      socket
      |> assign(:content, empty_content)
      |> assign(:editor_content, %{word_count: 0, character_count: 0})

    {:noreply, socket}
  end

  @impl true
  def handle_event("undo", _params, socket) do
    # Handle undo - you can implement this based on your needs
    {:noreply, socket}
  end

  @impl true
  def handle_event("redo", _params, socket) do
    # Handle redo - you can implement this based on your needs
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_editable", _params, socket) do
    current_editable = socket.assigns.editable
    new_editable = not current_editable

    socket =
      socket
      |> assign(:editable, new_editable)
      |> assign(:editor_config, %{editable: new_editable})

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_sample_content", _params, socket) do
    # Alias for load_sample to match button
    handle_event("load_sample", %{}, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <.svelte name="LandingPage" />
    </div>
    """
  end
end
