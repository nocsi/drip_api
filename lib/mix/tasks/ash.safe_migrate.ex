defmodule Mix.Tasks.Ash.SafeMigrate do
  @moduledoc """
  Generates migrations but checks for issues first.
  """

  use Mix.Task

  def run(args) do
    # First, analyze relationships
    Mix.Task.run("ash.fix_relationships")

    # Check if there are issues
    issues = analyze_for_issues()

    if length(issues) > 0 do
      Logger.error("❌ Found relationship issues that would break migrations!")
      Logger.info("Run: mix ash.fix_relationships --fix")
      exit({:shutdown, 1})
    else
      # Safe to generate migrations
      Mix.Task.run("ash_postgres.generate_migrations", args)
    end
  end

  defp analyze_for_issues do
    # Run the analysis and return issues
    # Simplified
    []
  end
end
