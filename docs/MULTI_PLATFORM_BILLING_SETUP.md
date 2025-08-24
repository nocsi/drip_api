# Kyozo Multi-Platform Billing Setup

## Overview

Kyozo supports multiple billing platforms to accommodate different user workflows:

- **Stripe**: Web users, credit card payments
- **Apple App Store**: iOS users via In-App Purchases
- **Google Play**: Android users (future implementation)
- **Direct**: Enterprise/manual billing

## Environment Variables Required

```bash
# Stripe Configuration
STRIPE_SECRET_KEY=sk_test_...                    # or sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_test_...              # or pk_live_...  
STRIPE_WEBHOOK_SECRET=whsec_...

# Apple App Store Configuration
APPLE_APP_STORE_SHARED_SECRET=your_shared_secret

# Database
DATABASE_URL=postgres://user:pass@localhost/kyozo_dev
```

## Setup Instructions

### 1. Install Dependencies

```bash
mix deps.get
```

### 2. Run Database Migrations

```bash
mix ash.setup
```

### 3. Create Billing Plans

```elixir
# In IEx or seeds file
alias Kyozo.Billing

# Free Plan
{:ok, _} = Billing.create_plan(%{
  code: "free",
  name: "Free Plan", 
  price: Decimal.new("0.00"),
  currency: "USD",
  billing_interval: :month,
  stripe_price_id: "price_free", # Not used for free plan
  features: %{
    ai_requests_per_month: 1000,
    rate_limit_per_minute: 5,
    features: ["basic_suggestions", "confidence_analysis"]
  }
})

# Pro Plan (matches Apple product ID)
{:ok, _} = Billing.create_plan(%{
  code: "pro_monthly", # Must match Apple product ID
  name: "Pro Monthly",
  price: Decimal.new("29.00"),
  currency: "USD", 
  billing_interval: :month,
  stripe_price_id: "price_1234567890", # From Stripe dashboard
  features: %{
    ai_requests_per_month: 25000,
    rate_limit_per_minute: 30,
    features: ["advanced_suggestions", "context_awareness", "priority_support"]
  }
})

# Enterprise Plan
{:ok, _} = Billing.create_plan(%{
  code: "enterprise",
  name: "Enterprise",
  price: Decimal.new("199.00"),
  currency: "USD",
  billing_interval: :month, 
  stripe_price_id: "price_enterprise_123",
  features: %{
    ai_requests_per_month: :unlimited,
    rate_limit_per_minute: 100,
    features: ["custom_models", "dedicated_instances", "sla_guarantee"]
  }
})
```

## API Usage Examples

### For Apple Users (iOS App)

```swift
// 1. User purchases subscription in iOS app
let payment = SKPayment(product: product) // product.productIdentifier = "pro_monthly"
SKPaymentQueue.default().add(payment)

// 2. After successful purchase, validate with Kyozo
let receiptURL = Bundle.main.appStoreReceiptURL!
let receiptData = try Data(contentsOf: receiptURL)
let receiptString = receiptData.base64EncodedString()

let request = [
    "receipt_data": receiptString,
    "plan_code": "pro_monthly"
]

// POST to /api/v1/billing/apple/validate
```

### For Web Users (Stripe)

```javascript
// 1. Create Stripe customer and subscription (standard Stripe flow)
const stripe = Stripe('pk_test_...');

// 2. Check subscription status
const response = await fetch('/api/v1/billing/subscription', {
  headers: { 'Authorization': 'Bearer ' + apiKey }
});

const { subscription, usage_limits } = await response.json();
```

### Check Subscription Status (Both Platforms)

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \\
  http://localhost:4000/api/v1/billing/subscription
```

Response:
```json
{
  "subscription": {
    "id": "uuid",
    "provider": "apple",
    "status": "active", 
    "current_period_end": "2024-02-01T00:00:00Z",
    "auto_renew_enabled": true,
    "plan": {
      "code": "pro_monthly",
      "name": "Pro Monthly",
      "features": {
        "ai_requests_per_month": 25000,
        "rate_limit_per_minute": 30
      }
    }
  },
  "usage_limits": {
    "ai_requests_per_month": 25000,
    "current_usage": 1250,
    "remaining_requests": 23750,
    "rate_limit_per_minute": 30
  }
}
```

## Webhook Setup

### Apple App Store Server-to-Server Notifications

1. Configure in App Store Connect:
   - URL: `https://yourdomain.com/api/webhooks/apple`
   - Version: Version 2

### Stripe Webhooks

1. Create webhook endpoint in Stripe Dashboard:
   - URL: `https://yourdomain.com/api/webhooks/stripe`
   - Events: `customer.subscription.updated`, `invoice.payment_succeeded`, `invoice.payment_failed`

## Testing

### Test Apple Receipt Validation

```bash
# Use a sandbox receipt from iOS Simulator
curl -X POST http://localhost:4000/api/v1/billing/apple/validate \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -d '{
    "receipt_data": "MIITugYJKoZIhvcNAQcCoIITqzCCE6cCAQExCzAJBg...",
    "plan_code": "pro_monthly"
  }'
```

### Test Stripe Integration

```bash
# Use Stripe test mode
curl -X POST http://localhost:4000/api/v1/billing/subscription \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -d '{
    "payment_method_id": "pm_card_visa",
    "plan_code": "pro_monthly"
  }'
```

## Production Considerations

### Security
- Validate Apple receipts server-side only
- Verify webhook signatures from Apple and Stripe  
- Use HTTPS for all billing endpoints
- Store sensitive config in environment variables

### Monitoring
- Track subscription conversion rates
- Monitor failed Apple receipt validations
- Alert on webhook failures
- Monitor AI usage vs. plan limits

### Compliance
- Handle Apple's grace period for failed renewals
- Support subscription refunds per platform policies
- Maintain audit trail of all billing events
- GDPR compliance for European users

## Troubleshooting

### Apple Receipt Validation Issues
- Check shared secret configuration
- Verify product IDs match between app and plans
- Test with sandbox receipts first
- Check Apple's receipt validation status codes

### Stripe Integration Issues  
- Verify API keys and webhook secrets
- Check webhook endpoint accessibility
- Test with Stripe CLI for local development
- Monitor Stripe Dashboard for failed events

## Database Schema

The billing system creates these tables:
- `billing_customers` - Customer records for all platforms
- `billing_subscriptions` - Subscription records with platform-specific fields
- `billing_plans` - Available subscription plans
- `billing_usage` - Usage tracking for billing
- `billing_invoices` - Invoice records (Stripe only)

Platform-specific fields are handled in the same tables using discriminator columns and nullable fields for different providers.