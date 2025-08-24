# Kyozo.store Pricing & Products

## Domain: **Kyozo.store** (NOT Kyozo.AI)

## Markdown Intelligence Services

### 1. **PromptSpect** - Security Scanning
- **Purpose**: Scan markdown/prompts for injection attacks and security vulnerabilities
- **Pricing**: $0.03 per scan
- **Endpoint**: `POST /api/v1/markdown/scan`
- **Billing Unit**: markdown/scan

### 2. **Impromptu** - Prompt Enhancement  
- **Purpose**: Automatically enhance prompts with context-aware improvements
- **Pricing**: $0.05 per enhancement
- **Endpoint**: `POST /api/v1/markdown/rally`
- **Billing Unit**: prompt/enhancement
- **Value Prop**: "Nobody wants to think about prompt engineering - we do it for you"

### 3. **Polyglot** - Multilingual Support
- **Purpose**: Add intelligent translations to markdown content
- **Pricing**: $0.02 per KB
- **Endpoint**: `POST /api/v1/markdown/polyglot`
- **Billing Unit**: kb/translation

## Subscription Plans

### Free Tier
- 10 PromptSpect scans/month
- 2 Impromptu enhancements/month  
- 10 KB Polyglot translations/month

### Pro Plan - $29/month (or $290/year)
- 1,000 PromptSpect scans/month
- 500 Impromptu enhancements/month
- 1,000 KB Polyglot translations/month
- Priority support

### Enterprise Plan - $99/month
- 10,000 PromptSpect scans/month
- 5,000 Impromptu enhancements/month
- 10,000 KB Polyglot translations/month
- Dedicated support
- Custom integrations

## Stripe Setup Commands

```bash
# Set your Stripe keys
export STRIPE_SECRET_KEY="sk_test_..."
export STRIPE_PUBLISHABLE_KEY="pk_test_..."
export STRIPE_WEBHOOK_SECRET="whsec_..."

# Create products in Stripe
mix run priv/scripts/create_stripe_products.exs

# Run migrations
mix ecto.migrate

# Start server
mix phx.server
```

## Testing the APIs

```bash
# Test PromptSpect
curl -X POST http://localhost:4000/api/v1/markdown/scan \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "markdown": "# Hello\n<script>alert(\"xss\")</script>",
    "strict_mode": true
  }'

# Test Impromptu
curl -X POST http://localhost:4000/api/v1/markdown/rally \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "prompt": "Write a function to calculate tax",
    "enhancement_level": "comprehensive"
  }'

# Test Polyglot  
curl -X POST http://localhost:4000/api/v1/markdown/polyglot \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "markdown": "# User Guide\nThis is how you use the app...",
    "target_languages": ["es", "fr", "ja"]
  }'
```

## Important Notes

1. **Domain is Kyozo.store** - Not Kyozo.AI!
2. All prices are in USD
3. Usage is tracked automatically via the AIUsageTracking plug
4. Billing is handled through Stripe metered billing
5. Free tier enforced via quota checking in the billing module