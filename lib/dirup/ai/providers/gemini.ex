defmodule Dirup.AI.Providers.Gemini do
  @behaviour Dirup.AI.Provider

  @impl Dirup.AI.Provider
  def skillsets, do: [:multimodality, :function_calling, :optimization_reasoning]

  @impl Dirup.AI.Provider
  def run_task(:suggest_optimizations, params) do
    # In a real implementation, you would call the Google Gemini API.
    IO.puts("Task :suggest_optimizations handled by Gemini")

    {:ok,
     %{provider: __MODULE__, suggestions: ["Use smaller base images", "Run tests in parallel"]}}
  end

  def run_task(task_name, _params) do
    {:error, {:unsupported_task_by_provider, task_name, __MODULE__}}
  end
end
