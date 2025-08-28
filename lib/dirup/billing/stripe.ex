defmodule Dirup.Billing.Stripe do
  @moduledoc """
  Stripe integration for Kyozo billing.
  Handles products, prices, usage-based billing, and subscriptions.
  """

  require Logger
  alias Dirup.Billing
  alias Dirup.Accounts

  # Product IDs (create these in Stripe Dashboard first)
  @products %{
    # Usage-based API access
    kyozo_api: "prod_kyozo_api",
    # Subscription with included credits
    kyozo_pro: "prod_kyozo_pro",
    # Enterprise plan
    kyozo_enterprise: "prod_kyozo_ent"
  }

  # Price IDs (create after products)
  @prices %{
    # Usage-based pricing
    # $0.03 per AI request
    api_ai_request: "price_ai_003",
    # $0.01 per scan
    api_scan: "price_scan_001",

    # Subscription tiers
    # $49/month
    pro_monthly: "price_pro_monthly",
    # $490/year
    pro_yearly: "price_pro_yearly",
    # Custom
    enterprise: "price_enterprise"
  }

  @doc """
  Initialize Stripe products and prices.
  Run this in production once: Dirup.Billing.Stripe.setup_products()
  """
  def setup_products do
    # Create products
    with {:ok, _} <-
           create_product(:dirup_api, %{
             name: "Kyozo API",
             description: "Pay-as-you-go AI-powered development tools",
             metadata: %{
               type: "usage_based",
               category: "api"
             }
           }),
         {:ok, _} <-
           create_product(:dirup_pro, %{
             name: "Kyozo Pro",
             description: "Professional plan with included credits",
             metadata: %{
               type: "subscription",
               category: "pro"
             }
           }),
         {:ok, _} <-
           create_product(:dirup_enterprise, %{
             name: "Kyozo Enterprise",
             description: "Enterprise AI development tools",
             metadata: %{
               type: "subscription",
               category: "enterprise"
             }
           }) do
      # Create prices
      setup_prices()
    end
  end

  defp setup_prices do
    # Usage-based AI request pricing
    with {:ok, _} <-
           create_price(:api_ai_request, %{
             product: @products.kyozo_api,
             currency: "usd",
             billing_scheme: "per_unit",
             # $0.03 in cents
             unit_amount: 3,
             usage_type: "metered",
             aggregate_usage: "sum",
             nickname: "AI Request",
             metadata: %{
               description: "Per AI request charge"
             }
           }),

         # Usage-based scan pricing
         {:ok, _} <-
           create_price(:api_scan, %{
             product: @products.kyozo_api,
             currency: "usd",
             billing_scheme: "per_unit",
             # $0.01 in cents
             unit_amount: 1,
             usage_type: "metered",
             aggregate_usage: "sum",
             nickname: "API Scan",
             metadata: %{
               description: "Per scan charge"
             }
           }),

         # Pro subscription
         {:ok, _} <-
           create_price(:pro_monthly, %{
             product: @products.kyozo_pro,
             currency: "usd",
             # $49.00
             unit_amount: 4900,
             recurring: %{interval: "month"},
             nickname: "Pro Monthly",
             metadata: %{
               included_requests: "3000",
               features: "ai_suggestions,code_analysis,api_access"
             }
           }),
         {:ok, _} <-
           create_price(:pro_yearly, %{
             product: @products.kyozo_pro,
             currency: "usd",
             # $490.00
             unit_amount: 49000,
             recurring: %{interval: "year"},
             nickname: "Pro Yearly",
             metadata: %{
               included_requests: "36000",
               features: "ai_suggestions,code_analysis,api_access,priority_support"
             }
           }) do
      {:ok, "Products and prices created successfully"}
    end
  end

  @doc """
  Create or get a Stripe customer for a user.
  """
  def ensure_customer(user) do
    case user.stripe_customer_id do
      nil ->
        create_customer(user)

      customer_id ->
        # Verify customer still exists
        case Stripe.Customer.retrieve(customer_id) do
          {:ok, customer} -> {:ok, customer}
          {:error, _} -> create_customer(user)
        end
    end
  end

  defp create_customer(user) do
    params = %{
      email: user.email,
      name: user.name || user.email,
      metadata: %{
        user_id: user.id,
        platform: "kyozo"
      }
    }

    case Stripe.Customer.create(params) do
      {:ok, customer} ->
        # Save customer ID to user
        # Note: Need to implement user update in Accounts domain
        # For now, just return the customer - user update can be handled elsewhere
        Logger.info("Created Stripe customer #{customer.id} for user #{user.id}")
        {:ok, customer}

      error ->
        Logger.error("Failed to create Stripe customer: #{inspect(error)}")
        error
    end
  end

  @doc """
  Create a subscription for Pro/Enterprise plans.
  """
  def create_subscription(user, price_key, opts \\ []) do
    with {:ok, customer} <- ensure_customer(user),
         price_id <- @prices[price_key] do
      params = %{
        customer: customer.id,
        items: [%{price: price_id}],
        metadata: %{
          user_id: user.id,
          plan: to_string(price_key)
        },
        # Important for SCA compliance
        payment_behavior: "default_incomplete",
        expand: ["latest_invoice.payment_intent"]
      }

      # Add trial period if specified
      params =
        if opts[:trial_days] do
          Map.put(params, :trial_period_days, opts[:trial_days])
        else
          params
        end

      case Stripe.Subscription.create(params) do
        {:ok, subscription} ->
          # Save subscription
          case save_subscription(user, subscription) do
            {:ok, _} ->
              # Return with payment intent for frontend
              {:ok,
               %{
                 subscription: subscription,
                 client_secret: subscription.latest_invoice.payment_intent.client_secret
               }}

            {:error, reason} ->
              Logger.error("Failed to save subscription: #{inspect(reason)}")
              {:error, reason}
          end

        error ->
          Logger.error("Failed to create subscription: #{inspect(error)}")
          error
      end
    end
  end

  @doc """
  Record usage for metered billing.
  Call this after each AI request or scan.
  """
  def record_usage(user, quantity \\ 1, action \\ "ai_request") do
    with {:ok, subscription} <- get_active_subscription(user),
         {:ok, item} <- find_subscription_item(subscription, get_price_for_action(action)) do
      timestamp = DateTime.utc_now() |> DateTime.to_unix()

      params = %{
        quantity: quantity,
        timestamp: timestamp,
        action: action,
        metadata: %{
          user_id: user.id,
          action: action
        }
      }

      case Stripe.SubscriptionItem.create_usage_record(item.id, params) do
        {:ok, _record} ->
          # Also track in our database for redundancy
          track_usage_internally(user, quantity, action)
          :ok

        error ->
          Logger.error("Failed to record usage: #{inspect(error)}")
          error
      end
    else
      _ ->
        # No active subscription, track for later billing
        track_usage_for_invoice(user, quantity, action)
    end
  end

  @doc """
  Create a checkout session for subscriptions.
  """
  def create_checkout_session(user, price_key, success_url, cancel_url) do
    with {:ok, customer} <- ensure_customer(user) do
      params = %{
        mode: "subscription",
        customer: customer.id,
        line_items: [
          %{
            price: @prices[price_key],
            quantity: 1
          }
        ],
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: %{
          user_id: user.id
        },
        # Enable tax collection
        automatic_tax: %{enabled: true},
        # Allow promotion codes
        allow_promotion_codes: true
      }

      Stripe.Checkout.Session.create(params)
    end
  end

  @doc """
  Create a customer portal session for managing subscriptions.
  """
  def create_portal_session(user, return_url) do
    with {:ok, customer} <- ensure_customer(user) do
      Stripe.BillingPortal.Session.create(%{
        customer: customer.id,
        return_url: return_url
      })
    end
  end

  @doc """
  Handle Stripe webhooks.
  """
  def handle_webhook_event(event) do
    case event.type do
      "checkout.session.completed" ->
        handle_checkout_completed(event.data.object)

      "customer.subscription.created" ->
        handle_subscription_created(event.data.object)

      "customer.subscription.updated" ->
        handle_subscription_updated(event.data.object)

      "customer.subscription.deleted" ->
        handle_subscription_deleted(event.data.object)

      "invoice.payment_succeeded" ->
        handle_payment_succeeded(event.data.object)

      "invoice.payment_failed" ->
        handle_payment_failed(event.data.object)

      _ ->
        Logger.info("Unhandled webhook event: #{event.type}")
        :ok
    end
  end

  # Private helper functions

  defp get_price_for_action("ai_request"), do: @prices.api_ai_request
  defp get_price_for_action("scan"), do: @prices.api_scan
  defp get_price_for_action(_), do: @prices.api_ai_request

  defp get_active_subscription(user) do
    case Billing.list_user_subscriptions(user.id) do
      {:ok, subscriptions} when is_list(subscriptions) and length(subscriptions) > 0 ->
        # Find active subscription
        active_subscription =
          Enum.find(subscriptions, fn sub ->
            sub.status in ["active", "trialing"] and not is_nil(sub.stripe_subscription_id)
          end)

        case active_subscription do
          nil ->
            {:error, :no_active_subscription}

          subscription ->
            # Fetch from Stripe to get current status
            case Stripe.Subscription.retrieve(subscription.stripe_subscription_id) do
              {:ok, stripe_subscription} ->
                if stripe_subscription.status in ["active", "trialing"] do
                  {:ok, stripe_subscription}
                else
                  {:error, :inactive_subscription}
                end

              error ->
                error
            end
        end

      _ ->
        {:error, :no_subscription}
    end
  end

  defp find_subscription_item(subscription, price_id) do
    case Enum.find(subscription.items.data, fn item ->
           item.price.id == price_id
         end) do
      nil -> {:error, :item_not_found}
      item -> {:ok, item}
    end
  end

  defp get_unbilled_usage(user) do
    # This should be implemented in the Billing domain
    case Billing.by_user(user.id) do
      {:ok, usage_records} ->
        usage_records
        |> Enum.filter(&(&1.billed == false))
        |> Enum.sum(& &1.quantity)

      _ ->
        0
    end
  end

  defp get_user_by_stripe_customer(customer_id) do
    # Find user by stripe customer ID
    case Accounts.list_users() do
      {:ok, users} ->
        case Enum.find(users, fn user -> user.stripe_customer_id == customer_id end) do
          nil -> {:error, :user_not_found}
          user -> {:ok, user}
        end

      error ->
        error
    end
  end

  defp create_product(key, params) do
    product_id = @products[key]

    case Stripe.Product.retrieve(product_id) do
      {:ok, product} ->
        {:ok, product}

      {:error, _} ->
        params = Map.put(params, :id, product_id)
        Stripe.Product.create(params)
    end
  end

  defp create_price(key, params) do
    price_id = @prices[key]

    # Check if price exists
    case Stripe.Price.retrieve(price_id) do
      {:ok, price} ->
        {:ok, price}

      {:error, _} ->
        params = Map.put(params, :id, price_id)
        Stripe.Price.create(params)
    end
  end

  defp save_subscription(user, stripe_subscription) do
    attrs = %{
      user_id: user.id,
      stripe_subscription_id: stripe_subscription.id,
      stripe_customer_id: stripe_subscription.customer,
      status: stripe_subscription.status,
      current_period_start: DateTime.from_unix!(stripe_subscription.current_period_start),
      current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
      plan_id: get_plan_from_subscription(stripe_subscription),
      metadata: stripe_subscription.metadata || %{}
    }

    # Use Ash API to create subscription
    Billing.create_subscription(attrs)
  end

  defp get_plan_from_subscription(subscription) do
    # Extract plan from price ID or metadata
    subscription.items.data
    |> List.first()
    |> Map.get(:price)
    |> Map.get(:id)
    |> map_price_to_plan()
  end

  defp map_price_to_plan(price_id) do
    case price_id do
      p when p == @prices.pro_monthly -> "pro_monthly"
      p when p == @prices.pro_yearly -> "pro_yearly"
      p when p == @prices.enterprise -> "enterprise"
      _ -> "usage_based"
    end
  end

  defp track_usage_internally(user, quantity, action) do
    usage_data = %{
      user_id: user.id,
      action: action,
      quantity: quantity,
      timestamp: DateTime.utc_now(),
      billed: false
    }

    case Billing.record_usage(usage_data) do
      {:ok, _usage} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to track usage internally: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp track_usage_for_invoice(user, quantity, action) do
    # Track unbilled usage for users without subscriptions
    track_usage_internally(user, quantity, action)

    # Optionally create an invoice if usage exceeds threshold
    maybe_create_usage_invoice(user)
  end

  defp maybe_create_usage_invoice(user) do
    # Get unbilled usage
    unbilled = get_unbilled_usage(user)
    # $0.03 per AI request
    total_amount = unbilled * 3

    # Create invoice if over $10
    # Amount in cents
    if total_amount >= 1000 do
      create_usage_invoice(user, unbilled, total_amount)
    else
      :ok
    end
  end

  defp create_usage_invoice(user, _quantity, total_amount) do
    with {:ok, customer} <- ensure_customer(user) do
      # Create invoice item
      invoice_item_params = %{
        customer: customer.id,
        amount: total_amount,
        currency: "usd",
        description: "API Usage Charges"
      }

      with {:ok, _item} <- Stripe.InvoiceItem.create(invoice_item_params),
           {:ok, invoice} <- Stripe.Invoice.create(%{customer: customer.id}) do
        # Auto-finalize and send
        Stripe.Invoice.finalize_invoice(invoice.id, %{auto_advance: true})
      end
    end
  end

  defp handle_checkout_completed(session) do
    # Update user with successful checkout
    user_id = session.metadata["user_id"]

    with {:ok, user} <- Accounts.get_user(user_id) do
      # Session completed successfully
      Logger.info("Checkout completed for user #{user_id}")

      # Send welcome email using existing email module
      send_subscription_welcome_email(user)
    end
  end

  defp handle_subscription_created(subscription) do
    user_id = subscription.metadata["user_id"]

    with {:ok, user} <- Accounts.get_user(user_id) do
      case save_subscription(user, subscription) do
        {:ok, _} ->
          Logger.info("Subscription created for user #{user_id}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to save new subscription: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp handle_subscription_updated(subscription) do
    # Update our records
    user_id = subscription.metadata["user_id"]

    with {:ok, user} <- Accounts.get_user(user_id) do
      save_subscription(user, subscription)
    end
  end

  defp handle_subscription_deleted(subscription) do
    # Mark subscription as canceled in our system
    case Billing.get_subscription_by_stripe_id(subscription.id) do
      {:ok, local_subscription} ->
        Billing.update_subscription(local_subscription, %{
          status: "canceled",
          canceled_at: DateTime.utc_now()
        })

      _ ->
        Logger.warning("Could not find local subscription for Stripe ID: #{subscription.id}")
        :ok
    end
  end

  defp handle_payment_succeeded(invoice) do
    # Log successful payment
    Logger.info("Payment succeeded for invoice #{invoice.id}")
    :ok
  end

  defp handle_payment_failed(invoice) do
    # Notify user of failed payment
    customer_id = invoice.customer

    with {:ok, user} <- get_user_by_stripe_customer(customer_id) do
      send_payment_failed_email(user, invoice)
    end
  end

  # Email helper functions using existing email module
  defp send_subscription_welcome_email(user) do
    # Use existing email infrastructure or create a simple notification
    Logger.info("Welcome email should be sent to #{user.email}")
    # TODO: Implement using Dirup.Accounts.Emails or similar
    :ok
  end

  defp send_payment_failed_email(user, _invoice) do
    # Use existing email infrastructure or create a simple notification
    Logger.warning("Payment failed email should be sent to #{user.email}")
    # TODO: Implement using Dirup.Accounts.Emails or similar
    :ok
  end
end
