defmodule Kyozo.Workspaces.ServiceDependency do
  @derive {Jason.Encoder,
           only: [
             :id,
             :dependency_type,
             :connection_string,
             :environment_variable,
             :startup_order,
             :is_required,
             :health_check_path,
             :timeout_seconds,
             :retry_count,
             :created_at,
             :updated_at
           ]}

  @moduledoc """
  ServiceDependency resource representing dependencies between services within a workspace.

  This resource models the relationships between services, including database connections,
  API dependencies, and startup ordering requirements for proper service orchestration.
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
    type "service-dependency"

    routes do
      base "/service-dependencies"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end

    # JSON-LD context metadata temporarily disabled during GraphQL cleanup
    # TODO: Re-enable JSON-LD metadata when AshJsonApi meta function is available
  end

  postgres do
    table "service_dependencies"
    repo Kyozo.Repo

    references do
      reference :dependent_service, on_delete: :delete, index?: true
      reference :required_service, on_delete: :delete, index?: true
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:dependent_service_id, :required_service_id], unique: true
      index [:workspace_id, :dependency_type]
      index [:team_id, :dependency_type]
      index [:startup_order, :workspace_id]
      index [:is_required, :workspace_id]
    end
  end

  actions do
    default_accept [
      :dependency_type,
      :connection_string,
      :environment_variable,
      :startup_order,
      :is_required,
      :health_check_path,
      :timeout_seconds,
      :retry_count
    ]

    defaults [:create, :read, :update, :destroy]

    read :list_service_dependencies do
      prepare build(
                load: [:dependent_service, :required_service, :workspace, :team],
                sort: [startup_order: :asc, created_at: :desc]
              )
    end

    read :list_by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false

      prepare build(
                filter: [workspace_id: arg(:workspace_id)],
                load: [:dependent_service, :required_service],
                sort: [startup_order: :asc]
              )
    end

    read :list_by_dependent_service do
      argument :dependent_service_id, :uuid, allow_nil?: false

      prepare build(
                filter: [dependent_service_id: arg(:dependent_service_id)],
                load: [:required_service, :workspace],
                sort: [startup_order: :asc]
              )
    end

    read :list_by_required_service do
      argument :required_service_id, :uuid, allow_nil?: false

      prepare build(
                filter: [required_service_id: arg(:required_service_id)],
                load: [:dependent_service, :workspace],
                sort: [startup_order: :asc]
              )
    end

    read :get_dependency_graph do
      argument :workspace_id, :uuid, allow_nil?: false

      prepare build(
                filter: [workspace_id: arg(:workspace_id)],
                load: [:dependent_service, :required_service]
              )
    end

    read :required_dependencies do
      argument :dependent_service_id, :uuid, allow_nil?: false

      prepare build(
                filter: [dependent_service_id: arg(:dependent_service_id), is_required: true],
                load: [:required_service],
                sort: [startup_order: :asc]
              )
    end

    create :create_service_dependency do
      accept [
        :dependency_type,
        :connection_string,
        :environment_variable,
        :startup_order,
        :is_required,
        :health_check_path,
        :timeout_seconds,
        :retry_count,
        :dependent_service_id,
        :required_service_id
      ]


    end

    update :update_service_dependency do
      accept [
        :dependency_type,
        :connection_string,
        :environment_variable,
        :startup_order,
        :is_required,
        :health_check_path,
        :timeout_seconds,
        :retry_count
      ]


    end

    action :validate_dependency_graph, :map do
      argument :workspace_id, :uuid, allow_nil?: false

      run {Kyozo.Workspaces.ServiceDependency.Actions.ValidateDependencyGraph, []}
    end

    action :get_startup_order, {:array, :uuid} do
      argument :workspace_id, :uuid, allow_nil?: false

      run {Kyozo.Workspaces.ServiceDependency.Actions.GetStartupOrder, []}
    end

    action :check_service_readiness, :boolean do
      argument :service_instance_id, :uuid, allow_nil?: false

      run {Kyozo.Workspaces.ServiceDependency.Actions.CheckServiceReadiness, []}
    end

    destroy :destroy_service_dependency do
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

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])

      authorize_if expr(
                     exists(
                       workspace.team.users,
                       id == ^actor(:id) and team_members.role in ["admin", "owner", "developer"]
                     )
                   )
    end

    policy action([:validate_dependency_graph, :get_startup_order, :check_service_readiness]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end
  end

  pub_sub do
    module KyozoWeb.Endpoint

    publish_all :create, ["service_dependencies", :workspace_id]
    publish_all :update, ["service_dependencies", :workspace_id]
    publish_all :destroy, ["service_dependencies", :workspace_id]
  end

  preparations do
    prepare build(load: [:dependent_service, :required_service, :workspace, :team])
  end

  changes do
  end

  validations do
    validate present([
               :dependency_type,
               :dependent_service_id,
               :required_service_id,
               :workspace_id,
               :team_id
             ])


  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :dependency_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    # Service requires another service to function
                    :requires,

                    # Service connects to another service (database, API)
                    :connects_to,

                    # Service depends on another for data
                    :depends_on,

                    # Service waits for another to start
                    :waits_for,

                    # Service communicates with another
                    :communicates_with
                  ]
    end

    attribute :connection_string, :string do
      public? true
      sensitive? true
      constraints max_length: 500
      # Template string like "postgres://{{required_service}}:5432/{{database_name}}"
    end

    attribute :environment_variable, :string do
      public? true
      constraints max_length: 100
      # Environment variable name to inject the connection string
    end

    attribute :startup_order, :integer do
      public? true
      constraints min: 0, max: 100
      default 0
      # Lower numbers start first, services with same order can start in parallel
    end

    attribute :is_required, :boolean do
      allow_nil? false
      public? true
      default true
      # Whether this dependency is required for the dependent service to function
    end

    attribute :health_check_path, :string do
      public? true
      constraints max_length: 200
      # Optional health check endpoint to verify dependency is ready
    end

    attribute :timeout_seconds, :integer do
      public? true
      constraints min: 1, max: 300
      default 30
      # Timeout for waiting for dependency to become ready
    end

    attribute :retry_count, :integer do
      public? true
      constraints min: 0, max: 10
      default 3
      # Number of retries when checking dependency readiness
    end

    attribute :dependency_metadata, :map do
      public? true
      default %{}
      # Additional dependency-specific configuration
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :dependent_service, Kyozo.Workspaces.ServiceInstance do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :required_service, Kyozo.Workspaces.ServiceInstance do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end
  end

  calculations do
    calculate :dependency_description, :string do
      load [:dependent_service, :required_service, :dependency_type]

      calculation fn dependencies, _context ->
        Enum.map(dependencies, fn dependency ->
          "#{dependency.dependent_service.name} #{dependency.dependency_type} #{dependency.required_service.name}"
        end)
      end
    end

    calculate :connection_template, :string do
      load [:connection_string, :required_service]

      calculation fn dependencies, _context ->
        Enum.map(dependencies, fn dependency ->
          if dependency.connection_string do
            dependency.connection_string
            |> String.replace("{{required_service}}", dependency.required_service.name)
            |> String.replace("{{required_service_id}}", dependency.required_service.id)
          else
            nil
          end
        end)
      end
    end

    calculate :is_database_dependency, :boolean do
      load [:required_service]

      calculation fn dependencies, _context ->
        Enum.map(dependencies, fn dependency ->
          dependency.required_service.service_type in ["postgres", "mysql", "mongodb", "redis"]
        end)
      end
    end

    calculate :is_api_dependency, :boolean do
      load [:required_service]

      calculation fn dependencies, _context ->
        Enum.map(dependencies, fn dependency ->
          dependency.required_service.service_type in ["nodejs", "python", "ruby", "java", "php"]
        end)
      end
    end

    calculate :readiness_check_url, :string do
      load [:required_service, :health_check_path]

      calculation fn dependencies, _context ->
        Enum.map(dependencies, fn dependency ->
          if dependency.health_check_path && dependency.required_service.deployment_url do
            "#{dependency.required_service.deployment_url}#{dependency.health_check_path}"
          else
            nil
          end
        end)
      end
    end
  end

  # Resource-specific functions

  @doc """
  Determines if this dependency is critical for service startup.
  """
  def critical?(%{is_required: true, dependency_type: type})
      when type in ["requires", "depends_on"] do
    true
  end

  def critical?(_), do: false

  @doc """
  Determines if this dependency involves a database service.
  """
  def database_dependency?(%{required_service: %{service_type: type}}) do
    type in ["postgres", "mysql", "mongodb", "redis"]
  end

  def database_dependency?(_), do: false

  @doc """
  Determines if this dependency involves an API service.
  """
  def api_dependency?(%{required_service: %{service_type: type}}) do
    type in ["nodejs", "python", "ruby", "java", "php", "golang", "rust", "dotnet"]
  end

  def api_dependency?(_), do: false

  @doc """
  Builds a connection string with proper variable substitution.
  """
  def build_connection_string(%{connection_string: nil}), do: nil

  def build_connection_string(%{connection_string: template, required_service: required_service}) do
    template
    |> String.replace("{{required_service}}", required_service.name)
    |> String.replace("{{required_service_id}}", required_service.id)
    |> String.replace("{{required_service_port}}", get_primary_port(required_service))
  end

  def build_connection_string(_), do: nil

  @doc """
  Gets the environment variable configuration for this dependency.
  """
  def environment_config(%{environment_variable: nil}), do: nil

  def environment_config(%{environment_variable: var_name} = dependency) do
    connection_string = build_connection_string(dependency)

    if connection_string do
      {var_name, connection_string}
    else
      nil
    end
  end

  @doc """
  Validates that adding this dependency won't create a circular dependency.
  """
  def validate_no_cycles(dependent_service_id, required_service_id, existing_dependencies \\ []) do
    # Build dependency graph
    graph = build_dependency_graph(existing_dependencies)

    # Check if adding this edge would create a cycle
    not creates_cycle?(graph, required_service_id, dependent_service_id)
  end

  @doc """
  Builds a startup order for services based on their dependencies.
  """
  def calculate_startup_order(dependencies) do
    # Group services by their startup_order value
    dependencies
    |> Enum.group_by(& &1.startup_order)
    |> Enum.sort_by(fn {order, _} -> order end)
    |> Enum.flat_map(fn {_order, deps} ->
      # Within the same startup order, sort by dependency requirements
      deps
      |> Enum.sort_by(&dependency_priority/1)
      |> Enum.map(& &1.dependent_service_id)
    end)
    |> Enum.uniq()
  end

  @doc """
  Gets services that have no dependencies (can start first).
  """
  def root_services(dependencies) do
    dependent_ids = MapSet.new(dependencies, & &1.dependent_service_id)
    required_ids = MapSet.new(dependencies, & &1.required_service_id)

    # Services that are required but don't depend on anything
    MapSet.difference(required_ids, dependent_ids)
    |> MapSet.to_list()
  end

  @doc """
  Gets services that nothing depends on (can be stopped last).
  """
  def leaf_services(dependencies) do
    dependent_ids = MapSet.new(dependencies, & &1.dependent_service_id)
    required_ids = MapSet.new(dependencies, & &1.required_service_id)

    # Services that depend on things but nothing depends on them
    MapSet.difference(dependent_ids, required_ids)
    |> MapSet.to_list()
  end

  @doc """
  Builds a dependency graph representation for analysis.
  """
  def build_dependency_graph(dependencies) do
    dependencies
    |> Enum.reduce(%{}, fn dep, graph ->
      dependent = dep.dependent_service_id
      required = dep.required_service_id

      Map.update(graph, dependent, [required], fn existing ->
        [required | existing] |> Enum.uniq()
      end)
    end)
  end

  @doc """
  Analyzes dependency complexity and provides recommendations.
  """
  def analyze_dependencies(dependencies) do
    graph = build_dependency_graph(dependencies)
    total_services = get_all_services(dependencies) |> length()
    total_dependencies = length(dependencies)

    %{
      total_services: total_services,
      total_dependencies: total_dependencies,
      complexity_score: calculate_complexity_score(graph),
      root_services: root_services(dependencies),
      leaf_services: leaf_services(dependencies),
      critical_dependencies: Enum.filter(dependencies, &critical?/1),
      database_dependencies: Enum.filter(dependencies, &database_dependency?/1),
      api_dependencies: Enum.filter(dependencies, &api_dependency?/1),
      startup_order: calculate_startup_order(dependencies),
      recommendations: generate_recommendations(dependencies, graph)
    }
  end

  # Private helper functions

  defp get_primary_port(%{port_mappings: port_mappings}) when is_map(port_mappings) do
    port_mappings
    |> Map.values()
    |> List.first()
    |> to_string()
  end

  defp get_primary_port(_), do: "8080"

  defp creates_cycle?(graph, from, to, visited \\ MapSet.new()) do
    if from == to do
      true
    else
      if MapSet.member?(visited, from) do
        false
      else
        new_visited = MapSet.put(visited, from)
        dependencies = Map.get(graph, from, [])

        Enum.any?(dependencies, fn dep ->
          creates_cycle?(graph, dep, to, new_visited)
        end)
      end
    end
  end

  defp dependency_priority(%{is_required: true, dependency_type: "requires"}), do: 1
  defp dependency_priority(%{is_required: true, dependency_type: "depends_on"}), do: 2
  defp dependency_priority(%{is_required: true}), do: 3
  defp dependency_priority(%{dependency_type: "requires"}), do: 4
  defp dependency_priority(%{dependency_type: "depends_on"}), do: 5
  defp dependency_priority(_), do: 6

  defp get_all_services(dependencies) do
    dependent = MapSet.new(dependencies, & &1.dependent_service_id)
    required = MapSet.new(dependencies, & &1.required_service_id)

    MapSet.union(dependent, required)
    |> MapSet.to_list()
  end

  defp calculate_complexity_score(graph) do
    service_count = map_size(graph)
    edge_count = graph |> Map.values() |> List.flatten() |> length()
    max_depth = calculate_max_dependency_depth(graph)

    # Complexity = services + (edges * 2) + (max_depth * 3)
    service_count + edge_count * 2 + max_depth * 3
  end

  defp calculate_max_dependency_depth(graph) do
    graph
    |> Map.keys()
    |> Enum.map(fn service -> calculate_depth(graph, service) end)
    |> Enum.max(fn -> 0 end)
  end

  defp calculate_depth(graph, service, visited \\ MapSet.new()) do
    if MapSet.member?(visited, service) do
      0
    else
      dependencies = Map.get(graph, service, [])
      new_visited = MapSet.put(visited, service)

      if Enum.empty?(dependencies) do
        1
      else
        max_child_depth =
          dependencies
          |> Enum.map(fn dep -> calculate_depth(graph, dep, new_visited) end)
          |> Enum.max(fn -> 0 end)

        1 + max_child_depth
      end
    end
  end

  defp generate_recommendations(dependencies, graph) do
    recommendations = []

    # Check for complex dependency chains
    recommendations =
      if calculate_max_dependency_depth(graph) > 5 do
        ["Consider simplifying dependency chains - maximum depth is > 5 levels" | recommendations]
      else
        recommendations
      end

    # Check for too many dependencies per service
    max_deps =
      graph
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.max(fn -> 0 end)

    recommendations =
      if max_deps > 10 do
        [
          "Some services have > 10 dependencies - consider service decomposition"
          | recommendations
        ]
      else
        recommendations
      end

    # Check for circular dependencies potential
    critical_deps = Enum.filter(dependencies, &critical?/1)

    recommendations =
      if length(critical_deps) / length(dependencies) > 0.8 do
        [
          "High percentage of critical dependencies - consider making some optional"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end
end
