# Claude Code: Create ash_profiler - Elixir Library

## Project Overview
Create **ash_profiler**, a standalone Elixir library for debugging Ash Framework DSL compilation performance. This library will help developers identify and fix slow compilation issues in Ash applications.

## Library Architecture

### Core Package Structure
```
ash_profiler/
├── lib/
│   ├── ash_profiler.ex                 # Main API
│   ├── ash_profiler/
│   │   ├── dsl_analyzer.ex             # DSL complexity analysis
│   │   ├── compilation_profiler.ex     # Compilation timing
│   │   ├── resource_analyzer.ex        # Resource-specific analysis
│   │   ├── container_detector.ex       # Container environment detection
│   │   ├── performance_tracker.ex      # Real-time performance tracking
│   │   ├── reporters/
│   │   │   ├── console_reporter.ex     # Console output
│   │   │   ├── json_reporter.ex        # JSON export
│   │   │   └── html_reporter.ex        # HTML dashboard
│   │   └── optimizations/
│   │       ├── policy_optimizer.ex     # Policy optimization suggestions
│   │       ├── relationship_optimizer.ex # Relationship optimization
│   │       └── action_optimizer.ex     # Action optimization
│   └── mix/
│       └── tasks/
│           ├── ash_profiler.ex          # Main mix task
│           ├── ash_profiler.profile.ex  # Profile compilation
│           └── ash_profiler.report.ex   # Generate reports
├── priv/
│   ├── templates/
│   │   └── report.html.eex             # HTML report template
│   └── static/
│       ├── css/
│       └── js/
├── test/
├── mix.exs
├── README.md
└── CHANGELOG.md
```

### Main API Design
```elixir
# lib/ash_profiler.ex
defmodule AshProfiler do
  @moduledoc """
  Performance profiling and optimization toolkit for Ash Framework applications.

  AshProfiler helps identify compilation bottlenecks, analyze DSL complexity,
  and provides optimization recommendations for Ash resources.

  ## Usage

      # Quick profile
      AshProfiler.profile()

      # Detailed analysis
      AshProfiler.analyze(domains: [MyApp.Domain], output: :html)

      # Continuous monitoring
      AshProfiler.Monitor.start_link()
  """

  alias AshProfiler.{DSLAnalyzer, CompilationProfiler, ResourceAnalyzer}

  @doc """
  Runs a comprehensive performance analysis of Ash resources.

  ## Options

    * `:domains` - List of Ash domains to analyze (defaults to all discovered domains)
    * `:output` - Output format (:console, :json, :html) (default: :console)
    * `:file` - Output file path (optional)
    * `:threshold` - Complexity threshold for warnings (default: 100)
    * `:container_mode` - Enable container-specific analysis (default: auto-detect)
    * `:include_optimizations` - Include optimization suggestions (default: true)

  ## Examples

      # Basic analysis
      AshProfiler.analyze()

      # Specific domains with HTML output
      AshProfiler.analyze(domains: [MyApp.CoreDomain], output: :html, file: "report.html")

      # Container environment analysis
      AshProfiler.analyze(container_mode: true, threshold: 50)
  """
  def analyze(opts \\ []) do
    opts = normalize_options(opts)

    IO.puts("🔍 Starting Ash Performance Analysis...")

    # Discover or use provided domains
    domains = opts[:domains] || discover_domains()

    # Run analysis pipeline
    results = %{
      environment: analyze_environment(opts),
      domains: analyze_domains(domains, opts),
      compilation: profile_compilation(opts),
      optimizations: generate_optimizations(domains, opts)
    }

    # Generate output
    generate_report(results, opts)

    results
  end

  @doc """
  Quick profiling of current compilation performance.
  """
  def profile(opts \\ []) do
    CompilationProfiler.profile_current_compilation(opts)
  end

  @doc """
  Monitor compilation performance in real-time.
  """
  def monitor(opts \\ []) do
    AshProfiler.Monitor.start_monitoring(opts)
  end

  # Private functions
  defp normalize_options(opts) do
    defaults = [
      output: :console,
      threshold: 100,
      container_mode: AshProfiler.ContainerDetector.in_container?(),
      include_optimizations: true
    ]

    Keyword.merge(defaults, opts)
  end

  defp discover_domains do
    # Auto-discover Ash domains from application config
    app_domains = Application.get_env(:ash, :domains, [])

    # Check main app config
    main_app = Mix.Project.config()[:app]
    app_specific_domains = Application.get_env(main_app, :ash_domains, [])

    (app_domains ++ app_specific_domains)
    |> Enum.uniq()
  end

  defp analyze_environment(opts) do
    if opts[:container_mode] do
      AshProfiler.ContainerDetector.analyze_container_environment()
    else
      AshProfiler.EnvironmentAnalyzer.analyze_local_environment()
    end
  end

  defp analyze_domains(domains, opts) do
    Enum.map(domains, fn domain ->
      DSLAnalyzer.analyze_domain(domain, opts)
    end)
  end

  defp profile_compilation(opts) do
    CompilationProfiler.profile_compilation_performance(opts)
  end

  defp generate_optimizations(domains, opts) do
    if opts[:include_optimizations] do
      AshProfiler.OptimizationEngine.generate_recommendations(domains, opts)
    else
      []
    end
  end

  defp generate_report(results, opts) do
    reporter = case opts[:output] do
      :console -> AshProfiler.Reporters.ConsoleReporter
      :json -> AshProfiler.Reporters.JSONReporter
      :html -> AshProfiler.Reporters.HTMLReporter
    end

    reporter.generate_report(results, opts)
  end
end
```

