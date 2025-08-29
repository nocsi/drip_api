defmodule Dirup.Containers.Changes.StartContainerDeployment do
  @moduledoc """
  Initiates container deployment for a service instance.

  This change handles the deployment process by:
  1. Building or pulling the appropriate container image
  2. Creating the container with proper configuration
  3. Starting the container and monitoring startup
  4. Creating deployment event records
  5. Setting up health checks and monitoring
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    # For now, this is a placeholder that sets up the deployment process
    # In a full implementation, this would:
    # 1. Queue a background job for container deployment
    # 2. Update the service instance status appropriately
    # 3. Create deployment event records

    Ash.Changeset.after_action(changeset, &start_deployment/2)
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp start_deployment(_changeset, service_instance) do
    # Create deployment started event
    create_deployment_event(service_instance, :deployment_started, %{
      started_at: DateTime.utc_now(),
      deployment_config: service_instance.deployment_config
    })

    # In a full implementation, this would:
    # 1. Validate deployment configuration
    # 2. Build container image if needed
    # 3. Create and start container
    # 4. Set up networking and volumes
    # 5. Configure health checks
    # 6. Update service instance with container details

    # Enqueue real deployment via Oban worker (ContainerManager handles runtime)
    Dirup.Containers.Workers.ContainerDeploymentWorker.enqueue_deploy(
      service_instance.id,
      tenant: service_instance.team_id
    )

    {:ok, service_instance}
  end

  defp create_deployment_event(service_instance, event_type, event_data) do
    # Create deployment event record
    try do
      Dirup.Containers.DeploymentEvent.create!(%{
        service_instance_id: service_instance.id,
        event_type: event_type,
        event_data: event_data,
        sequence_number: get_next_sequence_number(service_instance.id)
      })
    rescue
      # If deployment event creation fails, log but don't fail the deployment
      error ->
        require Logger
        Logger.warning("Failed to create deployment event: #{inspect(error)}")
    end
  end

  defp get_next_sequence_number(service_instance_id) do
    # Get the next sequence number for deployment events
    # This ensures proper ordering of events
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

  defp update_service_status(service_instance_id, status) do
    # Update the service instance status
    try do
      Dirup.Containers.ServiceInstance
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
