defmodule Dirup.AI.Router do
  @moduledoc """
  Routes AI tasks to the best provider based on a required skillset.

  This router uses a two-step process:
  1. Find the skill required for a given task (from config).
  2. Find an available provider that has the required skill (from config).
  """

  @doc """
  Routes a task to the best-suited AI provider.
  """
  def route_task(task_name, params) do
    with {:ok, skill} <- get_skill_for_task(task_name),
         {:ok, provider_module} <- find_provider_with_skill(skill) do
      # Call the `run_task` function on the dynamically selected provider
      apply(provider_module, :run_task, [task_name, params])
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_skill_for_task(task_name) do
    case Application.get_env(:dirup, :ai_task_skill_mapping)[task_name] do
      nil -> {:error, {:no_skill_mapping_for_task, task_name}}
      skill -> {:ok, skill}
    end
  end

  defp find_provider_with_skill(skill) do
    # Get the list of all available provider modules from config
    available_providers = Application.get_env(:dirup, :ai_providers)

    # Find the first provider that has the required skill
    provider =
      Enum.find(available_providers, fn provider_module ->
        skill in provider_module.skillsets()
      end)

    if provider do
      {:ok, provider}
    else
      {:error, {:no_provider_with_skill, skill}}
    end
  end
end
