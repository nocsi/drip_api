defmodule Kyozo.Workspaces.TopologyDetection do
  @derive {Jason.Encoder,
           only: [
             :id,
             :folder_path,
             :detection_timestamp,
             :detected_patterns,
             :service_graph,
             :recommended_services,
             :deployment_strategy,
             :total_services_detected,
             :status,
             :created_at,
             :updated_at
           ]}

  @moduledoc """
  TopologyDetection resource representing analysis results of workspace folder structures
  to automatically detect and recommend containerizable services.

  This resource stores the results of analyzing a workspace folder structure to identify
  potential services, their dependencies, and deployment configurations.
  """

  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    type "topology-detection"

    # JSON-LD context metadata temporarily disabled during GraphQL cleanup
    # TODO: Re-enable JSON-LD metadata when AshJsonApi meta function is available
  end

  postgres do
    table "topology_detections"
    repo Kyozo.Repo

    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :triggered_by, on_delete: :nilify, index?: true
    end

    custom_indexes do
      index [:workspace_id, :created_at]
      index [:workspace_id, :status]
      index [:team_id, :created_at]
      index [:status, :created_at]
    end
  end

  actions do
    default_accept [:folder_path]
    defaults [:create, :read, :destroy]

    read :list_topology_detections do
      prepare build(
                load: [:workspace, :team, :service_instances],
                sort: [created_at: :desc]
              )
    end

    read :list_by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false

      prepare build(
                filter: [workspace_id: arg(:workspace_id)],
                load: [:workspace, :service_instances],
                sort: [created_at: :desc]
              )
    end

    read :latest_by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false

      prepare build(
                filter: [workspace_id: arg(:workspace_id)],
                load: [:workspace, :service_instances],
                sort: [created_at: :desc],
                limit: 1
              )
    end

    create :create_topology_detection do
      accept [:folder_path, :workspace_id, :triggered_by_id]

      change set_attribute(:status, :analyzing)
      change set_attribute(:detection_timestamp, expr(now()))
    end

    create :analyze_workspace do
      accept [:folder_path]
      argument :workspace_id, :uuid, allow_nil?: false
      argument :folder_path, :string, default: "/"
      argument :max_depth, :integer, default: 5
      argument :auto_create_services, :boolean, default: false
      argument :detection_mode, :string, default: "comprehensive"

      change set_attribute(:workspace_id, arg(:workspace_id))
      change set_attribute(:status, :analyzing)
      change set_attribute(:detection_timestamp, expr(now()))
    end

    update :complete_analysis do
      accept [:detected_patterns, :service_graph, :recommended_services, :deployment_strategy]
      argument :detected_patterns, :map, allow_nil?: false
      argument :service_graph, :map, allow_nil?: false
      argument :recommended_services, {:array, :map}, default: []
      argument :deployment_strategy, :string, default: "compose_stack"

      change set_attribute(:status, :completed)
    end

    update :retry_analysis do
      accept []
      change set_attribute(:status, :analyzing)
    end

    destroy :destroy_topology_detection do
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type(:create) do
      authorize_if actor_present()
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])

      authorize_if expr(
                     exists(
                       workspace.team.users,
                       id == ^actor(:id) and team_members.role in ["admin", "owner"]
                     )
                   )
    end

    policy action([:analyze_workspace, :complete_analysis, :retry_analysis]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])

      authorize_if expr(
                     exists(
                       workspace.team.users,
                       id == ^actor(:id) and team_members.role in ["admin", "owner", "developer"]
                     )
                   )
    end
  end

  pub_sub do
    module KyozoWeb.Endpoint

    publish_all :create, ["topology_detections", :workspace_id]
    publish_all :update, ["topology_detections", :workspace_id]
    publish_all :destroy, ["topology_detections", :workspace_id]
  end

  preparations do
    prepare build(load: [:workspace, :team])
  end



  validations do
    validate present([:folder_path, :workspace_id, :team_id, :detection_timestamp])
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :folder_path, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 500
      default "/"
    end

    attribute :detection_timestamp, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:analyzing, :completed, :failed, :cancelled]
      default :analyzing
    end

    attribute :detected_patterns, :map do
      public? true
      default %{}

      # Structure: %{"nodejs" => %{"confidence" => 0.95, "matched_files" => [...], "detected_at" => timestamp}}
    end

    attribute :service_graph, :map do
      public? true
      default %{"nodes" => [], "edges" => []}
      # Structure: %{"nodes" => [...], "edges" => [...]}
    end

    attribute :recommended_services, {:array, :map} do
      public? true
      default []
      # Array of service recommendation maps
    end

    attribute :deployment_strategy, :atom do
      public? true
      constraints one_of: [:docker_compose, :kubernetes, :compose_stack, :single_container]
      default :compose_stack
    end

    attribute :total_services_detected, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :analysis_metadata, :map do
      public? true
      default %{}
      # Additional analysis data, performance metrics, etc.
    end

    attribute :error_details, :map do
      public? true
      default %{}
      # Error information if analysis failed
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :triggered_by, Kyozo.Accounts.User do
      allow_nil? true
      attribute_writable? true
    end

    has_many :service_instances, Kyozo.Workspaces.ServiceInstance do
      destination_attribute :topology_detection_id
    end
  end

  calculations do
    calculate :analysis_duration_seconds, :integer do
      load [:created_at, :updated_at]

      calculation fn detections, _context ->
        Enum.map(detections, fn detection ->
          if detection.status == :completed do
            DateTime.diff(detection.updated_at, detection.created_at)
          else
            nil
          end
        end)
      end
    end

    calculate :confidence_score, :decimal do
      load [:detected_patterns]

      calculation fn detections, _context ->
        Enum.map(detections, fn detection ->
          if map_size(detection.detected_patterns) > 0 do
            confidences =
              detection.detected_patterns
              |> Map.values()
              |> Enum.map(fn pattern -> Map.get(pattern, "confidence", 0.0) end)

            average_confidence = Enum.sum(confidences) / length(confidences)
            Decimal.from_float(average_confidence)
          else
            Decimal.new("0.0")
          end
        end)
      end
    end

    calculate :detected_service_types, {:array, :string} do
      load [:detected_patterns]

      calculation fn detections, _context ->
        Enum.map(detections, fn detection ->
          Map.keys(detection.detected_patterns)
        end)
      end
    end

    calculate :has_recommendations, :boolean do
      load [:recommended_services]

      calculation fn detections, _context ->
        Enum.map(detections, fn detection ->
          length(detection.recommended_services) > 0
        end)
      end
    end

    calculate :is_recent, :boolean do
      calculation fn detections, _context ->
        one_hour_ago = DateTime.add(DateTime.utc_now(), -3600)

        Enum.map(detections, fn detection ->
          DateTime.compare(detection.created_at, one_hour_ago) == :gt
        end)
      end
    end
  end

  # Resource-specific functions

  @doc """
  Determines if the detection analysis is complete.
  """
  def completed?(%{status: :completed}), do: true
  def completed?(_), do: false

  @doc """
  Determines if the detection analysis is still in progress.
  """
  def analyzing?(%{status: :analyzing}), do: true
  def analyzing?(_), do: false

  @doc """
  Determines if the detection analysis failed.
  """
  def failed?(%{status: :failed}), do: true
  def failed?(_), do: false

  @doc """
  Gets the primary detected service type with highest confidence.
  """
  def primary_service_type(%{detected_patterns: patterns}) when map_size(patterns) > 0 do
    patterns
    |> Enum.max_by(fn {_type, pattern} -> Map.get(pattern, "confidence", 0.0) end)
    |> elem(0)
  end

  def primary_service_type(_), do: nil

  @doc """
  Gets the total confidence score across all detected patterns.
  """
  def total_confidence(%{detected_patterns: patterns}) when map_size(patterns) > 0 do
    confidences =
      patterns
      |> Map.values()
      |> Enum.map(fn pattern -> Map.get(pattern, "confidence", 0.0) end)

    Enum.sum(confidences) / length(confidences)
  end

  def total_confidence(_), do: 0.0

  @doc """
  Gets service recommendations filtered by confidence threshold.
  """
  def high_confidence_recommendations(%{recommended_services: services}, min_confidence \\ 0.8) do
    services
    |> Enum.filter(fn service ->
      Map.get(service, "confidence", 0.0) >= min_confidence
    end)
    |> Enum.sort_by(fn service ->
      -Map.get(service, "confidence", 0.0)
    end)
  end

  @doc """
  Builds a service dependency graph from the detected patterns.
  """
  def build_dependency_graph(%{service_graph: %{"nodes" => nodes, "edges" => edges}}) do
    %{
      services: nodes,
      dependencies: edges,
      has_database:
        Enum.any?(nodes, fn node ->
          node["type"] in ["postgres", "mysql", "mongodb", "redis"]
        end),
      has_web_service:
        Enum.any?(nodes, fn node ->
          node["type"] in ["nodejs", "python", "ruby", "java", "php"]
        end),
      complexity_score: calculate_complexity_score(nodes, edges)
    }
  end

  def build_dependency_graph(_),
    do: %{
      services: [],
      dependencies: [],
      has_database: false,
      has_web_service: false,
      complexity_score: 0
    }

  @doc """
  Gets deployment recommendations based on detected patterns.
  """
  def deployment_recommendations(%{deployment_strategy: strategy, total_services_detected: count}) do
    base_recommendations = %{
      strategy: strategy,
      estimated_resources: estimate_resources(count),
      deployment_complexity: calculate_deployment_complexity(strategy, count)
    }

    case {strategy, count} do
      {"single_container", 1} ->
        Map.put(base_recommendations, :recommendations, [
          "Single container deployment suitable for simple applications",
          "Consider adding health checks and resource limits",
          "Monitor memory and CPU usage after deployment"
        ])

      {"docker_compose", n} when n <= 5 ->
        Map.put(base_recommendations, :recommendations, [
          "Docker Compose suitable for #{n} services",
          "Consider using volumes for persistent data",
          "Set up proper networking between services",
          "Configure environment-specific variables"
        ])

      {"kubernetes", n} when n > 5 ->
        Map.put(base_recommendations, :recommendations, [
          "Kubernetes recommended for #{n} services",
          "Consider implementing service mesh",
          "Set up proper ingress and load balancing",
          "Implement comprehensive monitoring and logging"
        ])

      _ ->
        Map.put(base_recommendations, :recommendations, [
          "Review deployment strategy based on detected services",
          "Consider scaling requirements and infrastructure constraints"
        ])
    end
  end

  # Private helper functions

  defp calculate_complexity_score(nodes, edges) do
    node_count = length(nodes)
    edge_count = length(edges)

    # Simple complexity scoring: nodes + (edges * 2)
    # More edges indicate more complex service interactions
    node_count + edge_count * 2
  end

  defp estimate_resources(service_count) do
    # 512MB per service
    base_memory = service_count * 512
    # 0.5 CPU per service
    base_cpu = service_count * 0.5

    %{
      estimated_memory_mb: base_memory,
      estimated_cpu_cores: base_cpu,
      # 2GB per service
      estimated_storage_gb: service_count * 2
    }
  end

  defp calculate_deployment_complexity(strategy, service_count) do
    base_score =
      case strategy do
        "single_container" -> 1
        "docker_compose" -> 2
        "compose_stack" -> 3
        "kubernetes" -> 4
        _ -> 2
      end

    # Adjust based on service count
    complexity_multiplier =
      case service_count do
        n when n <= 2 -> 1.0
        n when n <= 5 -> 1.5
        n when n <= 10 -> 2.0
        _ -> 3.0
      end

    round(base_score * complexity_multiplier)
  end
end
