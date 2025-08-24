defmodule KyozoWeb.API.BillingController do
  use KyozoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Kyozo.Billing
  alias KyozoWeb.JSONAPI
  alias OpenApiSpex.Schema

  action_fallback KyozoWeb.FallbackController

  defmodule AppleReceiptRequest do
    @moduledoc """
    Request schema for Apple receipt validation
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Apple Receipt Validation",
      description: "Validate Apple App Store receipt",
      type: :object,
      properties: %{
        receipt_data: %Schema{
          type: :string,
          description: "Base64 encoded Apple receipt data",
          example: "MIITugYJKoZIhvcNAQcCoIITqzCCE6cCAQExCzAJBg..."
        },
        plan_code: %Schema{
          type: :string,
          description: "Plan code matching the Apple product ID",
          example: "pro_monthly"
        }
      },
      required: [:receipt_data, :plan_code]
    })
  end

  defmodule SubscriptionResponse do
    @moduledoc """
    Response schema for subscription operations
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Subscription Response",
      description: "Subscription status and details",
      type: :object,
      properties: %{
        subscription: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            provider: %Schema{type: :string, enum: ["stripe", "apple", "google"]},
            status: %Schema{type: :string, enum: ["active", "past_due", "canceled", "expired"]},
            current_period_end: %Schema{type: :string, format: :datetime},
            auto_renew_enabled: %Schema{type: :boolean},
            plan: %Schema{
              type: :object,
              properties: %{
                code: %Schema{type: :string},
                name: %Schema{type: :string},
                features: %Schema{type: :object}
              }
            }
          }
        },
        usage_limits: %Schema{
          type: :object,
          properties: %{
            ai_requests_per_month: %Schema{type: :integer},
            current_usage: %Schema{type: :integer},
            remaining_requests: %Schema{type: :integer}
          }
        }
      }
    })
  end

  operation(:validate_apple_receipt,
    summary: "Validate Apple App Store receipt",
    description: "Validate and process Apple In-App Purchase receipt for subscription",
    request_body: {"Apple Receipt", "application/json", AppleReceiptRequest},
    responses: %{
      200 => {"Subscription created/updated", "application/json", SubscriptionResponse},
      400 => {"Invalid receipt", "application/json", JSONAPI.Schemas.Error},
      404 => {"Plan not found", "application/json", JSONAPI.Schemas.Error}
    },
    tags: ["Billing"]
  )

  operation(:get_subscription_status,
    summary: "Get current subscription status",
    description: "Get user's current subscription status and usage limits",
    responses: %{
      200 => {"Subscription status", "application/json", SubscriptionResponse},
      404 => {"No active subscription", "application/json", JSONAPI.Schemas.Error}
    },
    tags: ["Billing"]
  )

  operation(:apple_webhook,
    summary: "Apple App Store server-to-server notification",
    description: "Handle Apple App Store subscription events",
    request_body: {"Apple Notification", "application/json", %Schema{type: :object}},
    responses: %{
      200 => {"Notification processed", "application/json", %Schema{type: :object}}
    },
    tags: ["Billing"]
  )

  def validate_apple_receipt(conn, params) do
    current_user = conn.assigns.current_user
    receipt_data = params["receipt_data"]
    plan_code = params["plan_code"]

    with {:ok, plan} <- Billing.get_plan_by_code(plan_code),
         {:ok, customer} <- Billing.ensure_apple_customer(current_user, receipt_data),
         {:ok, subscription} <- create_or_update_apple_subscription(customer, plan, receipt_data) do
      usage_limits = calculate_usage_limits(subscription)

      response = %{
        subscription: format_subscription_response(subscription),
        usage_limits: usage_limits
      }

      conn
      |> put_status(:ok)
      |> json(response)
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def get_subscription_status(conn, _params) do
    current_user = conn.assigns.current_user

    case Billing.get_active_user_subscription(current_user.id) do
      {:ok, subscription} ->
        usage_limits = calculate_usage_limits(subscription)

        response = %{
          subscription: format_subscription_response(subscription),
          usage_limits: usage_limits
        }

        conn
        |> put_status(:ok)
        |> json(response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No active subscription found"})
    end
  end

  def apple_webhook(conn, params) do
    # Verify the notification is from Apple (implement signature verification)
    case verify_apple_notification(conn, params) do
      :ok ->
        process_apple_notification(params)

        conn
        |> put_status(:ok)
        |> json(%{status: "processed"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  # Stripe webhook endpoint
  def stripe_webhook(conn, _params) do
    payload = conn.assigns.raw_body
    sig_header = get_req_header(conn, "stripe-signature") |> List.first()

    case Stripe.Webhook.construct_event(payload, sig_header, get_stripe_webhook_secret()) do
      {:ok, event} ->
        process_stripe_event(event)

        conn
        |> put_status(:ok)
        |> json(%{received: true})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  # Private helper functions

  defp create_or_update_apple_subscription(customer, plan, receipt_data) do
    case Billing.AppleReceiptValidator.validate_and_parse(receipt_data) do
      {:ok, receipt_info} ->
        # Check if subscription already exists
        case Billing.get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
          {:ok, existing_subscription} ->
            # Update existing subscription
            Billing.update_subscription(existing_subscription, %{
              current_period_end: receipt_info.expires_date,
              status: determine_apple_status(receipt_info),
              apple_auto_renew_status: receipt_info.auto_renew_status,
              apple_receipt_data: receipt_data
            })

          {:error, :not_found} ->
            # Create new subscription
            Billing.create_subscription(%{
              user_id: customer.user_id,
              customer_id: customer.id,
              plan_id: plan.id,
              provider: :apple,
              apple_transaction_id: receipt_info.latest_transaction_id,
              apple_original_transaction_id: receipt_info.original_transaction_id,
              apple_product_id: receipt_info.product_id,
              apple_receipt_data: receipt_data,
              status: determine_apple_status(receipt_info),
              current_period_start: receipt_info.purchase_date,
              current_period_end: receipt_info.expires_date,
              auto_renew_enabled: receipt_info.auto_renew_status,
              apple_auto_renew_status: receipt_info.auto_renew_status
            })
        end

      {:error, reason} ->
        {:error, "Invalid Apple receipt: #{reason}"}
    end
  end

  defp calculate_usage_limits(subscription) do
    plan = subscription.plan
    current_usage = get_monthly_ai_usage(subscription.user_id)

    monthly_limit =
      case plan.features["ai_requests_per_month"] do
        :unlimited -> :unlimited
        limit -> limit
      end

    remaining =
      case monthly_limit do
        :unlimited -> :unlimited
        limit -> max(0, limit - current_usage)
      end

    %{
      ai_requests_per_month: monthly_limit,
      current_usage: current_usage,
      remaining_requests: remaining,
      rate_limit_per_minute: plan.features["rate_limit_per_minute"] || 60
    }
  end

  defp format_subscription_response(subscription) do
    %{
      id: subscription.id,
      provider: subscription.provider,
      status: subscription.status,
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      auto_renew_enabled: subscription.auto_renew_enabled,
      cancel_at_period_end: subscription.cancel_at_period_end,
      plan: %{
        code: subscription.plan.code,
        name: subscription.plan.name,
        features: subscription.plan.features
      }
    }
  end

  defp determine_apple_status(receipt_info) do
    now = DateTime.utc_now()

    cond do
      receipt_info.cancellation_date ->
        :canceled

      DateTime.compare(receipt_info.expires_date, now) == :gt ->
        :active

      receipt_info.grace_period_expires_date &&
          DateTime.compare(receipt_info.grace_period_expires_date, now) == :gt ->
        :past_due

      true ->
        :expired
    end
  end

  defp get_monthly_ai_usage(user_id) do
    now = DateTime.utc_now()
    start_of_month = %{now | day: 1, hour: 0, minute: 0, second: 0}

    case Billing.get_monthly_usage(user_id, start_of_month.month, start_of_month.year) do
      {:ok, usage_records} ->
        usage_records
        |> Enum.filter(&(&1.service == "ai_api"))
        |> Enum.count()

      {:error, _} ->
        0
    end
  end

  defp verify_apple_notification(_conn, _params) do
    # Implement Apple notification signature verification
    # This should verify the notification came from Apple
    :ok
  end

  defp process_apple_notification(notification) do
    case Billing.AppleReceiptValidator.validate_notification(notification) do
      {:ok, %{notification_type: type, subscription_data: data}} ->
        handle_apple_notification_type(type, data)

      {:error, reason} ->
        Logger.error("Failed to process Apple notification: #{reason}")
    end
  end

  defp handle_apple_notification_type("INITIAL_BUY", data) do
    # Handle new subscription
    Logger.info("New Apple subscription: #{data.original_transaction_id}")
  end

  defp handle_apple_notification_type("DID_RENEW", data) do
    # Handle subscription renewal
    Logger.info("Apple subscription renewed: #{data.original_transaction_id}")
  end

  defp handle_apple_notification_type("DID_FAIL_TO_RENEW", data) do
    # Handle failed renewal
    Logger.info("Apple subscription failed to renew: #{data.original_transaction_id}")
  end

  defp handle_apple_notification_type("DID_CANCEL", data) do
    # Handle cancellation
    Logger.info("Apple subscription canceled: #{data.original_transaction_id}")
  end

  defp handle_apple_notification_type(type, data) do
    Logger.info("Unhandled Apple notification type: #{type}, data: #{inspect(data)}")
  end

  defp process_stripe_event(%{type: "customer.subscription.updated"} = event) do
    subscription_data = event.data.object

    case Billing.get_subscription_by_stripe_id(subscription_data.id) do
      {:ok, subscription} ->
        Billing.sync_with_stripe(subscription, subscription_data)

      {:error, :not_found} ->
        Logger.warning(
          "Received Stripe webhook for unknown subscription: #{subscription_data.id}"
        )
    end
  end

  defp process_stripe_event(%{type: "invoice.payment_succeeded"} = event) do
    # Handle successful payment
    Logger.info("Stripe payment succeeded: #{event.data.object.id}")
  end

  defp process_stripe_event(%{type: "invoice.payment_failed"} = event) do
    # Handle failed payment
    Logger.info("Stripe payment failed: #{event.data.object.id}")
  end

  defp process_stripe_event(event) do
    Logger.info("Unhandled Stripe event: #{event.type}")
  end

  defp get_stripe_webhook_secret do
    System.get_env("STRIPE_WEBHOOK_SECRET") ||
      Application.get_env(:stripity_stripe, :webhook_secret) ||
      raise "STRIPE_WEBHOOK_SECRET not configured"
  end
end
