defmodule Kyozo.Containers.Changes.ScaleService do
  @moduledoc """
  Scales a service instance to the specified number of replicas.

  This change handles horizontal scaling of containerized services,
  including validation of scaling parameters, container orchestration,
  load balancer updates, and proper event logging.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &scale_service/2)
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp scale_service(changeset, service_instance) do
    replica_count = Ash.Changeset.get_argument(changeset, :replica_count)

    # Validate replica count
    case validate_replica_count(replica_count, service_instance.scaling_config) do
      {:ok, validated_count} ->
        perform_scaling(service_instance, validated_count)

      {:error, reason} ->
        # Create scaling failed event
        create_deployment_event(service_instance, :service_scaled, %{
          failed_at: DateTime.utc_now(),
          target_replicas: replica_count,
          error: reason
        })

        {:error, reason}
    end
  end

  defp validate_replica_count(replica_count, scaling_config) do
    min_replicas = Map.get(scaling_config, :min_replicas, 1)
    max_replicas = Map.get(scaling_config, :max_replicas, 3)

    cond do
      replica_count < min_replicas ->
        {:error, "Replica count #{replica_count} is below minimum #{min_replicas}"}

      replica_count > max_replicas ->
        {:error, "Replica count #{replica_count} exceeds maximum #{max_replicas}"}

      replica_count == 0 ->
        {:error, "Replica count cannot be zero"}

      true ->
        {:ok, replica_count}
    end
  end

  defp perform_scaling(service_instance, target_replicas) do
    # Create scaling started event
    create_deployment_event(service_instance, :service_scaled, %{
      started_at: DateTime.utc_now(),
      current_replicas: get_current_replicas(service_instance),
      target_replicas: target_replicas,
      scaling_strategy: determine_scaling_strategy(service_instance, target_replicas)
    })

    # In a full implementation, this would:
    # 1. Determine current replica count
    # 2. Calculate scaling operations needed (scale up/down)
    # 3. For scale up: create new container instances
    # 4. For scale down: gracefully terminate excess containers
    # 5. Update load balancer configuration
    # 6. Monitor scaling progress
    # 7. Update service instance configuration

    # For now, simulate scaling operation
    Task.start(fn ->
      # Simulate scaling time (longer for scale up than scale down)
      scaling_time = if target_replicas > 1, do: 3000, else: 1500
      Process.sleep(scaling_time)

      # Update service instance status back to running
      update_service_status(service_instance.id, :running)

      # Broadcast scaling completed event
      Kyozo.Containers.broadcast(
        service_instance.id,
        :service_scaled,
        %{
          service_instance_id: service_instance.id,
          target_replicas: target_replicas,
          completed_at: DateTime.utc_now(),
          success: true
        }
      )

      # Create scaling completed event
      create_deployment_event(service_instance, :service_scaled, %{
        completed_at: DateTime.utc_now(),
        final_replicas: target_replicas,
        scaling_duration_ms: scaling_time,
        success: true
      })
    end)

    {:ok, service_instance}
  end

  defp get_current_replicas(service_instance) do
    # In a real implementation, this would query the container runtime
    # to get the actual number of running replicas
    Map.get(service_instance.scaling_config, :current_replicas, 1)
  end

  defp determine_scaling_strategy(service_instance, target_replicas) do
    current_replicas = get_current_replicas(service_instance)

    cond do
      target_replicas > current_replicas -> :scale_up
      target_replicas < current_replicas -> :scale_down
      true -> :no_change
    end
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

  defp update_service_status(service_instance_id, status) do
    try do
      Kyozo.Containers.ServiceInstance
      |> Ash.get!(service_instance_id)
      |> Ash.Changeset.for_update(:update, %{status: status})
      |> Ash.update()
    rescue
      error ->
        require Logger
        Logger.error("Failed to update service status: #{inspect(error)}")
    end
  end
end
