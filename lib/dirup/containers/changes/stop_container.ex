defmodule Dirup.Containers.Changes.StopContainer do
  @moduledoc """
  Stops a running container for a service instance.

  This change handles gracefully stopping a running container,
  including proper cleanup of resources, network connections,
  and event logging for audit trails.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &stop_container/2)
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp stop_container(_changeset, service_instance) do
    # Create service stop event
    create_deployment_event(service_instance, :service_stopped, %{
      stopped_at: DateTime.utc_now(),
      container_id: service_instance.container_id,
      reason: "user_requested"
    })

    # In a full implementation, this would:
    # 1. Send SIGTERM to container
    # 2. Wait for graceful shutdown (with timeout)
    # 3. Force stop with SIGKILL if needed
    # 4. Clean up networking and volumes
    # 5. Update container status
    # 6. Stop health checks

    # Enqueue real stop via Oban worker
    Dirup.Containers.Workers.ContainerDeploymentWorker.enqueue_stop(
      service_instance.id,
      graceful: true,
      tenant: service_instance.team_id
    )

    {:ok, service_instance}
  end

  defp create_deployment_event(service_instance, event_type, event_data) do
    try do
      Dirup.Containers.DeploymentEvent.create!(%{
        service_instance_id: service_instance.id,
        event_type: event_type,
        event_data: event_data,
        sequence_number: get_next_sequence_number(service_instance.id)
      })
    rescue
      error ->
        require Logger
        Logger.warning("Failed to create deployment event: #{inspect(error)}")
    end
  end

  defp get_next_sequence_number(service_instance_id) do
    try do
      result =
        Dirup.Containers.DeploymentEvent
        |> Ash.Query.filter(service_instance_id == ^service_instance_id)
        |> Ash.Query.select([:sequence_number])
        |> Ash.Query.sort(sequence_number: :desc)
        |> Ash.Query.limit(1)
        |> Ash.read()

      case result do
        {:ok, [%{sequence_number: last_seq}]} -> last_seq + 1
        {:ok, []} -> 1
        {:error, _} -> 1
      end
    rescue
      _ -> 1
    end
  end
end
