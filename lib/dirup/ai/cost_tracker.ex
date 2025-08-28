defmodule Dirup.AI.CostTracker do
  @moduledoc """
  Tracks token usage and costs for AI provider operations.
  
  Provides real-time cost monitoring, budget controls, and usage analytics
  for all AI providers (Anthropic, OpenAI, xAI).
  """
  
  use Ash.Resource,
    domain: Dirup.AI,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "ai_usage_logs"
    repo Dirup.Repo
  end
  
  attributes do
    uuid_primary_key :id
    
    attribute :provider, :atom do
      allow_nil? false
      constraints [one_of: [:anthropic, :openai, :xai]]
    end
    
    attribute :task_type, :atom do
      allow_nil? false
      constraints [one_of: [
        :code_generation, :dockerfile_generation, :security_analysis,
        :pattern_recognition, :dependency_detection, :optimization_suggestions,
        :reasoning, :architecture_analysis, :complex_inference
      ]]
    end
    
    attribute :model_used, :string do
      allow_nil? false
    end
    
    attribute :input_tokens, :integer do
      allow_nil? false
    end
    
    attribute :output_tokens, :integer do
      allow_nil? false
    end
    
    attribute :total_tokens, :integer do
      allow_nil? false
    end
    
    attribute :estimated_cost_usd, :decimal do
      allow_nil? false
      constraints [precision: 10, scale: 6]
    end
    
    attribute :request_duration_ms, :integer do
      allow_nil? false
    end
    
    attribute :workspace_id, :uuid
    attribute :team_id, :uuid
    attribute :user_id, :uuid
    
    attribute :success, :boolean do
      default true
    end
    
    attribute :error_type, :string
    attribute :error_message, :string
    
    timestamps()
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :by_provider do
      argument :provider, :atom do
        allow_nil? false
      end
      filter expr(provider == ^arg(:provider))
    end
    
    read :by_workspace do
      argument :workspace_id, :uuid do
        allow_nil? false
      end
      filter expr(workspace_id == ^arg(:workspace_id))
    end
    
    read :by_team do
      argument :team_id, :uuid do
        allow_nil? false
      end
      filter expr(team_id == ^arg(:team_id))
    end
    
    read :recent_usage do
      argument :days, :integer do
        default 7
      end
      filter expr(inserted_at >= ago(^arg(:days), :day))
    end
    
    read :cost_summary do
      prepare build(sort: [inserted_at: :desc])
    end
  end
  
  aggregates do
    sum :daily_cost, :estimated_cost_usd do
      filter expr(inserted_at >= ago(1, :day))
    end
    
    sum :monthly_cost, :estimated_cost_usd do
      filter expr(inserted_at >= ago(30, :day))
    end
    
    count :total_requests, :id
  end
  
  calculations do
    calculate :provider_breakdown, {:array, :map}, expr(
      fragment("""
      SELECT json_agg(
        json_build_object(
          'provider', provider,
          'cost', SUM(estimated_cost_usd),
          'tokens', SUM(total_tokens),
          'requests', COUNT(*)
        )
      )
      FROM ai_usage_logs
      WHERE inserted_at >= NOW() - INTERVAL '30 days'
      GROUP BY provider
      """)
    )
    
    calculate :hourly_usage, {:array, :map}, expr(
      fragment("""
      SELECT json_agg(
        json_build_object(
          'hour', DATE_TRUNC('hour', inserted_at),
          'cost', SUM(estimated_cost_usd),
          'tokens', SUM(total_tokens),
          'requests', COUNT(*)
        ) ORDER BY DATE_TRUNC('hour', inserted_at)
      )
      FROM ai_usage_logs
      WHERE inserted_at >= NOW() - INTERVAL '24 hours'
      GROUP BY DATE_TRUNC('hour', inserted_at)
      """)
    )
  end
  
  @doc """
  Log AI usage with cost calculation.
  """
  def log_usage(params) do
    params_with_cost = calculate_cost(params)
    
    Ash.create(__MODULE__, params_with_cost)
  end
  
  @doc """
  Get current cost for a provider today.
  """
  def daily_cost(provider) do
    today = Date.utc_today()
    
    __MODULE__
    |> Ash.Query.for_read(:by_provider, %{provider: provider})
    |> Ash.Query.filter(expr(fragment("DATE(?)", inserted_at) == ^today))
    |> Ash.read!()
    |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.estimated_cost_usd))
  end
  
  @doc """
  Check if usage is within budget limits.
  """
  def within_budget?(provider, budget_limit_usd) do
    current_cost = daily_cost(provider)
    Decimal.compare(current_cost, Decimal.new(budget_limit_usd)) != :gt
  end
  
  @doc """
  Get usage statistics for analytics.
  """
  def get_usage_stats(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    workspace_id = Keyword.get(opts, :workspace_id)
    team_id = Keyword.get(opts, :team_id)
    
    query = 
      __MODULE__
      |> Ash.Query.for_read(:recent_usage, %{days: days})
    
    query = 
      case {workspace_id, team_id} do
        {ws_id, nil} when not is_nil(ws_id) ->
          Ash.Query.filter(query, expr(workspace_id == ^ws_id))
        {nil, t_id} when not is_nil(t_id) ->
          Ash.Query.filter(query, expr(team_id == ^t_id))
        _ ->
          query
      end
    
    results = Ash.read!(query)
    
    %{
      total_cost: Enum.reduce(results, Decimal.new(0), &Decimal.add(&2, &1.estimated_cost_usd)),
      total_tokens: Enum.reduce(results, 0, &(&2 + &1.total_tokens)),
      total_requests: length(results),
      providers: group_by_provider(results),
      task_types: group_by_task_type(results),
      daily_breakdown: group_by_day(results)
    }
  end
  
  # Private functions
  
  @provider_costs %{
    anthropic: %{
      "claude-3-opus-20240229" => %{input: 0.000015, output: 0.000075},
      "claude-3-sonnet-20240229" => %{input: 0.000003, output: 0.000015},
      "claude-3-haiku-20240307" => %{input: 0.00000025, output: 0.00000125}
    },
    openai: %{
      "gpt-4-turbo-preview" => %{input: 0.00001, output: 0.00003},
      "gpt-4" => %{input: 0.00003, output: 0.00006},
      "text-embedding-3-large" => %{input: 0.00000013, output: 0}
    },
    xai: %{
      "grok-2" => %{input: 0.000002, output: 0.000010},
      "grok-1" => %{input: 0.0000015, output: 0.000008}
    }
  }
  
  defp calculate_cost(params) do
    provider = params.provider
    model = params.model_used
    input_tokens = params.input_tokens || 0
    output_tokens = params.output_tokens || 0
    
    costs = @provider_costs[provider][model]
    
    if costs do
      input_cost = Decimal.mult(Decimal.new(input_tokens), Decimal.new(costs.input))
      output_cost = Decimal.mult(Decimal.new(output_tokens), Decimal.new(costs.output))
      total_cost = Decimal.add(input_cost, output_cost)
      
      params
      |> Map.put(:total_tokens, input_tokens + output_tokens)
      |> Map.put(:estimated_cost_usd, total_cost)
    else
      params
      |> Map.put(:total_tokens, input_tokens + output_tokens)
      |> Map.put(:estimated_cost_usd, Decimal.new(0))
    end
  end
  
  defp group_by_provider(logs) do
    logs
    |> Enum.group_by(& &1.provider)
    |> Enum.map(fn {provider, logs} ->
      %{
        provider: provider,
        cost: Enum.reduce(logs, Decimal.new(0), &Decimal.add(&2, &1.estimated_cost_usd)),
        tokens: Enum.reduce(logs, 0, &(&2 + &1.total_tokens)),
        requests: length(logs)
      }
    end)
  end
  
  defp group_by_task_type(logs) do
    logs
    |> Enum.group_by(& &1.task_type)
    |> Enum.map(fn {task_type, logs} ->
      %{
        task_type: task_type,
        cost: Enum.reduce(logs, Decimal.new(0), &Decimal.add(&2, &1.estimated_cost_usd)),
        tokens: Enum.reduce(logs, 0, &(&2 + &1.total_tokens)),
        requests: length(logs)
      }
    end)
  end
  
  defp group_by_day(logs) do
    logs
    |> Enum.group_by(&Date.to_string(DateTime.to_date(&1.inserted_at)))
    |> Enum.map(fn {date, logs} ->
      %{
        date: date,
        cost: Enum.reduce(logs, Decimal.new(0), &Decimal.add(&2, &1.estimated_cost_usd)),
        tokens: Enum.reduce(logs, 0, &(&2 + &1.total_tokens)),
        requests: length(logs)
      }
    end)
    |> Enum.sort_by(& &1.date)
  end
end