defmodule Dirup.Containers.Calculations.ResourceUtilization do
  @moduledoc """
  Calculates resource utilization metrics for service instances.

  This calculation provides a comprehensive view of how much CPU, memory,
  and storage resources are being used by a containerized service relative
  to its configured limits.
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
    Enum.map(records, &calculate_resource_utilization/1)
  end

  defp calculate_resource_utilization(service_instance) do
    case service_instance.status do
      :running ->
        calculate_running_utilization(service_instance)

      _ ->
        %{
          cpu: %{used: 0, limit: 0, percentage: 0},
          memory: %{used: 0, limit: 0, percentage: 0},
          storage: %{used: 0, limit: 0, percentage: 0},
          status: "not_running"
        }
    end
  end

  defp calculate_running_utilization(service_instance) do
    # In a real implementation, this would:
    # 1. Query container runtime for current resource usage
    # 2. Parse resource limits from service configuration
    # 3. Calculate utilization percentages
    # 4. Determine if any limits are being exceeded

    resource_limits = service_instance.resource_limits || %{}

    # Mock utilization data (in production, would come from Docker API/cAdvisor)
    mock_utilization = %{
      cpu: calculate_cpu_utilization(resource_limits),
      memory: calculate_memory_utilization(resource_limits),
      storage: calculate_storage_utilization(resource_limits),
      status: "healthy",
      last_updated: DateTime.utc_now()
    }

    mock_utilization
  end

  defp calculate_cpu_utilization(resource_limits) do
    # Parse CPU limit
    cpu_limit = parse_cpu_limit(resource_limits["cpu"] || "0.5")

    # Mock current usage (would be real data from container)
    # 0-80% of limit
    cpu_used = :rand.uniform() * cpu_limit * 0.8

    %{
      used: Float.round(cpu_used, 3),
      limit: cpu_limit,
      percentage: Float.round(cpu_used / cpu_limit * 100, 1),
      unit: "cores"
    }
  end

  defp calculate_memory_utilization(resource_limits) do
    # Parse memory limit
    memory_limit_bytes = parse_memory_limit(resource_limits["memory"] || "512Mi")

    # Mock current usage
    # 0-90% of limit
    memory_used_bytes = trunc(:rand.uniform() * memory_limit_bytes * 0.9)

    %{
      used: memory_used_bytes,
      limit: memory_limit_bytes,
      percentage: Float.round(memory_used_bytes / memory_limit_bytes * 100, 1),
      used_human: format_bytes(memory_used_bytes),
      limit_human: format_bytes(memory_limit_bytes),
      unit: "bytes"
    }
  end

  defp calculate_storage_utilization(resource_limits) do
    # Parse storage limit
    storage_limit_bytes = parse_memory_limit(resource_limits["storage"] || "1Gi")

    # Mock current usage
    # 0-60% of limit
    storage_used_bytes = trunc(:rand.uniform() * storage_limit_bytes * 0.6)

    %{
      used: storage_used_bytes,
      limit: storage_limit_bytes,
      percentage: Float.round(storage_used_bytes / storage_limit_bytes * 100, 1),
      used_human: format_bytes(storage_used_bytes),
      limit_human: format_bytes(storage_limit_bytes),
      unit: "bytes"
    }
  end

  defp parse_cpu_limit(cpu_str) when is_binary(cpu_str) do
    case Regex.run(~r/^(\d+(?:\.\d+)?)\s*(m)?$/i, String.trim(cpu_str)) do
      [_, number_str, "m"] ->
        # Millicpu format (1000m = 1 CPU)
        case Float.parse(number_str) do
          {number, ""} -> number / 1000
          # default
          _ -> 0.5
        end

      [_, number_str, _] ->
        # Decimal CPU cores
        case Float.parse(number_str) do
          {number, ""} -> number
          # default
          _ -> 0.5
        end

      _ ->
        # default
        0.5
    end
  end

  defp parse_cpu_limit(cpu_num) when is_number(cpu_num), do: cpu_num
  defp parse_cpu_limit(_), do: 0.5

  defp parse_memory_limit(memory_str) when is_binary(memory_str) do
    case Regex.run(~r/^(\d+(?:\.\d+)?)\s*(Ki?|Mi?|Gi?|Ti?)?$/i, String.trim(memory_str)) do
      [_, number_str, unit] ->
        case Float.parse(number_str) do
          {number, ""} ->
            multiplier = get_memory_multiplier(unit)
            trunc(number * multiplier)

          _ ->
            # 512Mi default
            536_870_912
        end

      _ ->
        # 512Mi default
        536_870_912
    end
  end

  defp parse_memory_limit(memory_num) when is_number(memory_num), do: trunc(memory_num)
  defp parse_memory_limit(_), do: 536_870_912

  defp get_memory_multiplier(""), do: 1
  defp get_memory_multiplier("K"), do: 1_000
  defp get_memory_multiplier("Ki"), do: 1_024
  defp get_memory_multiplier("M"), do: 1_000_000
  defp get_memory_multiplier("Mi"), do: 1_048_576
  defp get_memory_multiplier("G"), do: 1_000_000_000
  defp get_memory_multiplier("Gi"), do: 1_073_741_824
  defp get_memory_multiplier("T"), do: 1_000_000_000_000
  defp get_memory_multiplier("Ti"), do: 1_099_511_627_776
  defp get_memory_multiplier(unit), do: get_memory_multiplier(String.downcase(unit))

  defp format_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"

  defp format_bytes(bytes) when bytes < 1_048_576 do
    "#{Float.round(bytes / 1_024, 1)} KB"
  end

  defp format_bytes(bytes) when bytes < 1_073_741_824 do
    "#{Float.round(bytes / 1_048_576, 1)} MB"
  end

  defp format_bytes(bytes) do
    "#{Float.round(bytes / 1_073_741_824, 1)} GB"
  end

  @impl true
  def select(_query, _opts, _context) do
    [:status, :resource_limits, :container_id]
  end
end
