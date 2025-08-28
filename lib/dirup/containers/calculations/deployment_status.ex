defmodule Dirup.Containers.Calculations.DeploymentStatus do
  @moduledoc """
  Calculates a human-readable deployment status for service instances.

  This calculation provides a comprehensive status string that combines
  the current service status with additional context like health checks,
  scaling operations, and error conditions.
  """

  use Ash.Resource.Calculation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def load(query, _opts, _context) do
    query
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &calculate_deployment_status/1)
  end

  defp calculate_deployment_status(service_instance) do
    base_status = determine_base_status(service_instance.status)

    case service_instance.status do
      :running ->
        enhance_running_status(base_status, service_instance)

      :error ->
        enhance_error_status(base_status, service_instance)

      :deploying ->
        enhance_deploying_status(base_status, service_instance)

      :scaling ->
        enhance_scaling_status(base_status, service_instance)

      _ ->
        base_status
    end
  end

  defp determine_base_status(:detecting), do: "Analyzing folder structure"
  defp determine_base_status(:configuring), do: "Preparing deployment configuration"
  defp determine_base_status(:building), do: "Building container image"
  defp determine_base_status(:deploying), do: "Deploying service"
  defp determine_base_status(:running), do: "Running"
  defp determine_base_status(:stopping), do: "Stopping service"
  defp determine_base_status(:stopped), do: "Stopped"
  defp determine_base_status(:error), do: "Error"
  defp determine_base_status(:scaling), do: "Scaling service"
  defp determine_base_status(_), do: "Unknown"

  defp enhance_running_status(base_status, service_instance) do
    case service_instance.last_health_check_at do
      nil ->
        "#{base_status} (health unknown)"

      last_check ->
        time_since_check = DateTime.diff(DateTime.utc_now(), last_check, :minute)

        if time_since_check > 5 do
          "#{base_status} (health check overdue)"
        else
          "#{base_status} (healthy)"
        end
    end
  end

  defp enhance_error_status(base_status, service_instance) do
    # In a real implementation, we would check the latest deployment event
    # for error details
    case service_instance.container_id do
      nil -> "#{base_status} - deployment failed"
      _ -> "#{base_status} - runtime failure"
    end
  end

  defp enhance_deploying_status(base_status, service_instance) do
    case service_instance.deployed_at do
      nil ->
        base_status

      deployed_at ->
        minutes_deploying = DateTime.diff(DateTime.utc_now(), deployed_at, :minute)

        if minutes_deploying > 10 do
          "#{base_status} (taking longer than expected)"
        else
          "#{base_status} (#{minutes_deploying}m elapsed)"
        end
    end
  end

  defp enhance_scaling_status(base_status, service_instance) do
    current_replicas = get_current_replicas(service_instance)
    "#{base_status} (#{current_replicas} replicas)"
  end

  defp get_current_replicas(service_instance) do
    case service_instance.scaling_config do
      %{current_replicas: replicas} when is_integer(replicas) -> replicas
      _ -> 1
    end
  end

  @impl true
  def select(_query, _opts, _context) do
    [:status, :last_health_check_at, :container_id, :deployed_at, :scaling_config]
  end
end
