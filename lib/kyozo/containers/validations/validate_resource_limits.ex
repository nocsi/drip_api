defmodule Kyozo.Containers.Validations.ValidateResourceLimits do
  @moduledoc """
  Validates resource limits for service instances.

  This validation ensures that resource limits (memory, CPU, storage)
  are properly formatted with valid units and reasonable values for
  containerized services.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts) do
    case Ash.Changeset.get_attribute(changeset, :resource_limits) do
      nil ->
        :ok

      resource_limits when is_map(resource_limits) ->
        validate_resource_limits(resource_limits)

      _ ->
        {:error, field: :resource_limits, message: "must be a map"}
    end
  end

  defp validate_resource_limits(resource_limits) when map_size(resource_limits) == 0, do: :ok

  defp validate_resource_limits(resource_limits) do
    resource_limits
    |> Enum.reduce_while(:ok, fn {resource_type, limit_value}, _acc ->
      case validate_single_limit(resource_type, limit_value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_single_limit(resource_type, limit_value) do
    case normalize_resource_type(resource_type) do
      {:ok, normalized_type} ->
        validate_limit_value(normalized_type, limit_value)

      :error ->
        {:error, field: :resource_limits, message: "unknown resource type: #{resource_type}"}
    end
  end

  defp normalize_resource_type(resource_type) when is_atom(resource_type) do
    normalize_resource_type(Atom.to_string(resource_type))
  end

  defp normalize_resource_type(resource_type) when is_binary(resource_type) do
    normalized = String.downcase(resource_type)

    case normalized do
      type when type in ["memory", "mem", "ram"] -> {:ok, :memory}
      type when type in ["cpu", "processor", "vcpu"] -> {:ok, :cpu}
      type when type in ["storage", "disk", "volume"] -> {:ok, :storage}
      _ -> :error
    end
  end

  defp normalize_resource_type(_), do: :error

  defp validate_limit_value(:memory, value) when is_binary(value) do
    case parse_memory_value(value) do
      {:ok, bytes} ->
        validate_memory_range(bytes)

      :error ->
        {:error,
         field: :resource_limits,
         message: "invalid memory format: #{value}. Use format like '512Mi', '1Gi', '2048M'"}
    end
  end

  defp validate_limit_value(:cpu, value) when is_binary(value) do
    case parse_cpu_value(value) do
      {:ok, cpu_units} ->
        validate_cpu_range(cpu_units)

      :error ->
        {:error,
         field: :resource_limits,
         message: "invalid CPU format: #{value}. Use format like '0.5', '1000m', '2'"}
    end
  end

  defp validate_limit_value(:cpu, value) when is_number(value) do
    validate_cpu_range(value)
  end

  defp validate_limit_value(:storage, value) when is_binary(value) do
    case parse_storage_value(value) do
      {:ok, bytes} ->
        validate_storage_range(bytes)

      :error ->
        {:error,
         field: :resource_limits,
         message: "invalid storage format: #{value}. Use format like '1Gi', '500Mi', '10G'"}
    end
  end

  defp validate_limit_value(resource_type, value) do
    {:error,
     field: :resource_limits, message: "invalid value for #{resource_type}: #{inspect(value)}"}
  end

  # Memory parsing (supports K, Ki, M, Mi, G, Gi, T, Ti)
  defp parse_memory_value(value) do
    case Regex.run(~r/^(\d+(?:\.\d+)?)\s*(Ki?|Mi?|Gi?|Ti?)?$/i, String.trim(value)) do
      [_, number_str, unit] ->
        case Float.parse(number_str) do
          {number, ""} ->
            multiplier = get_memory_multiplier(unit)
            {:ok, trunc(number * multiplier)}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

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

  # CPU parsing (supports decimal and millicpu format like 1000m)
  defp parse_cpu_value(value) do
    case Regex.run(~r/^(\d+(?:\.\d+)?)\s*(m)?$/i, String.trim(value)) do
      [_, number_str, "m"] ->
        # Millicpu format (1000m = 1 CPU)
        case Float.parse(number_str) do
          {number, ""} -> {:ok, number / 1000}
          _ -> :error
        end

      [_, number_str, _] ->
        # Decimal CPU cores
        case Float.parse(number_str) do
          {number, ""} -> {:ok, number}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  # Storage parsing (same as memory for now)
  defp parse_storage_value(value), do: parse_memory_value(value)

  # Validation ranges
  defp validate_memory_range(bytes) do
    # 64Mi minimum
    min_memory = 64 * 1_048_576
    # 32Gi maximum
    max_memory = 32 * 1_073_741_824

    cond do
      bytes < min_memory ->
        {:error, field: :resource_limits, message: "memory must be at least 64Mi"}

      bytes > max_memory ->
        {:error, field: :resource_limits, message: "memory cannot exceed 32Gi"}

      true ->
        :ok
    end
  end

  defp validate_cpu_range(cpu_units) do
    # 10m minimum
    min_cpu = 0.01
    # 16 CPU cores maximum
    max_cpu = 16.0

    cond do
      cpu_units < min_cpu ->
        {:error, field: :resource_limits, message: "CPU must be at least 0.01 (10m)"}

      cpu_units > max_cpu ->
        {:error, field: :resource_limits, message: "CPU cannot exceed 16 cores"}

      true ->
        :ok
    end
  end

  defp validate_storage_range(bytes) do
    # 100Mi minimum
    min_storage = 100 * 1_048_576
    # 1000Gi maximum
    max_storage = 1000 * 1_073_741_824

    cond do
      bytes < min_storage ->
        {:error, field: :resource_limits, message: "storage must be at least 100Mi"}

      bytes > max_storage ->
        {:error, field: :resource_limits, message: "storage cannot exceed 1000Gi"}

      true ->
        :ok
    end
  end

  @impl true
  def describe(_opts) do
    [
      message: "must have valid resource limits",
      vars: []
    ]
  end
end
