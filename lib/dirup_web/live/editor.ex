defmodule DirupWeb.Live.Editor do
  use DirupWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    initial_content = %{
      "type" => "doc",
      "content" => []
    }

    socket =
      socket
      |> assign(:content, initial_content)
      |> assign(:editable, true)
      |> assign(:placeholder, "Start writing...")
      |> assign(:editor_content, %{word_count: 0, character_count: 0})
      |> assign(:editor_state, %{can_undo: false, can_redo: false})
      |> assign(:editor_config, %{editable: true})

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
    <div class="min-h-screen">
      <!-- Header -->
      <div class="bg-white border-b border-gray-200 px-6 py-4">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-semibold text-gray-900">TipTap Editor</h1>

          <div class="flex items-center space-x-4">
            <!-- Editor Stats -->
            <div class="text-sm text-gray-500">
              Words: {@editor_content[:word_count] || 0} |
              Characters: {@editor_content[:character_count] || 0}
            </div>
            
    <!-- Editor Controls -->
            <div class="flex items-center space-x-2">
              <button
                phx-click="undo"
                disabled={!@editor_state.can_undo}
                class="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed rounded"
              >
                Undo
              </button>

              <button
                phx-click="redo"
                disabled={!@editor_state.can_redo}
                class="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed rounded"
              >
                Redo
              </button>

              <button
                phx-click="toggle_editable"
                class="px-3 py-1 text-sm bg-blue-100 hover:bg-blue-200 text-blue-700 rounded"
              >
                {if @editor_config.editable, do: "Read Only", else: "Editable"}
              </button>

              <button
                phx-click="load_sample_content"
                class="px-3 py-1 text-sm bg-green-100 hover:bg-green-200 text-green-700 rounded"
              >
                Load Sample
              </button>

              <button
                phx-click="clear_content"
                class="px-3 py-1 text-sm bg-red-100 hover:bg-red-200 text-red-700 rounded"
              >
                Clear
              </button>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Main Content -->
      <div class="relative">
        <.svelte
          name="Editor"
          props={
            %{
              initialContent: @content,
              editable: @editable,
              placeholder: @placeholder
            }
          }
        />
      </div>
      
    <!-- Simple Status Bar -->
      <div class="fixed bottom-0 left-0 right-0 bg-gray-50 border-t border-gray-200 px-6 py-2">
        <div class="flex items-center justify-between text-sm text-gray-600">
          <div class="flex items-center space-x-4">
            <span>LiveView TipTap Editor</span>
            <span class="flex items-center">
              <span class="w-2 h-2 rounded-full mr-2 bg-green-400"></span> Connected
            </span>
          </div>

          <div class="flex items-center space-x-2">
            <button
              phx-click="load_sample"
              class="px-3 py-1 text-sm bg-blue-100 hover:bg-blue-200 text-blue-700 rounded"
            >
              Load Sample
            </button>

            <button
              phx-click="clear_content"
              class="px-3 py-1 text-sm bg-red-100 hover:bg-red-200 text-red-700 rounded"
            >
              Clear
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
