defmodule KyozoWeb.Live.Team.Dashboard do
  use KyozoWeb, :live_view

  alias Kyozo.Accounts
  alias Kyozo.Accounts.{Team, UserTeam, Invitation}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(KyozoWeb.PubSub, "members:#{current_user.id}")
      Phoenix.PubSub.subscribe(KyozoWeb.PubSub, "invitations:#{current_user.id}")
    end

    socket =
      socket
      |> assign(:page_title, "Team Dashboard")
      |> assign(:current_tab, "overview")
      |> assign(:show_create_team_modal, false)
      |> assign(:show_invite_modal, false)
      |> assign(:selected_team, nil)
      |> assign(:invite_email, "")
      |> assign(:team_form, to_form(%{}))
      |> load_teams_and_data()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_tab = params["tab"] || "overview"

    socket =
      socket
      |> assign(:current_tab, current_tab)
      |> maybe_select_team(params["team_id"])

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/team/dashboard?tab=#{tab}")}
  end

  def handle_event("select_team", %{"team_id" => team_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/team/dashboard?tab=#{socket.assigns.current_tab}&team_id=#{team_id}")}
  end

  def handle_event("show_create_team_modal", _params, socket) do
    form = Accounts.create_team(%{}, actor: socket.assigns.current_user) |> to_form()

    socket =
      socket
      |> assign(:show_create_team_modal, true)
      |> assign(:team_form, form)

    {:noreply, socket}
  end

  def handle_event("hide_create_team_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_team_modal, false)}
  end

  def handle_event("create_team", %{"form" => team_params}, socket) do
    case Accounts.create_team(team_params, actor: socket.assigns.current_user) do
      {:ok, team} ->
        socket =
          socket
          |> assign(:show_create_team_modal, false)
          |> put_flash(:info, "Team '#{team.name}' created successfully!")
          |> load_teams_and_data()

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :team_form, to_form(form))}
    end
  end

  def handle_event("show_invite_modal", _params, socket) do
    {:noreply, assign(socket, show_invite_modal: true, invite_email: "")}
  end

  def handle_event("hide_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  def handle_event("invite_user", %{"email" => email}, socket) do
    case Accounts.get_user_by_email(email) do
      {:ok, user} ->
        case Accounts.invite_user(%{invited_user_id: user.id},
                                  actor: socket.assigns.current_user,
                                  tenant: socket.assigns.selected_team) do
          {:ok, _invitation} ->
            socket =
              socket
              |> assign(:show_invite_modal, false)
              |> put_flash(:info, "Invitation sent to #{email}")
              |> load_team_data(socket.assigns.selected_team)

            {:noreply, socket}

          {:error, _error} ->
            socket = put_flash(socket, :error, "Failed to send invitation")
            {:noreply, socket}
        end

      {:error, _} ->
        socket = put_flash(socket, :error, "User with email #{email} not found")
        {:noreply, socket}
    end
  end

  def handle_event("remove_member", %{"member_id" => member_id}, socket) do
    case Accounts.remove_team_member(%{id: member_id},
                                    actor: socket.assigns.current_user,
                                    tenant: socket.assigns.selected_team) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Member removed successfully")
          |> load_team_data(socket.assigns.selected_team)

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to remove member")
        {:noreply, socket}
    end
  end

  def handle_event("change_member_role", %{"member_id" => member_id, "role" => role}, socket) do
    case Accounts.change_member_role(%{id: member_id, role: role},
                                    actor: socket.assigns.current_user,
                                    tenant: socket.assigns.selected_team) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Member role updated successfully")
          |> load_team_data(socket.assigns.selected_team)

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to update member role")
        {:noreply, socket}
    end
  end

  def handle_event("cancel_invitation", %{"invitation_id" => invitation_id}, socket) do
    case Accounts.cancel_invitation(%{id: invitation_id},
                                   actor: socket.assigns.current_user,
                                   tenant: socket.assigns.selected_team) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Invitation cancelled")
          |> load_team_data(socket.assigns.selected_team)

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to cancel invitation")
        {:noreply, socket}
    end
  end

  def handle_event("accept_invitation", %{"invitation_id" => invitation_id}, socket) do
    case Accounts.accept_invitation(%{id: invitation_id}, actor: socket.assigns.current_user) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Invitation accepted!")
          |> load_teams_and_data()

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to accept invitation")
        {:noreply, socket}
    end
  end

  def handle_event("decline_invitation", %{"invitation_id" => invitation_id}, socket) do
    case Accounts.decline_invitation(%{id: invitation_id}, actor: socket.assigns.current_user) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Invitation declined")
          |> load_teams_and_data()

        {:noreply, socket}

      {:error, _error} ->
        socket = put_flash(socket, :error, "Failed to decline invitation")
        {:noreply, socket}
    end
  end

  def handle_event("leave_team", %{"team_id" => team_id}, socket) do
    # Find the user's membership in this team
    case Enum.find(socket.assigns.team_members, &(&1.team_id == team_id && &1.user_id == socket.assigns.current_user.id)) do
      nil ->
        socket = put_flash(socket, :error, "You are not a member of this team")
        {:noreply, socket}

      user_team ->
        case Accounts.leave_team(%{id: user_team.id},
                                actor: socket.assigns.current_user,
                                tenant: team_id) do
          {:ok, _} ->
            socket =
              socket
              |> put_flash(:info, "Left team successfully")
              |> load_teams_and_data()

            {:noreply, socket}

          {:error, _error} ->
            socket = put_flash(socket, :error, "Failed to leave team")
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_info({:member_added, _member}, socket) do
    {:noreply, load_teams_and_data(socket)}
  end

  def handle_info({:member_removed, _member}, socket) do
    {:noreply, load_teams_and_data(socket)}
  end

  def handle_info({:invitation_received, _invitation}, socket) do
    {:noreply, load_teams_and_data(socket)}
  end

  def handle_info({:invitation_cancelled, _invitation}, socket) do
    {:noreply, load_teams_and_data(socket)}
  end

  # Helper functions
  defp load_teams_and_data(socket) do
    current_user = socket.assigns.current_user

    # Load user's teams
    user_teams = Accounts.list_user_teams(actor: current_user)

    # Load received invitations
    received_invitations = Accounts.list_received_invitations(actor: current_user)

    socket =
      socket
      |> assign(:user_teams, user_teams)
      |> assign(:received_invitations, received_invitations)

    # If a team is selected, load its data
    if socket.assigns[:selected_team] do
      load_team_data(socket, socket.assigns.selected_team)
    else
      socket
      |> assign(:team_members, [])
      |> assign(:sent_invitations, [])
    end
  end

  defp load_team_data(socket, team) when is_map(team) do
    load_team_data(socket, team.id)
  end

  defp load_team_data(socket, team_id) when is_binary(team_id) do
    # Load team members
    team_members = Accounts.list_team_members(actor: socket.assigns.current_user, tenant: team_id)

    # Load sent invitations for this team
    sent_invitations = Accounts.list_invitations_sent(actor: socket.assigns.current_user, tenant: team_id)

    socket
    |> assign(:team_members, team_members)
    |> assign(:sent_invitations, sent_invitations)
  end

  defp maybe_select_team(socket, nil), do: socket
  defp maybe_select_team(socket, team_id) do
    # Find the team in user's teams
    case Enum.find(socket.assigns.user_teams || [], &(&1.id == team_id)) do
      nil -> socket
      team ->
        socket
        |> assign(:selected_team, team)
        |> load_team_data(team)
    end
  end

  defp role_color(role) do
    case role do
      "owner" -> "bg-purple-100 text-purple-800"
      "admin" -> "bg-blue-100 text-blue-800"
      "member" -> "bg-gray-100 text-gray-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Team Dashboard</h1>
          <p class="mt-2 text-gray-600">Manage your teams, members, and invitations</p>
        </div>

        <!-- Navigation Tabs -->
        <div class="mb-8">
          <nav class="flex space-x-8" aria-label="Tabs">
            <button
              phx-click="switch_tab"
              phx-value-tab="overview"
              class={[
                "py-2 px-1 border-b-2 font-medium text-sm transition-colors",
                if(@current_tab == "overview",
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Overview
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="teams"
              class={[
                "py-2 px-1 border-b-2 font-medium text-sm transition-colors",
                if(@current_tab == "teams",
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              My Teams
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="invitations"
              class={[
                "py-2 px-1 border-b-2 font-medium text-sm transition-colors",
                if(@current_tab == "invitations",
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Invitations
              <%= if length(@received_invitations || []) > 0 do %>
                <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                  <%= length(@received_invitations) %>
                </span>
              <% end %>
            </button>
          </nav>
        </div>

        <!-- Tab Content -->
        <div class="space-y-6">
          <%= case @current_tab do %>
            <% "overview" -> %>
              <%= render_overview(assigns) %>
            <% "teams" -> %>
              <%= render_teams(assigns) %>
            <% "invitations" -> %>
              <%= render_invitations(assigns) %>
          <% end %>
        </div>
      </div>

      <!-- Create Team Modal -->
      <%= if @show_create_team_modal do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 transition-opacity" aria-hidden="true">
              <div class="absolute inset-0 bg-gray-500 opacity-75"></div>
            </div>

            <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
              <div>
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                  Create New Team
                </h3>

                <.simple_form for={@team_form} phx-submit="create_team">
                  <.input field={@team_form[:name]} label="Team Name" required />
                  <.input field={@team_form[:domain]} label="Domain" placeholder="my-team" required />
                  <.input field={@team_form[:description]} label="Description" type="textarea" />

                  <div class="mt-6 flex justify-end space-x-3">
                    <button
                      type="button"
                      phx-click="hide_create_team_modal"
                      class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                    <button type="submit" class="bg-indigo-600 py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white hover:bg-indigo-700">
                      Create Team
                    </button>
                  </div>
                </.simple_form>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Invite User Modal -->
      <%= if @show_invite_modal do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 transition-opacity" aria-hidden="true">
              <div class="absolute inset-0 bg-gray-500 opacity-75"></div>
            </div>

            <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
              <div>
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                  Invite User to <%= @selected_team.name %>
                </h3>

                <form phx-submit="invite_user">
                  <div class="mb-4">
                    <label for="email" class="block text-sm font-medium text-gray-700">Email Address</label>
                    <input
                      type="email"
                      name="email"
                      id="email"
                      value={@invite_email}
                      class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                      placeholder="user@example.com"
                      required
                    />
                  </div>

                  <div class="mt-6 flex justify-end space-x-3">
                    <button
                      type="button"
                      phx-click="hide_invite_modal"
                      class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="bg-indigo-600 py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white hover:bg-indigo-700"
                    >
                      Send Invitation
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_overview(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <!-- Teams Count -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-8 w-8 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">My Teams</dt>
                <dd class="text-2xl font-semibold text-gray-900"><%= length(@user_teams || []) %></dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Pending Invitations -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-8 w-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Pending Invitations</dt>
                <dd class="text-2xl font-semibold text-gray-900"><%= length(@received_invitations || []) %></dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Quick Actions</h3>
          <div class="space-y-3">
            <button
              phx-click="show_create_team_modal"
              class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 text-sm font-medium"
            >
              Create New Team
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="invitations"
              class="w-full bg-gray-100 text-gray-700 py-2 px-4 rounded-md hover:bg-gray-200 text-sm font-medium"
            >
              View Invitations
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Recent Teams -->
    <%= if length(@user_teams || []) > 0 do %>
      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Recent Teams</h3>
        </div>
        <div class="divide-y divide-gray-200">
          <%= for team <- Enum.take(@user_teams, 5) do %>
            <div class="px-6 py-4 flex items-center justify-between">
              <div>
                <h4 class="text-sm font-medium text-gray-900"><%= team.name %></h4>
                <p class="text-sm text-gray-500"><%= team.domain %></p>
              </div>
              <button
                phx-click="select_team"
                phx-value-team_id={team.id}
                class="text-indigo-600 hover:text-indigo-500 text-sm font-medium"
              >
                Manage →
              </button>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_teams(assigns) do
    ~H"""
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-xl font-semibold text-gray-900">My Teams</h2>
      <button
        phx-click="show_create_team_modal"
        class="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 text-sm font-medium"
      >
        Create Team
      </button>
    </div>

    <%= if length(@user_teams || []) == 0 do %>
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No teams</h3>
        <p class="mt-1 text-sm text-gray-500">Get started by creating a new team.</p>
        <div class="mt-6">
          <button
            phx-click="show_create_team_modal"
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
          >
            Create Team
          </button>
        </div>
      </div>
    <% else %>
      <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        <%= for team <- @user_teams do %>
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900"><%= team.name %></h3>
              <%= if team.id == (@selected_team && @selected_team.id) do %>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  Selected
                </span>
              <% end %>
            </div>

            <div class="space-y-2 mb-4">
              <p class="text-sm text-gray-600">Domain: <%= team.domain %></p>
              <%= if team.description do %>
                <p class="text-sm text-gray-600"><%= team.description %></p>
              <% end %>
            </div>

            <div class="flex justify-between">
              <button
                phx-click="select_team"
                phx-value-team_id={team.id}
                class="text-indigo-600 hover:text-indigo-500 text-sm font-medium"
              >
                <%= if team.id == (@selected_team && @selected_team.id), do: "Selected", else: "Select" %>
              </button>
              <button
                phx-click="leave_team"
                phx-value-team_id={team.id}
                class="text-red-600 hover:text-red-500 text-sm font-medium"
                data-confirm="Are you sure you want to leave this team?"
              >
                Leave
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Team Management Section -->
      <%= if @selected_team do %>
        <div class="mt-8 bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
            <h3 class="text-lg font-medium text-gray-900">Managing: <%= @selected_team.name %></h3>
            <button
              phx-click="show_invite_modal"
              class="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 text-sm font-medium"
            >
              Invite Member
            </button>
          </div>

          <!-- Team Members -->
          <div class="px-6 py-4">
            <h4 class="text-md font-medium text-gray-900 mb-4">Team Members (<%= length(@team_members || []) %>)</h4>
            <%= if length(@team_members || []) == 0 do %>
              <p class="text-gray-500 text-sm">No team members found.</p>
            <% else %>
              <div class="space-y-3">
                <%= for member <- @team_members do %>
                  <div class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-md">
                    <div class="flex items-center space-x-3">
                      <div class="flex-shrink-0">
                        <div class="h-8 w-8 bg-gray-300 rounded-full flex items-center justify-center">
                          <span class="text-sm font-medium text-gray-700">
                            <%= String.first(member.user.name || member.user.email) |> String.upcase() %>
                          </span>
                        </div>
                      </div>
                      <div>
                        <p class="text-sm font-medium text-gray-900"><%= member.user.name || member.user.email %></p>
                        <p class="text-sm text-gray-500"><%= member.user.email %></p>
                      </div>
                    </div>
                    <div class="flex items-center space-x-2">
                      <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", role_color(member.role)]}>
                        <%= String.capitalize(member.role) %>
                      </span>
                      <%= if member.can_manage do %>
                        <button
                          phx-click="remove_member"
                          phx-value-member_id={member.id}
                          class="text-red-600 hover:text-red-500 text-sm"
                          data-confirm="Are you sure you want to remove this member?"
                        >
                          Remove
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Sent Invitations -->
          <%= if length(@sent_invitations || []) > 0 do %>
            <div class="px-6 py-4 border-t border-gray-200">
              <h4 class="text-md font-medium text-gray-900 mb-4">Pending Invitations (<%= length(@sent_invitations) %>)</h4>
              <div class="space-y-3">
                <%= for invitation <- @sent_invitations do %>
                  <div class="flex items-center justify-between py-2 px-3 bg-yellow-50 rounded-md">
                    <div class="flex items-center space-x-3">
                      <div class="flex-shrink-0">
                        <div class="h-8 w-8 bg-yellow-300 rounded-full flex items-center justify-center">
                          <span class="text-sm font-medium text-yellow-700">
                            <%= String.first(invitation.invited_user.name || invitation.invited_user.email) |> String.upcase() %>
                          </span>
                        </div>
                      </div>
                      <div>
                        <p class="text-sm font-medium text-gray-900"><%= invitation.invited_user.name || invitation.invited_user.email %></p>
                        <p class="text-sm text-gray-500"><%= invitation.invited_user.email %></p>
                      </div>
                    </div>
                    <div class="flex items-center space-x-2">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                        Pending
                      </span>
                      <button
                        phx-click="cancel_invitation"
                        phx-value-invitation_id={invitation.id}
                        class="text-red-600 hover:text-red-500 text-sm"
                        data-confirm="Are you sure you want to cancel this invitation?"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    <% end %>
    """
  end

  defp render_invitations(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Received Invitations -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Received Invitations</h3>
        </div>
        <%= if length(@received_invitations || []) == 0 do %>
          <div class="px-6 py-8 text-center">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No invitations</h3>
            <p class="mt-1 text-sm text-gray-500">You don't have any pending team invitations.</p>
          </div>
        <% else %>
          <div class="divide-y divide-gray-200">
            <%= for invitation <- @received_invitations do %>
              <div class="px-6 py-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-4">
                    <div class="flex-shrink-0">
                      <div class="h-10 w-10 bg-indigo-100 rounded-full flex items-center justify-center">
                        <span class="text-sm font-medium text-indigo-700">
                          <%= String.first(invitation.team.name) |> String.upcase() %>
                        </span>
                      </div>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-900">Invited to <%= invitation.team.name %></h4>
                      <p class="text-sm text-gray-500">From <%= invitation.inviter_user.name || invitation.inviter_user.email %></p>
                      <%= if invitation.team.description do %>
                        <p class="text-sm text-gray-500 mt-1"><%= invitation.team.description %></p>
                      <% end %>
                    </div>
                  </div>
                  <div class="flex space-x-3">
                    <button
                      phx-click="accept_invitation"
                      phx-value-invitation_id={invitation.id}
                      class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 text-sm font-medium"
                    >
                      Accept
                    </button>
                    <button
                      phx-click="decline_invitation"
                      phx-value-invitation_id={invitation.id}
                      class="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400 text-sm font-medium"
                    >
                      Decline
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
