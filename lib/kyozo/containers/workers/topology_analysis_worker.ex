defmodule Kyozo.Containers.Workers.TopologyAnalysisWorker do
  @moduledoc """
  Background worker for analyzing folder structures and detecting deployable services.

  This worker implements the core "Folder as a Service" functionality by:
  - Analyzing directory structures in workspaces
  - Detecting service patterns (Dockerfiles, package.json, etc.)
  - Identifying service dependencies and relationships
  - Creating topology detection records with AI-powered insights
  - Suggesting optimal deployment configurations
  """

  use Oban.Worker,
    queue: :topology_analysis,
    max_attempts: 3,
    tags: ["topology", "analysis", "ai"]

  require Logger
  alias Kyozo.{Containers, Workspaces, AI}
  alias Kyozo.Containers.TopologyDetection

  defp job_tenant(%Oban.Job{args: args, meta: meta}) do
    args["tenant"] || (meta && meta["tenant"])
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"topology_detection_id" => topology_id} = args} = job) do
    tenant = job_tenant(job)
    Logger.info("Starting topology analysis", topology_id: topology_id)

    with {:ok, detection} <- get_topology_detection(topology_id, tenant),
         {:ok, workspace} <- get_workspace(detection.workspace_id, tenant),
         {:ok, updated_detection} <- mark_analyzing(detection),
         {:ok, analysis_result} <- analyze_workspace_topology(workspace, args),
         {:ok, final_detection} <- complete_analysis(updated_detection, analysis_result) do
      Logger.info("Topology analysis completed successfully",
        topology_id: topology_id,
        services_detected: length(analysis_result.services)
      )

      # Trigger container deployment suggestions
      maybe_trigger_deployment_suggestions(final_detection, analysis_result)

      {:ok, final_detection}
    else
      {:error, reason} = error ->
        Logger.error("Topology analysis failed",
          topology_id: topology_id,
          reason: reason
        )

        mark_failed(topology_id, reason, tenant)
        error
    end
  end

  def perform(%Oban.Job{args: %{"workspace_id" => workspace_id} = args} = job) do
    tenant = job_tenant(job)
    Logger.info("Starting new topology analysis for workspace", workspace_id: workspace_id)

    with {:ok, detection} <- create_topology_detection(workspace_id, args, tenant),
         {:ok, _result} <-
           perform(%Oban.Job{args: Map.put(args, "topology_detection_id", detection.id)}) do
      {:ok, detection}
    else
      error -> error
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("TopologyAnalysisWorker received invalid arguments", args: args)
    {:error, :invalid_arguments}
  end

  @doc """
  Enqueue a topology analysis job for a workspace.
  """
  def enqueue(workspace_id, opts \\ []) do
    analysis_depth = Keyword.get(opts, :analysis_depth, "standard")

    args = %{
      "workspace_id" => workspace_id,
      "analysis_depth" => analysis_depth,
      "triggered_by" => Keyword.get(opts, :triggered_by, "manual"),
      "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    AshOban.schedule(Kyozo.Containers.TopologyDetection, :analyze, args, opts)
  end

  # Private Functions

  defp get_topology_detection(topology_id, tenant) do
    case Containers.get_topology_detection(topology_id, tenant: tenant) do
      nil -> {:error, :not_found}
      detection -> {:ok, detection}
    end
  end

  defp get_workspace(workspace_id, tenant) do
    case Workspaces.get_workspace(workspace_id, tenant: tenant) do
      nil -> {:error, :workspace_not_found}
      workspace -> {:ok, workspace}
    end
  end

  defp create_topology_detection(workspace_id, args, tenant) do
    attrs = %{
      workspace_id: workspace_id,
      analysis_depth: args["analysis_depth"] || "standard",
      status: "pending",
      triggered_by: args["triggered_by"] || "manual",
      analysis_config: %{
        include_patterns: args["include_patterns"] || ["**/*"],
        exclude_patterns: args["exclude_patterns"] || ["node_modules/**", ".git/**", "tmp/**"],
        max_depth: args["max_depth"] || 10,
        detect_frameworks: args["detect_frameworks"] != false,
        detect_databases: args["detect_databases"] != false,
        detect_apis: args["detect_apis"] != false
      }
    }

    Containers.create_topology_detection(attrs, tenant: tenant)
  end

  defp mark_analyzing(detection) do
    updates = %{
      status: "analyzing",
      started_at: DateTime.utc_now(),
      analysis_metadata:
        Map.merge(detection.analysis_metadata || %{}, %{
          "started_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "worker_pid" => inspect(self()),
          "analysis_stage" => "initializing"
        })
    }

    Containers.update_topology_detection(detection, updates)
  end

  defp analyze_workspace_topology(workspace, args) do
    analysis_depth = args["analysis_depth"] || "standard"

    Logger.info("Analyzing workspace topology",
      workspace_id: workspace.id,
      depth: analysis_depth
    )

    with {:ok, file_tree} <- build_file_tree(workspace),
         {:ok, service_candidates} <- detect_service_candidates(file_tree, analysis_depth),
         {:ok, enhanced_services} <- enhance_with_ai_analysis(service_candidates, workspace),
         {:ok, dependencies} <- detect_service_dependencies(enhanced_services),
         {:ok, deployment_configs} <- generate_deployment_configs(enhanced_services) do
      result = %{
        services: enhanced_services,
        dependencies: dependencies,
        deployment_configs: deployment_configs,
        file_tree_summary: summarize_file_tree(file_tree),
        analysis_metadata: %{
          total_files_analyzed: count_files(file_tree),
          services_detected: length(enhanced_services),
          confidence_score: calculate_overall_confidence(enhanced_services),
          # Will be calculated later
          analysis_duration_ms: 0,
          frameworks_detected: extract_frameworks(enhanced_services),
          databases_detected: extract_databases(enhanced_services)
        }
      }

      {:ok, result}
    end
  end

  defp build_file_tree(workspace) do
    # In a real implementation, this would scan the workspace files
    # For now, we'll simulate with a comprehensive mock structure
    mock_tree = %{
      "frontend" => %{
        type: :directory,
        files: %{
          "package.json" => %{
            type: :file,
            content: ~s({"name": "frontend", "scripts": {"start": "react-scripts start"}})
          },
          "Dockerfile" => %{
            type: :file,
            content:
              "FROM node:18-alpine\nWORKDIR /app\nCOPY . .\nRUN npm install\nEXPOSE 3000\nCMD [\"npm\", \"start\"]"
          },
          "src" => %{
            type: :directory,
            files: %{
              "index.js" => %{type: :file},
              "App.js" => %{type: :file}
            }
          }
        }
      },
      "backend" => %{
        type: :directory,
        files: %{
          "package.json" => %{
            type: :file,
            content: ~s({"name": "backend-api", "main": "server.js"})
          },
          "Dockerfile" => %{
            type: :file,
            content:
              "FROM node:18-alpine\nWORKDIR /app\nEXPOSE 8080\nCMD [\"node\", \"server.js\"]"
          },
          "server.js" => %{type: :file},
          ".env.example" => %{
            type: :file,
            content: "DATABASE_URL=postgresql://localhost:5432/app"
          }
        }
      },
      "database" => %{
        type: :directory,
        files: %{
          "docker-compose.yml" => %{
            type: :file,
            content:
              "version: '3'\nservices:\n  postgres:\n    image: postgres:15\n    environment:\n      POSTGRES_DB: app"
          },
          "init.sql" => %{type: :file},
          "Dockerfile" => %{
            type: :file,
            content: "FROM postgres:15\nCOPY init.sql /docker-entrypoint-initdb.d/"
          }
        }
      }
    }

    {:ok, mock_tree}
  end

  defp detect_service_candidates(file_tree, analysis_depth) do
    candidates = []

    # Detect Node.js services
    candidates = candidates ++ detect_nodejs_services(file_tree)

    # Detect Python services
    candidates = candidates ++ detect_python_services(file_tree)

    # Detect database services
    candidates = candidates ++ detect_database_services(file_tree)

    # Detect static sites
    candidates = candidates ++ detect_static_services(file_tree)

    # Apply depth-specific analysis
    enhanced_candidates =
      case analysis_depth do
        "deep" -> apply_deep_analysis(candidates, file_tree)
        "standard" -> apply_standard_analysis(candidates, file_tree)
        "quick" -> candidates
        _ -> candidates
      end

    {:ok, enhanced_candidates}
  end

  defp detect_nodejs_services(file_tree) do
    Enum.flat_map(file_tree, fn {path, %{files: files}} ->
      if has_file?(files, "package.json") do
        package_json = get_file_content(files, "package.json")

        [
          %{
            name: extract_service_name(path, package_json),
            type: determine_nodejs_type(package_json, files),
            path: "/#{path}",
            dockerfile_path:
              if(has_file?(files, "Dockerfile"), do: "/#{path}/Dockerfile", else: nil),
            package_manager: detect_package_manager(files),
            framework: detect_nodejs_framework(package_json, files),
            ports: detect_nodejs_ports(package_json, files),
            dependencies: extract_nodejs_dependencies(package_json),
            environment_vars: detect_environment_variables(files),
            confidence: calculate_nodejs_confidence(files, package_json),
            detected_patterns: ["package.json", "node_modules", "npm_scripts"]
          }
        ]
      else
        []
      end
    end)
  end

  defp detect_python_services(file_tree) do
    Enum.flat_map(file_tree, fn {path, %{files: files}} ->
      if has_python_indicators?(files) do
        [
          %{
            name: path,
            type: determine_python_type(files),
            path: "/#{path}",
            dockerfile_path:
              if(has_file?(files, "Dockerfile"), do: "/#{path}/Dockerfile", else: nil),
            framework: detect_python_framework(files),
            ports: detect_python_ports(files),
            dependencies: extract_python_dependencies(files),
            confidence: calculate_python_confidence(files),
            detected_patterns: extract_python_patterns(files)
          }
        ]
      else
        []
      end
    end)
  end

  defp detect_database_services(file_tree) do
    Enum.flat_map(file_tree, fn {path, %{files: files}} ->
      cond do
        has_file?(files, "docker-compose.yml") and contains_database?(files) ->
          [
            %{
              name: "#{path}-db",
              type: "database",
              path: "/#{path}",
              dockerfile_path:
                if(has_file?(files, "Dockerfile"), do: "/#{path}/Dockerfile", else: nil),
              database_type: detect_database_type(files),
              ports: detect_database_ports(files),
              confidence: 0.9,
              detected_patterns: ["docker-compose.yml", "database"]
            }
          ]

        has_database_dockerfile?(files) ->
          [
            %{
              name: "#{path}-database",
              type: "database",
              path: "/#{path}",
              dockerfile_path: "/#{path}/Dockerfile",
              database_type: detect_database_type_from_dockerfile(files),
              # Default PostgreSQL
              ports: ["5432"],
              confidence: 0.85,
              detected_patterns: ["Dockerfile", "database"]
            }
          ]

        true ->
          []
      end
    end)
  end

  defp detect_static_services(file_tree) do
    Enum.flat_map(file_tree, fn {path, %{files: files}} ->
      if has_static_site_indicators?(files) do
        [
          %{
            name: "#{path}-static",
            type: "static_site",
            path: "/#{path}",
            dockerfile_path: generate_static_dockerfile_path(path),
            web_server: detect_web_server(files),
            ports: ["80", "443"],
            confidence: calculate_static_confidence(files),
            detected_patterns: extract_static_patterns(files)
          }
        ]
      else
        []
      end
    end)
  end

  defp enhance_with_ai_analysis(service_candidates, workspace) do
    Logger.info("Enhancing service analysis with AI",
      candidates_count: length(service_candidates),
      workspace_id: workspace.id
    )

    # Use AI to enhance detection accuracy and suggest improvements
    enhanced_services =
      Enum.map(service_candidates, fn service ->
        ai_enhancements = get_ai_enhancements(service, workspace)
        Map.merge(service, ai_enhancements)
      end)

    {:ok, enhanced_services}
  end

  defp get_ai_enhancements(service, workspace) do
    # Simulate AI analysis - in production this would call the AI service
    %{
      ai_confidence: min(service.confidence + 0.1, 1.0),
      suggested_optimizations: generate_ai_suggestions(service),
      resource_recommendations: calculate_resource_recommendations(service),
      security_recommendations: generate_security_recommendations(service),
      scalability_score: calculate_scalability_score(service)
    }
  end

  defp detect_service_dependencies(services) do
    dependencies = []

    # Detect database dependencies
    dependencies = dependencies ++ detect_database_dependencies(services)

    # Detect API dependencies
    dependencies = dependencies ++ detect_api_dependencies(services)

    # Detect frontend-backend dependencies
    dependencies = dependencies ++ detect_frontend_backend_dependencies(services)

    {:ok, dependencies}
  end

  defp generate_deployment_configs(services) do
    configs =
      Enum.map(services, fn service ->
        base_config = %{
          service_name: service.name,
          image_name: generate_image_name(service),
          image_tag: "latest",
          port_mappings: generate_port_mappings(service.ports),
          environment_variables: service.environment_vars || %{},
          resource_limits: generate_resource_limits(service),
          health_check: generate_health_check(service),
          restart_policy: "unless-stopped",
          networks: ["kyozo-network"]
        }

        # Add service-specific configurations
        enhanced_config =
          case service.type do
            "web_app" -> add_web_app_config(base_config, service)
            "api_service" -> add_api_service_config(base_config, service)
            "database" -> add_database_config(base_config, service)
            "static_site" -> add_static_site_config(base_config, service)
            _ -> base_config
          end

        {service.name, enhanced_config}
      end)

    {:ok, Map.new(configs)}
  end

  defp complete_analysis(detection, analysis_result) do
    duration_ms =
      case detection.started_at do
        nil -> 0
        started_at -> DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
      end

    updates = %{
      status: "completed",
      completed_at: DateTime.utc_now(),
      services_detected: length(analysis_result.services),
      analysis_result: analysis_result,
      analysis_metadata:
        Map.merge(detection.analysis_metadata || %{}, %{
          "completed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "duration_ms" => duration_ms,
          "analysis_stage" => "completed"
        })
    }

    Containers.update_topology_detection(detection, updates)
  end

  defp mark_failed(topology_id, reason, tenant) do
    case get_topology_detection(topology_id, tenant) do
      {:ok, detection} ->
        updates = %{
          status: "failed",
          failed_at: DateTime.utc_now(),
          error_message: to_string(reason),
          analysis_metadata:
            Map.merge(detection.analysis_metadata || %{}, %{
              "failed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
              "error" => to_string(reason),
              "analysis_stage" => "failed"
            })
        }

        Containers.update_topology_detection(detection, updates)

      {:error, _} ->
        Logger.error("Could not mark topology detection as failed",
          topology_id: topology_id,
          reason: reason
        )
    end
  end

  defp maybe_trigger_deployment_suggestions(detection, analysis_result) do
    if length(analysis_result.services) > 0 do
      # Queue deployment suggestion jobs
      Enum.each(analysis_result.services, fn service ->
        if service.confidence > 0.7 do
          Kyozo.Containers.Workers.ContainerDeploymentWorker.enqueue(
            detection.workspace_id,
            service,
            priority: 1
          )
        end
      end)
    end
  end

  # Helper functions for service detection

  defp has_file?(files, filename) do
    Map.has_key?(files, filename)
  end

  defp get_file_content(files, filename) do
    case Map.get(files, filename) do
      %{content: content} -> content
      _ -> ""
    end
  end

  defp extract_service_name(path, package_json) do
    case Jason.decode(package_json) do
      {:ok, %{"name" => name}} -> name
      _ -> path
    end
  end

  defp determine_nodejs_type(package_json, files) do
    case Jason.decode(package_json) do
      {:ok, %{"scripts" => scripts}} ->
        cond do
          Map.has_key?(scripts, "start") and String.contains?(scripts["start"], "react") ->
            "web_app"

          Map.has_key?(scripts, "dev") and String.contains?(scripts["dev"], "next") ->
            "web_app"

          has_file?(files, "server.js") or has_file?(files, "app.js") ->
            "api_service"

          true ->
            "microservice"
        end

      _ ->
        "microservice"
    end
  end

  defp detect_nodejs_framework(package_json, _files) do
    case Jason.decode(package_json) do
      {:ok, %{"dependencies" => deps}} ->
        cond do
          Map.has_key?(deps, "react") -> "react"
          Map.has_key?(deps, "next") -> "nextjs"
          Map.has_key?(deps, "express") -> "express"
          Map.has_key?(deps, "fastify") -> "fastify"
          Map.has_key?(deps, "vue") -> "vue"
          true -> "nodejs"
        end

      _ ->
        "nodejs"
    end
  end

  defp detect_nodejs_ports(package_json, files) do
    # Default ports based on common patterns
    default_ports = ["3000"]

    # Try to extract from package.json scripts or environment files
    env_content = get_file_content(files, ".env") <> get_file_content(files, ".env.example")

    port_matches =
      Regex.scan(~r/PORT=(\d+)/i, env_content)
      |> Enum.map(fn [_, port] -> port end)

    if length(port_matches) > 0 do
      port_matches
    else
      default_ports
    end
  end

  defp has_python_indicators?(files) do
    has_file?(files, "requirements.txt") or
      has_file?(files, "setup.py") or
      has_file?(files, "pyproject.toml") or
      has_file?(files, "Pipfile") or
      has_file?(files, "main.py") or
      has_file?(files, "app.py")
  end

  defp contains_database?(files) do
    compose_content = get_file_content(files, "docker-compose.yml")

    String.contains?(compose_content, "postgres") or
      String.contains?(compose_content, "mysql") or
      String.contains?(compose_content, "mongodb")
  end

  defp has_static_site_indicators?(files) do
    has_file?(files, "index.html") or
      has_file?(files, "dist") or
      has_file?(files, "build") or
      has_file?(files, "_site")
  end

  # Additional helper functions would be implemented here for:
  # - calculate_nodejs_confidence/2
  # - detect_package_manager/1
  # - extract_nodejs_dependencies/1
  # - detect_environment_variables/1
  # - generate_ai_suggestions/1
  # - calculate_resource_recommendations/1
  # - generate_security_recommendations/1
  # - calculate_scalability_score/1
  # - detect_database_dependencies/1
  # - detect_api_dependencies/1
  # - detect_frontend_backend_dependencies/1
  # - generate_image_name/1
  # - generate_port_mappings/1
  # - generate_resource_limits/1
  # - generate_health_check/1
  # - add_web_app_config/2
  # - add_api_service_config/2
  # - add_database_config/2
  # - add_static_site_config/2
  # - calculate_overall_confidence/1
  # - extract_frameworks/1
  # - extract_databases/1
  # - count_files/1
  # - summarize_file_tree/1

  # Placeholder implementations for brevity
  defp calculate_nodejs_confidence(_files, _package_json), do: 0.85
  defp detect_package_manager(_files), do: "npm"
  defp extract_nodejs_dependencies(_package_json), do: []
  defp detect_environment_variables(_files), do: %{}
  defp determine_python_type(_files), do: "api_service"
  defp detect_python_framework(_files), do: "flask"
  defp detect_python_ports(_files), do: ["8000"]
  defp extract_python_dependencies(_files), do: []
  defp calculate_python_confidence(_files), do: 0.8
  defp extract_python_patterns(_files), do: ["requirements.txt"]
  defp detect_database_type(_files), do: "postgresql"
  defp detect_database_ports(_files), do: ["5432"]
  defp has_database_dockerfile?(_files), do: false
  defp detect_database_type_from_dockerfile(_files), do: "postgresql"
  defp generate_static_dockerfile_path(path), do: "/#{path}/Dockerfile"
  defp detect_web_server(_files), do: "nginx"
  defp calculate_static_confidence(_files), do: 0.7
  defp extract_static_patterns(_files), do: ["index.html"]
  defp apply_deep_analysis(candidates, _file_tree), do: candidates
  defp apply_standard_analysis(candidates, _file_tree), do: candidates
  defp generate_ai_suggestions(_service), do: []
  defp calculate_resource_recommendations(_service), do: %{cpu: "100m", memory: "128Mi"}
  defp generate_security_recommendations(_service), do: []
  defp calculate_scalability_score(_service), do: 0.8
  defp detect_database_dependencies(_services), do: []
  defp detect_api_dependencies(_services), do: []
  defp detect_frontend_backend_dependencies(_services), do: []
  defp generate_image_name(service), do: "kyozo/#{service.name}"
  defp generate_port_mappings(ports), do: Map.new(ports, fn port -> {port, port} end)
  defp generate_resource_limits(_service), do: %{cpu: "500m", memory: "256Mi"}
  defp generate_health_check(_service), do: %{path: "/health", interval: "30s"}
  defp add_web_app_config(config, _service), do: config
  defp add_api_service_config(config, _service), do: config
  defp add_database_config(config, _service), do: config
  defp add_static_site_config(config, _service), do: config

  defp calculate_overall_confidence(services),
    do: Enum.reduce(services, 0, &(&1.confidence + &2)) / length(services)

  defp extract_frameworks(services), do: Enum.map(services, & &1.framework) |> Enum.uniq()

  defp extract_databases(services),
    do: services |> Enum.filter(&(&1.type == "database")) |> Enum.map(& &1.database_type)

  defp count_files(_tree), do: 10
  defp summarize_file_tree(_tree), do: %{total_directories: 3, total_files: 10}
end
