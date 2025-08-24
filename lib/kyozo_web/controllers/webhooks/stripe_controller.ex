defmodule KyozoWeb.Webhooks.StripeController do
  use KyozoWeb, :controller
  require Logger

  alias Kyozo.Billing

  @webhook_secret Application.compile_env(:stripity_stripe, :webhook_secret) ||
                    System.get_env("STRIPE_WEBHOOK_SECRET")

  def webhook(conn, _params) do
    payload = conn.assigns[:raw_body] || get_raw_body(conn)
    signature = get_req_header(conn, "stripe-signature") |> List.first()

    case Stripe.Webhook.construct_event(payload, signature, @webhook_secret) do
      {:ok, event} ->
        process_event(event)

        conn
        |> put_status(:ok)
        |> json(%{received: true})

      {:error, error} ->
        Logger.error("Stripe webhook signature verification failed: #{inspect(error)}")

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid signature"})
    end
  end

  # Private functions

  defp get_raw_body(conn) do
    # If raw_body isn't set by a plug, read from the connection
    case conn.assigns[:raw_body] do
      nil ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        body

      body ->
        body
    end
  end

  defp process_event(%{"type" => "customer.subscription.created"} = event) do
    Logger.info("Processing Stripe subscription created: #{event["data"]["object"]["id"]}")
    handle_subscription_event(event["data"]["object"], :created)
  end

  defp process_event(%{"type" => "customer.subscription.updated"} = event) do
    Logger.info("Processing Stripe subscription updated: #{event["data"]["object"]["id"]}")
    handle_subscription_event(event["data"]["object"], :updated)
  end

  defp process_event(%{"type" => "customer.subscription.deleted"} = event) do
    Logger.info("Processing Stripe subscription deleted: #{event["data"]["object"]["id"]}")
    handle_subscription_event(event["data"]["object"], :deleted)
  end

  defp process_event(%{"type" => "customer.subscription.trial_will_end"} = event) do
    Logger.info("Processing Stripe trial ending: #{event["data"]["object"]["id"]}")
    handle_subscription_event(event["data"]["object"], :trial_ending)
  end

  defp process_event(%{"type" => "invoice.payment_succeeded"} = event) do
    Logger.info("Processing Stripe payment succeeded: #{event["data"]["object"]["id"]}")
    handle_invoice_event(event["data"]["object"], :paid)
  end

  defp process_event(%{"type" => "invoice.payment_failed"} = event) do
    Logger.info("Processing Stripe payment failed: #{event["data"]["object"]["id"]}")
    handle_invoice_event(event["data"]["object"], :failed)
  end

  defp process_event(%{"type" => "invoice.upcoming"} = event) do
    Logger.info("Processing Stripe upcoming invoice: #{event["data"]["object"]["id"]}")
    handle_invoice_event(event["data"]["object"], :upcoming)
  end

  defp process_event(%{"type" => "customer.created"} = event) do
    Logger.info("Processing Stripe customer created: #{event["data"]["object"]["id"]}")
    handle_customer_event(event["data"]["object"], :created)
  end

  defp process_event(%{"type" => "customer.updated"} = event) do
    Logger.info("Processing Stripe customer updated: #{event["data"]["object"]["id"]}")
    handle_customer_event(event["data"]["object"], :updated)
  end

  defp process_event(%{"type" => "customer.deleted"} = event) do
    Logger.info("Processing Stripe customer deleted: #{event["data"]["object"]["id"]}")
    handle_customer_event(event["data"]["object"], :deleted)
  end

  defp process_event(%{"type" => "setup_intent.succeeded"} = event) do
    Logger.info("Processing Stripe setup intent succeeded: #{event["data"]["object"]["id"]}")
    # Handle successful payment method setup
    :ok
  end

  defp process_event(event) do
    Logger.info("Unhandled Stripe webhook event: #{event["type"]}")
    :ok
  end

  defp handle_subscription_event(stripe_subscription, action) do
    case find_subscription_by_stripe_id(stripe_subscription["id"]) do
      {:ok, subscription} ->
        sync_subscription_from_stripe(subscription, stripe_subscription, action)

      {:error, :not_found} when action == :created ->
        create_subscription_from_stripe(stripe_subscription)

      {:error, :not_found} ->
        Logger.warning("Subscription not found for Stripe ID: #{stripe_subscription["id"]}")
        :ok

      {:error, reason} ->
        Logger.error("Error finding subscription: #{inspect(reason)}")
        :error
    end
  end

  defp handle_invoice_event(stripe_invoice, action) do
    subscription_id = stripe_invoice["subscription"]

    if subscription_id do
      case find_subscription_by_stripe_id(subscription_id) do
        {:ok, subscription} ->
          process_invoice_for_subscription(stripe_invoice, subscription, action)

        {:error, :not_found} ->
          Logger.warning("Subscription not found for invoice: #{stripe_invoice["id"]}")
          :ok

        {:error, reason} ->
          Logger.error("Error finding subscription for invoice: #{inspect(reason)}")
          :error
      end
    else
      Logger.info("Invoice without subscription: #{stripe_invoice["id"]}")
      :ok
    end
  end

  defp handle_customer_event(stripe_customer, action) do
    case find_customer_by_stripe_id(stripe_customer["id"]) do
      {:ok, customer} ->
        sync_customer_from_stripe(customer, stripe_customer, action)

      {:error, :not_found} when action == :created ->
        Logger.info("Customer created in Stripe but not in our system: #{stripe_customer["id"]}")
        :ok

      {:error, :not_found} ->
        Logger.warning("Customer not found for Stripe ID: #{stripe_customer["id"]}")
        :ok

      {:error, reason} ->
        Logger.error("Error finding customer: #{inspect(reason)}")
        :error
    end
  end

  defp find_subscription_by_stripe_id(stripe_subscription_id) do
    # This function needs to be implemented in the Billing domain
    # For now, we'll use a placeholder that tries to find by attribute
    case Billing.list_subscriptions() do
      {:ok, subscriptions} ->
        subscription =
          Enum.find(subscriptions, fn sub ->
            sub.stripe_subscription_id == stripe_subscription_id
          end)

        if subscription do
          {:ok, subscription}
        else
          {:error, :not_found}
        end

      error ->
        error
    end
  end

  defp find_customer_by_stripe_id(stripe_customer_id) do
    # Find customer by Stripe ID using list and filter approach
    case Billing.list_customers() do
      {:ok, customers} ->
        customer = Enum.find(customers, fn c -> c.stripe_customer_id == stripe_customer_id end)

        if customer do
          {:ok, customer}
        else
          {:error, :not_found}
        end

      error ->
        Logger.error("Failed to list customers: #{inspect(error)}")
        {:error, :not_found}
    end
  rescue
    UndefinedFunctionError ->
      Logger.warning("list_customers not implemented")
      {:error, :not_found}
  end

  defp sync_subscription_from_stripe(subscription, stripe_data, action) do
    update_params = %{
      status: stripe_status_to_subscription_status(stripe_data["status"]),
      current_period_start: DateTime.from_unix!(stripe_data["current_period_start"]),
      current_period_end: DateTime.from_unix!(stripe_data["current_period_end"]),
      cancel_at_period_end: stripe_data["cancel_at_period_end"] || false,
      metadata:
        Map.merge(subscription.metadata || %{}, %{
          "stripe_synced_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "webhook_event" => to_string(action)
        })
    }

    # Handle canceled subscriptions
    update_params =
      if stripe_data["canceled_at"] do
        Map.put(update_params, :canceled_at, DateTime.from_unix!(stripe_data["canceled_at"]))
      else
        update_params
      end

    case Billing.update_subscription(subscription, update_params) do
      {:ok, updated_subscription} ->
        Logger.info("Successfully synced subscription #{subscription.id} from Stripe")
        broadcast_subscription_update(updated_subscription, action)
        {:ok, updated_subscription}

      {:error, reason} ->
        Logger.error(
          "Failed to sync subscription #{subscription.id} from Stripe: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp sync_customer_from_stripe(customer, stripe_data, action) do
    update_params = %{
      email: stripe_data["email"],
      name: stripe_data["name"],
      metadata:
        Map.merge(customer.metadata || %{}, %{
          "stripe_synced_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "webhook_event" => to_string(action)
        })
    }

    case Billing.update_customer(customer, update_params) do
      {:ok, updated_customer} ->
        Logger.info("Successfully synced customer #{customer.id} from Stripe")
        {:ok, updated_customer}

      {:error, reason} ->
        Logger.error("Failed to sync customer #{customer.id} from Stripe: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_subscription_from_stripe(stripe_subscription) do
    # Find the customer first
    case find_customer_by_stripe_id(stripe_subscription["customer"]) do
      {:ok, customer} ->
        # Try to find the plan by Stripe price ID
        case find_plan_by_stripe_price_id(
               stripe_subscription["items"]["data"]
               |> List.first()
               |> get_in(["price", "id"])
             ) do
          {:ok, plan} ->
            subscription_params = %{
              user_id: customer.user_id,
              customer_id: customer.id,
              plan_id: plan.id,
              provider: :stripe,
              stripe_subscription_id: stripe_subscription["id"],
              status: stripe_status_to_subscription_status(stripe_subscription["status"]),
              current_period_start:
                DateTime.from_unix!(stripe_subscription["current_period_start"]),
              current_period_end: DateTime.from_unix!(stripe_subscription["current_period_end"]),
              cancel_at_period_end: stripe_subscription["cancel_at_period_end"] || false,
              metadata: %{
                "created_from_webhook" => true,
                "stripe_synced_at" => DateTime.utc_now() |> DateTime.to_iso8601()
              }
            }

            case Billing.create_subscription(subscription_params) do
              {:ok, subscription} ->
                Logger.info("Successfully created subscription from Stripe webhook")
                broadcast_subscription_update(subscription, :created)
                {:ok, subscription}

              {:error, reason} ->
                Logger.error("Failed to create subscription from webhook: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, :not_found} ->
            Logger.warning(
              "Plan not found for Stripe price ID in webhook: #{stripe_subscription["items"]["data"] |> List.first() |> get_in(["price", "id"])}"
            )

            {:error, :plan_not_found}

          error ->
            error
        end

      {:error, :not_found} ->
        Logger.warning(
          "Customer not found for Stripe ID in webhook: #{stripe_subscription["customer"]}"
        )

        {:error, :customer_not_found}

      error ->
        error
    end
  end

  defp process_invoice_for_subscription(stripe_invoice, subscription, action) do
    case action do
      :paid ->
        # Record successful payment
        record_successful_payment(subscription, stripe_invoice)

      :failed ->
        # Handle failed payment
        handle_failed_payment(subscription, stripe_invoice)

      :upcoming ->
        # Send upcoming payment notification
        send_upcoming_payment_notification(subscription, stripe_invoice)

      _ ->
        Logger.info("Unhandled invoice action: #{action}")
        :ok
    end
  end

  defp find_plan_by_stripe_price_id(stripe_price_id) do
    case Billing.list_plans() do
      {:ok, plans} ->
        plan = Enum.find(plans, fn p -> p.stripe_price_id == stripe_price_id end)

        if plan do
          {:ok, plan}
        else
          {:error, :not_found}
        end

      error ->
        error
    end
  end

  defp record_successful_payment(subscription, stripe_invoice) do
    Logger.info("Recording successful payment for subscription #{subscription.id}")

    # Update subscription if needed (e.g., if it was past due)
    if subscription.status == :past_due do
      Billing.update_subscription(subscription, %{status: :active})
    end

    # You could create a payment record here if you have a payments table
    :ok
  end

  defp handle_failed_payment(subscription, stripe_invoice) do
    Logger.warning("Payment failed for subscription #{subscription.id}")

    # Update subscription status to past_due
    case Billing.update_subscription(subscription, %{status: :past_due}) do
      {:ok, updated_subscription} ->
        broadcast_subscription_update(updated_subscription, :payment_failed)
        :ok

      {:error, reason} ->
        Logger.error("Failed to update subscription status: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_upcoming_payment_notification(subscription, stripe_invoice) do
    Logger.info("Upcoming payment notification for subscription #{subscription.id}")
    # Here you could send an email notification or push notification
    :ok
  end

  defp broadcast_subscription_update(subscription, event) do
    Billing.broadcast("user:#{subscription.user_id}", event, %{
      subscription_id: subscription.id,
      status: subscription.status,
      current_period_end: subscription.current_period_end
    })
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
end
