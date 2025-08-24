defmodule KyozoWeb.Plugs.AIRateLimit do
  @moduledoc """
  Rate limiting for AI API endpoints based on user tier
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias Kyozo.{Accounts, RateLimit}

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    case check_rate_limit(user, get_endpoint(conn)) do
      {:ok, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        |> put_resp_header("x-ratelimit-reset", get_reset_time())

      {:error, :rate_limited, reset_in} ->
        conn
        |> put_status(429)
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> put_resp_header("retry-after", to_string(reset_in))
        |> json(%{
          error: "Rate limit exceeded",
          message: "Too many AI requests. Upgrade your plan or try again later.",
          retry_after_seconds: reset_in
        })
        |> halt()

      {:error, :no_subscription} ->
        conn
        |> put_status(402)
        |> json(%{
          error: "Payment required",
          message: "AI features require an active subscription"
        })
        |> halt()
    end
  end

  defp check_rate_limit(nil, _endpoint), do: {:error, :no_subscription}

  defp check_rate_limit(user, endpoint) do
    # Get user's current plan and usage
    plan = Accounts.get_user_plan(user)
    current_usage = RateLimit.get_usage(user.id, endpoint, :monthly)

    case plan.ai_requests_per_month do
      :unlimited ->
        {:ok, :unlimited}

      limit when current_usage >= limit ->
        reset_in = seconds_until_month_reset()
        {:error, :rate_limited, reset_in}

      limit ->
        {:ok, limit - current_usage}
    end
  end

  defp get_endpoint(conn) do
    case conn.path_info do
      ["api", "v1", "ai", "suggest"] -> "suggest"
      ["api", "v1", "ai", "confidence"] -> "confidence"
      _ -> "unknown"
    end
  end

  defp get_reset_time do
    DateTime.utc_now()
    |> DateTime.add(seconds_until_month_reset(), :second)
    |> DateTime.to_unix()
    |> to_string()
  end

  defp seconds_until_month_reset do
    now = DateTime.utc_now()
    next_month = %{now | day: 1} |> DateTime.add(32, :day) |> Map.put(:day, 1)
    DateTime.diff(next_month, now)
  end
end
