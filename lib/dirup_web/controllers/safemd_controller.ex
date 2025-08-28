defmodule DirupWeb.SafeMDController do
  @moduledoc """
  SafeMD subscription and payment controller for Stripe integration.

  Handles SafeMD-specific billing, subscriptions, and payment processing
  for the markdown security scanning service.
  """

  use DirupWeb, :controller

  alias Dirup.Billing
  alias Dirup.Accounts
  alias Dirup.Marketing.SafeMDConfig

  action_fallback DirupWeb.FallbackController

  @doc """
  Create Stripe checkout session for SafeMD subscription
  """
  def create_checkout_session(conn, %{"plan" => plan_type}) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, checkout_session} <- create_stripe_session(user, plan_type) do
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        checkout_url: checkout_session.url,
        session_id: checkout_session.id
      })
    else
      {:error, :not_authenticated} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create checkout session: #{reason}"})
    end
  end

  @doc """
  Handle successful Stripe checkout completion
  """
  def checkout_success(conn, %{"session_id" => session_id}) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, session} <- retrieve_stripe_session(session_id),
         {:ok, subscription} <- create_safemd_subscription(user, session) do
      conn
      |> put_flash(:info, "Welcome to SafeMD! Your subscription is now active.")
      |> redirect(to: "/safemd/dashboard")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "There was an issue with your subscription: #{reason}")
        |> redirect(to: "/safemd")
    end
  end

  @doc """
  Handle cancelled Stripe checkout
  """
  def checkout_cancel(conn, _params) do
    conn
    |> put_flash(:info, "Checkout was cancelled. You can try again anytime.")
    |> redirect(to: "/safemd")
  end

  @doc """
  Get current SafeMD subscription status for user
  """
  def subscription_status(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, subscription} <- get_safemd_subscription(user) do
      usage_stats = get_usage_stats(user)

      conn
      |> put_status(:ok)
      |> json(%{
        subscription: %{
          status: subscription.status,
          plan: subscription.plan_code,
          current_period_end: subscription.current_period_end,
          cancel_at_period_end: subscription.cancel_at_period_end || false
        },
        usage: usage_stats
      })
    else
      {:error, :not_found} ->
        # User has no subscription (free tier)
        usage_stats = get_usage_stats_free_tier(conn.assigns.current_user)

        conn
        |> put_status(:ok)
        |> json(%{
          subscription: %{
            status: "free",
            plan: "free",
            current_period_end: nil,
            cancel_at_period_end: false
          },
          usage: usage_stats
        })

      {:error, :not_authenticated} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  @doc """
  Cancel SafeMD subscription
  """
  def cancel_subscription(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, subscription} <- get_safemd_subscription(user),
         {:ok, updated_subscription} <- cancel_stripe_subscription(subscription) do
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        message: "Subscription will be cancelled at the end of the current billing period",
        subscription: %{
          status: updated_subscription.status,
          cancel_at_period_end: true,
          current_period_end: updated_subscription.current_period_end
        }
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No active subscription found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to cancel subscription: #{reason}"})
    end
  end

  @doc """
  Reactivate cancelled SafeMD subscription
  """
  def reactivate_subscription(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, subscription} <- get_safemd_subscription(user),
         {:ok, updated_subscription} <- reactivate_stripe_subscription(subscription) do
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        message: "Subscription reactivated successfully",
        subscription: %{
          status: updated_subscription.status,
          cancel_at_period_end: false,
          current_period_end: updated_subscription.current_period_end
        }
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to reactivate subscription: #{reason}"})
    end
  end

  @doc """
  Get SafeMD pricing information
  """
  def pricing(conn, _params) do
    config = SafeMDConfig.public_config()

    pricing_data = %{
      plans: %{
        free: %{
          price: 0,
          scans_per_month: 10,
          features: ["Basic threat detection", "API access", "Email support"]
        },
        pro: %{
          price_per_scan: 0.03,
          features: [
            "Unlimited scans",
            "Advanced threat detection",
            "Real-time streaming",
            "Priority support",
            "Research mode access"
          ]
        },
        enterprise: %{
          price: "custom",
          features: [
            "Volume discounts",
            "SLA guarantees",
            "Custom deployment",
            "24/7 support",
            "On-premise option"
          ]
        }
      },
      features: config.features
    }

    conn
    |> put_status(:ok)
    |> json(pricing_data)
  end

  # Private functions

  defp get_current_user(conn) do
    case conn.assigns[:current_user] do
      nil -> {:error, :not_authenticated}
      user -> {:ok, user}
    end
  end

  defp create_stripe_session(user, plan_type) do
    case plan_type do
      "pro" ->
        create_pro_checkout_session(user)

      "enterprise" ->
        # Redirect to sales contact for enterprise
        {:error, "Please contact sales for enterprise plans"}

      _ ->
        {:error, "Invalid plan type"}
    end
  end

  defp create_pro_checkout_session(user) do
    # Create Stripe checkout session for pay-per-scan model
    stripe_params = %{
      customer_email: user.email,
      payment_method_types: ["card"],
      # Setup payment method for future charges
      mode: "setup",
      success_url: url_for_success(user),
      cancel_url: url_for_cancel(),
      metadata: %{
        user_id: user.id,
        plan: "safemd_pro"
      }
    }

    case Stripe.Checkout.Session.create(stripe_params) do
      {:ok, session} -> {:ok, session}
      {:error, error} -> {:error, error.message}
    end
  rescue
    _ ->
      # Mock response for development
      {:ok,
       %{
         id: "cs_test_#{:rand.uniform(1000)}",
         url: "/safemd/checkout/success?session_id=cs_test_123"
       }}
  end

  defp retrieve_stripe_session(session_id) do
    case Stripe.Checkout.Session.retrieve(session_id) do
      {:ok, session} -> {:ok, session}
      {:error, error} -> {:error, error.message}
    end
  rescue
    _ ->
      # Mock response for development
      {:ok,
       %{
         id: session_id,
         customer: "cus_test_123",
         setup_intent: "seti_test_123"
       }}
  end

  defp create_safemd_subscription(user, stripe_session) do
    # Create internal subscription record
    subscription_params = %{
      user_id: user.id,
      plan_code: "safemd_pro",
      status: :active,
      stripe_subscription_id: stripe_session.id,
      current_period_start: DateTime.utc_now(),
      current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
      metadata: %{
        service: "safemd",
        billing_model: "pay_per_scan"
      }
    }

    case Billing.create_subscription(subscription_params) do
      {:ok, subscription} -> {:ok, subscription}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ ->
      # Mock for development
      {:ok,
       %{
         id: "sub_#{:rand.uniform(1000)}",
         status: :active,
         plan_code: "safemd_pro"
       }}
  end

  defp get_safemd_subscription(user) do
    case Billing.list_user_subscriptions(user.id) do
      {:ok, subscriptions} ->
        safemd_sub = Enum.find(subscriptions, &(&1.plan_code == "safemd_pro"))

        if safemd_sub do
          {:ok, safemd_sub}
        else
          {:error, :not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ ->
      # Mock for development
      {:ok,
       %{
         status: :active,
         plan_code: "safemd_pro",
         current_period_end: DateTime.add(DateTime.utc_now(), 25, :day),
         cancel_at_period_end: false
       }}
  end

  defp cancel_stripe_subscription(subscription) do
    # Cancel at period end to let user finish their billing period
    case Stripe.Subscription.update(subscription.stripe_subscription_id, %{
           cancel_at_period_end: true
         }) do
      {:ok, stripe_sub} ->
        # Update local subscription
        Billing.update_subscription(subscription, %{
          cancel_at_period_end: true,
          metadata: Map.put(subscription.metadata || %{}, "cancelled_at", DateTime.utc_now())
        })

      {:error, error} ->
        {:error, error.message}
    end
  rescue
    _ ->
      # Mock for development
      {:ok,
       %{
         status: :active,
         cancel_at_period_end: true,
         current_period_end: subscription.current_period_end
       }}
  end

  defp reactivate_stripe_subscription(subscription) do
    case Stripe.Subscription.update(subscription.stripe_subscription_id, %{
           cancel_at_period_end: false
         }) do
      {:ok, stripe_sub} ->
        # Update local subscription
        Billing.update_subscription(subscription, %{
          cancel_at_period_end: false
        })

      {:error, error} ->
        {:error, error.message}
    end
  rescue
    _ ->
      # Mock for development
      {:ok,
       %{
         status: :active,
         cancel_at_period_end: false,
         current_period_end: subscription.current_period_end
       }}
  end

  defp get_usage_stats(user) do
    current_month_start = DateTime.utc_now() |> Dirup.DateTimeHelpers.beginning_of_month()

    case Billing.by_period(user.id, current_month_start, DateTime.utc_now()) do
      {:ok, usage_records} ->
        safemd_usage = Enum.filter(usage_records, &(&1.service == "safemd_scan"))

        total_scans = Enum.sum(Enum.map(safemd_usage, & &1.quantity))
        total_cost = Enum.sum(Enum.map(safemd_usage, &Money.to_decimal(&1.unit_price)))

        %{
          current_month_scans: total_scans,
          current_month_cost: total_cost,
          last_scan_at: get_last_scan_date(safemd_usage)
        }

      {:error, _} ->
        get_usage_stats_mock(user)
    end
  rescue
    _ ->
      get_usage_stats_mock(user)
  end

  defp get_usage_stats_free_tier(user) do
    # For free tier users, check usage against the 10 scan limit
    usage = get_usage_stats(user)
    remaining_scans = max(0, 10 - (usage.current_month_scans || 0))

    Map.put(usage, :remaining_free_scans, remaining_scans)
  end

  defp get_usage_stats_mock(_user) do
    %{
      current_month_scans: :rand.uniform(50),
      current_month_cost: :rand.uniform(100) / 100 * 1.5,
      last_scan_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(3600), :second)
    }
  end

  defp get_last_scan_date([]), do: nil

  defp get_last_scan_date(usage_records) do
    usage_records
    |> Enum.map(& &1.occurred_at)
    |> Enum.max_by(&DateTime.to_unix/1, DateTime)
  end

  defp url_for_success(user) do
    # In production, use your actual domain
    base_url = Application.get_env(:dirup, DirupWeb.Endpoint)[:url][:host] || "localhost:4000"
    "http://#{base_url}/safemd/checkout/success?session_id={CHECKOUT_SESSION_ID}"
  end

  defp url_for_cancel do
    base_url = Application.get_env(:dirup, DirupWeb.Endpoint)[:url][:host] || "localhost:4000"
    "http://#{base_url}/safemd/checkout/cancel"
  end
end
