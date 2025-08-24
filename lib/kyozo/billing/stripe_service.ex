defmodule Kyozo.Billing.StripeService do
  @moduledoc """
  Main Stripe integration service that handles all Stripe API calls
  and works around Ash 3.5 limitations
  """

  require Logger
  alias Kyozo.Billing

  @doc """
  Create or get a Stripe customer for a user
  """
  def ensure_customer_for_user(user) do
    # Try to find existing customer
    case Billing.Customer.by_user(user.id) do
      {:ok, customer} when not is_nil(customer.stripe_customer_id) ->
        {:ok, customer}

      {:ok, customer} ->
        # Customer exists but no Stripe ID, create in Stripe
        create_stripe_customer_for_existing(customer)

      {:error, _} ->
        # No customer record, create both
        create_customer_and_stripe(user)
    end
  end

  @doc """
  Create a subscription for a customer
  """
  def create_subscription(customer, plan_code, payment_method_id \\ nil) do
    with {:ok, plan} <- get_or_create_plan(plan_code),
         {:ok, stripe_sub} <- create_stripe_subscription(customer, plan, payment_method_id),
         {:ok, subscription} <- create_subscription_record(customer, plan, stripe_sub) do
      {:ok, subscription}
    else
      {:error, %Stripe.Error{} = error} ->
        {:error, format_stripe_error(error)}

      error ->
        error
    end
  end

  @doc """
  Add a payment method to a customer
  """
  def add_payment_method(customer, payment_method_id) do
    with {:ok, _} <-
           attach_payment_method_to_stripe(customer.stripe_customer_id, payment_method_id),
         {:ok, updated_customer} <- set_default_payment_method(customer, payment_method_id) do
      {:ok, updated_customer}
    end
  end

  @doc """
  Process a webhook event from Stripe
  """
  def process_webhook_event(event) do
    Logger.info("Processing Stripe webhook: #{event["type"]}")

    case event["type"] do
      "customer.subscription.created" ->
        handle_subscription_created(event["data"]["object"])

      "customer.subscription.updated" ->
        handle_subscription_updated(event["data"]["object"])

      "customer.subscription.deleted" ->
        handle_subscription_deleted(event["data"]["object"])

      "invoice.payment_succeeded" ->
        handle_payment_succeeded(event["data"]["object"])

      "invoice.payment_failed" ->
        handle_payment_failed(event["data"]["object"])

      _ ->
        Logger.info("Unhandled Stripe event type: #{event["type"]}")
        {:ok, :unhandled}
    end
  end

  # Private functions

  defp create_stripe_customer_for_existing(customer) do
    stripe_params = %{
      email: customer.email,
      name: customer.name,
      metadata: %{
        user_id: customer.user_id,
        customer_id: customer.id
      }
    }

    case Stripe.Customer.create(stripe_params) do
      {:ok, stripe_customer} ->
        customer
        |> Ash.Changeset.for_update(:update, %{
          stripe_customer_id: stripe_customer.id
        })
        |> Ash.update()

      {:error, error} ->
        {:error, format_stripe_error(error)}
    end
  end

  defp create_customer_and_stripe(user) do
    # First create in Stripe
    stripe_params = %{
      email: user.email,
      name: user.name || user.email,
      metadata: %{
        user_id: user.id
      }
    }

    case Stripe.Customer.create(stripe_params) do
      {:ok, stripe_customer} ->
        # Then create local record
        Billing.Customer.create(%{
          user_id: user.id,
          email: user.email,
          name: user.name,
          stripe_customer_id: stripe_customer.id,
          provider: :stripe
        })

      {:error, error} ->
        {:error, format_stripe_error(error)}
    end
  end

  defp get_or_create_plan(plan_code) do
    case Billing.Plan.by_code(plan_code) do
      {:ok, plan} -> {:ok, plan}
      {:error, _} -> create_default_plan(plan_code)
    end
  end

  defp create_default_plan(plan_code) do
    # Create a default plan if it doesn't exist
    plan_configs = %{
      "PRO_MONTHLY" => %{
        name: "Pro Monthly",
        price_cents: 2900,
        interval: :monthly,
        tier: :pro
      },
      "TEAM_MONTHLY" => %{
        name: "Team Monthly",
        price_cents: 9900,
        interval: :monthly,
        tier: :team
      }
    }

    config =
      Map.get(plan_configs, plan_code, %{
        name: plan_code,
        price_cents: 0,
        interval: :monthly,
        tier: :free
      })

    # Create in Stripe first
    with {:ok, product} <- Stripe.Product.create(%{name: config.name}),
         {:ok, price} <-
           Stripe.Price.create(%{
             product: product.id,
             unit_amount: config.price_cents,
             currency: "usd",
             recurring: %{interval: to_string(config.interval)}
           }) do
      Billing.Plan.create_with_stripe(%{
        code: plan_code,
        name: config.name,
        price_cents: config.price_cents,
        interval: config.interval,
        tier: config.tier,
        stripe_product_id: product.id,
        stripe_price_id: price.id
      })
    end
  end

  defp create_stripe_subscription(customer, plan, payment_method_id) do
    params = %{
      customer: customer.stripe_customer_id,
      items: [%{price: plan.stripe_price_id}],
      expand: ["latest_invoice.payment_intent"]
    }

    params =
      if payment_method_id do
        Map.merge(params, %{
          default_payment_method: payment_method_id,
          payment_behavior: "default_incomplete"
        })
      else
        params
      end

    Stripe.Subscription.create(params)
  end

  defp create_subscription_record(customer, plan, stripe_sub) do
    Billing.Subscription.create(%{
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

  defp attach_payment_method_to_stripe(stripe_customer_id, payment_method_id) do
    Stripe.PaymentMethod.attach(%{
      payment_method: payment_method_id,
      customer: stripe_customer_id
    })
  end

  defp set_default_payment_method(customer, payment_method_id) do
    with {:ok, _} <-
           Stripe.Customer.update(customer.stripe_customer_id, %{
             invoice_settings: %{
               default_payment_method: payment_method_id
             }
           }) do
      customer
      |> Ash.Changeset.for_update(:update, %{
        metadata: Map.put(customer.metadata || %{}, "default_payment_method", payment_method_id)
      })
      |> Ash.update()
    end
  end

  defp handle_subscription_created(stripe_sub) do
    Logger.info("Handling subscription created: #{stripe_sub["id"]}")

    # Find customer
    with {:ok, customer} <- find_customer_by_stripe_id(stripe_sub["customer"]),
         {:ok, plan} <- find_plan_by_stripe_price(get_subscription_price_id(stripe_sub)) do
      # Check if subscription already exists
      case find_subscription_by_stripe_id(stripe_sub["id"]) do
        {:ok, _existing} ->
          Logger.info("Subscription already exists, updating")
          handle_subscription_updated(stripe_sub)

        {:error, :not_found} ->
          create_subscription_record(customer, plan, stripe_sub)
      end
    else
      error ->
        Logger.error("Failed to handle subscription created: #{inspect(error)}")
        error
    end
  end

  defp handle_subscription_updated(stripe_sub) do
    with {:ok, subscription} <- find_subscription_by_stripe_id(stripe_sub["id"]) do
      subscription
      |> Ash.Changeset.for_update(:update, %{
        status: atomize_status(stripe_sub["status"]),
        current_period_start: DateTime.from_unix!(stripe_sub["current_period_start"]),
        current_period_end: DateTime.from_unix!(stripe_sub["current_period_end"]),
        cancel_at_period_end: stripe_sub["cancel_at_period_end"] || false
      })
      |> Ash.update()
    end
  end

  defp handle_subscription_deleted(stripe_sub) do
    with {:ok, subscription} <- find_subscription_by_stripe_id(stripe_sub["id"]) do
      subscription
      |> Ash.Changeset.for_update(:cancel)
      |> Ash.update()
    end
  end

  defp handle_payment_succeeded(invoice) do
    Logger.info("Payment succeeded for invoice: #{invoice["id"]}")
    # Record usage or update subscription status if needed
    {:ok, :payment_recorded}
  end

  defp handle_payment_failed(invoice) do
    Logger.warning("Payment failed for invoice: #{invoice["id"]}")

    if subscription_id = invoice["subscription"] do
      with {:ok, subscription} <- find_subscription_by_stripe_id(subscription_id) do
        subscription
        |> Ash.Changeset.for_update(:update, %{
          status: :past_due
        })
        |> Ash.update()
      end
    end
  end

  # Helper functions

  defp find_customer_by_stripe_id(stripe_id) do
    case Billing.Customer.read() do
      {:ok, customers} ->
        case Enum.find(customers, &(&1.stripe_customer_id == stripe_id)) do
          nil -> {:error, :not_found}
          customer -> {:ok, customer}
        end

      error ->
        error
    end
  end

  defp find_plan_by_stripe_price(stripe_price_id) do
    case Billing.Plan.read() do
      {:ok, plans} ->
        case Enum.find(plans, &(&1.stripe_price_id == stripe_price_id)) do
          nil -> {:error, :not_found}
          plan -> {:ok, plan}
        end

      error ->
        error
    end
  end

  defp find_subscription_by_stripe_id(stripe_id) do
    case Billing.Subscription.read() do
      {:ok, subscriptions} ->
        case Enum.find(subscriptions, &(&1.stripe_subscription_id == stripe_id)) do
          nil -> {:error, :not_found}
          subscription -> {:ok, subscription}
        end

      error ->
        error
    end
  end

  defp get_subscription_price_id(stripe_sub) do
    get_in(stripe_sub, ["items", "data", Access.at(0), "price", "id"])
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

  defp format_stripe_error(%Stripe.Error{} = error) do
    %{
      type: error.code || :unknown_error,
      message: error.message || "Unknown Stripe error",
      param: get_in(error.extra, [:param]),
      request_id: get_in(error.extra, [:request_id])
    }
  end

  defp format_stripe_error(error), do: inspect(error)
end