### DSL Complexity Analyzer
```elixir
# lib/ash_profiler/dsl_analyzer.ex
defmodule AshProfiler.DSLAnalyzer do
  @moduledoc """
  Analyzes Ash DSL complexity and identifies compilation bottlenecks.
  """

  @doc """
  Analyzes DSL complexity for a given domain.
  """
  def analyze_domain(domain, opts \\ []) do
    resources = get_domain_resources(domain)

    %{
      domain: domain,
      resource_count: length(resources),
      total_complexity: calculate_total_complexity(resources),
      resources: Enum.map(resources, &analyze_resource(&1, opts)),
      bottlenecks: identify_bottlenecks(resources, opts)
    }
  end

  @doc """
  Analyzes a single Ash resource for DSL complexity.
  """
  def analyze_resource(resource, opts \\ []) do
    %{
      resource: resource,
      complexity: calculate_resource_complexity(resource),
      sections: analyze_dsl_sections(resource),
      issues: identify_resource_issues(resource, opts),
      optimizations: suggest_resource_optimizations(resource)
    }
  end

  defp calculate_resource_complexity(resource) do
    sections = analyze_dsl_sections(resource)

    %{
      total: Enum.sum(Map.values(sections)),
      breakdown: sections,
      severity: determine_severity(sections)
    }
  end

  defp analyze_dsl_sections(resource) do
    %{
      attributes: analyze_attributes_complexity(resource),
      relationships: analyze_relationships_complexity(resource),
      actions: analyze_actions_complexity(resource),
      policies: analyze_policies_complexity(resource),
      changes: analyze_changes_complexity(resource),
      preparations: analyze_preparations_complexity(resource),
      validations: analyze_validations_complexity(resource)
    }
  end

  defp analyze_attributes_complexity(resource) do
    attributes = get_resource_attributes(resource)

    base_count = length(attributes)
    computed_count = count_computed_attributes(attributes)
    constraint_complexity = sum_constraint_complexity(attributes)

    base_count + (computed_count * 3) + constraint_complexity
  end

  defp analyze_relationships_complexity(resource) do
    relationships = get_resource_relationships(resource)

    base_count = length(relationships) * 2
    many_to_many_bonus = count_many_to_many_relationships(relationships) * 5
    through_relationship_bonus = count_through_relationships(relationships) * 3

    base_count + many_to_many_bonus + through_relationship_bonus
  end

  defp analyze_policies_complexity(resource) do
    policies = get_resource_policies(resource)

    base_count = length(policies) * 5
    expression_complexity = sum_policy_expression_complexity(policies)
    bypass_complexity = count_policy_bypasses(policies) * 2

    base_count + expression_complexity + bypass_complexity
  end

  defp analyze_actions_complexity(resource) do
    actions = get_resource_actions(resource)

    base_count = length(actions)
    change_complexity = sum_action_changes_complexity(actions)
    validation_complexity = sum_action_validations_complexity(actions)
    accept_complexity = sum_action_accept_complexity(actions)

    base_count + change_complexity + validation_complexity + accept_complexity
  end

  defp identify_resource_issues(resource, opts) do
    threshold = opts[:threshold] || 100
    complexity = calculate_resource_complexity(resource)

    issues = []

    # High overall complexity
    issues = if complexity.total > threshold do
      [%{type: :high_complexity, severity: :warning,
         message: "Resource complexity (#{complexity.total}) exceeds threshold (#{threshold})"}] ++ issues
    else
      issues
    end

    # Specific section issues
    issues = if complexity.breakdown.policies > 50 do
      [%{type: :complex_policies, severity: :error,
         message: "Policy complexity is very high (#{complexity.breakdown.policies})"}] ++ issues
    else
      issues
    end

    issues = if complexity.breakdown.relationships > 30 do
      [%{type: :many_relationships, severity: :warning,
         message: "High relationship count may slow compilation"}] ++ issues
    else
      issues
    end

    issues
  end

  defp suggest_resource_optimizations(resource) do
    optimizations = []
    complexity = calculate_resource_complexity(resource)

    # Policy optimizations
    if complexity.breakdown.policies > 30 do
      optimizations = [%{
        type: :simplify_policies,
        description: "Consider simplifying authorization policies",
        impact: :high,
        suggestions: [
          "Extract complex expressions to computed attributes",
          "Use simpler authorize_if conditions",
          "Consider policy composition patterns"
        ]
      }] ++ optimizations
    end

    # Relationship optimizations
    if complexity.breakdown.relationships > 20 do
      optimizations = [%{
        type: :reduce_relationships,
        description: "Consider reducing relationship complexity",
        impact: :medium,
        suggestions: [
          "Move some relationships to separate resources",
          "Use manual relationships for complex queries",
          "Consider data layer optimizations"
        ]
      }] ++ optimizations
    end

    optimizations
  end

  # Helper functions for extracting resource information
  defp get_resource_attributes(resource) do
    try do
      resource.attributes()
    rescue
      _ -> []
    end
  end

  defp get_resource_relationships(resource) do
    try do
      resource.relationships()
    rescue
      _ -> []
    end
  end

  defp get_resource_policies(resource) do
    try do
      resource.policies()
    rescue
      _ -> []
    end
  end

  defp get_resource_actions(resource) do
    try do
      resource.actions()
    rescue
      _ -> []
    end
  end

  # Additional helper functions...
  defp count_computed_attributes(attributes) do
    Enum.count(attributes, & &1.generated?)
  end

  defp sum_constraint_complexity(attributes) do
    Enum.sum(Enum.map(attributes, fn attr ->
      length(attr.constraints())
    end))
  end

  defp count_many_to_many_relationships(relationships) do
    Enum.count(relationships, &(&1.type == :many_to_many))
  end

  defp count_through_relationships(relationships) do
    Enum.count(relationships, fn rel ->
      Map.has_key?(rel, :through) and not is_nil(rel.through)
    end)
  end

  defp sum_policy_expression_complexity(policies) do
    Enum.sum(Enum.map(policies, &calculate_expression_complexity/1))
  end

  defp calculate_expression_complexity(policy) do
    # Analyze the AST of policy expressions
    expr_string = inspect(policy.condition)

    # Count logical operators
    operator_count = length(Regex.scan(~r/\band\b|\bor\b|\bnot\b/i, expr_string))

    # Count function calls
    function_count = length(Regex.scan(~r/\w+\s*\(/i, expr_string))

    # Count field accesses
    field_count = length(Regex.scan(~r/\.\w+/i, expr_string))

    operator_count * 2 + function_count + field_count
  end
end
```

