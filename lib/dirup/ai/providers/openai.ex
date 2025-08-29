defmodule Dirup.AI.Providers.OpenAI do
  @behaviour Dirup.AI.Provider

  @impl Dirup.AI.Provider
  def skillsets, do: [:dependency_detection, :security_analysis]

  @impl Dirup.AI.Provider
  def run_task(:dependency_detection, params) do
    # In a real implementation, you would call the OpenAI API.
    IO.puts("Task :dependency_detection handled by OpenAI")

    {:ok, %{provider: __MODULE__, dependencies: ["phoenix", "ecto"]}}
  end

  def run_task(:security_analysis, params) do
    # In a real implementation, you would call the OpenAI API.
    IO.puts("Task :security_analysis handled by OpenAI")

    {:ok, %{provider: __MODULE__, issues: ["SQL injection vulnerability found..."]}}
  end

  def run_task(task_name, _params) do
    {:error, {:unsupported_task_by_provider, task_name, __MODULE__}}
  end
end
