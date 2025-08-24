# Stripe Setup for SafeMD

## Environment Variables

Add to your `.env` file:

```bash
# Stripe API Keys
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# For production
STRIPE_SECRET_KEY_LIVE=sk_live_...
STRIPE_PUBLIC_KEY_LIVE=pk_live_...
STRIPE_WEBHOOK_SECRET_LIVE=whsec_...
```

## Create Products in Stripe Dashboard

Run this script to create products via API:

```elixir
# Run in iex -S mix

defmodule SetupStripe do
  def create_products do
    # Create main scan product
    {:ok, scan_product} = Stripe.Product.create(%{
      name: "SafeMD Scans",
      description: "Enterprise markdown security scanning for AI systems",
      metadata: %{
        product_type: "safemd_scan"
      }
    })
    
    # Create metered price for pay-as-you-go
    {:ok, scan_price} = Stripe.Price.create(%{
      product: scan_product.id,
      nickname: "Pay-as-you-go scanning",
      currency: "usd",
      recurring: %{
        interval: "month",
        usage_type: "metered"
      },
      billing_scheme: "per_unit",
      unit_amount: 3  # $0.03
    })
    
    # Create credit packages
    {:ok, credit_product} = Stripe.Product.create(%{
      name: "SafeMD Credit Packages",
      description: "Prepaid scanning credits"
    })
    
    # 1K credits - $25 (2.5¢ per scan)
    Stripe.Price.create(%{
      product: credit_product.id,
      nickname: "1,000 scan credits",
      currency: "usd",
      unit_amount: 2500,
      metadata: %{credits: "1000"}
    })
    
    # 10K credits - $200 (2¢ per scan)
    Stripe.Price.create(%{
      product: credit_product.id,
      nickname: "10,000 scan credits",
      currency: "usd",
      unit_amount: 20000,
      metadata: %{credits: "10000"}
    })
    
    # 100K credits - $1,500 (1.5¢ per scan)
    Stripe.Price.create(%{
      product: credit_product.id,
      nickname: "100,000 scan credits",
      currency: "usd",
      unit_amount: 150000,
      metadata: %{credits: "100000"}
    })
    
    # Create subscription product
    {:ok, sub_product} = Stripe.Product.create(%{
      name: "SafeMD Subscriptions",
      description: "Monthly plans with included scans"
    })
    
    # Starter - $49/mo (2,000 scans included)
    Stripe.Price.create(%{
      product: sub_product.id,
      nickname: "Starter Plan",
      currency: "usd",
      recurring: %{interval: "month"},
      unit_amount: 4900,
      metadata: %{
        included_scans: "2000",
        overage_price: "0.025"  # 2.5¢ per extra scan
      }
    })
    
    # Professional - $299/mo (15,000 scans included)
    Stripe.Price.create(%{
      product: sub_product.id,
      nickname: "Professional Plan",
      currency: "usd",
      recurring: %{interval: "month"},
      unit_amount: 29900,
      metadata: %{
        included_scans: "15000",
        overage_price: "0.02"  # 2¢ per extra scan
      }
    })
    
    # Enterprise - $999/mo (100,000 scans included)
    Stripe.Price.create(%{
      product: sub_product.id,
      nickname: "Enterprise Plan",
      currency: "usd",
      recurring: %{interval: "month"},
      unit_amount: 99900,
      metadata: %{
        included_scans: "100000",
        overage_price: "0.015",  # 1.5¢ per extra scan
        features: "priority_support,custom_rules,sla"
      }
    })
    
    IO.puts("Products created! Update price IDs in Kyozo.Billing.SafeMD module")
  end
end

SetupStripe.create_products()
```

## Webhook Configuration

