defmodule DirupWeb.Plugs.AIUsageTracking do
  @moduledoc """
  Tracks AI API usage for billing and rate limiting
  """
  import Plug.Conn
  alias Dirup.Billing

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> track_request_start()
    |> register_before_send(&track_request_completion/1)
  end

  defp track_request_start(conn) do
    assign(conn, :ai_request_start, System.monotonic_time(:millisecond))
  end

  defp track_request_completion(conn) do
    start_time = conn.assigns[:ai_request_start]

    if start_time do
      duration = System.monotonic_time(:millisecond) - start_time

      # Track usage metrics
      user_id = get_current_user_id(conn)
      team_id = get_current_team_id(conn)
      endpoint = get_ai_endpoint(conn)

      usage_data = %{
        user_id: user_id,
        team_id: team_id,
        endpoint: endpoint,
        duration_ms: duration,
        request_size: get_request_size(conn),
        response_size: get_response_size(conn),
        status_code: conn.status,
        timestamp: DateTime.utc_now()
      }

      # Async usage tracking (don't block response)
      Task.start(fn ->
        Billing.track_ai_usage(usage_data)
        update_rate_limit_counters(user_id, team_id, endpoint)
      end)
    end

    conn
  end

  defp get_current_user_id(conn) do
    case conn.assigns[:current_user] do
      nil -> nil
      user -> user.id
    end
  end

  defp get_current_team_id(conn) do
    case conn.assigns[:current_team] do
      nil -> nil
      team -> team.id
    end
  end

  defp get_ai_endpoint(conn) do
    case conn.path_info do
      ["api", "v1", "ai", "suggest"] -> "suggest"
      ["api", "v1", "ai", "confidence"] -> "confidence"
      _ -> "unknown"
    end
  end

  defp get_request_size(conn) do
    # Estimate request size from body
    case conn.assigns[:raw_body] do
      nil -> 0
      body -> byte_size(body)
    end
  end

  defp get_response_size(conn) do
    # Get response size if available
    case get_resp_header(conn, "content-length") do
      [size] -> String.to_integer(size)
      _ -> 0
    end
  end

  defp update_rate_limit_counters(user_id, team_id, endpoint) do
    # Update Redis/ETS counters for rate limiting
    Dirup.RateLimit.increment_usage(user_id, endpoint)
    if team_id, do: Dirup.RateLimit.increment_usage(team_id, endpoint)
  end
end