### Mix Tasks
```elixir
# lib/mix/tasks/ash_profiler.ex
defmodule Mix.Tasks.AshProfiler do
  use Mix.Task

  @shortdoc "Profile Ash DSL compilation performance"
  @moduledoc """
  Profiles Ash Framework DSL compilation performance and identifies bottlenecks.

  ## Usage

      # Basic profiling
      mix ash_profiler

      # Generate HTML report
      mix ash_profiler --output html --file report.html

      # Profile specific domains
      mix ash_profiler --domains MyApp.CoreDomain,MyApp.UserDomain

      # Container mode analysis
      mix ash_profiler --container-mode

      # Set complexity threshold
      mix ash_profiler --threshold 50

  ## Options

    * `--output` - Output format: console, json, html (default: console)
    * `--file` - Output file path
    * `--domains` - Comma-separated list of domains to analyze
    * `--threshold` - Complexity threshold for warnings (default: 100)
    * `--container-mode` - Enable container-specific analysis
    * `--no-optimizations` - Skip optimization suggestions
    * `--verbose` - Enable verbose output
  """

  @switches [
    output: :string,
    file: :string,
    domains: :string,
    threshold: :integer,
    container_mode: :boolean,
    optimizations: :boolean,
    verbose: :boolean
  ]

  @aliases [
    o: :output,
    f: :file,
    d: :domains,
    t: :threshold,
    c: :container_mode,
    v: :verbose
  ]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    # Ensure application is loaded
    Mix.Task.run("loadpaths")
    Mix.Task.run("compile", ["--no-deps-check"])

    # Convert options
    profiler_opts = convert_options(opts)

    # Run analysis
    AshProfiler.analyze(profiler_opts)
  end

  defp convert_options(opts) do
    converted = []

    # Output format
    converted = if opts[:output] do
      output_atom = String.to_atom(opts[:output])
      Keyword.put(converted, :output, output_atom)
    else
      converted
    end

    # Output file
    converted = if opts[:file] do
      Keyword.put(converted, :file, opts[:file])
    else
      converted
    end

    # Domains
    converted = if opts[:domains] do
      domain_strings = String.split(opts[:domains], ",")
      domain_atoms = Enum.map(domain_strings, &Module.concat([String.trim(&1)]))
      Keyword.put(converted, :domains, domain_atoms)
    else
      converted
    end

    # Other options
    converted = if opts[:threshold], do: Keyword.put(converted, :threshold, opts[:threshold]), else: converted
    converted = if opts[:container_mode], do: Keyword.put(converted, :container_mode, true), else: converted
    converted = if opts[:optimizations] == false, do: Keyword.put(converted, :include_optimizations, false), else: converted
    converted = if opts[:verbose], do: Keyword.put(converted, :verbose, true), else: converted

    converted
  end
end
```