1. In Stripe Dashboard, go to Developers → Webhooks
2. Add endpoint: `https://api.kyozo.com/webhooks/stripe`
3. Select events:
   - `checkout.session.completed`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`

## Database Migrations

```elixir
# Create billing tables
defmodule Kyozo.Repo.Migrations.CreateBillingTables do
  use Ecto.Migration
  
  def change do
    # Credits ledger
    create table(:billing_credits) do
      add :user_id, references(:users), null: false
      add :amount, :integer, null: false  # Can be negative for deductions
      add :balance, :integer, null: false  # Running balance
      add :service, :string, null: false  # "safemd_scan"
      add :description, :string
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create index(:billing_credits, [:user_id, :service])
    create index(:billing_credits, :inserted_at)
    
    # Usage tracking
    create table(:billing_usage) do
      add :user_id, references(:users), null: false
      add :service, :string, null: false
      add :quantity, :integer, default: 1
      add :metadata, :map, default: %{}
      add :billed, :boolean, default: false
      
      timestamps()
    end
    
    create index(:billing_usage, [:user_id, :service, :inserted_at])
    create index(:billing_usage, [:billed, :inserted_at])
    
    # Subscription cache
    create table(:billing_subscriptions) do
      add :user_id, references(:users), null: false
      add :stripe_subscription_id, :string, null: false
      add :stripe_customer_id, :string, null: false
      add :service, :string, null: false
      add :plan, :string, null: false
      add :status, :string, null: false
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancel_at_period_end, :boolean, default: false
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create unique_index(:billing_subscriptions, :stripe_subscription_id)
    create index(:billing_subscriptions, [:user_id, :service])
    
    # Add Stripe customer ID to users
    alter table(:users) do
      add :stripe_customer_id, :string
    end
    
    create unique_index(:users, :stripe_customer_id)
  end
end
```

## Controller Integration

```elixir
defmodule KyozoWeb.BillingController do
  use KyozoWeb, :controller
  
  alias Kyozo.Billing.SafeMD
  
  def checkout(conn, %{"product" => product}) do
    user = conn.assigns.current_user
    product_atom = String.to_atom(product)
    
    success_url = Routes.billing_url(conn, :success)
    cancel_url = Routes.billing_url(conn, :plans)
    
    case SafeMD.create_checkout_session(user, product_atom, success_url, cancel_url) do
      {:ok, session} ->
        # Redirect to Stripe Checkout
        redirect(conn, external: session.url)
        
      {:error, reason} ->
        conn
        |> put_flash(:error, "Unable to create checkout session: #{reason}")
        |> redirect(to: Routes.billing_path(conn, :plans))
    end
  end
  
  def success(conn, %{"session_id" => session_id}) do
    # Verify session and show success page
    conn
    |> put_flash(:info, "Payment successful! Your credits will be available shortly.")
    |> redirect(to: Routes.dashboard_path(conn, :index))
  end
  
  def usage(conn, _params) do
    user = conn.assigns.current_user
    billing_status = SafeMD.get_billing_status(user)
    
    render(conn, "usage.html", billing_status: billing_status)
  end
end
```

## Webhook Handler

```elixir
defmodule KyozoWeb.WebhookController do
  use KyozoWeb, :controller
  
  alias Kyozo.Billing.SafeMD
  
  def stripe(conn, _params) do
    payload = conn.assigns.raw_body
    signature = get_req_header(conn, "stripe-signature") |> List.first()
    
    case Stripe.Webhook.construct_event(
      payload,
      signature,
      Application.get_env(:stripity_stripe, :webhook_secret)
    ) do
      {:ok, event} ->
        # Process async to return quickly
        Task.start(fn -> SafeMD.handle_webhook(event) end)
        
        conn
        |> put_status(200)
        |> json(%{received: true})
        
      {:error, reason} ->
        Logger.error("Invalid webhook: #{reason}")
        
        conn
        |> put_status(400)
        |> json(%{error: "Invalid signature"})
    end
  end
end
```

## Testing Payments

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to local
stripe listen --forward-to localhost:4000/webhooks/stripe

# Trigger test events
stripe trigger checkout.session.completed
stripe trigger invoice.payment_succeeded
```

## Frontend Integration

```javascript
// Load Stripe.js
const stripe = Stripe('<%= Application.get_env(:stripity_stripe, :public_key) %>');

// Redirect to checkout
async function purchaseCredits(productType) {
  const response = await fetch('/api/v1/billing/checkout', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify({ product: productType })
  });
  
  const { url } = await response.json();
  window.location.href = url;
}
```