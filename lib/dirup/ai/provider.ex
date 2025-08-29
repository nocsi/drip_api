defmodule Dirup.AI.Provider do
  @moduledoc """
  Defines the behaviour for an AI provider, including its capabilities (skillsets)
  and the interface for executing tasks.
  """

  @doc """
  Returns a list of atoms representing the provider's special skillsets.
  e.g. [:code_generation, :complex_reasoning, :security_analysis]
  """
  @callback skillsets() :: [atom()]

  @doc """
  Executes a specific AI task.
  """
  @callback run_task(task_name :: atom(), params :: map()) :: {:ok, any()} | {:error, any()}
end
