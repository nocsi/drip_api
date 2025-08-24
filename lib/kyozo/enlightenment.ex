defmodule Kyozo.Enlightenment do
  @moduledoc """
  Enlightenment engine for service detection and intelligent code generation.

  This module scans workspaces to detect services, databases, APIs, and other
  infrastructure components, then generates helpful Markdown content with
  connection code, setup instructions, and example usage.

  ## Features

  - **Service Detection**: Automatically finds Docker Compose, Kubernetes, and other services
  - **Database Discovery**: Detects database connections and generates client code
  - **API Integration**: Finds OpenAPI specs and generates client libraries
  - **Environment Setup**: Creates environment-specific configuration
  - **Code Generation**: Produces working code examples in multiple languages
  """

  require Logger

  alias Kyozo.Workspaces

  @type enlightenment_result :: %{
          services: list(map()),
          databases: list(map()),
          apis: list(map()),
          configs: list(map()),
          notebooks: list(map()),
          generated_content: String.t()
        }

  @type service_info :: %{
          type: atom(),
          name: String.t(),
          config: map(),
          ports: list(integer()),
          dependencies: list(String.t()),
          connection_code: String.t()
        }

  @doc """
  Scan a workspace and detect all enlightenment opportunities.

  Returns a comprehensive analysis of the workspace including services,
  databases, APIs, and suggested integrations.

  ## Examples

      iex> Enlightenment.scan_workspace("workspace-123")
      {:ok, %{
        services: [%{type: :postgres, name: "db", ports: [5432]}],
        databases: [%{type: :postgresql, host: "localhost"}],
        apis: [%{type: :openapi, spec_path: "/api/openapi.json"}],
        generated_content: "# Detected Services\\n..."
      }}
  """
  @spec scan_workspace(String.t()) :: {:ok, enlightenment_result()} | {:error, String.t()}
  def scan_workspace(workspace_id) do
    with {:ok, _workspace} <- Workspaces.get_workspace(workspace_id),
         {:ok, files} <- Workspaces.list_files(workspace_id: workspace_id) do
      enlightenments = %{
        services: detect_services(files),
        databases: detect_databases(files),
        apis: detect_apis(files),
        configs: detect_configs(files),
        notebooks: find_existing_notebooks(files)
      }

      {:ok, enlightenments}
    else
      error -> {:error, "Failed to scan workspace: #{inspect(error)}"}
    end
  end

  @doc """
  Enlighten a specific Markdown file by injecting detected services and generated code.
  """
  @spec enlighten_file(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def enlighten_file(file, opts \\ []) do
    force_refresh = Keyword.get(opts, :force_refresh, false)

    # Check if we need to refresh enlightenment data
    should_refresh = force_refresh || enlightenment_stale?(file)

    if should_refresh do
      case scan_workspace(file.workspace_id) do
        {:ok, enlightenments} ->
          enhanced_content = generate_enhanced_content(file, enlightenments)

          file
          |> Ash.Changeset.for_update(:update_content, %{content: enhanced_content})
          |> Ash.Changeset.force_change_attribute(:enlightenment_metadata, %{
            "detected_services" => enlightenments.services,
            "generated_cells" => extract_generated_cell_ids(enhanced_content),
            "last_scan" => DateTime.utc_now() |> DateTime.to_iso8601()
          })
          |> Ash.update()

        error ->
          error
      end
    else
      {:ok, file}
    end
  end

  # Service Detection Functions

  @spec detect_services(list(map())) :: list(service_info())
  defp detect_services(files) do
    files
    |> Enum.flat_map(&detect_service_from_file/1)
    |> Enum.uniq_by(& &1.name)
  end

  @spec detect_service_from_file(map()) :: list(service_info())
  defp detect_service_from_file(file) do
    cond do
      String.ends_with?(file.name, "docker-compose.yml") ->
        detect_docker_compose_services(file)

      String.ends_with?(file.name, "docker-compose.yaml") ->
        detect_docker_compose_services(file)

      file.name == "Dockerfile" ->
        detect_dockerfile_service(file)

      String.ends_with?(file.name, ".k8s.yml") ->
        detect_kubernetes_services(file)

      String.ends_with?(file.name, ".k8s.yaml") ->
        detect_kubernetes_services(file)

      file.name == "package.json" ->
        detect_nodejs_service(file)

      file.name == "requirements.txt" ->
        detect_python_service(file)

      file.name == "mix.exs" ->
        detect_elixir_service(file)

      true ->
        []
    end
  end

  @spec detect_docker_compose_services(map()) :: list(service_info())
  defp detect_docker_compose_services(file) do
    case get_file_content(file) do
      {:ok, content} ->
        case YamlElixir.read_from_string(content) do
          {:ok, %{"services" => services}} ->
            Enum.map(services, fn {name, config} ->
              parse_docker_service(name, config)
            end)

          _ ->
            []
        end

      _ ->
        []
    end
  end

  @spec parse_docker_service(String.t(), map()) :: service_info()
  defp parse_docker_service(name, config) do
    image = Map.get(config, "image", "")
    ports = extract_ports(Map.get(config, "ports", []))

    service_type = determine_service_type(image, name, config)

    %{
      type: service_type,
      name: name,
      image: image,
      ports: ports,
      environment: Map.get(config, "environment", []),
      volumes: Map.get(config, "volumes", []),
      depends_on: Map.get(config, "depends_on", []),
      connection_code: generate_connection_code(service_type, name, ports, config)
    }
  end

  @spec determine_service_type(String.t(), String.t(), map()) :: atom()
  defp determine_service_type(image, name, _config) do
    cond do
      String.contains?(image, "postgres") -> :postgresql
      String.contains?(image, "mysql") -> :mysql
      String.contains?(image, "redis") -> :redis
      String.contains?(image, "mongo") -> :mongodb
      String.contains?(image, "nginx") -> :nginx
      String.contains?(image, "apache") -> :apache
      String.contains?(image, "elasticsearch") -> :elasticsearch
      String.contains?(image, "rabbitmq") -> :rabbitmq
      String.contains?(image, "kafka") -> :kafka
      String.contains?(name, "api") -> :api_service
      String.contains?(name, "web") -> :web_service
      String.contains?(name, "app") -> :application
      true -> :generic
    end
  end

  @spec extract_ports(list()) :: list(integer())
  defp extract_ports(port_configs) do
    port_configs
    |> Enum.map(fn
      port when is_integer(port) ->
        port

      port_string when is_binary(port_string) ->
        case String.split(port_string, ":") do
          [_host_port, container_port] -> String.to_integer(container_port)
          [port] -> String.to_integer(port)
          _ -> nil
        end

      %{"target" => target} ->
        target

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec generate_connection_code(atom(), String.t(), list(integer()), map()) :: String.t()
  defp generate_connection_code(service_type, name, ports, config) do
    case service_type do
      :postgresql -> generate_postgres_connection(name, ports, config)
      :mysql -> generate_mysql_connection(name, ports, config)
      :redis -> generate_redis_connection(name, ports, config)
      :mongodb -> generate_mongodb_connection(name, ports, config)
      :api_service -> generate_api_connection(name, ports, config)
      _ -> generate_generic_connection(name, ports, config)
    end
  end

  defp generate_postgres_connection(name, ports, config) do
    port = List.first(ports) || 5432
    env = Map.get(config, "environment", [])
    database = extract_env_value(env, "POSTGRES_DB") || "postgres"
    username = extract_env_value(env, "POSTGRES_USER") || "postgres"

    """
    ```elixir
    # Connect to #{name} PostgreSQL service
    {:ok, conn} = Postgrex.start_link(
      hostname: "#{name}",
      port: #{port},
      database: "#{database}",
      username: "#{username}",
      password: System.get_env("POSTGRES_PASSWORD") || "postgres"
    )

    # Test connection
    Postgrex.query!(conn, "SELECT version()", [])
    ```
    """
  end

  defp generate_mysql_connection(name, ports, config) do
    port = List.first(ports) || 3306
    env = Map.get(config, "environment", [])
    database = extract_env_value(env, "MYSQL_DATABASE") || "mysql"

    """
    ```elixir
    # Connect to #{name} MySQL service
    {:ok, conn} = MyXQL.start_link(
      hostname: "#{name}",
      port: #{port},
      database: "#{database}",
      username: System.get_env("MYSQL_USER") || "root",
      password: System.get_env("MYSQL_PASSWORD") || "mysql"
    )

    # Test connection
    MyXQL.query!(conn, "SELECT VERSION()", [])
    ```
    """
  end

  defp generate_redis_connection(name, ports, _config) do
    port = List.first(ports) || 6379

    """
    ```elixir
    # Connect to #{name} Redis service
    {:ok, conn} = Redix.start_link(host: "#{name}", port: #{port})

    # Test connection
    Redix.command!(conn, ["PING"])
    ```
    """
  end

  defp generate_mongodb_connection(name, ports, config) do
    port = List.first(ports) || 27017
    env = Map.get(config, "environment", [])
    database = extract_env_value(env, "MONGO_INITDB_DATABASE") || "mongodb"

    """
    ```elixir
    # Connect to #{name} MongoDB service
    {:ok, conn} = Mongo.start_link(
      url: "mongodb://#{name}:#{port}/#{database}"
    )

    # Test connection
    Mongo.find_one(conn, "test", %{})
    ```
    """
  end

  defp generate_api_connection(name, ports, _config) do
    port = List.first(ports) || 3000

    """
    ```elixir
    # Connect to #{name} API service
    base_url = "http://#{name}:#{port}"

    # Test API connection
    response = Req.get!(base_url <> "/health")
    IO.inspect(response.status)
    ```
    """
  end

  defp generate_generic_connection(name, ports, _config) do
    port = List.first(ports)

    if port do
      """
      ```bash
      # Test #{name} service connection
      curl http://#{name}:#{port}
      ```
      """
    else
      """
      ```bash
      # #{name} service is available in the network
      # Check service logs: docker-compose logs #{name}
      ```
      """
    end
  end

  # Database Detection

  @spec detect_databases(list(map())) :: list(map())
  defp detect_databases(files) do
    files
    |> Enum.flat_map(&detect_database_from_file/1)
    |> Enum.uniq_by(& &1.name)
  end

  @spec detect_database_from_file(map()) :: list(map())
  defp detect_database_from_file(file) do
    cond do
      String.ends_with?(file.name, ".env") ->
        detect_env_databases(file)

      file.name == "config.exs" ->
        detect_elixir_databases(file)

      file.name == "database.yml" ->
        detect_rails_databases(file)

      String.contains?(file.name, "migration") ->
        detect_migration_databases(file)

      true ->
        []
    end
  end

  defp detect_env_databases(file) do
    case get_file_content(file) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.flat_map(&parse_env_line_for_db/1)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  defp parse_env_line_for_db(line) do
    cond do
      String.contains?(line, "DATABASE_URL") ->
        [%{type: :connection_string, name: "database", source: "DATABASE_URL"}]

      String.contains?(line, "POSTGRES") ->
        [%{type: :postgresql, name: "postgres", source: "environment"}]

      String.contains?(line, "MYSQL") ->
        [%{type: :mysql, name: "mysql", source: "environment"}]

      String.contains?(line, "REDIS") ->
        [%{type: :redis, name: "redis", source: "environment"}]

      true ->
        []
    end
  end

  # API Detection

  @spec detect_apis(list(map())) :: list(map())
  defp detect_apis(files) do
    files
    |> Enum.flat_map(&detect_api_from_file/1)
    |> Enum.uniq_by(& &1.name)
  end

  @spec detect_api_from_file(map()) :: list(map())
  defp detect_api_from_file(file) do
    cond do
      String.contains?(file.name, "openapi") ->
        [%{type: :openapi, name: "api", spec_path: file.file_path, file: file}]

      String.contains?(file.name, "swagger") ->
        [%{type: :swagger, name: "api", spec_path: file.file_path, file: file}]

      file.name == "api.json" ->
        [%{type: :json_api, name: "api", spec_path: file.file_path, file: file}]

      String.ends_with?(file.name, "_controller.ex") ->
        [%{type: :phoenix_controller, name: extract_controller_name(file.name), file: file}]

      true ->
        []
    end
  end

  defp extract_controller_name(filename) do
    filename
    |> String.replace("_controller.ex", "")
    |> String.replace("_", " ")
    |> String.trim()
  end

  # Config Detection

  @spec detect_configs(list(map())) :: list(map())
  defp detect_configs(files) do
    files
    |> Enum.flat_map(&detect_config_from_file/1)
  end

  @spec detect_config_from_file(map()) :: list(map())
  defp detect_config_from_file(file) do
    cond do
      String.ends_with?(file.name, ".env") ->
        [%{type: :env_file, name: file.name, path: file.file_path}]

      file.name == "config.exs" ->
        [%{type: :elixir_config, name: "elixir", path: file.file_path}]

      file.name == "package.json" ->
        [%{type: :nodejs_config, name: "nodejs", path: file.file_path}]

      file.name == "requirements.txt" ->
        [%{type: :python_deps, name: "python", path: file.file_path}]

      true ->
        []
    end
  end

  # Content Generation

  @spec generate_enhanced_content(map(), enlightenment_result()) :: String.t()
  defp generate_enhanced_content(file, enlightenments) do
    base_content = file.content || generate_base_markdown_content(file)

    sections =
      [
        generate_services_section(enlightenments.services),
        generate_databases_section(enlightenments.databases),
        generate_apis_section(enlightenments.apis),
        generate_configs_section(enlightenments.configs)
      ]
      |> Enum.reject(&(String.trim(&1) == ""))

    if Enum.empty?(sections) do
      base_content
    else
      enhanced_sections = Enum.join(sections, "\n\n")

      if String.contains?(base_content, "## Detected Services") do
        # Replace existing enlightenment content
        Regex.replace(
          ~r/## Detected Services.*?(?=##[^#]|\z)/s,
          base_content,
          enhanced_sections
        )
      else
        # Append new enlightenment content
        base_content <> "\n\n" <> enhanced_sections
      end
    end
  end

  defp generate_base_markdown_content(file) do
    workspace_name = (file.workspace && file.workspace.name) || "Workspace"

    """
    # #{workspace_name} Enlightenment

    <!-- metadata: {"enlightenment": {"workspace_id": "#{file.workspace_id}", "generated_at": "#{DateTime.utc_now() |> DateTime.to_iso8601()}"}} -->

    Welcome to your enlightened workspace! This Markdown file will help you explore and work with your project.

    ## Getting Started

    ```elixir
    # Setup common dependencies
    Mix.install([
      {:req, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:explorer, "~> 0.7"}
    ])
    ```
    """
  end

  defp generate_services_section(services) when length(services) > 0 do
    service_content =
      services
      |> Enum.map(&format_service/1)
      |> Enum.join("\n\n")

    """
    ## Detected Services

    <!-- metadata: {"enlightenment": {"type": "services", "auto_generated": true}} -->

    We detected the following services in your workspace:

    #{service_content}

    ### Service Dependencies

    ```elixir
    # Install service-specific dependencies
    Mix.install([
      #{generate_service_dependencies(services)}
    ])
    ```
    """
  end

  defp generate_services_section(_), do: ""

  defp format_service(service) do
    """
    ### #{String.capitalize(to_string(service.name))} (#{service.type})

    #{if service[:image], do: "**Image:** `#{service.image}`", else: ""}
    #{if length(service.ports) > 0, do: "**Ports:** #{Enum.join(service.ports, ", ")}", else: ""}

    #{service.connection_code}
    """
  end

  defp generate_service_dependencies(services) do
    deps =
      services
      |> Enum.flat_map(&service_to_dependencies/1)
      |> Enum.uniq()
      |> Enum.map(fn {name, version} -> "      #{name}: \"#{version}\"" end)
      |> Enum.join(",\n")

    if deps == "" do
      "      # No additional dependencies needed"
    else
      deps
    end
  end

  defp service_to_dependencies(service) do
    case service.type do
      :postgresql -> [{:postgrex, "~> 0.17"}]
      :mysql -> [{:myxql, "~> 0.6"}]
      :redis -> [{:redix, "~> 1.2"}]
      :mongodb -> [{:mongodb_driver, "~> 1.0"}]
      _ -> []
    end
  end

  defp generate_databases_section(databases) when length(databases) > 0 do
    """
    ## Database Connections

    <!-- livebook:{"enlightenment": {"type": "databases", "auto_generated": true}} -->

    #{Enum.map_join(databases, "\n\n", &format_database/1)}
    """
  end

  defp generate_databases_section(_), do: ""

  defp format_database(database) do
    "**#{String.capitalize(to_string(database.type))}** detected from #{database.source}"
  end

  defp generate_apis_section(apis) when length(apis) > 0 do
    """
    ## API Integration

    <!-- livebook:{"enlightenment": {"type": "apis", "auto_generated": true}} -->

    #{Enum.map_join(apis, "\n\n", &format_api/1)}
    """
  end

  defp generate_apis_section(_), do: ""

  defp format_api(api) do
    case api.type do
      :openapi ->
        """
        ### OpenAPI Specification

        Found OpenAPI spec at `#{api.spec_path}`:

        ```elixir
        # Load and explore the API
        spec = File.read!("#{api.spec_path}") |> Jason.decode!()
        IO.puts("API Title: \#{spec["info"]["title"]}")
        IO.puts("API Version: \#{spec["info"]["version"]}")
        ```
        """

      :phoenix_controller ->
        """
        ### Phoenix Controller: #{api.name}

        ```elixir
        # Test #{api.name} endpoints
        base_url = "http://localhost:4000"

        # Add specific endpoint calls here
        response = Req.get!(base_url <> "/api/#{api.name}")
        IO.inspect(response.body)
        ```
        """

      _ ->
        "**#{String.capitalize(to_string(api.type))}** found: #{api.name}"
    end
  end

  defp generate_configs_section(configs) when length(configs) > 0 do
    """
    ## Configuration

    <!-- livebook:{"enlightenment": {"type": "configs", "auto_generated": true}} -->

    Configuration files detected:

    #{Enum.map_join(configs, "\n", fn config -> "- **#{config.type}**: `#{config.name}`" end)}

    ```elixir
    # Load environment configuration
    #{generate_config_loading_code(configs)}
    ```
    """
  end

  defp generate_configs_section(_), do: ""

  defp generate_config_loading_code(configs) do
    configs
    |> Enum.map(&config_to_code/1)
    |> Enum.join("\n")
  end

  defp config_to_code(config) do
    case config.type do
      :env_file ->
        """
        # Load #{config.name}
        if File.exists?("#{config.path}") do
          File.read!("#{config.path}")
          |> String.split("\\n")
          |> Enum.each(fn line ->
            case String.split(line, "=", parts: 2) do
              [key, value] -> System.put_env(String.trim(key), String.trim(value))
              _ -> :ok
            end
          end)
        end
        """

      _ ->
        "# Configuration: #{config.name} at #{config.path}"
    end
  end

  # Utility Functions

  defp find_existing_notebooks(files) do
    files
    |> Enum.filter(
      &(String.ends_with?(&1.name, ".md") || String.ends_with?(&1.name, ".markdown"))
    )
    |> Enum.map(fn file ->
      %{name: file.name, path: file.file_path, id: file.id}
    end)
  end

  defp enlightenment_stale?(file) do
    case file.enlightenment_metadata do
      %{"last_scan" => last_scan} ->
        case DateTime.from_iso8601(last_scan) do
          {:ok, last_scan_dt, _} ->
            DateTime.diff(DateTime.utc_now(), last_scan_dt, :hour) > 1

          _ ->
            true
        end

      _ ->
        true
    end
  end

  defp extract_generated_cell_ids(content) do
    ~r/<!-- metadata:{"enlightenment": {"[^"]*": "[^"]*"}} -->/
    |> Regex.scan(content)
    |> Enum.with_index()
    |> Enum.map(fn {_match, index} -> "enlightenment_#{index}" end)
  end

  defp get_file_content(file) do
    # This would integrate with your file storage system
    # For now, return the content if available
    case file.content do
      nil -> {:error, "No content available"}
      content -> {:ok, content}
    end
  end

  defp extract_env_value(env_list, key) when is_list(env_list) do
    env_list
    |> Enum.find_value(fn
      env_string when is_binary(env_string) ->
        case String.split(env_string, "=", parts: 2) do
          [^key, value] -> value
          _ -> nil
        end

      _ ->
        nil
    end)
  end

  defp extract_env_value(_, _), do: nil

  # Additional utility functions for different service types
  defp detect_dockerfile_service(_file), do: []
  defp detect_kubernetes_services(_file), do: []
  defp detect_nodejs_service(_file), do: []
  defp detect_python_service(_file), do: []
  defp detect_elixir_service(_file), do: []
  defp detect_elixir_databases(_file), do: []
  defp detect_rails_databases(_file), do: []
  defp detect_migration_databases(_file), do: []
end
