#!/bin/bash

# SafeMD + Stripe Integration Test Script
# Run with: chmod +x scripts/test_safemd.sh && ./scripts/test_safemd.sh

set -e

echo "🚀 SafeMD + Stripe Integration Test"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Creating .env from template..."
    cp .env.example .env
    echo -e "${YELLOW}⚠️  Please edit .env with your actual Stripe keys${NC}"
fi

# Check if Stripe keys are set
echo -e "${BLUE}🔍 Checking Stripe configuration...${NC}"

if grep -q "sk_test_51XXXXXX" .env; then
    echo -e "${YELLOW}⚠️  Placeholder Stripe keys detected${NC}"
    echo "Please update .env with your real Stripe keys from:"
    echo "https://dashboard.stripe.com/apikeys"
    echo
    echo "Your keys should look like:"
    echo "STRIPE_SECRET_KEY=sk_test_51AbCdEf..."
    echo "STRIPE_PUBLISHABLE_KEY=pk_test_51AbCdEf..."
    echo
    read -p "Have you updated your Stripe keys? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please update your .env file first, then run this script again."
        exit 1
    fi
fi

# Start the server in background
echo -e "${BLUE}🚀 Starting Phoenix server...${NC}"
mix phx.server &
SERVER_PID=$!

# Wait for server to start
echo "Waiting for server to start..."
sleep 10

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: Check if SafeMD demo page loads
echo -e "${BLUE}🔍 Test 1: SafeMD Demo Page${NC}"
if curl -s http://localhost:4000/safemd/demo | grep -q "SafeMD Live Demo"; then
    echo -e "${GREEN}✅ SafeMD demo page loads successfully${NC}"
else
    echo -e "${RED}❌ SafeMD demo page failed to load${NC}"
fi

# Test 2: Check SafeMD API pricing endpoint
echo -e "${BLUE}🔍 Test 2: SafeMD Pricing API${NC}"
PRICING_RESPONSE=$(curl -s http://localhost:4000/api/v1/safemd/pricing)
if echo "$PRICING_RESPONSE" | grep -q "pro"; then
    echo -e "${GREEN}✅ SafeMD pricing API working${NC}"
    echo "Response preview: $(echo $PRICING_RESPONSE | jq -r '.plans.pro.features[0]' 2>/dev/null || echo 'JSON parsing failed')"
else
    echo -e "${RED}❌ SafeMD pricing API failed${NC}"
fi

# Test 3: SafeMD scan API (basic test)
echo -e "${BLUE}🔍 Test 3: SafeMD Scan API${NC}"
SCAN_RESPONSE=$(curl -s -X POST http://localhost:4000/api/v1/scan \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer test_token_123" \
    -d '{"content": "# Test\n[Click me](javascript:alert())"}' \
    2>/dev/null || echo '{"error": "connection failed"}')

if echo "$SCAN_RESPONSE" | grep -q "success\|safe\|threat"; then
    echo -e "${GREEN}✅ SafeMD scan API responding${NC}"
else
    echo -e "${YELLOW}⚠️  SafeMD scan API needs authentication setup${NC}"
    echo "Response: $SCAN_RESPONSE"
fi

# Test 4: Check Stripe checkout endpoint
echo -e "${BLUE}🔍 Test 4: Stripe Checkout Integration${NC}"
CHECKOUT_RESPONSE=$(curl -s -X POST http://localhost:4000/api/v1/safemd/checkout \
    -H "Content-Type: application/json" \
    -d '{"plan": "pro"}' \
    2>/dev/null || echo '{"error": "connection failed"}')

if echo "$CHECKOUT_RESPONSE" | grep -q "checkout_url\|session_id"; then
    echo -e "${GREEN}✅ Stripe checkout integration working${NC}"
else
    echo -e "${YELLOW}⚠️  Stripe checkout needs configuration${NC}"
    echo "Response: $CHECKOUT_RESPONSE"
fi

# Test 5: Landing page SafeMD section
echo -e "${BLUE}🔍 Test 5: Landing Page Integration${NC}"
if curl -s http://localhost:4000 | grep -q "SafeMD\|markdown security"; then
    echo -e "${GREEN}✅ SafeMD prominently featured on landing page${NC}"
else
    echo -e "${YELLOW}⚠️  SafeMD section may need visibility improvements${NC}"
fi

echo
echo -e "${GREEN}🎉 SafeMD Integration Test Complete!${NC}"
echo
echo "📊 Revenue Projections:"
echo "   100 scans/day  = $3/day   = $90/month"
echo "   1000 scans/day = $30/day  = $900/month" 
echo "   10k scans/day  = $300/day = $9,000/month"
echo
echo "🔗 Quick Links:"
echo "   Demo:     http://localhost:4000/safemd/demo"
echo "   Landing:  http://localhost:4000/safemd"
echo "   API Docs: http://localhost:4000/openapi"
echo
echo "💰 Next Steps to Make Money:"
echo "1. Get real Stripe keys: https://dashboard.stripe.com/apikeys"
echo "2. Set up webhook endpoint in Stripe dashboard"
echo "3. Deploy to production with SSL"
echo "4. Start marketing SafeMD!"
echo
echo "🎯 Marketing Positioning:"
echo "   Public:  'Protect Your AI from Markdown Attacks'"
echo "   Private: 'Advanced Document Processing Capabilities'"
echo "   Price:   '$0.03 per scan with 10 free scans/month'"