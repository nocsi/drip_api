defmodule KyozoWeb.Live.Team.DashboardSvelte do
  use KyozoWeb, :live_view

  alias Kyozo.Accounts

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(KyozoWeb.PubSub, "members:#{current_user.id}")
      Phoenix.PubSub.subscribe(KyozoWeb.PubSub, "invitations:#{current_user.id}")
    end

    socket =
      socket
      |> assign(:page_title, "Team Dashboard - Svelte")
      |> assign(:current_tab, "overview")
      |> assign(:selected_team, nil)
      |> load_teams_and_data()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_tab = params["tab"] || "overview"
    
    socket = 
      socket
      |> assign(:current_tab, current_tab)

    {:noreply, socket}
  end

  @impl true
  def handle_event("test_event", _params, socket) do
    socket = put_flash(socket, :info, "Svelte integration working!")
    {:noreply, socket}
  end

  # Helper functions
  defp load_teams_and_data(socket) do
    current_user = socket.assigns.current_user

    # Load user's teams (simplified for now)
    user_teams = case Accounts.list_user_teams(actor: current_user) do
      {:ok, teams} -> teams
      _ -> []
    end
    
    # Load received invitations (simplified for now)
    received_invitations = case Accounts.list_received_invitations(actor: current_user) do
      {:ok, invitations} -> invitations
      _ -> []
    end
    
    socket
    |> assign(:user_teams, user_teams)
    |> assign(:received_invitations, received_invitations)
    |> assign(:team_members, [])
    |> assign(:sent_invitations, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Flash Messages -->
        <.flash_group flash={@flash} />
        
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Team Dashboard (Svelte Version)</h1>
          <p class="mt-2 text-gray-600">Enhanced team management with Svelte components</p>
        </div>

        <!-- Simple Test for now -->
        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-xl font-semibold mb-4">Team Management</h2>
          <p class="text-gray-600 mb-4">This will be enhanced with Svelte components.</p>
          
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-6">
            <!-- Teams Count -->
            <div class="bg-indigo-50 p-4 rounded-lg">
              <h3 class="font-medium text-indigo-900">My Teams</h3>
              <p class="text-2xl font-bold text-indigo-600"><%= length(@user_teams) %></p>
            </div>

            <!-- Invitations Count -->
            <div class="bg-yellow-50 p-4 rounded-lg">
              <h3 class="font-medium text-yellow-900">Pending Invitations</h3>
              <p class="text-2xl font-bold text-yellow-600"><%= length(@received_invitations) %></p>
            </div>

            <!-- Quick Actions -->
            <div class="bg-green-50 p-4 rounded-lg">
              <h3 class="font-medium text-green-900">Quick Actions</h3>
              <button 
                phx-click="test_event"
                class="mt-2 bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
              >
                Test Svelte
              </button>
            </div>
          </div>

          <div class="text-sm text-gray-500">
            <p>📝 TODO: Integrate with TeamDashboard.svelte component</p>
            <p>🔧 Current teams: <%= length(@user_teams) %></p>
            <p>📧 Pending invitations: <%= length(@received_invitations) %></p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end