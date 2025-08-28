defmodule Dirup.Billing.StripeTest do
  @moduledoc """
  Test module for Stripe integration with Ash 3.5
  This handles edge cases and provides a working implementation
  """

  alias Dirup.Billing
  alias Dirup.Accounts

  @doc """
  Create a test subscription flow
  """
  def test_subscription_flow(user_email) do
    with {:ok, user} <- get_or_create_test_user(user_email),
         {:ok, customer} <- ensure_stripe_customer(user),
         {:ok, payment_method} <- create_test_payment_method(),
         {:ok, subscription} <- create_test_subscription(customer, payment_method) do
      {:ok,
       %{
         user: user,
         customer: customer,
         subscription: subscription
       }}
    end
  end

  @doc """
  Test webhook processing
  """
  def test_webhook_event(event_type, data) do
    event = %{
      "type" => event_type,
      "data" => %{
        "object" => data
      }
    }

    case event_type do
      "customer.subscription.created" ->
        handle_subscription_created(data)

      "customer.subscription.updated" ->
        handle_subscription_updated(data)

      "invoice.payment_succeeded" ->
        handle_payment_succeeded(data)

      _ ->
        {:ok, :unhandled}
    end
  end

  # Private functions

  defp get_or_create_test_user(email) do
    case Accounts.get_user_by_email(email) do
      {:ok, user} ->
        {:ok, user}

      {:error, _} ->
        Accounts.create_user(%{
          email: email,
          password: "TestPassword123!",
          password_confirmation: "TestPassword123!"
        })
    end
  end

  defp ensure_stripe_customer(user) do
    case Billing.get_customer_by_user(user.id) do
      {:ok, customer} ->
        {:ok, customer}

      {:error, _} ->
        # Create Stripe customer
        stripe_params = %{
          email: user.email,
          metadata: %{
            user_id: user.id,
            created_by: "test"
          }
        }

        case Stripe.Customer.create(stripe_params) do
          {:ok, stripe_customer} ->
            Billing.create_customer(%{
              user_id: user.id,
              stripe_customer_id: stripe_customer.id,
              email: user.email,
              provider: :stripe
            })

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp create_test_payment_method do
    # Create a test payment method using Stripe test tokens
    case Stripe.PaymentMethod.create(%{
           type: "card",
           card: %{
             # Stripe test token
             token: "tok_visa"
           }
         }) do
      {:ok, payment_method} -> {:ok, payment_method.id}
      error -> error
    end
  end

  defp create_test_subscription(customer, payment_method_id) do
    # First, attach payment method to customer
    with {:ok, _} <-
           Stripe.PaymentMethod.attach(
             %{
               payment_method: payment_method_id
             },
             customer: customer.stripe_customer_id
           ),

         # Set as default payment method
         {:ok, _} <-
           Stripe.Customer.update(customer.stripe_customer_id, %{
             invoice_settings: %{
               default_payment_method: payment_method_id
             }
           }),

         # Get a test plan
         {:ok, plan} <- get_test_plan(),

         # Create subscription
         {:ok, stripe_sub} <-
           Stripe.Subscription.create(%{
             customer: customer.stripe_customer_id,
             items: [%{price: plan.stripe_price_id}],
             payment_settings: %{
               payment_method_types: ["card"]
             },
             expand: ["latest_invoice.payment_intent"]
           }) do
      # Create local subscription record
      Billing.create_subscription(%{
        user_id: customer.user_id,
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: stripe_sub.id,
        status: atomize_status(stripe_sub.status),
        current_period_start: DateTime.from_unix!(stripe_sub.current_period_start),
        current_period_end: DateTime.from_unix!(stripe_sub.current_period_end),
        provider: :stripe
      })
    end
  end

  defp get_test_plan do
    case Billing.get_plan_by_code("PRO_MONTHLY") do
      {:ok, plan} ->
        {:ok, plan}

      {:error, _} ->
        # Create a test plan if it doesn't exist
        create_test_plan()
    end
  end

  defp create_test_plan do
    # Create Stripe product
    with {:ok, product} <-
           Stripe.Product.create(%{
             name: "Pro Monthly",
             description: "Test Pro Plan"
           }),

         # Create Stripe price
         {:ok, price} <-
           Stripe.Price.create(%{
             product: product.id,
             # $29.00
             unit_amount: 2900,
             currency: "usd",
             recurring: %{
               interval: "month"
             }
           }) do
      # Create local plan record
      Billing.Plan.create_with_stripe!(%{
        code: "PRO_MONTHLY",
        name: "Pro Monthly",
        description: "Test Pro Plan",
        tier: :pro,
        price_cents: 2900,
        currency: "USD",
        interval: :monthly,
        stripe_product_id: product.id,
        stripe_price_id: price.id,
        active: true
      })
    end
  end

  defp handle_subscription_created(stripe_sub) do
    # Find customer
    with {:ok, customer} <- find_customer_by_stripe_id(stripe_sub["customer"]),
         {:ok, plan} <-
           find_plan_by_stripe_price_id(
             get_in(stripe_sub, ["items", "data", Access.at(0), "price", "id"])
           ) do
      Billing.create_subscription(%{
        user_id: customer.user_id,
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: stripe_sub["id"],
        status: atomize_status(stripe_sub["status"]),
        current_period_start: DateTime.from_unix!(stripe_sub["current_period_start"]),
        current_period_end: DateTime.from_unix!(stripe_sub["current_period_end"]),
        provider: :stripe
      })
    end
  end

  defp handle_subscription_updated(stripe_sub) do
    with {:ok, subscription} <- find_subscription_by_stripe_id(stripe_sub["id"]) do
      Billing.update_subscription(subscription, %{
        status: atomize_status(stripe_sub["status"]),
        current_period_start: DateTime.from_unix!(stripe_sub["current_period_start"]),
        current_period_end: DateTime.from_unix!(stripe_sub["current_period_end"]),
        cancel_at_period_end: stripe_sub["cancel_at_period_end"] || false
      })
    end
  end

  defp handle_payment_succeeded(invoice) do
    # Log successful payment
    IO.inspect(invoice, label: "Payment succeeded")
    {:ok, :payment_recorded}
  end

  defp find_customer_by_stripe_id(stripe_id) do
    # This is a workaround for Ash 3.5 - using list and filter
    case Billing.Customer.read() do
      {:ok, customers} ->
        customer = Enum.find(customers, &(&1.stripe_customer_id == stripe_id))
        if customer, do: {:ok, customer}, else: {:error, :not_found}

      error ->
        error
    end
  end

  defp find_plan_by_stripe_price_id(stripe_price_id) do
    case Billing.Plan.read() do
      {:ok, plans} ->
        plan = Enum.find(plans, &(&1.stripe_price_id == stripe_price_id))
        if plan, do: {:ok, plan}, else: {:error, :not_found}

      error ->
        error
    end
  end

  defp find_subscription_by_stripe_id(stripe_id) do
    case Billing.Subscription.read() do
      {:ok, subscriptions} ->
        sub = Enum.find(subscriptions, &(&1.stripe_subscription_id == stripe_id))
        if sub, do: {:ok, sub}, else: {:error, :not_found}

      error ->
        error
    end
  end

  defp atomize_status(status) do
    case status do
      "active" -> :active
      "past_due" -> :past_due
      "canceled" -> :canceled
      "incomplete" -> :incomplete
      "incomplete_expired" -> :incomplete_expired
      "trialing" -> :trialing
      "unpaid" -> :unpaid
      _ -> :unknown
    end
  end
end
