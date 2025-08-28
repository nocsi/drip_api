defmodule DirupWeb.ExecutionChannel do
  @moduledoc """
  WebSocket channel for real-time execution updates and collaboration.

  Provides live updates for:
  - Markdown execution progress
  - Notebook cell execution status
  - Container deployment status
  - Collaborative editing events
  - AI processing updates
  """

  use Phoenix.Channel
  require Logger

  alias Dirup.{Accounts, Workspaces, Containers}
  alias DirupWeb.Presence

  @doc """
  Join execution channel for a specific resource.

  Channel topics:
  - "execution:notebook:{id}" - Notebook execution updates
  - "execution:container:{id}" - Container deployment updates
  - "execution:file:{id}" - File processing updates
  - "execution:workspace:{id}" - Workspace-wide execution events
  """
  def join("execution:notebook:" <> notebook_id, params, socket) do
    case authorize_notebook_access(notebook_id, socket) do
      {:ok, notebook} ->
        socket =
          socket
          |> assign(:notebook, notebook)
          |> assign(:resource_type, :notebook)
          |> assign(:resource_id, notebook_id)

        send(self(), :after_join)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "notebook_not_found"}}

      {:error, :unauthorized} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def join("execution:container:" <> container_id, params, socket) do
    case authorize_container_access(container_id, socket) do
      {:ok, container} ->
        socket =
          socket
          |> assign(:container, container)
          |> assign(:resource_type, :container)
          |> assign(:resource_id, container_id)

        send(self(), :after_join)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "container_not_found"}}

      {:error, :unauthorized} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def join("execution:file:" <> file_id, params, socket) do
    case authorize_file_access(file_id, socket) do
      {:ok, file} ->
        socket =
          socket
          |> assign(:file, file)
          |> assign(:resource_type, :file)
          |> assign(:resource_id, file_id)

        send(self(), :after_join)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "file_not_found"}}

      {:error, :unauthorized} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def join("execution:workspace:" <> workspace_id, params, socket) do
    case authorize_workspace_access(workspace_id, socket) do
      {:ok, workspace} ->
        socket =
          socket
          |> assign(:workspace, workspace)
          |> assign(:resource_type, :workspace)
          |> assign(:resource_id, workspace_id)

        send(self(), :after_join)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "workspace_not_found"}}

      {:error, :unauthorized} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def join(_, _, _socket) do
    {:error, %{reason: "invalid_topic"}}
  end

  # Handle after join to set up presence and subscriptions
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.current_user.id
    topic = socket.topic

    # Track user presence
    {:ok, _} =
      Presence.track(socket, user_id, %{
        online_at: inspect(System.system_time(:second)),
        user: %{
          id: user_id,
          name: socket.assigns.current_user.name || "Unknown"
        }
      })

    # Subscribe to relevant events based on resource type
    setup_subscriptions(socket)

    # Send current status
    push_current_status(socket)

    {:noreply, socket}
  end

  # Execution control messages
  def handle_in("execute", %{"type" => "notebook"}, socket) do
    notebook = socket.assigns.notebook
    user = socket.assigns.current_user

    case execute_notebook(notebook, user) do
      {:ok, execution_id} ->
        broadcast!(socket, "execution_started", %{
          execution_id: execution_id,
          started_by: user.id,
          started_at: DateTime.utc_now()
        })

        {:reply, {:ok, %{execution_id: execution_id}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("execute", %{"type" => "cell", "cell_id" => cell_id}, socket) do
    notebook = socket.assigns.notebook
    user = socket.assigns.current_user

    case execute_cell(notebook, cell_id, user) do
      {:ok, execution_id} ->
        broadcast!(socket, "cell_execution_started", %{
          cell_id: cell_id,
          execution_id: execution_id,
          started_by: user.id,
          started_at: DateTime.utc_now()
        })

        {:reply, {:ok, %{execution_id: execution_id}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("execute", %{"type" => "container"}, socket) do
    container = socket.assigns.container
    user = socket.assigns.current_user

    case deploy_container(container, user) do
      {:ok, deployment_id} ->
        broadcast!(socket, "deployment_started", %{
          deployment_id: deployment_id,
          started_by: user.id,
          started_at: DateTime.utc_now()
        })

        {:reply, {:ok, %{deployment_id: deployment_id}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("stop", %{"execution_id" => execution_id}, socket) do
    user = socket.assigns.current_user

    case stop_execution(execution_id, user) do
      :ok ->
        broadcast!(socket, "execution_stopped", %{
          execution_id: execution_id,
          stopped_by: user.id,
          stopped_at: DateTime.utc_now()
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("get_status", _params, socket) do
    status = get_resource_status(socket)
    {:reply, {:ok, status}, socket}
  end

  def handle_in("subscribe_logs", %{"execution_id" => execution_id}, socket) do
    case subscribe_to_logs(execution_id, socket) do
      :ok ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  # Collaborative editing events
  def handle_in("cursor_move", %{"position" => position}, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "cursor_moved", %{
      user_id: user.id,
      position: position,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  def handle_in("selection_change", %{"range" => range}, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "selection_changed", %{
      user_id: user.id,
      range: range,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  # Handle execution status updates from background processes
  def handle_info({:execution_update, execution_id, status}, socket) do
    push(socket, "execution_update", %{
      execution_id: execution_id,
      status: status,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  def handle_info({:cell_output, execution_id, cell_id, output}, socket) do
    push(socket, "cell_output", %{
      execution_id: execution_id,
      cell_id: cell_id,
      output: output,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  def handle_info({:deployment_update, deployment_id, status}, socket) do
    push(socket, "deployment_update", %{
      deployment_id: deployment_id,
      status: status,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  def handle_info({:container_logs, container_id, logs}, socket) do
    push(socket, "container_logs", %{
      container_id: container_id,
      logs: logs,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  def handle_info({:ai_processing, task_id, progress}, socket) do
    push(socket, "ai_progress", %{
      task_id: task_id,
      progress: progress,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  def handle_info({:markdown_parsed, file_id, semantic_data}, socket) do
    push(socket, "markdown_parsed", %{
      file_id: file_id,
      semantic_data: semantic_data,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  # Handle presence events
  def handle_info(%Phoenix.Socket.Broadcast{topic: _, event: "presence_diff"}, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  # Private helper functions

  defp authorize_notebook_access(notebook_id, socket) do
    user = socket.assigns.current_user

    # Implementation would check if user has access to notebook
    # For now, return success with mock notebook
    {:ok, %{id: notebook_id, name: "Notebook", user_id: user.id}}
  end

  defp authorize_container_access(container_id, socket) do
    user = socket.assigns.current_user

    case Containers.get_service_instance(container_id, actor: user) do
      {:ok, container} -> {:ok, container}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp authorize_file_access(file_id, socket) do
    user = socket.assigns.current_user

    case Workspaces.get_file(file_id, actor: user) do
      {:ok, file} -> {:ok, file}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp authorize_workspace_access(workspace_id, socket) do
    user = socket.assigns.current_user

    case Workspaces.get_workspace(workspace_id, actor: user) do
      {:ok, workspace} -> {:ok, workspace}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp setup_subscriptions(socket) do
    case socket.assigns.resource_type do
      :notebook ->
        # Subscribe to notebook execution events
        Phoenix.PubSub.subscribe(Dirup.PubSub, "notebook_execution:#{socket.assigns.resource_id}")

      :container ->
        # Subscribe to container events
        Phoenix.PubSub.subscribe(Dirup.PubSub, "container_events:#{socket.assigns.resource_id}")

      :file ->
        # Subscribe to file processing events
        Phoenix.PubSub.subscribe(Dirup.PubSub, "file_processing:#{socket.assigns.resource_id}")

      :workspace ->
        # Subscribe to workspace-wide events
        Phoenix.PubSub.subscribe(Dirup.PubSub, "workspace_events:#{socket.assigns.resource_id}")
    end
  end

  defp push_current_status(socket) do
    status = get_resource_status(socket)
    push(socket, "current_status", status)
  end

  defp get_resource_status(socket) do
    case socket.assigns.resource_type do
      :notebook ->
        %{
          type: "notebook",
          id: socket.assigns.resource_id,
          status: "idle",
          last_execution: nil
        }

      :container ->
        container = socket.assigns.container

        %{
          type: "container",
          id: container.id,
          status: container.status,
          uptime: Containers.ServiceInstance.uptime(container),
          deployment_status: Containers.ServiceInstance.deployment_status(container)
        }

      :file ->
        file = socket.assigns.file

        %{
          type: "file",
          id: file.id,
          name: file.name,
          last_modified: file.updated_at,
          processing_status: "idle"
        }

      :workspace ->
        workspace = socket.assigns.workspace

        %{
          type: "workspace",
          id: workspace.id,
          name: workspace.name,
          active_executions: get_active_executions(workspace.id)
        }
    end
  end

  defp execute_notebook(notebook, user) do
    # Implementation would start notebook execution
    execution_id = Ecto.UUID.generate()

    # Start background execution process
    Task.start(fn ->
      simulate_notebook_execution(notebook, execution_id)
    end)

    {:ok, execution_id}
  end

  defp execute_cell(notebook, cell_id, user) do
    # Implementation would execute specific cell
    execution_id = Ecto.UUID.generate()

    # Start background cell execution
    Task.start(fn ->
      simulate_cell_execution(notebook, cell_id, execution_id)
    end)

    {:ok, execution_id}
  end

  defp deploy_container(container, user) do
    # Implementation would start container deployment
    case Containers.deploy_service(container, actor: user) do
      {:ok, _} ->
        deployment_id = Ecto.UUID.generate()
        {:ok, deployment_id}

      error ->
        error
    end
  end

  defp stop_execution(execution_id, user) do
    # Implementation would stop the execution
    Logger.info("Stopping execution #{execution_id} by user #{user.id}")
    :ok
  end

  defp subscribe_to_logs(execution_id, socket) do
    # Subscribe to log stream for specific execution
    Phoenix.PubSub.subscribe(Dirup.PubSub, "execution_logs:#{execution_id}")
    :ok
  end

  defp get_active_executions(workspace_id) do
    # Would query for active executions in workspace
    []
  end

  # Simulation functions for testing
  defp simulate_notebook_execution(notebook, execution_id) do
    Process.sleep(1000)

    Phoenix.PubSub.broadcast(
      Dirup.PubSub,
      "notebook_execution:#{notebook.id}",
      {:execution_update, execution_id, %{status: "running", progress: 0.2}}
    )

    Process.sleep(2000)

    Phoenix.PubSub.broadcast(
      Dirup.PubSub,
      "notebook_execution:#{notebook.id}",
      {:execution_update, execution_id, %{status: "running", progress: 0.6}}
    )

    Process.sleep(1500)

    Phoenix.PubSub.broadcast(
      Dirup.PubSub,
      "notebook_execution:#{notebook.id}",
      {:execution_update, execution_id, %{status: "completed", progress: 1.0}}
    )
  end

  defp simulate_cell_execution(notebook, cell_id, execution_id) do
    Process.sleep(500)

    Phoenix.PubSub.broadcast(
      Dirup.PubSub,
      "notebook_execution:#{notebook.id}",
      {:cell_output, execution_id, cell_id, %{type: "text", content: "Cell execution started..."}}
    )

    Process.sleep(1000)

    Phoenix.PubSub.broadcast(
      Dirup.PubSub,
      "notebook_execution:#{notebook.id}",
      {:cell_output, execution_id, cell_id, %{type: "text", content: "Processing complete!"}}
    )

    Phoenix.PubSub.broadcast(
      Dirup.PubSub,
      "notebook_execution:#{notebook.id}",
      {:execution_update, execution_id, %{status: "completed", cell_id: cell_id}}
    )
  end
end
