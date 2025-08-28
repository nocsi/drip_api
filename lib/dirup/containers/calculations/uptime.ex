defmodule Dirup.Containers.Calculations.Uptime do
  @moduledoc """
  Calculates the uptime in seconds for a service instance.

  This calculation determines how long a service has been running
  by comparing the deployment timestamp with the current time.
  Returns 0 if the service is not currently running.
  """

  use Ash.Resource.Calculation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def load(query, _opts, _context) do
    query
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &calculate_uptime/1)
  end

  defp calculate_uptime(service_instance) do
    case service_instance.status do
      :running ->
        case service_instance.deployed_at do
          nil ->
            0

          deployed_at ->
            now = DateTime.utc_now()
            DateTime.diff(now, deployed_at, :second)
        end

      _ ->
        0
    end
  end

  @impl true
  def select(_query, _opts, _context) do
    [:status, :deployed_at]
  end
end
