defmodule Kyozo.Containers.Changes.StartContainer do
  @moduledoc """
  Starts an existing container for a service instance.

  This change handles starting a previously deployed container that
  is currently in a stopped state. It differs from deployment in that
  the container already exists and just needs to be started.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &start_container/2)
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp start_container(_changeset, service_instance) do
    # Create service start event
    create_deployment_event(service_instance, :service_started, %{
      started_at: DateTime.utc_now(),
      container_id: service_instance.container_id
    })

    # In a full implementation, this would:
    # 1. Validate container exists
    # 2. Start the Docker container
    # 3. Wait for container to be ready
    # 4. Update health check status
    # 5. Restore networking and volume mounts

    # For now, simulate container start
    Task.start(fn ->
      # Simulate startup time
      Process.sleep(500)

      # Broadcast container started event
      Kyozo.Containers.broadcast(
        service_instance.id,
        :container_started,
        %{
          service_instance_id: service_instance.id,
          container_id: service_instance.container_id,
          started_at: DateTime.utc_now()
        }
      )
    end)

    {:ok, service_instance}
  end

  defp create_deployment_event(service_instance, event_type, event_data) do
    try do
      Kyozo.Containers.DeploymentEvent.create!(%{
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
        Kyozo.Containers.DeploymentEvent
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
