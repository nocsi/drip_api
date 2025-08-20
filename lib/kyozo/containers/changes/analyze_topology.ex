defmodule Kyozo.Containers.Changes.AnalyzeTopology do
  @moduledoc """
  Analyzes workspace folders to detect service patterns and generate deployment recommendations.

  This change implements the core "Folder as a Service" intelligence by examining
  file structures, detecting technology stacks, and providing confidence-scored
  recommendations for containerized deployments.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &analyze_topology/2)
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp analyze_topology(changeset, topology_detection) do
    workspace_id =
      Ash.Changeset.get_argument(changeset, :workspace_id) ||
        Ash.Changeset.get_attribute(changeset, :workspace_id) ||
        topology_detection.workspace_id

    folder_path =
      Ash.Changeset.get_argument(changeset, :folder_path) ||
        Ash.Changeset.get_attribute(changeset, :folder_path) ||
        topology_detection.folder_path

    case perform_analysis(workspace_id, folder_path) do
      {:ok, analysis_result} ->
        # Update the topology detection with analysis results
        updated_detection =
          topology_detection
          |> Map.merge(analysis_result)
          |> Map.put(:detection_timestamp, DateTime.utc_now())

        {:ok, updated_detection}

      {:error, reason} ->
        require Logger
        Logger.error("Topology analysis failed: #{inspect(reason)}")

        # Return detection with error information
        error_result = %{
          detected_patterns: %{},
          service_graph: %{},
          recommended_services: [],
          confidence_scores: %{},
          file_indicators: [],
          deployment_strategy: :custom,
          total_services_detected: 0,
          analysis_metadata: %{error: reason, failed_at: DateTime.utc_now()}
        }

        updated_detection = Map.merge(topology_detection, error_result)
        {:ok, updated_detection}
    end
  end

  defp perform_analysis(workspace_id, folder_path) do
    with {:ok, workspace} <- get_workspace(workspace_id),
         {:ok, files} <- get_folder_files(workspace, folder_path),
         {:ok, patterns} <- detect_service_patterns(files),
         {:ok, recommendations} <- generate_service_recommendations(files, patterns),
         {:ok, service_graph} <- build_service_dependency_graph(files, patterns) do
      analysis_result = %{
        detected_patterns: patterns,
        service_graph: service_graph,
        recommended_services: recommendations,
        confidence_scores: extract_confidence_scores(patterns),
        file_indicators: extract_file_indicators(files),
        deployment_strategy: determine_deployment_strategy(patterns),
        total_services_detected: length(recommendations),
        analysis_metadata: %{
          analyzed_at: DateTime.utc_now(),
          file_count: length(files),
          analysis_version: "1.0.0"
        }
      }

      {:ok, analysis_result}
    else
      error -> error
    end
  end

  defp get_workspace(workspace_id) do
    try do
      workspace = Kyozo.Workspaces.get!(workspace_id, load: [:files])
      {:ok, workspace}
    rescue
      error -> {:error, "Failed to load workspace: #{inspect(error)}"}
    end
  end

  defp get_folder_files(workspace, folder_path) do
    try do
      # Normalize folder path
      normalized_path = normalize_path(folder_path)

      # Filter files that are within the specified folder path
      matching_files =
        workspace.files
        |> Enum.filter(fn file ->
          file_path = normalize_path(file.file_path || "")
          String.starts_with?(file_path, normalized_path) and not is_nil(file.file_path)
        end)
        |> Enum.reject(fn file -> file.deleted_at != nil end)

      {:ok, matching_files}
    rescue
      error -> {:error, "Failed to filter files: #{inspect(error)}"}
    end
  end

  defp normalize_path("/"), do: ""
  defp normalize_path(""), do: ""

  defp normalize_path(path) when is_binary(path) do
    path
    |> String.trim_leading("/")
    |> String.trim_trailing("/")
  end

  defp normalize_path(_), do: ""

  defp detect_service_patterns(files) do
    service_indicators = %{
      nodejs: %{
        files: ["package.json", "yarn.lock", "npm-shrinkwrap.json", "package-lock.json"],
        patterns: [~r/\.js$/, ~r/\.ts$/, ~r/\.jsx$/, ~r/\.tsx$/],
        confidence_boost: 0.9
      },
      python: %{
        files: ["requirements.txt", "Pipfile", "pyproject.toml", "setup.py", "poetry.lock"],
        patterns: [~r/\.py$/, ~r/__init__\.py$/, ~r/\.pyc$/],
        confidence_boost: 0.9
      },
      golang: %{
        files: ["go.mod", "go.sum", "Gopkg.toml"],
        patterns: [~r/\.go$/, ~r/main\.go$/],
        confidence_boost: 0.95
      },
      rust: %{
        files: ["Cargo.toml", "Cargo.lock"],
        patterns: [~r/\.rs$/, ~r/main\.rs$/],
        confidence_boost: 0.95
      },
      ruby: %{
        files: ["Gemfile", "Gemfile.lock", "config.ru"],
        patterns: [~r/\.rb$/, ~r/\.erb$/],
        confidence_boost: 0.85
      },
      java: %{
        files: ["pom.xml", "build.gradle", "settings.gradle"],
        patterns: [~r/\.java$/, ~r/\.jar$/],
        confidence_boost: 0.85
      },
      containerized: %{
        files: ["Dockerfile", "Containerfile"],
        patterns: [],
        confidence_boost: 1.0
      },
      compose_stack: %{
        files: ["docker-compose.yml", "docker-compose.yaml", "compose.yml"],
        patterns: [],
        confidence_boost: 1.0
      },
      static_site: %{
        files: ["index.html", "_config.yml", "netlify.toml"],
        patterns: [~r/\.html$/, ~r/\.css$/, ~r/\.scss$/],
        confidence_boost: 0.7
      },
      proxy: %{
        files: ["nginx.conf", "apache.conf", "haproxy.cfg", "traefik.yml"],
        patterns: [],
        confidence_boost: 0.9
      }
    }

    file_names =
      Enum.map(files, fn file ->
        file.file_path |> String.split("/") |> List.last()
      end)

    patterns =
      Enum.reduce(service_indicators, %{}, fn {service_type, indicators}, acc ->
        confidence = calculate_service_confidence(files, file_names, indicators)

        if confidence > 0.3 do
          Map.put(acc, service_type, %{
            confidence: confidence,
            matched_files: find_matched_files(file_names, indicators),
            detected_at: DateTime.utc_now()
          })
        else
          acc
        end
      end)

    {:ok, patterns}
  end

  defp calculate_service_confidence(files, file_names, indicators) do
    file_score = calculate_file_score(file_names, indicators.files)
    pattern_score = calculate_pattern_score(files, indicators.patterns)

    base_score = (file_score + pattern_score) / 2
    boosted_score = base_score * indicators.confidence_boost

    min(boosted_score, 1.0)
  end

  defp calculate_file_score(file_names, indicator_files) do
    matches =
      Enum.count(file_names, fn file_name ->
        Enum.any?(indicator_files, &(&1 == file_name))
      end)

    case matches do
      0 -> 0.0
      1 -> 0.6
      2 -> 0.8
      _ -> 1.0
    end
  end

  defp calculate_pattern_score(files, patterns) when length(patterns) == 0, do: 0.0

  defp calculate_pattern_score(files, patterns) do
    matching_files =
      Enum.count(files, fn file ->
        file_name = file.file_path |> String.split("/") |> List.last()
        Enum.any?(patterns, &Regex.match?(&1, file_name))
      end)

    total_files = length(files)
    if total_files == 0, do: 0.0, else: min(matching_files / total_files, 1.0)
  end

  defp find_matched_files(file_names, indicator_files) do
    Enum.filter(file_names, fn file_name ->
      Enum.any?(indicator_files, &(&1 == file_name))
    end)
  end

  defp generate_service_recommendations(files, detected_patterns) do
    recommendations =
      Enum.map(detected_patterns, fn {service_type, detection} ->
        %{
          service_type: service_type,
          confidence: detection.confidence,
          name: generate_service_name(service_type, files),
          deployment_config: generate_deployment_config(service_type, files),
          port_mappings: suggest_port_mappings(service_type),
          environment_variables: extract_env_variables(service_type, files),
          resource_limits: suggest_resource_limits(service_type),
          health_check_config: generate_health_check(service_type),
          recommended_at: DateTime.utc_now()
        }
      end)

    {:ok, recommendations}
  end

  defp generate_service_name(service_type, files) do
    # Try to extract name from package.json, Cargo.toml, etc.
    # For now, generate a simple name based on service type
    "#{service_type}_service_#{:rand.uniform(1000)}"
  end

  defp generate_deployment_config(:nodejs, _files) do
    %{
      build_command: "npm ci",
      start_command: "npm start",
      node_version: "18",
      package_manager: "npm",
      environment: "production"
    }
  end

  defp generate_deployment_config(:python, _files) do
    %{
      python_version: "3.11",
      framework: "auto-detect",
      requirements_file: "requirements.txt",
      environment: "production"
    }
  end

  defp generate_deployment_config(:containerized, _files) do
    %{
      dockerfile_path: "Dockerfile",
      build_args: %{},
      multi_stage: false
    }
  end

  defp generate_deployment_config(:compose_stack, _files) do
    %{
      compose_file: "docker-compose.yml",
      services: [],
      networks: [],
      volumes: []
    }
  end

  defp generate_deployment_config(_, _files), do: %{}

  defp suggest_port_mappings(:nodejs), do: %{"3000/tcp" => 3000}
  defp suggest_port_mappings(:python), do: %{"8000/tcp" => 8000}
  defp suggest_port_mappings(:golang), do: %{"8080/tcp" => 8080}
  defp suggest_port_mappings(:rust), do: %{"8080/tcp" => 8080}
  defp suggest_port_mappings(:ruby), do: %{"3000/tcp" => 3000}
  defp suggest_port_mappings(:java), do: %{"8080/tcp" => 8080}
  defp suggest_port_mappings(:static_site), do: %{"80/tcp" => 80}
  defp suggest_port_mappings(:proxy), do: %{"80/tcp" => 80, "443/tcp" => 443}
  defp suggest_port_mappings(_), do: %{}

  defp extract_env_variables(_service_type, _files) do
    # In a real implementation, this would parse .env files, docker-compose.yml, etc.
    %{
      "NODE_ENV" => "production",
      "PORT" => "3000"
    }
  end

  defp suggest_resource_limits(:golang), do: %{memory: "256Mi", cpu: "0.25", storage: "500Mi"}
  defp suggest_resource_limits(:rust), do: %{memory: "256Mi", cpu: "0.25", storage: "500Mi"}
  defp suggest_resource_limits(:static_site), do: %{memory: "64Mi", cpu: "0.1", storage: "100Mi"}
  defp suggest_resource_limits(_), do: %{memory: "512Mi", cpu: "0.5", storage: "1Gi"}

  defp generate_health_check(:nodejs) do
    %{
      path: "/health",
      port: 3000,
      interval_seconds: 30,
      timeout_seconds: 10,
      retries: 3
    }
  end

  defp generate_health_check(:python) do
    %{
      path: "/health",
      port: 8000,
      interval_seconds: 30,
      timeout_seconds: 10,
      retries: 3
    }
  end

  defp generate_health_check(_), do: %{}

  defp build_service_dependency_graph(_files, detected_patterns) do
    # In a real implementation, this would analyze:
    # 1. Import/require statements
    # 2. Network calls and API dependencies
    # 3. Database connections
    # 4. External service integrations

    service_types = Map.keys(detected_patterns)

    graph = %{
      nodes: Enum.map(service_types, &to_string/1),
      edges: [],
      metadata: %{
        total_services: length(service_types),
        complexity: determine_complexity(service_types)
      }
    }

    {:ok, graph}
  end

  defp determine_complexity(service_types) when length(service_types) <= 1, do: :simple
  defp determine_complexity(service_types) when length(service_types) <= 3, do: :moderate
  defp determine_complexity(_), do: :complex

  defp extract_confidence_scores(patterns) do
    Enum.into(patterns, %{}, fn {service_type, detection} ->
      {service_type, detection.confidence}
    end)
  end

  defp extract_file_indicators(files) do
    Enum.map(files, fn file ->
      %{
        file_path: file.file_path,
        content_type: file.content_type,
        file_size: file.file_size,
        is_directory: file.is_directory || false
      }
    end)
  end

  defp determine_deployment_strategy(patterns) do
    service_types = Map.keys(patterns)

    cond do
      :compose_stack in service_types -> :compose_stack
      :containerized in service_types -> :kubernetes
      length(service_types) == 1 -> :single_service
      length(service_types) > 1 -> :compose_stack
      true -> :custom
    end
  end
end
