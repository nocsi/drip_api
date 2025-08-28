defmodule Dirup.Containers.DockerClient do
  @moduledoc """
  Docker API client for container operations.

  This module provides a comprehensive interface to the Docker daemon via HTTP API,
  enabling container lifecycle management, image operations, and monitoring.

  The client supports both Unix socket and TCP connections to Docker daemon.
  """

  require Logger
  alias Dirup.Containers.DockerClient.{Config, Error}

  @type container_id :: String.t()
  @type image_name :: String.t()
  @type container_config :: map()
  @type container_stats :: map()
  @type docker_response :: {:ok, map()} | {:error, Error.t()}

  # Docker API version
  @api_version "1.41"

  # Default configuration
  @default_config %{
    socket_path: "/var/run/docker.sock",
    tcp_host: nil,
    tcp_port: 2375,
    tls: false,
    timeout: 30_000,
    connect_timeout: 5_000
  }

  ## Public API

  @doc """
  Gets Docker system information and verifies connectivity.
  """
  @spec ping() :: :ok | {:error, Error.t()}
  def ping do
    case get("/_ping") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets Docker version information.
  """
  @spec version() :: docker_response()
  def version do
    get("/version")
  end

  ## Container Operations

  @doc """
  Lists all containers (running and stopped).

  ## Options
    * `:all` - Include stopped containers (default: false)
    * `:filters` - Map of filters to apply
  """
  @spec list_containers(keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_containers(opts \\ []) do
    all = Keyword.get(opts, :all, false)
    filters = Keyword.get(opts, :filters, %{})

    query_params = %{
      "all" => all,
      "filters" => Jason.encode!(filters)
    }

    get("/containers/json", query_params)
  end

  @doc """
  Creates a new container from an image.

  ## Container Config
    * `:image` - Image name (required)
    * `:name` - Container name
    * `:env` - Environment variables as list of "KEY=value"
    * `:ports` - Port configuration
    * `:volumes` - Volume mounts
    * `:working_dir` - Working directory
    * `:cmd` - Command to run
    * `:entrypoint` - Entrypoint override
    * `:labels` - Container labels
    * `:restart_policy` - Restart policy configuration
    * `:resource_limits` - CPU/Memory limits
  """
  @spec create_container(container_config()) :: {:ok, map()} | {:error, Error.t()}
  def create_container(config) do
    container_spec = build_container_spec(config)

    endpoint =
      case Map.get(config, :name) do
        nil -> "/containers/create"
        name -> "/containers/create?name=#{URI.encode(name)}"
      end

    post(endpoint, container_spec)
  end

  @doc """
  Starts a container.
  """
  @spec start_container(container_id()) :: :ok | {:error, Error.t()}
  def start_container(container_id) do
    case post("/containers/#{container_id}/start", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Stops a container gracefully.

  ## Options
    * `:timeout` - Seconds to wait before killing (default: 10)
  """
  @spec stop_container(container_id(), keyword()) :: :ok | {:error, Error.t()}
  def stop_container(container_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10)

    case post("/containers/#{container_id}/stop?t=#{timeout}", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Removes a container.

  ## Options
    * `:force` - Force removal of running container (default: false)
    * `:volumes` - Remove associated volumes (default: false)
  """
  @spec remove_container(container_id(), keyword()) :: :ok | {:error, Error.t()}
  def remove_container(container_id, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    volumes = Keyword.get(opts, :volumes, false)

    query_params = %{
      "force" => force,
      "v" => volumes
    }

    case delete("/containers/#{container_id}", query_params) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets container inspection details.
  """
  @spec inspect_container(container_id()) :: docker_response()
  def inspect_container(container_id) do
    get("/containers/#{container_id}/json")
  end

  @doc """
  Gets container statistics.

  ## Options
    * `:stream` - Stream stats continuously (default: false)
  """
  @spec get_container_stats(container_id(), keyword()) :: docker_response()
  def get_container_stats(container_id, opts \\ []) do
    stream = Keyword.get(opts, :stream, false)

    case get("/containers/#{container_id}/stats?stream=#{stream}") do
      {:ok, stats} -> {:ok, parse_container_stats(stats)}
      error -> error
    end
  end

  @doc """
  Gets container logs.

  ## Options
    * `:stdout` - Include stdout (default: true)
    * `:stderr` - Include stderr (default: true)
    * `:tail` - Number of lines from end of logs (default: "all")
    * `:since` - Unix timestamp or relative time
  """
  @spec get_container_logs(container_id(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def get_container_logs(container_id, opts \\ []) do
    params = %{
      "stdout" => Keyword.get(opts, :stdout, true),
      "stderr" => Keyword.get(opts, :stderr, true),
      "tail" => Keyword.get(opts, :tail, "all")
    }

    params =
      case Keyword.get(opts, :since) do
        nil -> params
        since -> Map.put(params, "since", since)
      end

    get("/containers/#{container_id}/logs", params)
  end

  ## Image Operations

  @doc """
  Lists Docker images.

  ## Options
    * `:all` - Show intermediate images (default: false)
    * `:filters` - Map of filters to apply
  """
  @spec list_images(keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_images(opts \\ []) do
    all = Keyword.get(opts, :all, false)
    filters = Keyword.get(opts, :filters, %{})

    query_params = %{
      "all" => all,
      "filters" => Jason.encode!(filters)
    }

    get("/images/json", query_params)
  end

  @doc """
  Builds an image from a Dockerfile.

  ## Options
    * `:dockerfile` - Path to Dockerfile (default: "Dockerfile")
    * `:tag` - Tag for the built image
    * `:build_args` - Build arguments as map
    * `:target` - Multi-stage build target
    * `:no_cache` - Don't use cache (default: false)
    * `:rm` - Remove intermediate containers (default: true)
  """
  @spec build_image(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def build_image(context_path, opts \\ []) do
    cond do
      not File.exists?(context_path) ->
        {:error, Error.new(:context_not_found, "Build context not found: #{context_path}")}

      not File.exists?(Path.join(context_path, Keyword.get(opts, :dockerfile, "Dockerfile"))) ->
        {:error,
         Error.new(
           :dockerfile_not_found,
           "Dockerfile not found: #{Path.join(context_path, Keyword.get(opts, :dockerfile, "Dockerfile"))}"
         )}

      true ->
        # Create tar archive of build context
        with {:ok, tar_data} <- create_build_context_tar(context_path),
             {:ok, response} <- build_image_from_tar(tar_data, opts) do
          {:ok, response}
        end
    end
  end

  @doc """
  Pulls an image from registry.
  """
  @spec pull_image(image_name()) :: {:ok, map()} | {:error, Error.t()}
  def pull_image(image_name) do
    post("/images/create?fromImage=#{URI.encode(image_name)}", %{})
  end

  @doc """
  Removes an image.

  ## Options
    * `:force` - Force removal (default: false)
    * `:no_prune` - Don't delete untagged parents (default: false)
  """
  @spec remove_image(image_name(), keyword()) :: :ok | {:error, Error.t()}
  def remove_image(image_name, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    no_prune = Keyword.get(opts, :no_prune, false)

    query_params = %{
      "force" => force,
      "noprune" => no_prune
    }

    case delete("/images/#{URI.encode(image_name)}", query_params) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Cleans up unused images.
  """
  @spec prune_images() :: {:ok, map()} | {:error, Error.t()}
  def prune_images do
    post("/images/prune", %{})
  end

  @doc """
  Builds an image from a tar archive.

  ## Parameters
    * `tar_content` - Binary tar archive data containing build context
    * `options` - Build options (same as build_image/2)

  ## Options
    * `:dockerfile` - Path to Dockerfile within tar (default: "Dockerfile")
    * `:tag` - Tag for the built image
    * `:build_args` - Build arguments as map
    * `:target` - Multi-stage build target
    * `:no_cache` - Don't use cache (default: false)
    * `:rm` - Remove intermediate containers (default: true)
  """
  @spec build_from_tar(binary(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def build_from_tar(tar_content, options \\ []) do
    build_image_from_tar(tar_content, options)
  end

  ## Private HTTP Methods

  defp get(endpoint, query_params \\ %{}) do
    url = build_url(endpoint, query_params)

    case make_request(:get, url) do
      {:ok, response} -> parse_response(response)
      error -> error
    end
  end

  defp post(endpoint, body, query_params \\ %{}) do
    url = build_url(endpoint, query_params)

    case make_request(:post, url, body) do
      {:ok, response} -> parse_response(response)
      error -> error
    end
  end

  defp delete(endpoint, query_params) do
    url = build_url(endpoint, query_params)

    case make_request(:delete, url) do
      {:ok, response} -> parse_response(response)
      error -> error
    end
  end

  defp make_request(method, url, body \\ nil) do
    _options = build_request_options()

    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    request_body = if body, do: Jason.encode!(body), else: ""

    case Req.request(
           method: method,
           url: url,
           headers: headers,
           body: request_body,
           unix_socket: get_socket_path()
         ) do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error_message = extract_error_message(body)
        {:error, Error.new(:http_error, "Docker API error (#{status}): #{error_message}")}

      {:error, reason} ->
        {:error, Error.new(:connection_error, "Failed to connect to Docker: #{inspect(reason)}")}
    end
  rescue
    error ->
      Logger.error("Docker client request failed", error: Exception.message(error))
      {:error, Error.new(:request_error, Exception.message(error))}
  end

  defp build_url(endpoint, query_params) do
    base_url = get_base_url()
    query_string = build_query_string(query_params)

    url = "#{base_url}/v#{@api_version}#{endpoint}"

    if query_string != "", do: "#{url}?#{query_string}", else: url
  end

  defp get_base_url do
    config = get_config()

    if config.tcp_host do
      protocol = if config.tls, do: "https", else: "http"
      "#{protocol}://#{config.tcp_host}:#{config.tcp_port}"
    else
      "http://localhost"
    end
  end

  defp get_socket_path do
    config = get_config()
    if config.tcp_host, do: nil, else: config.socket_path
  end

  defp build_query_string(params) when map_size(params) == 0, do: ""

  defp build_query_string(params) do
    params
    |> Enum.map(fn {k, v} -> "#{URI.encode(to_string(k))}=#{URI.encode(to_string(v))}" end)
    |> Enum.join("&")
  end

  defp build_request_options do
    config = get_config()

    [
      timeout: config.timeout,
      connect_timeout: config.connect_timeout
    ]
  end

  defp parse_response(%{body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      # Return raw body if not JSON
      {:error, _} -> {:ok, body}
    end
  end

  defp parse_response(%{body: body}), do: {:ok, body}

  defp extract_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"message" => message}} -> message
      _ -> body
    end
  end

  defp extract_error_message(_), do: "Unknown error"

  ## Container Configuration Builders

  defp build_container_spec(config) do
    %{
      "Image" => Map.fetch!(config, :image),
      "Env" => Map.get(config, :env, []),
      "WorkingDir" => Map.get(config, :working_dir),
      "Cmd" => Map.get(config, :cmd),
      "Entrypoint" => Map.get(config, :entrypoint),
      "Labels" => Map.get(config, :labels, %{}),
      "ExposedPorts" => build_exposed_ports(config),
      "HostConfig" => build_host_config(config)
    }
    |> remove_nil_values()
  end

  defp build_exposed_ports(config) do
    ports = Map.get(config, :ports, %{})

    Enum.reduce(ports, %{}, fn {container_port, _}, acc ->
      port_key = "#{container_port}/tcp"
      Map.put(acc, port_key, %{})
    end)
  end

  defp build_host_config(config) do
    %{
      "PortBindings" => build_port_bindings(config),
      "Binds" => build_volume_binds(config),
      "RestartPolicy" => build_restart_policy(config),
      "Memory" => get_memory_limit(config),
      "CpuShares" => get_cpu_shares(config),
      "CpuQuota" => get_cpu_quota(config),
      "CpuPeriod" => get_cpu_period(config)
    }
    |> remove_nil_values()
  end

  defp build_port_bindings(config) do
    ports = Map.get(config, :ports, %{})

    Enum.reduce(ports, %{}, fn {container_port, host_port}, acc ->
      port_key = "#{container_port}/tcp"
      binding = [%{"HostPort" => to_string(host_port)}]
      Map.put(acc, port_key, binding)
    end)
  end

  defp build_volume_binds(config) do
    volumes = Map.get(config, :volumes, [])

    Enum.map(volumes, fn
      {host_path, container_path} -> "#{host_path}:#{container_path}"
      {host_path, container_path, :readonly} -> "#{host_path}:#{container_path}:ro"
      volume_spec when is_binary(volume_spec) -> volume_spec
    end)
  end

  defp build_restart_policy(config) do
    case Map.get(config, :restart_policy) do
      nil -> nil
      :no -> %{"Name" => "no"}
      :always -> %{"Name" => "always"}
      :unless_stopped -> %{"Name" => "unless-stopped"}
      {:on_failure, max_retries} -> %{"Name" => "on-failure", "MaximumRetryCount" => max_retries}
    end
  end

  defp get_memory_limit(config) do
    case get_in(config, [:resource_limits, :memory]) do
      nil -> nil
      memory when is_binary(memory) -> parse_memory_limit(memory)
      memory when is_integer(memory) -> memory
    end
  end

  defp get_cpu_shares(config) do
    case get_in(config, [:resource_limits, :cpu_shares]) do
      nil -> nil
      shares when is_number(shares) -> shares
    end
  end

  defp get_cpu_quota(config) do
    case get_in(config, [:resource_limits, :cpu_quota]) do
      nil -> nil
      quota when is_number(quota) -> quota
    end
  end

  defp get_cpu_period(config) do
    case get_in(config, [:resource_limits, :cpu_period]) do
      # Default Docker CPU period
      nil -> 100_000
      period when is_number(period) -> period
    end
  end

  defp parse_memory_limit(memory_str) do
    case Regex.run(~r/^(\d+(?:\.\d+)?)\s*([KMGT]?[Bb]?)$/i, String.trim(memory_str)) do
      [_, amount_str, unit] ->
        amount = String.to_float(amount_str)

        multiplier =
          case String.downcase(unit) do
            "" -> 1
            "b" -> 1
            "kb" -> 1024
            "mb" -> 1024 * 1024
            "gb" -> 1024 * 1024 * 1024
            "tb" -> 1024 * 1024 * 1024 * 1024
            _ -> 1
          end

        trunc(amount * multiplier)

      _ ->
        Logger.warning("Invalid memory limit format: #{memory_str}")
        nil
    end
  end

  defp remove_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  ## Build Context Helpers

  defp create_build_context_tar(context_path) do
    tar_path = Path.join(System.tmp_dir(), "docker_build_#{:rand.uniform(1_000_000)}.tar")

    try do
      case System.cmd("tar", ["-cf", tar_path, "-C", context_path, "."], stderr_to_stdout: true) do
        {_, 0} ->
          tar_data = File.read!(tar_path)
          {:ok, tar_data}

        {error, _} ->
          {:error, Error.new(:tar_creation_failed, "Failed to create build context: #{error}")}
      end
    after
      File.rm(tar_path)
    end
  end

  defp build_image_from_tar(tar_data, opts) do
    query_params = build_build_query_params(opts)

    url = build_url("/build", query_params)

    headers = [
      {"Content-Type", "application/x-tar"},
      {"Accept", "application/json"}
    ]

    case Req.request(
           method: :post,
           url: url,
           headers: headers,
           body: tar_data,
           unix_socket: get_socket_path()
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        # Docker returns a JSON stream; parse lines and extract image ID/tag
        {:ok, parse_build_output(body, Keyword.get(opts, :tag))}

      {:ok, %{status: status, body: body}} ->
        {:error, Error.new(:http_error, "Docker build error (#{status}): #{extract_error_message(body)}")}

      {:error, reason} ->
        {:error, Error.new(:connection_error, "Failed to connect to Docker: #{inspect(reason)}")}
    end
  rescue
    error ->
      Logger.error("Docker build request failed", error: Exception.message(error))
      {:error, Error.new(:request_error, Exception.message(error))}
  end

  defp parse_build_output(body, tag) when is_binary(body) do
    lines = String.split(body, "\n", trim: true)

    {image_id, stream} =
      Enum.reduce(lines, {nil, []}, fn line, {id, acc} ->
        case Jason.decode(line) do
          {:ok, %{"stream" => s}} -> {id, [s | acc]}
          {:ok, %{"aux" => %{"ID" => new_id}}} -> {new_id, acc}
          {:ok, %{"error" => err}} -> throw({:build_error, err})
          _ -> {id, acc}
        end
      end)

    %{
      image_id: image_id,
      image_name: if(tag, do: tag, else: image_id),
      output: Enum.reverse(stream)
    }
  catch
    {:build_error, err} ->
      Logger.error("Docker build returned error", error: err)
      %{
        error: err,
        output: body
      }
  end

  defp build_build_query_params(opts) do
    %{}
    |> put_if_present("dockerfile", Keyword.get(opts, :dockerfile))
    |> put_if_present("t", Keyword.get(opts, :tag))
    |> put_if_present("target", Keyword.get(opts, :target))
    |> put_if_present("nocache", Keyword.get(opts, :no_cache))
    |> put_if_present("rm", Keyword.get(opts, :rm, true))
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  ## Container Stats Parsing

  defp parse_container_stats(raw_stats) do
    %{
      cpu: parse_cpu_stats(raw_stats),
      memory: parse_memory_stats(raw_stats),
      network: parse_network_stats(raw_stats),
      block_io: parse_block_io_stats(raw_stats),
      timestamp: DateTime.utc_now()
    }
  end

  defp parse_cpu_stats(%{"cpu_stats" => cpu_stats, "precpu_stats" => precpu_stats}) do
    cpu_delta =
      get_in(cpu_stats, ["cpu_usage", "total_usage"]) -
        get_in(precpu_stats, ["cpu_usage", "total_usage"])

    system_delta =
      get_in(cpu_stats, ["system_cpu_usage"]) -
        get_in(precpu_stats, ["system_cpu_usage"])

    cpu_count = length(get_in(cpu_stats, ["cpu_usage", "percpu_usage"]) || [])

    cpu_percent =
      if system_delta > 0 and cpu_delta > 0 do
        cpu_delta / system_delta * cpu_count * 100.0
      else
        0.0
      end

    %{
      percent: Float.round(cpu_percent, 2),
      usage: get_in(cpu_stats, ["cpu_usage", "total_usage"]),
      system_usage: get_in(cpu_stats, ["system_cpu_usage"])
    }
  end

  defp parse_cpu_stats(_), do: %{percent: 0.0, usage: 0, system_usage: 0}

  defp parse_memory_stats(%{"memory_stats" => memory_stats}) do
    usage = get_in(memory_stats, ["usage"]) || 0
    limit = get_in(memory_stats, ["limit"]) || 1

    %{
      usage: usage,
      limit: limit,
      percent: Float.round(usage / limit * 100.0, 2)
    }
  end

  defp parse_memory_stats(_), do: %{usage: 0, limit: 0, percent: 0.0}

  defp parse_network_stats(%{"networks" => networks}) do
    Enum.reduce(networks, %{rx_bytes: 0, tx_bytes: 0}, fn {_name, stats}, acc ->
      %{
        rx_bytes: acc.rx_bytes + (stats["rx_bytes"] || 0),
        tx_bytes: acc.tx_bytes + (stats["tx_bytes"] || 0)
      }
    end)
  end

  defp parse_network_stats(_), do: %{rx_bytes: 0, tx_bytes: 0}

  defp parse_block_io_stats(%{"blkio_stats" => blkio_stats}) do
    read_bytes = sum_blkio_values(get_in(blkio_stats, ["io_service_bytes_recursive"]), "Read")
    write_bytes = sum_blkio_values(get_in(blkio_stats, ["io_service_bytes_recursive"]), "Write")

    %{
      read_bytes: read_bytes,
      write_bytes: write_bytes
    }
  end

  defp parse_block_io_stats(_), do: %{read_bytes: 0, write_bytes: 0}

  defp sum_blkio_values(nil, _), do: 0

  defp sum_blkio_values(values, op) do
    values
    |> Enum.filter(&(&1["op"] == op))
    |> Enum.sum_by(&(&1["value"] || 0))
  end

  ## Configuration

  defp get_config do
    Application.get_env(:dirup, __MODULE__, @default_config)
    |> Enum.into(@default_config)
  end
end

# Error handling module
defmodule Dirup.Containers.DockerClient.Error do
  @moduledoc """
  Docker client error types and handling.
  """

  defstruct [:type, :message, :details]

  @type t :: %__MODULE__{
          type: atom(),
          message: String.t(),
          details: any()
        }

  def new(type, message, details \\ nil) do
    %__MODULE__{
      type: type,
      message: message,
      details: details
    }
  end
end

# Configuration module
defmodule Dirup.Containers.DockerClient.Config do
  @moduledoc """
  Docker client configuration helpers.
  """

  def default_socket_path do
    case :os.type() do
      {:unix, :darwin} -> "/var/run/docker.sock"
      {:unix, :linux} -> "/var/run/docker.sock"
      {:win32, _} -> "//./pipe/docker_engine"
    end
  end

  def validate_config(config) do
    # Add configuration validation if needed
    {:ok, config}
  end
end
