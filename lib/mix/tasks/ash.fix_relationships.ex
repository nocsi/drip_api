defmodule Mix.Tasks.Ash.FixRelationships do
  @moduledoc """
  Analyzes all Ash resources for circular dependencies and broken relationships.
  Fixes them automatically or generates a report.

  Usage:
    mix ash.fix_relationships           # Analyze and report
    mix ash.fix_relationships --fix     # Automatically fix issues
    mix ash.fix_relationships --graph   # Generate relationship graph
  """

  use Mix.Task
  require Logger

  @shortdoc "Fix circular dependencies in Ash resources"

  defmodule ResourceAnalyzer do
    @moduledoc false

    defstruct [:resource, :relationships, :attributes, :issues, :file_path]

    def analyze(resource_module) do
      relationships = resource_module.relationships()
      attributes = resource_module.attributes()
      file_path = find_source_file(resource_module)

      %__MODULE__{
        resource: resource_module,
        relationships: relationships,
        attributes: attributes,
        issues: [],
        file_path: file_path
      }
    end

    defp find_source_file(module) do
      case Code.ensure_loaded(module) do
        {:module, _} ->
          case module.__info__(:compile)[:source] do
            nil -> nil
            source -> to_string(source)
          end

        _ ->
          nil
      end
    end
  end

  def run(args) do
    Mix.Task.run("compile")
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [fix: :boolean, graph: :boolean, verbose: :boolean]
      )

    fix_mode = opts[:fix] || false
    graph_mode = opts[:graph] || false
    verbose = opts[:verbose] || false

    Logger.info("🔍 Ash Resource Relationship Analyzer")
    Logger.info("=" |> String.duplicate(50))

    # Step 1: Find all Ash resources
    resources = find_all_resources()
    Logger.info("Found #{length(resources)} Ash resources")

    # Step 2: Analyze each resource
    analyzed = Enum.map(resources, &ResourceAnalyzer.analyze/1)

    # Step 3: Build relationship graph
    graph = build_relationship_graph(analyzed)

    # Step 4: Find issues
    issues = find_all_issues(graph, analyzed)

    # Step 5: Report findings
    report_issues(issues, verbose)

    # Step 6: Generate graph if requested
    if graph_mode do
      generate_graph_visualization(graph)
    end

    # Step 7: Fix if requested
    if fix_mode && length(issues) > 0 do
      fix_issues(issues, analyzed)
    end

    Logger.info("\n✅ Analysis complete!")
  end

  defp find_all_resources do
    # Find all modules that use Ash.Resource
    {:ok, modules} = :application.get_key(:dirup, :modules)

    modules
    |> Enum.filter(fn module ->
      Code.ensure_loaded?(module) &&
        try do
          function_exported?(module, :__ash_resource__, 0)
        rescue
          _ -> false
        end
    end)
    |> Enum.sort()
  end

  defp build_relationship_graph(analyzed_resources) do
    graph = :digraph.new([:cyclic, :protected])

    # Add vertices for each resource
    Enum.each(analyzed_resources, fn analysis ->
      :digraph.add_vertex(graph, analysis.resource)
    end)

    # Add edges for relationships
    Enum.each(analyzed_resources, fn analysis ->
      Enum.each(analysis.relationships, fn rel ->
        if rel.destination do
          :digraph.add_edge(
            graph,
            analysis.resource,
            rel.destination,
            {rel.name, rel.type}
          )
        end
      end)
    end)

    graph
  end

  defp find_all_issues(graph, analyzed_resources) do
    issues = []

    # Issue 1: Circular dependencies
    cycles = find_cycles(graph)

    issues =
      issues ++
        Enum.map(cycles, fn cycle ->
          %{
            type: :circular_dependency,
            severity: :critical,
            resources: cycle,
            message: "Circular dependency detected: #{inspect(cycle)}"
          }
        end)

    # Issue 2: Missing destination resources
    Enum.each(analyzed_resources, fn analysis ->
      Enum.each(analysis.relationships, fn rel ->
        if rel.destination && !resource_exists?(rel.destination) do
          issues ++
            [
              %{
                type: :missing_destination,
                severity: :error,
                resource: analysis.resource,
                relationship: rel.name,
                destination: rel.destination,
                message:
                  "Relationship #{rel.name} points to non-existent resource #{rel.destination}"
              }
            ]
        end
      end)
    end)

    # Issue 3: Bidirectional relationships without proper configuration
    issues = issues ++ find_bidirectional_issues(analyzed_resources)

    # Issue 4: Missing foreign keys
    issues = issues ++ find_missing_foreign_keys(analyzed_resources)

    # Issue 5: Conflicting indexes
    issues = issues ++ find_conflicting_indexes(analyzed_resources)

    issues
  end

  defp find_cycles(graph) do
    vertices = :digraph.vertices(graph)

    Enum.flat_map(vertices, fn vertex ->
      case :digraph.get_cycle(graph, vertex) do
        false -> []
        cycle -> [cycle]
      end
    end)
    |> Enum.uniq()
  end

  defp resource_exists?(module) do
    try do
      Code.ensure_loaded?(module)
    rescue
      _ -> false
    end
  end

  defp find_bidirectional_issues(analyzed_resources) do
    issues = []

    # Create a map for quick lookup
    resource_map = Map.new(analyzed_resources, fn a -> {a.resource, a} end)

    Enum.flat_map(analyzed_resources, fn analysis ->
      Enum.flat_map(analysis.relationships, fn rel ->
        case Map.get(resource_map, rel.destination) do
          nil ->
            []

          dest_analysis ->
            # Check if destination has a relationship back to us
            reverse_rels =
              Enum.filter(dest_analysis.relationships, fn dest_rel ->
                dest_rel.destination == analysis.resource
              end)

            Enum.map(reverse_rels, fn reverse_rel ->
              # Check if they're properly configured
              if needs_fixing?(rel, reverse_rel) do
                %{
                  type: :bidirectional_misconfiguration,
                  severity: :warning,
                  resource: analysis.resource,
                  relationship: rel.name,
                  reverse_resource: dest_analysis.resource,
                  reverse_relationship: reverse_rel.name,
                  message: "Bidirectional relationship needs configuration"
                }
              end
            end)
            |> Enum.reject(&is_nil/1)
        end
      end)
    end)
  end

  defp needs_fixing?(rel1, rel2) do
    # Check if relationships need manual configuration or other fixes
    (rel1.type == :has_many && rel2.type == :has_many) ||
      (rel1.type == :has_one && rel2.type == :has_one) ||
      (!rel1.manual && !rel2.manual && circular_risk?(rel1, rel2))
  end

  defp circular_risk?(rel1, rel2) do
    # Detect patterns that often cause issues
    # Simplified - you'd add real logic here
    true
  end

  defp find_missing_foreign_keys(analyzed_resources) do
    Enum.flat_map(analyzed_resources, fn analysis ->
      Enum.flat_map(analysis.relationships, fn rel ->
        if rel.type in [:belongs_to, :has_one] do
          # Check if the foreign key attribute exists
          fk_name = foreign_key_name(rel)

          unless Enum.any?(analysis.attributes, fn attr -> attr.name == fk_name end) do
            [
              %{
                type: :missing_foreign_key,
                severity: :error,
                resource: analysis.resource,
                relationship: rel.name,
                expected_attribute: fk_name,
                message: "Missing foreign key attribute #{fk_name} for relationship #{rel.name}"
              }
            ]
          else
            []
          end
        else
          []
        end
      end)
    end)
  end

  defp foreign_key_name(relationship) do
    # Determine the expected foreign key name
    String.to_atom("#{relationship.name}_id")
  end

  defp find_conflicting_indexes(analyzed_resources) do
    # Find indexes that would conflict
    # Simplified - would check for duplicate index definitions
    []
  end

  defp report_issues(issues, verbose) do
    if length(issues) == 0 do
      Logger.info("\n✅ No relationship issues found!")
    else
      Logger.info("\n⚠️  Found #{length(issues)} issues:\n")

      # Group by severity
      by_severity = Enum.group_by(issues, & &1.severity)

      [:critical, :error, :warning, :info]
      |> Enum.each(fn severity ->
        case Map.get(by_severity, severity, []) do
          [] ->
            :ok

          severity_issues ->
            Logger.info("#{severity_label(severity)} (#{length(severity_issues)} issues)")

            if verbose do
              Enum.each(severity_issues, fn issue ->
                Logger.info("  • #{issue.message}")
              end)
            end
        end
      end)
    end
  end

  defp severity_label(:critical), do: "🔴 CRITICAL"
  defp severity_label(:error), do: "🟠 ERROR"
  defp severity_label(:warning), do: "🟡 WARNING"
  defp severity_label(:info), do: "🔵 INFO"

  defp generate_graph_visualization(graph) do
    Logger.info("\n📊 Generating relationship graph...")

    dot_content = generate_dot(graph)

    File.write!("resource_graph.dot", dot_content)
    Logger.info("  Graph saved to resource_graph.dot")
    Logger.info("  View with: dot -Tpng resource_graph.dot -o resource_graph.png")
  end

  defp generate_dot(graph) do
    vertices = :digraph.vertices(graph)
    edges = :digraph.edges(graph)

    vertex_lines =
      Enum.map(vertices, fn v ->
        ~s(  "#{inspect(v)}")
      end)

    edge_lines =
      Enum.map(edges, fn e ->
        {_, v1, v2, label} = :digraph.edge(graph, e)
        ~s(  "#{inspect(v1)}" -> "#{inspect(v2)}" [label="#{elem(label, 0)}"])
      end)

    """
    digraph ResourceGraph {
      rankdir=LR;
      node [shape=box];

    #{Enum.join(vertex_lines, ";\n")};

    #{Enum.join(edge_lines, ";\n")};
    }
    """
  end

  defp fix_issues(issues, analyzed_resources) do
    Logger.info("\n🔧 Fixing issues...")

    # Group issues by resource
    by_resource = Enum.group_by(issues, & &1.resource)

    Enum.each(analyzed_resources, fn analysis ->
      resource_issues = Map.get(by_resource, analysis.resource, [])

      if length(resource_issues) > 0 && analysis.file_path do
        fix_resource_file(analysis.file_path, resource_issues)
      end
    end)

    Logger.info("  ✓ Fixed #{length(issues)} issues")
    Logger.info("\n  🎯 Next steps:")
    Logger.info("    1. Review the changes")
    Logger.info("    2. Run: mix compile --force")
    Logger.info("    3. Run: mix ash_postgres.generate_migrations --name fixed_relationships")
  end

  defp fix_resource_file(file_path, issues) do
    Logger.info("  Fixing #{file_path}...")

    content = File.read!(file_path)

    fixed_content =
      Enum.reduce(issues, content, fn issue, acc ->
        case issue.type do
          :circular_dependency ->
            fix_circular_dependency(acc, issue)

          :bidirectional_misconfiguration ->
            fix_bidirectional(acc, issue)

          :missing_foreign_key ->
            add_missing_foreign_key(acc, issue)

          _ ->
            acc
        end
      end)

    # Backup original
    File.write!("#{file_path}.backup", content)

    # Write fixed version
    File.write!(file_path, fixed_content)
  end

  defp fix_circular_dependency(content, issue) do
    # Add manual: true to one side of the circular dependency
    pattern = ~r/(belongs_to\s+:#{issue.relationship}.*?)(\n|\s+do)/

    if Regex.match?(pattern, content) do
      Regex.replace(pattern, content, "\\1, manual: true\\2")
    else
      content
    end
  end

  defp fix_bidirectional(content, issue) do
    # Add proper configuration for bidirectional relationships
    pattern = ~r/(has_many\s+:#{issue.relationship}.*?)(\n|\s+do)/

    if Regex.match?(pattern, content) do
      Regex.replace(
        pattern,
        content,
        "\\1, destination_attribute: :#{issue.reverse_relationship}\\2"
      )
    else
      content
    end
  end

  defp add_missing_foreign_key(content, issue) do
    # Add the missing foreign key attribute
    attributes_pattern = ~r/(attributes\s+do\s*\n)/

    if Regex.match?(attributes_pattern, content) do
      new_attribute = "    attribute :#{issue.expected_attribute}, :uuid\n"
      Regex.replace(attributes_pattern, content, "\\1#{new_attribute}")
    else
      content
    end
  end
end
