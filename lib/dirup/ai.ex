defmodule Dirup.AI do
  @moduledoc """
  Unified interface for AI operations in Dirup.

  Provides intelligent multi-provider routing that leverages each AI provider's strengths
  for optimal task completion.
  """

  @doc """
  Analyzes a folder structure and returns AI-powered insights.
  """
  def analyze_folder(folder_path, opts \\ []) do
    # This task could be a meta-task that calls other, more specific tasks
    # via the router to build a comprehensive analysis.
    # For now, it's a placeholder.
    {:ok, %{status: :placeholder, path: folder_path, opts: opts}}
  end

  @doc """
  Generates a Dockerfile using the best configured provider.
  """
  def generate_dockerfile(service_analysis) do
    Dirup.AI.Router.route_task(:dockerfile_generation, service_analysis)
  end

  @doc """
  Detects service dependencies using the best configured provider.
  """
  def detect_dependencies(code_files) do
    Dirup.AI.Router.route_task(:dependency_detection, %{code_files: code_files})
  end

  @doc """
  Analyzes system architecture using the best configured provider.
  """
  def analyze_architecture(full_topology) do
    Dirup.AI.Router.route_task(:architecture_analysis, %{topology: full_topology})
  end

  @doc """
  Performs comprehensive security analysis using the best configured provider.
  """
  def security_analysis(folder_structure) do
    Dirup.AI.Router.route_task(:security_analysis, %{folder_structure: folder_structure})
  end

  @doc """
  Generates optimization recommendations using the best configured provider.
  """
  def suggest_optimizations(metrics, structure) do
    Dirup.AI.Router.route_task(:optimization_reasoning, %{
      metrics: metrics,
      structure: structure
    })
  end
end
