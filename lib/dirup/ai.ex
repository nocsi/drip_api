defmodule Dirup.AI do
  @moduledoc """
  Unified interface for AI operations in Dirup.
  
  Provides intelligent multi-provider routing that leverages each AI provider's strengths
  for optimal task completion. Includes load balancing, circuit breaking, and failover.
  """

  alias Dirup.AI.{ProviderRouter, TaskDistributor}

  @doc """
  Analyzes a folder structure and returns AI-powered insights.
  """
  def analyze_folder(folder_path, opts \\ []) do
    with {:ok, structure} <- get_folder_structure(folder_path),
         {:ok, analysis} <- distribute_ai_analysis(structure, opts) do
      {:ok, %{
        service_type: analysis.detected_type,
        confidence: analysis.confidence,
        dockerfile: analysis.generated_dockerfile,
        dependencies: analysis.dependencies,
        security_issues: analysis.security_findings,
        optimizations: analysis.suggested_optimizations
      }}
    end
  end

  @doc """
  Generates a Dockerfile using the best provider for code generation (Anthropic).
  """
  def generate_dockerfile(service_analysis) do
    ProviderRouter.route_task(:dockerfile_generation, service_analysis)
  end

  @doc """
  Detects service dependencies using the best provider for pattern recognition (OpenAI).
  """
  def detect_dependencies(code_files) do
    ProviderRouter.route_task(:dependency_detection, %{code_files: code_files})
  end

  @doc """
  Analyzes system architecture using the best provider for complex reasoning (xAI).
  """
  def analyze_architecture(full_topology) do
    ProviderRouter.route_task(:architecture_analysis, %{topology: full_topology})
  end

  @doc """
  Performs comprehensive security analysis using provider best suited for security.
  """
  def security_analysis(folder_structure) do
    ProviderRouter.route_task(:security_analysis, %{folder_structure: folder_structure})
  end

  @doc """
  Generates optimization recommendations using reasoning-focused provider.
  """
  def suggest_optimizations(metrics, structure) do
    ProviderRouter.route_task(:optimization_reasoning, %{
      metrics: metrics, 
      structure: structure
    })
  end

  @doc """
  Enhanced folder analysis that uses all providers in parallel for comprehensive insights.
  """
  def comprehensive_analysis(folder_path) do
    TaskDistributor.distribute_analysis(folder_path)
  end

  # Private helper functions

  defp get_folder_structure(folder_path) do
    # This would be implemented to actually scan the folder structure
    # For now, return a mock structure
    {:ok, %{
      path: folder_path,
      files: [],
      directories: [],
      size: 0,
      last_modified: DateTime.utc_now()
    }}
  end

  defp distribute_ai_analysis(structure, opts) do
    # Distribute analysis tasks to appropriate providers
    case TaskDistributor.distribute_analysis(structure.path) do
      {:ok, results} -> {:ok, merge_analysis_results(results)}
      error -> error
    end
  end

  defp merge_analysis_results(results) do
    %{
      detected_type: results[:pattern_detection][:primary_type],
      confidence: calculate_average_confidence(results),
      generated_dockerfile: results[:dockerfile_generation][:content],
      dependencies: results[:dependency_analysis][:dependencies] || [],
      security_findings: results[:security_review][:issues] || [],
      suggested_optimizations: results[:optimization_reasoning][:suggestions] || []
    }
  end

  defp calculate_average_confidence(results) do
    confidences = 
      results
      |> Enum.map(fn {_key, result} -> Map.get(result, :confidence, 0.0) end)
      |> Enum.filter(&(&1 > 0))

    if length(confidences) > 0 do
      Enum.sum(confidences) / length(confidences)
    else
      0.0
    end
  end
end