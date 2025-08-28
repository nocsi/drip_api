defmodule Dirup.Containers.Validations.ValidatePortMappings do
  @moduledoc """
  Validates port mappings for service instances.

  This validation ensures that port mappings are properly formatted,
  use valid port ranges, and don't conflict with system or reserved ports.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts) do
    case Ash.Changeset.get_attribute(changeset, :port_mappings) do
      nil ->
        :ok

      port_mappings when is_map(port_mappings) ->
        validate_port_mappings(port_mappings)

      _ ->
        {:error, field: :port_mappings, message: "must be a map"}
    end
  end

  defp validate_port_mappings(port_mappings) when map_size(port_mappings) == 0, do: :ok

  defp validate_port_mappings(port_mappings) do
    port_mappings
    |> Enum.reduce_while(:ok, fn {container_port, host_port}, _acc ->
      case validate_single_mapping(container_port, host_port) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
    |> case do
      :ok -> validate_no_conflicts(port_mappings)
      error -> error
    end
  end

  defp validate_single_mapping(container_port, host_port) do
    with :ok <- validate_container_port(container_port),
         :ok <- validate_host_port(host_port) do
      :ok
    end
  end

  defp validate_container_port(port_spec) when is_binary(port_spec) do
    case parse_port_spec(port_spec) do
      {:ok, port, protocol} ->
        with :ok <- validate_port_number(port, "container"),
             :ok <- validate_protocol(protocol) do
          :ok
        end

      :error ->
        {:error, field: :port_mappings, message: "invalid container port format: #{port_spec}"}
    end
  end

  defp validate_container_port(port) when is_integer(port) do
    validate_port_number(port, "container")
  end

  defp validate_container_port(port) do
    {:error,
     field: :port_mappings,
     message: "container port must be string or integer, got: #{inspect(port)}"}
  end

  defp validate_host_port(port) when is_integer(port) do
    with :ok <- validate_port_number(port, "host"),
         :ok <- validate_not_reserved_port(port) do
      :ok
    end
  end

  defp validate_host_port(port) do
    {:error, field: :port_mappings, message: "host port must be integer, got: #{inspect(port)}"}
  end

  defp parse_port_spec(port_spec) do
    case String.split(port_spec, "/") do
      [port_str] ->
        case Integer.parse(port_str) do
          {port, ""} -> {:ok, port, "tcp"}
          _ -> :error
        end

      [port_str, protocol] when protocol in ["tcp", "udp", "sctp"] ->
        case Integer.parse(port_str) do
          {port, ""} -> {:ok, port, protocol}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp validate_port_number(port, port_type) when is_integer(port) do
    cond do
      port < 1 ->
        {:error,
         field: :port_mappings, message: "#{port_type} port must be positive, got: #{port}"}

      port > 65535 ->
        {:error,
         field: :port_mappings, message: "#{port_type} port must be <= 65535, got: #{port}"}

      true ->
        :ok
    end
  end

  defp validate_protocol(protocol) when protocol in ["tcp", "udp", "sctp"], do: :ok

  defp validate_protocol(protocol) do
    {:error,
     field: :port_mappings, message: "invalid protocol: #{protocol}. Must be tcp, udp, or sctp"}
  end

  defp validate_not_reserved_port(port) do
    # Common reserved/system ports that should not be used
    reserved_ports = [
      # System ports
      # SSH
      22,
      # SMTP
      25,
      # DNS
      53,
      # HTTP (allow for proxies)
      80,
      # POP3
      110,
      # IMAP
      143,
      # HTTPS (allow for proxies)
      443,
      # IMAPS
      993,
      # POP3S
      995,

      # Database ports
      # MySQL
      3306,
      # PostgreSQL
      5432,
      # Redis
      6379,
      # MongoDB
      27017

      # Application servers (warn but allow)
      # 3000, # Node.js dev server
      # 8000, # Python dev server
      # 8080, # Common app server
    ]

    # Only block the most critical system ports
    critical_ports = [22, 25, 53, 110, 143, 993, 995]

    cond do
      port in critical_ports ->
        {:error, field: :port_mappings, message: "port #{port} is reserved for system use"}

      port < 1024 and port not in [80, 443] ->
        {:error, field: :port_mappings, message: "port #{port} is in privileged range (< 1024)"}

      true ->
        :ok
    end
  end

  defp validate_no_conflicts(port_mappings) do
    host_ports =
      port_mappings
      |> Map.values()
      |> Enum.sort()

    duplicates =
      host_ports
      |> Enum.frequencies()
      |> Enum.filter(fn {_port, count} -> count > 1 end)
      |> Enum.map(fn {port, _count} -> port end)

    case duplicates do
      [] ->
        :ok

      [port | _] ->
        {:error, field: :port_mappings, message: "duplicate host port: #{port}"}
    end
  end

  @impl true
  def describe(_opts) do
    [
      message: "must have valid port mappings",
      vars: []
    ]
  end
end