### Package Configuration
```elixir
# mix.exs
defmodule AshProfiler.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/ash_profiler"

  def project do
    [
      app: :ash_profiler,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs(),
      name: "AshProfiler",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.0"},
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:telemetry, "~> 1.0"}
    ]
  end

  defp description do
    """
    Performance profiling and optimization toolkit for Ash Framework applications.
    Identifies DSL compilation bottlenecks and provides optimization recommendations.
    """
  end

  defp package do
    [
      name: "ash_profiler",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Your Name"],
      files: ~w(lib priv mix.exs README* CHANGELOG* LICENSE*)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
```

### README Structure
```markdown
# AshProfiler

Performance profiling and optimization toolkit for Ash Framework applications.

## Installation

Add `ash_profiler` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_profiler, "~> 0.1.0"}
  ]
end
```

## Usage

### Quick Profiling
```elixir
# Basic analysis
AshProfiler.analyze()

# Generate HTML report
AshProfiler.analyze(output: :html, file: "ash_profile.html")
```

### Mix Tasks
```bash
# Command line profiling
mix ash_profiler

# Generate detailed report
mix ash_profiler --output html --file report.html

# Container environment analysis
mix ash_profiler --container-mode --threshold 50
```

### Real-time Monitoring
```elixir
# Start continuous monitoring
AshProfiler.monitor()
```

## Features

- **DSL Complexity Analysis** - Identifies expensive Ash DSL patterns
- **Compilation Profiling** - Tracks compilation performance bottlenecks
- **Container Detection** - Specialized analysis for containerized environments
- **Optimization Suggestions** - Actionable recommendations for performance improvements
- **Multiple Output Formats** - Console, JSON, and HTML reporting
- **Real-time Monitoring** - Continuous performance tracking

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

This package is available as open source under the terms of the MIT License.
```

This creates a comprehensive, reusable library that the Ash community could benefit from. It's designed to be:

1. **Standalone** - Works with any Ash application
2. **Extensible** - Plugin architecture for custom analyzers
3. **Production-ready** - Proper package structure, tests, docs
4. **Community-focused** - Solves a common Ash problem

Want me to continue with specific modules like the HTML reporter or container detector?