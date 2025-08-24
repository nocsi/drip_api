defmodule KyozoWeb.Live.Containers.Dashboard do
  use KyozoWeb, :live_view

  alias Kyozo.Containers
  alias Kyozo.Accounts

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to container events for real-time updates
      Phoenix.PubSub.subscribe(Kyozo.PubSub, "containers:#{socket.assigns.current_team.id}")
      Phoenix.PubSub.subscribe(Kyozo.PubSub, "container_manager")
    end

    socket =
      socket
      |> assign(:page_title, "Container Dashboard")
      |> assign(:services, [])
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:stats, %{
        total_services: 0,
        running_services: 0,
        stopped_services: 0,
        error_services: 0,
        total_cpu_usage: 0,
        total_memory_usage: 0,
        recent_deployments: 0,
        avg_response_time: 0,
        uptime_percentage: 100
      })
      |> assign(:filter, %{
        status: nil,
        service_type: nil,
        workspace_id: nil,
        search: ""
      })

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    workspace_id = params["workspace_id"]
    team_id = socket.assigns.current_team.id

    socket =
      socket
      |> assign(:workspace_id, workspace_id)
      |> assign(:team_id, team_id)
      |> load_services()

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_services", _params, socket) do
    {:noreply, load_services(socket)}
  end

  @impl true
  def handle_event("filter_services", %{"filter" => filter_params}, socket) do
    current_filter = socket.assigns.filter

    updated_filter = %{
      current_filter
      | status: filter_params["status"],
        service_type: filter_params["service_type"],
        search: filter_params["search"] || ""
    }

    socket =
      socket
      |> assign(:filter, updated_filter)
      |> apply_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "service_action",
        %{"action" => action, "service_id" => service_id} = params,
        socket
      ) do
    case handle_service_action(action, service_id, params, socket) do
      {:ok, message} ->
        socket =
          socket
          |> put_flash(:info, message)
          |> load_services()

        {:noreply, socket}

      {:error, error} ->
        socket = put_flash(socket, :error, "Failed to #{action} service: #{error}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:container_event, event}, socket) do
    # Handle real-time container events
    socket =
      case event do
        %{type: "service_status_changed", service_id: service_id, status: new_status} ->
          update_service_status(socket, service_id, new_status)

        %{type: "service_deployed", service: service} ->
          socket
          |> update(:services, fn services -> [service | services] end)
          |> load_stats()

        %{type: "service_removed", service_id: service_id} ->
          socket
          |> update(:services, fn services ->
            Enum.reject(services, &(&1.id == service_id))
          end)
          |> load_stats()

        %{type: "metrics_updated", service_id: service_id, metrics: metrics} ->
          update_service_metrics(socket, service_id, metrics)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:container_manager_status, status}, socket) do
    # Handle container manager status updates
    socket = assign(socket, :container_manager_status, status)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <!-- Svelte Container Dashboard Component -->
      <div
        id="container-dashboard"
        phx-hook="SvelteContainerDashboard"
        data-team-id={@team_id}
        data-workspace-id={@workspace_id}
        data-services={Jason.encode!(@services)}
        data-stats={Jason.encode!(@stats)}
        data-loading={@loading}
        data-error={@error}
        data-filter={Jason.encode!(@filter)}
      >
        <!-- Fallback content while Svelte loads -->
        <div class="container-dashboard-fallback">
          <%= if @loading do %>
            <div class="text-center py-12">
              <div class="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500">
              </div>
              <p class="mt-4 text-gray-600">Loading container services...</p>
            </div>
          <% else %>
            <div class="space-y-6">
              <!-- Header -->
              <div class="flex justify-between items-center">
                <div>
                  <h1 class="text-3xl font-bold tracking-tight">Container Services</h1>
                  <p class="text-gray-600">
                    Manage and monitor your containerized applications
                  </p>
                </div>
                <button class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg">
                  Deploy Service
                </button>
              </div>
              
    <!-- Stats Grid -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div class="bg-white p-6 rounded-lg shadow">
                  <div class="flex items-center">
                    <div class="flex-1">
                      <h3 class="text-sm font-medium text-gray-500">Total Services</h3>
                      <p class="text-2xl font-semibold text-gray-900">{@stats.total_services}</p>
                    </div>
                    <div class="w-8 h-8 bg-blue-500 rounded-lg flex items-center justify-center">
                      <svg
                        class="w-5 h-5 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"
                        >
                        </path>
                      </svg>
                    </div>
                  </div>
                </div>

                <div class="bg-white p-6 rounded-lg shadow">
                  <div class="flex items-center">
                    <div class="flex-1">
                      <h3 class="text-sm font-medium text-gray-500">Running</h3>
                      <p class="text-2xl font-semibold text-green-600">{@stats.running_services}</p>
                    </div>
                    <div class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center">
                      <svg
                        class="w-5 h-5 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        >
                        </path>
                      </svg>
                    </div>
                  </div>
                </div>

                <div class="bg-white p-6 rounded-lg shadow">
                  <div class="flex items-center">
                    <div class="flex-1">
                      <h3 class="text-sm font-medium text-gray-500">CPU Usage</h3>
                      <p class="text-2xl font-semibold text-gray-900">
                        {Float.round(@stats.total_cpu_usage, 1)}%
                      </p>
                    </div>
                    <div class="w-8 h-8 bg-yellow-500 rounded-lg flex items-center justify-center">
                      <svg
                        class="w-5 h-5 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"
                        >
                        </path>
                      </svg>
                    </div>
                  </div>
                </div>

                <div class="bg-white p-6 rounded-lg shadow">
                  <div class="flex items-center">
                    <div class="flex-1">
                      <h3 class="text-sm font-medium text-gray-500">Memory</h3>
                      <p class="text-2xl font-semibold text-gray-900">
                        {Float.round(@stats.total_memory_usage, 1)}%
                      </p>
                    </div>
                    <div class="w-8 h-8 bg-purple-500 rounded-lg flex items-center justify-center">
                      <svg
                        class="w-5 h-5 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                        >
                        </path>
                      </svg>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Services List -->
              <%= if @error do %>
                <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg
                        class="h-5 w-5 text-red-400"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                        >
                        </path>
                      </svg>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-sm font-medium text-red-800">Error loading services</h3>
                      <p class="mt-2 text-sm text-red-700">{@error}</p>
                    </div>
                  </div>
                </div>
              <% else %>
                <%= if Enum.empty?(@services) do %>
                  <div class="text-center py-12">
                    <svg
                      class="mx-auto h-12 w-12 text-gray-400"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"
                      >
                      </path>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No services</h3>
                    <p class="mt-1 text-sm text-gray-500">
                      Get started by deploying your first service.
                    </p>
                    <div class="mt-6">
                      <button
                        type="button"
                        class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg"
                      >
                        Deploy Service
                      </button>
                    </div>
                  </div>
                <% else %>
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    <%= for service <- @services do %>
                      <div class="bg-white overflow-hidden shadow rounded-lg">
                        <div class="p-6">
                          <div class="flex items-center">
                            <div class="flex-shrink-0">
                              <div class="flex items-center justify-center h-8 w-8 rounded-lg bg-blue-500 text-white font-medium text-sm">
                                {String.first(service.service_type) |> String.upcase()}
                              </div>
                            </div>
                            <div class="ml-4 flex-1">
                              <h3 class="text-lg leading-6 font-medium text-gray-900">
                                {service.name}
                              </h3>
                              <p class="text-sm text-gray-500">{service.folder_path}</p>
                            </div>
                            <div class="flex-shrink-0">
                              <span class={get_status_badge_class(service.status)}>
                                {String.capitalize(service.status)}
                              </span>
                            </div>
                          </div>

                          <div class="mt-4">
                            <div class="text-sm text-gray-600">
                              <p><strong>Type:</strong> {service.service_type}</p>
                              <%= if service.deployed_at do %>
                                <p>
                                  <strong>Deployed:</strong> {format_datetime(service.deployed_at)}
                                </p>
                              <% end %>
                            </div>
                          </div>

                          <div class="mt-4 flex space-x-2">
                            <%= if service.status in ["stopped", "error"] do %>
                              <button
                                phx-click="service_action"
                                phx-value-action="start"
                                phx-value-service_id={service.id}
                                class="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                              >
                                Start
                              </button>
                            <% end %>

                            <%= if service.status in ["running", "deploying"] do %>
                              <button
                                phx-click="service_action"
                                phx-value-action="stop"
                                phx-value-service_id={service.id}
                                class="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded-md text-white bg-red-600 hover:bg-red-700"
                              >
                                Stop
                              </button>
                            <% end %>

                            <%= if service.status == "running" do %>
                              <button
                                phx-click="service_action"
                                phx-value-action="restart"
                                phx-value-service_id={service.id}
                                class="inline-flex items-center px-3 py-1 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                              >
                                Restart
                              </button>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp load_services(socket) do
    team_id = socket.assigns.team_id
    workspace_id = socket.assigns.workspace_id

    socket = assign(socket, :loading, true)

    try do
      # Build query parameters
      query = []
      query = if workspace_id, do: [filter: [workspace_id: workspace_id]] ++ query, else: query

      case Containers.list_service_instances(
             query,
             actor: socket.assigns.current_user,
             tenant: socket.assigns.current_team
           ) do
        {:ok, services} ->
          socket
          |> assign(:services, services)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> load_stats()

        {:error, reason} ->
          socket
          |> assign(:services, [])
          |> assign(:loading, false)
          |> assign(:error, "Failed to load services: #{inspect(reason)}")
      end
    rescue
      error ->
        socket
        |> assign(:services, [])
        |> assign(:loading, false)
        |> assign(:error, "Error loading services: #{Exception.message(error)}")
    end
  end

  defp load_stats(socket) do
    services = socket.assigns.services

    stats = %{
      total_services: length(services),
      running_services: Enum.count(services, &(&1.status == "running")),
      stopped_services: Enum.count(services, &(&1.status == "stopped")),
      error_services: Enum.count(services, &(&1.status == "error")),
      # Would be calculated from metrics
      total_cpu_usage: 0,
      # Would be calculated from metrics
      total_memory_usage: 0,
      recent_deployments:
        Enum.count(services, fn service ->
          case service.deployed_at do
            nil ->
              false

            deployed_at ->
              DateTime.diff(DateTime.utc_now(), deployed_at, :hour) <= 24
          end
        end),
      # Would be calculated from metrics
      avg_response_time: 0,
      uptime_percentage:
        if length(services) > 0 do
          running_count = Enum.count(services, &(&1.status == "running"))
          running_count / length(services) * 100
        else
          100
        end
    }

    assign(socket, :stats, stats)
  end

  defp apply_filters(socket) do
    # This would apply client-side filters in a real implementation
    # For now, just return the socket as filtering will happen in Svelte
    socket
  end

  defp handle_service_action(action, service_id, _params, socket) do
    current_user = socket.assigns.current_user
    current_team = socket.assigns.current_team

    with {:ok, service} <-
           Containers.get_service_instance(service_id, actor: current_user, tenant: current_team) do
      case action do
        "start" ->
          case Containers.start_container(service, actor: current_user, tenant: current_team) do
            {:ok, _service} -> {:ok, "Service started successfully"}
            {:error, reason} -> {:error, reason}
          end

        "stop" ->
          case Containers.stop_container(service, actor: current_user, tenant: current_team) do
            {:ok, _service} -> {:ok, "Service stopped successfully"}
            {:error, reason} -> {:error, reason}
          end

        "restart" ->
          with {:ok, _stopped} <-
                 Containers.stop_container(service, actor: current_user, tenant: current_team),
               {:ok, _started} <-
                 Containers.start_container(service, actor: current_user, tenant: current_team) do
            {:ok, "Service restarted successfully"}
          else
            {:error, reason} -> {:error, reason}
          end

        "delete" ->
          case Containers.destroy_service_instance(service,
                 actor: current_user,
                 tenant: current_team
               ) do
            {:ok, _service} -> {:ok, "Service deleted successfully"}
            {:error, reason} -> {:error, reason}
          end

        _ ->
          {:error, "Unknown action: #{action}"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_service_status(socket, service_id, new_status) do
    update(socket, :services, fn services ->
      Enum.map(services, fn service ->
        if service.id == service_id do
          %{service | status: new_status, updated_at: DateTime.utc_now()}
        else
          service
        end
      end)
    end)
    |> load_stats()
  end

  defp update_service_metrics(socket, service_id, _metrics) do
    # In a real implementation, this would update service metrics
    # For now, just trigger a stats reload
    load_stats(socket)
  end

  defp get_status_badge_class(status) do
    case status do
      "running" ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"

      "stopped" ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"

      "error" ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"

      "deploying" ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"

      _ ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    end
  end

  defp format_datetime(datetime) do
    case datetime do
      %DateTime{} ->
        Calendar.strftime(datetime, "%m/%d/%Y %H:%M")

      datetime when is_binary(datetime) ->
        case DateTime.from_iso8601(datetime) do
          {:ok, dt, _} -> Calendar.strftime(dt, "%m/%d/%Y %H:%M")
          _ -> datetime
        end

      _ ->
        "Unknown"
    end
  end
end
