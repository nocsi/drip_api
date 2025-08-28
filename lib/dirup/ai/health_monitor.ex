defmodule Dirup.AI.HealthMonitor do
  @moduledoc """
  Health monitoring system for AI providers.
  
  Continuously monitors provider availability, response times, error rates,
  and implements circuit breaker patterns for resilient AI operations.
  """
  
  use GenServer
  require Logger
  
  alias Dirup.AI.CostTracker
  
  @check_interval 30_000  # 30 seconds
  @circuit_breaker_threshold 5  # failures before opening circuit
  @circuit_breaker_timeout 60_000  # 1 minute before trying again
  
  defstruct [
    :providers,
    :health_status,
    :circuit_breakers,
    :failure_counts,
    :last_check_times,
    :response_times
  ]
  
  ## Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Check if a provider is available and healthy.
  """
  def provider_available?(provider) do
    GenServer.call(__MODULE__, {:provider_available, provider})
  end
  
  @doc """
  Get health status for all providers.
  """
  def get_health_status do
    GenServer.call(__MODULE__, :get_health_status)
  end
  
  @doc """
  Record a successful API call for circuit breaker tracking.
  """
  def record_success(provider, response_time_ms) do
    GenServer.cast(__MODULE__, {:record_success, provider, response_time_ms})
  end
  
  @doc """
  Record a failed API call for circuit breaker tracking.
  """
  def record_failure(provider, error_type) do
    GenServer.cast(__MODULE__, {:record_failure, provider, error_type})
  end
  
  @doc """
  Force a health check for specific provider.
  """
  def force_health_check(provider) do
    GenServer.cast(__MODULE__, {:force_health_check, provider})
  end
  
  ## Server Implementation
  
  def init(_opts) do
    providers = [:anthropic, :openai, :xai]
    
    state = %__MODULE__{
      providers: providers,
      health_status: init_health_status(providers),
      circuit_breakers: init_circuit_breakers(providers),
      failure_counts: init_failure_counts(providers),
      last_check_times: init_last_check_times(providers),
      response_times: init_response_times(providers)
    }
    
    # Schedule first health check
    schedule_health_check()
    
    {:ok, state}
  end
  
  def handle_call({:provider_available, provider}, _from, state) do
    available = is_provider_available?(provider, state)
    {:reply, available, state}
  end
  
  def handle_call(:get_health_status, _from, state) do
    status = build_health_report(state)
    {:reply, status, state}
  end
  
  def handle_cast({:record_success, provider, response_time}, state) do
    new_state = 
      state
      |> reset_failure_count(provider)
      |> close_circuit_breaker(provider)
      |> record_response_time(provider, response_time)
      |> update_health_status(provider, :healthy)
    
    {:noreply, new_state}
  end
  
  def handle_cast({:record_failure, provider, error_type}, state) do
    new_state = 
      state
      |> increment_failure_count(provider)
      |> maybe_open_circuit_breaker(provider)
      |> update_health_status(provider, :unhealthy)
      |> log_failure(provider, error_type)
    
    {:noreply, new_state}
  end
  
  def handle_cast({:force_health_check, provider}, state) do
    new_state = perform_health_check(provider, state)
    {:noreply, new_state}
  end
  
  def handle_info(:health_check, state) do
    new_state = perform_all_health_checks(state)
    schedule_health_check()
    {:noreply, new_state}
  end
  
  ## Private Functions
  
  defp init_health_status(providers) do
    providers
    |> Enum.map(&{&1, :unknown})
    |> Map.new()
  end
  
  defp init_circuit_breakers(providers) do
    providers
    |> Enum.map(&{&1, :closed})
    |> Map.new()
  end
  
  defp init_failure_counts(providers) do
    providers
    |> Enum.map(&{&1, 0})
    |> Map.new()
  end
  
  defp init_last_check_times(providers) do
    providers
    |> Enum.map(&{&1, nil})
    |> Map.new()
  end
  
  defp init_response_times(providers) do
    providers
    |> Enum.map(&{&1, []})
    |> Map.new()
  end
  
  defp schedule_health_check do
    Process.send_after(self(), :health_check, @check_interval)
  end
  
  defp is_provider_available?(provider, state) do
    circuit_status = Map.get(state.circuit_breakers, provider, :closed)
    health_status = Map.get(state.health_status, provider, :unknown)
    
    circuit_status == :closed and health_status in [:healthy, :unknown]
  end
  
  defp perform_all_health_checks(state) do
    Enum.reduce(state.providers, state, fn provider, acc_state ->
      perform_health_check(provider, acc_state)
    end)
  end
  
  defp perform_health_check(provider, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case check_provider_health(provider) do
      {:ok, response_time} ->
        state
        |> reset_failure_count(provider)
        |> close_circuit_breaker(provider)
        |> record_response_time(provider, response_time)
        |> update_health_status(provider, :healthy)
        |> update_last_check_time(provider)
        
      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        timeout_duration = end_time - start_time
        
        state
        |> increment_failure_count(provider)
        |> maybe_open_circuit_breaker(provider)
        |> update_health_status(provider, :unhealthy)
        |> update_last_check_time(provider)
        |> log_failure(provider, reason)
    end
  end
  
  defp check_provider_health(provider) do
    start_time = System.monotonic_time(:millisecond)
    
    case provider do
      :anthropic -> health_check_anthropic()
      :openai -> health_check_openai()
      :xai -> health_check_grok()
    end
    |> case do
      :ok ->
        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time
        {:ok, response_time}
        
      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      {:error, Exception.message(error)}
  end
  
  defp health_check_anthropic do
    # Simple health check - attempt to get model info or make minimal request
    case make_anthropic_health_request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp health_check_openai do
    case make_openai_health_request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp health_check_grok do
    case make_grok_health_request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  # Placeholder health check implementations
  # These would be replaced with actual API calls
  
  defp make_anthropic_health_request do
    # In production, this would make an actual API call to Claude
    # For now, simulate based on configuration
    case get_provider_config(:anthropic) do
      %{api_key: key} when is_binary(key) -> {:ok, %{status: "healthy"}}
      _ -> {:error, "API key not configured"}
    end
  end
  
  defp make_openai_health_request do
    case get_provider_config(:openai) do
      %{api_key: key} when is_binary(key) -> {:ok, %{status: "healthy"}}
      _ -> {:error, "API key not configured"}
    end
  end
  
  defp make_grok_health_request do
    case get_provider_config(:xai) do
      %{api_key: key} when is_binary(key) -> {:ok, %{status: "healthy"}}
      _ -> {:error, "API key not configured"}
    end
  end
  
  defp get_provider_config(provider) do
    Application.get_env(:dirup, :ai_providers, %{})
    |> Map.get(provider, %{})
  end
  
  defp reset_failure_count(state, provider) do
    %{state | failure_counts: Map.put(state.failure_counts, provider, 0)}
  end
  
  defp increment_failure_count(state, provider) do
    current = Map.get(state.failure_counts, provider, 0)
    %{state | failure_counts: Map.put(state.failure_counts, provider, current + 1)}
  end
  
  defp close_circuit_breaker(state, provider) do
    %{state | circuit_breakers: Map.put(state.circuit_breakers, provider, :closed)}
  end
  
  defp maybe_open_circuit_breaker(state, provider) do
    failure_count = Map.get(state.failure_counts, provider, 0)
    
    if failure_count >= @circuit_breaker_threshold do
      Logger.warning("Opening circuit breaker for #{provider} after #{failure_count} failures")
      
      # Schedule circuit breaker reset
      Process.send_after(self(), {:reset_circuit_breaker, provider}, @circuit_breaker_timeout)
      
      %{state | circuit_breakers: Map.put(state.circuit_breakers, provider, :open)}
    else
      state
    end
  end
  
  defp record_response_time(state, provider, response_time) do
    current_times = Map.get(state.response_times, provider, [])
    # Keep only last 10 response times for average calculation
    new_times = [response_time | current_times] |> Enum.take(10)
    
    %{state | response_times: Map.put(state.response_times, provider, new_times)}
  end
  
  defp update_health_status(state, provider, status) do
    %{state | health_status: Map.put(state.health_status, provider, status)}
  end
  
  defp update_last_check_time(state, provider) do
    %{state | last_check_times: Map.put(state.last_check_times, provider, DateTime.utc_now())}
  end
  
  defp log_failure(state, provider, error) do
    Logger.warning("Health check failed for #{provider}: #{inspect(error)}")
    
    # Optionally log to cost tracker for failure analytics
    try do
      CostTracker.log_usage(%{
        provider: provider,
        task_type: :health_check,
        model_used: "health_check",
        input_tokens: 0,
        output_tokens: 0,
        request_duration_ms: 0,
        success: false,
        error_type: "health_check_failure",
        error_message: to_string(error)
      })
    rescue
      _ -> :ok  # Don't fail health checks due to logging issues
    end
    
    state
  end
  
  defp build_health_report(state) do
    %{
      providers: 
        Enum.map(state.providers, fn provider ->
          %{
            name: provider,
            status: Map.get(state.health_status, provider),
            circuit_breaker: Map.get(state.circuit_breakers, provider),
            failure_count: Map.get(state.failure_counts, provider, 0),
            last_check: Map.get(state.last_check_times, provider),
            avg_response_time: calculate_avg_response_time(provider, state),
            available: is_provider_available?(provider, state)
          }
        end),
      last_updated: DateTime.utc_now()
    }
  end
  
  defp calculate_avg_response_time(provider, state) do
    times = Map.get(state.response_times, provider, [])
    
    if length(times) > 0 do
      Enum.sum(times) / length(times)
    else
      nil
    end
  end
  
  def handle_info({:reset_circuit_breaker, provider}, state) do
    Logger.info("Resetting circuit breaker for #{provider}")
    new_state = %{state | circuit_breakers: Map.put(state.circuit_breakers, provider, :half_open)}
    {:noreply, new_state}
  end
end