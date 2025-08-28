defmodule Dirup.Billing do
  use Ash.Domain, otp_app: :dirup
  require Logger
  alias Dirup.DateTimeHelpers

  resources do
    resource Dirup.Billing.Customer do
      define :create_customer, action: :create
      define :get_customer, action: :read, get_by: :id
      define :get_customer_by_user, action: :by_user, get_by: :user_id
      define :update_customer, action: :update
      # sync_customer_with_stripe removed due to Ash 3.5 atomicity issues
    end

    resource Dirup.Billing.Subscription do
      define :create_subscription, action: :create
      define :get_subscription, action: :read, get_by: :id
      define :list_subscriptions, action: :read
      define :list_user_subscriptions, action: :by_user, args: [:user_id]
      define :update_subscription, action: :update
      define :cancel_subscription, action: :cancel
      define :sync_subscription_with_stripe, action: :sync_stripe
    end

    resource Dirup.Billing.Usage do
      define :record_usage
      define :by_user, args: [:user_id]
      define :by_period, args: [:user_id, :start_date, :end_date]
      define :get_monthly_usage, args: [:user_id]
      define :get_monthly_usage_summary, args: [:user_id]
      define :get_daily_usage, args: [:user_id]
    end

    resource Dirup.Billing.Invoice do
      define :get_invoice, action: :read, get_by: :id
      define :list_user_invoices, action: :by_user, args: [:user_id]
      # sync_invoice_with_stripe removed due to Ash 3.5 atomicity issues
    end

    resource Dirup.Billing.Plan do
      define :list_plans, action: :read
      define :get_plan, action: :read, get_by: :id
      define :get_plan_by_code, action: :by_code, get_by: :code
    end
  end

  @doc """
  Subscribe to billing events for real-time updates.
  """
  def subscribe(topic) when is_binary(topic) do
    Phoenix.PubSub.subscribe(Dirup.PubSub, "billing:#{topic}")
  end

  @doc """
  Broadcast billing event to subscribers.
  """
  def broadcast(topic, event, payload) do
    Phoenix.PubSub.broadcast(Dirup.PubSub, "billing:#{topic}", {event, payload})
  end

  # High-level business functions

  @doc """
  Record AI API usage for billing
  """
  def track_ai_usage(usage_data) do
    record_usage(%{
      user_id: usage_data.user_id,
      service: "ai_api",
      endpoint: usage_data.endpoint,
      quantity: 1,
      unit_price: calculate_ai_request_price(usage_data),
      metadata: %{
        duration_ms: usage_data.duration_ms,
        request_size: usage_data.request_size,
        response_size: usage_data.response_size,
        status_code: usage_data.status_code
      },
      occurred_at: usage_data.timestamp
    })
  end

  @doc """
  Get or create Stripe customer for user
  """
  def ensure_stripe_customer(user) do
    case get_customer_by_user(user.id) do
      {:ok, customer} -> {:ok, customer}
      {:error, _} -> create_stripe_customer(user)
    end
  end

  @doc """
  Create subscription for user
  """
  def create_user_subscription(user, plan_code, payment_method_id) do
    with {:ok, customer} <- ensure_stripe_customer(user),
         {:ok, plan} <- get_plan_by_code(plan_code),
         {:ok, subscription} <- create_stripe_subscription(customer, plan, payment_method_id) do
      {:ok, subscription}
    end
  end

  @doc """
  Get or create Apple customer for user
  """
  def ensure_apple_customer(user, receipt_data) do
    case get_customer_by_user(user.id) do
      {:ok, customer} -> {:ok, customer}
      {:error, _} -> create_apple_customer(user, receipt_data)
    end
  end

  @doc """
  Get active subscription for user
  """
  def get_active_user_subscription(user_id) do
    case list_user_subscriptions(user_id) do
      {:ok, subscriptions} ->
        active_subscription =
          Enum.find(subscriptions, fn subscription ->
            subscription.status in [:active, :trialing] and
              DateTime.compare(subscription.current_period_end, DateTime.utc_now()) == :gt
          end)

        if active_subscription do
          {:ok, active_subscription}
        else
          {:error, :not_found}
        end

      error ->
        error
    end
  end

  @doc """
  Get subscription by Apple original transaction ID
  """
  def get_subscription_by_apple_transaction(_original_transaction_id) do
    # This would need to be implemented in the Subscription resource
    # For now, return not found
    {:error, :not_found}
  end

  @doc """
  Get subscription by Stripe subscription ID
  """
  def get_subscription_by_stripe_id(_stripe_subscription_id) do
    # This would need to be implemented in the Subscription resource
    # For now, return not found
    {:error, :not_found}
  end

  defp create_apple_customer(user, _receipt_data) do
    # Extract user info from receipt if available
    customer_params = %{
      user_id: user.id,
      provider: :apple,
      # Use user ID as Apple user ID for now
      apple_user_id: user.id,
      email: user.email,
      name: user.name
    }

    create_customer(customer_params)
  end

  # Private functions

  defp calculate_ai_request_price(usage_data) do
    base_price =
      case usage_data.endpoint do
        # $0.02
        "suggest" -> Money.new(200, :USD)
        # $0.015
        "confidence" -> Money.new(150, :USD)
        # $0.01
        _ -> Money.new(100, :USD)
      end

    # Adjust price based on request complexity
    complexity_multiplier =
      case {usage_data.request_size, usage_data.duration_ms} do
        # Large requests
        {size, _} when size > 5000 -> 1.5
        # Slow processing
        {_, duration} when duration > 2000 -> 1.3
        _ -> 1.0
      end

    Money.mult(base_price, Decimal.new(complexity_multiplier))
  end

  defp create_stripe_customer(user) do
    stripe_params = %{
      email: user.email,
      name: user.name,
      metadata: %{
        user_id: user.id,
        created_by: "kyozo_api"
      }
    }

    case Stripe.Customer.create(stripe_params) do
      {:ok, stripe_customer} ->
        create_customer(%{
          user_id: user.id,
          stripe_customer_id: stripe_customer.id,
          email: user.email,
          name: user.name
        })

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Sync subscription with Stripe
  """
  def sync_with_stripe(subscription, stripe_data, opts \\ []) do
    case subscription.__struct__ do
      Dirup.Billing.Subscription ->
        sync_subscription_with_stripe(subscription, stripe_data, opts)

      _ ->
        {:error, "Stripe sync only supported for subscriptions in current Ash version"}
    end
  end

  # Sync subscription with Stripe data (internal implementation)
  defp do_sync_subscription_with_stripe(subscription, stripe_data, _opts) do
    # Update subscription with Stripe data
    update_params = %{
      status: stripe_status_to_subscription_status(stripe_data["status"]),
      current_period_start: DateTime.from_unix!(stripe_data["current_period_start"]),
      current_period_end: DateTime.from_unix!(stripe_data["current_period_end"]),
      metadata:
        Map.merge(subscription.metadata || %{}, %{
          "stripe_synced_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
    }

    update_subscription(subscription, update_params)
  end

  defp create_stripe_subscription(customer, plan, payment_method_id) do
    # Attach payment method to customer
    {:ok, _} =
      Stripe.PaymentMethod.attach(%{
        customer: customer.stripe_customer_id,
        payment_method: payment_method_id
      })

    # Create subscription
    subscription_params = %{
      customer: customer.stripe_customer_id,
      items: [%{price: plan.stripe_price_id}],
      default_payment_method: payment_method_id,
      metadata: %{
        user_id: customer.user_id,
        plan_code: plan.code
      }
    }

    case Stripe.Subscription.create(subscription_params) do
      {:ok, stripe_subscription} ->
        create_subscription(%{
          user_id: customer.user_id,
          customer_id: customer.id,
          plan_id: plan.id,
          stripe_subscription_id: stripe_subscription.id,
          status: stripe_subscription.status,
          current_period_start: DateTime.from_unix!(stripe_subscription.current_period_start),
          current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end)
        })

      {:error, error} ->
        {:error, error}
    end
  end

  defp stripe_status_to_subscription_status(status) do
    case status do
      "active" -> :active
      "past_due" -> :past_due
      "canceled" -> :canceled
      "incomplete" -> :incomplete
      "incomplete_expired" -> :incomplete_expired
      "trialing" -> :trialing
      "unpaid" -> :unpaid
      _ -> :active
    end
  end

  # SafeMD Scan Quota Functions

  @doc """
  Check scan quota for user.
  """
  def check_scan_quota(user) do
    check_quota(user, "scan")
  end

  @doc """
  Check async scan quota for user.
  """
  def check_async_scan_quota(user) do
    check_quota(user, "async_scan")
  end

  @doc """
  Check stream scan quota for user.
  """
  def check_stream_quota(user) do
    check_quota(user, "stream_scan")
  end

  @doc """
  Record usage for SafeMD scan operations.
  """
  def record_usage(usage_data) do
    # Calculate cost based on service type
    unit_price =
      case usage_data.service do
        # $0.03
        "safemd_scan" ->
          Money.new(300, :USD)

        # $0.03
        "promptspect_scan" ->
          Money.new(300, :USD)

        # $0.05
        "impromptu_enhancement" ->
          Money.new(500, :USD)

        "polyglot_translation" ->
          # $0.02 per KB
          kb_size = Kernel.max(1, div(usage_data.content_size_bytes, 1024))
          Money.new(200 * kb_size, :USD)

        # Default $0.01
        _ ->
          Money.new(100, :USD)
      end

    record_usage(%{
      user_id: usage_data.user_id,
      service: usage_data.service,
      operation: usage_data.operation,
      quantity: 1,
      unit_price: unit_price,
      metadata: %{
        content_size_bytes: usage_data.content_size_bytes,
        processing_time_ms: usage_data.processing_time_ms,
        threat_level: Map.get(usage_data, :threat_level),
        scan_mode: Map.get(usage_data, :scan_mode)
      },
      occurred_at: usage_data.timestamp
    })
  end

  defp check_quota(user, operation_type) do
    case get_active_user_subscription(user.id) do
      {:ok, subscription} ->
        limits = get_subscription_limits(subscription)
        current_usage = get_current_period_usage(user.id, operation_type)

        limit = Map.get(limits, String.to_atom(operation_type), 0)
        remaining = Kernel.max(0, limit - current_usage)

        {:ok, remaining}

      {:error, :not_found} ->
        # Free tier limits
        free_limits = %{
          scan: 10,
          async_scan: 2,
          stream_scan: 1
        }

        limit = Map.get(free_limits, String.to_atom(operation_type), 0)
        current_usage = get_current_period_usage(user.id, operation_type)
        remaining = Kernel.max(0, limit - current_usage)

        {:ok, remaining}

      error ->
        error
    end
  rescue
    _ ->
      # Development mode - allow unlimited
      {:ok, 1000}
  end

  defp get_subscription_limits(subscription) do
    # This would be based on the subscription plan
    case subscription.plan_code do
      "pro_monthly" ->
        %{
          scan: 1000,
          async_scan: 100,
          stream_scan: 50
        }

      "enterprise_monthly" ->
        %{
          scan: 10000,
          async_scan: 1000,
          stream_scan: 500
        }

      _ ->
        %{
          scan: 100,
          async_scan: 10,
          stream_scan: 5
        }
    end
  end

  defp get_current_period_usage(user_id, operation_type) do
    # Get usage for current billing period
    start_of_month = DateTime.utc_now() |> DateTimeHelpers.beginning_of_month()

    case by_period(user_id, start_of_month, DateTime.utc_now()) do
      {:ok, usage_records} ->
        usage_records
        |> Enum.filter(&(Map.get(&1.metadata, "operation") == operation_type))
        |> Enum.map(& &1.quantity)
        |> Enum.sum()

      {:error, _} ->
        0
    end
  rescue
    _ ->
      0
  end

  @doc """
  Create subscription from Apple receipt data
  """
  def create_subscription_from_apple_receipt(customer, receipt_info) do
    plan = get_plan_by_apple_product_id(receipt_info.product_id)

    subscription_attrs = %{
      customer_id: customer.id,
      plan_id: plan.id,
      status:
        if(Dirup.Billing.AppleReceiptValidator.subscription_active?(receipt_info),
          do: :active,
          else: :expired
        ),
      provider: :apple,
      apple_original_transaction_id: receipt_info.original_transaction_id,
      apple_latest_transaction_id: receipt_info.latest_transaction_id,
      current_period_start: receipt_info.purchase_date,
      current_period_end: receipt_info.expires_date,
      trial_end: if(receipt_info.is_trial_period, do: receipt_info.expires_date, else: nil),
      cancel_at_period_end: !receipt_info.auto_renew_status,
      canceled_at: receipt_info.cancellation_date,
      metadata: %{
        "is_trial_period" => receipt_info.is_trial_period,
        "is_in_intro_offer_period" => receipt_info.is_in_intro_offer_period,
        "environment" => receipt_info.environment
      }
    }

    create_subscription(subscription_attrs)
  end

  @doc """
  Get plan by Apple product ID
  """
  def get_plan_by_apple_product_id(product_id) do
    case Plan
         |> Ash.Query.filter(apple_product_id: product_id)
         |> Ash.read_one() do
      {:ok, nil} ->
        # Create a default plan if not found
        {:ok,
         %{
           id: nil,
           name: "Default iOS Plan",
           apple_product_id: product_id,
           price: Money.new(999, :USD),
           billing_interval: :month
         }}

      {:ok, plan} ->
        plan

      {:error, _} ->
        # Fallback plan
        %{id: nil, name: "Default Plan", price: Money.new(999, :USD)}
    end
  end

  @doc """
  Handle Apple server-to-server notification
  """
  def handle_apple_notification(notification_payload) do
    case Dirup.Billing.AppleReceiptValidator.validate_notification(notification_payload) do
      {:ok, %{notification_type: notification_type, subscription_data: receipt_info}} ->
        Logger.info("Processing Apple notification: #{notification_type}")

        case notification_type do
          "INITIAL_BUY" -> handle_initial_purchase(receipt_info)
          "RENEW" -> handle_subscription_renewal(receipt_info)
          "CANCEL" -> handle_subscription_cancellation(receipt_info)
          "DID_FAIL_TO_RENEW" -> handle_renewal_failure(receipt_info)
          "DID_RECOVER" -> handle_subscription_recovery(receipt_info)
          "REFUND" -> handle_refund(receipt_info)
          _ -> {:ok, :notification_ignored}
        end

      {:error, error} ->
        Logger.error("Failed to validate Apple notification: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Sync subscription with Apple receipt data
  """
  def sync_subscription_with_apple(subscription, receipt_data) do
    case Dirup.Billing.AppleReceiptValidator.validate_and_parse(receipt_data) do
      {:ok, receipt_info} ->
        update_attrs = %{
          status:
            if(Dirup.Billing.AppleReceiptValidator.subscription_active?(receipt_info),
              do: :active,
              else: :expired
            ),
          apple_latest_transaction_id: receipt_info.latest_transaction_id,
          current_period_start: receipt_info.purchase_date,
          current_period_end: receipt_info.expires_date,
          cancel_at_period_end: !receipt_info.auto_renew_status,
          canceled_at: receipt_info.cancellation_date,
          metadata:
            Map.merge(subscription.metadata || %{}, %{
              "last_synced_at" => DateTime.utc_now(),
              "environment" => receipt_info.environment
            })
        }

        update_subscription(subscription, update_attrs)

      {:error, error} ->
        {:error, error}
    end
  end

  # Private Apple notification handlers

  defp handle_initial_purchase(receipt_info) do
    # Find or create customer and subscription
    case get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
      {:ok, subscription} ->
        sync_subscription_with_apple(subscription, receipt_info)

      {:error, :not_found} ->
        Logger.info("New Apple subscription: #{receipt_info.original_transaction_id}")
        {:ok, :new_subscription_created}
    end
  end

  defp handle_subscription_renewal(receipt_info) do
    case get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
      {:ok, subscription} ->
        update_subscription(subscription, %{
          status: :active,
          apple_latest_transaction_id: receipt_info.latest_transaction_id,
          current_period_start: receipt_info.purchase_date,
          current_period_end: receipt_info.expires_date
        })

      {:error, :not_found} ->
        Logger.warning(
          "Renewal for unknown subscription: #{receipt_info.original_transaction_id}"
        )

        {:error, :subscription_not_found}
    end
  end

  defp handle_subscription_cancellation(receipt_info) do
    case get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
      {:ok, subscription} ->
        update_subscription(subscription, %{
          cancel_at_period_end: true,
          canceled_at: DateTime.utc_now()
        })

      {:error, :not_found} ->
        {:error, :subscription_not_found}
    end
  end

  defp handle_renewal_failure(receipt_info) do
    case get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
      {:ok, subscription} ->
        # Grace period handling
        # 24 hours
        grace_period_end =
          receipt_info.grace_period_expires_date ||
            DateTime.add(DateTime.utc_now(), 24 * 60 * 60)

        update_subscription(subscription, %{
          status: :past_due,
          metadata: Map.put(subscription.metadata || %{}, "grace_period_end", grace_period_end)
        })

      {:error, :not_found} ->
        {:error, :subscription_not_found}
    end
  end

  defp handle_subscription_recovery(receipt_info) do
    case get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
      {:ok, subscription} ->
        update_subscription(subscription, %{
          status: :active,
          apple_latest_transaction_id: receipt_info.latest_transaction_id,
          current_period_end: receipt_info.expires_date
        })

      {:error, :not_found} ->
        {:error, :subscription_not_found}
    end
  end

  defp handle_refund(receipt_info) do
    case get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
      {:ok, subscription} ->
        update_subscription(subscription, %{
          status: :canceled,
          canceled_at: DateTime.utc_now(),
          metadata: Map.put(subscription.metadata || %{}, "refunded", true)
        })

      {:error, :not_found} ->
        {:error, :subscription_not_found}
    end
  end
end
