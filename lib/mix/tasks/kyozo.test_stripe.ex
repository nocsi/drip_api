defmodule Mix.Tasks.Kyozo.TestStripe do
  use Mix.Task

  @shortdoc "Test Stripe integration with Ash"
  @moduledoc """
  Tests the Stripe integration to ensure it's working correctly.

  ## Usage

      mix kyozo.test_stripe [email]

  ## Examples

      mix kyozo.test_stripe
      mix kyozo.test_stripe test@example.com
  """

  alias Kyozo.Billing.StripeTest

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    email = List.first(args) || "test_#{System.unique_integer([:positive])}@example.com"

    IO.puts("Testing Stripe integration with email: #{email}")
    IO.puts("=====================================")

    # Test 1: Check Stripe configuration
    test_stripe_config()

    # Test 2: Test customer creation
    test_customer_creation(email)

    # Test 3: Test subscription flow
    test_subscription_flow(email)

    # Test 4: Test webhook processing
    test_webhook_processing()

    IO.puts("\nAll tests completed!")
  end

  defp test_stripe_config do
    IO.puts("\n1. Testing Stripe Configuration:")

    api_key = Application.get_env(:stripity_stripe, :api_key)
    webhook_secret = Application.get_env(:stripity_stripe, :webhook_secret)

    if api_key && String.starts_with?(api_key, "sk_test_") do
      IO.puts("   ✓ Stripe API key configured (test mode)")
    else
      IO.puts("   ✗ Stripe API key not configured or not in test mode")
      IO.puts("     Set STRIPE_SECRET_KEY environment variable")
    end

    if webhook_secret && String.starts_with?(webhook_secret, "whsec_") do
      IO.puts("   ✓ Stripe webhook secret configured")
    else
      IO.puts("   ✗ Stripe webhook secret not configured")
      IO.puts("     Set STRIPE_WEBHOOK_SECRET environment variable")
    end
  end

  defp test_customer_creation(email) do
    IO.puts("\n2. Testing Customer Creation:")

    case StripeTest.test_subscription_flow(email) do
      {:ok, %{customer: customer}} ->
        IO.puts("   ✓ Customer created successfully")
        IO.puts("     - Customer ID: #{customer.id}")
        IO.puts("     - Stripe ID: #{customer.stripe_customer_id}")

      {:error, error} ->
        IO.puts("   ✗ Customer creation failed: #{inspect(error)}")
    end
  end

  defp test_subscription_flow(email) do
    IO.puts("\n3. Testing Subscription Flow:")

    case StripeTest.test_subscription_flow(email) do
      {:ok, %{subscription: subscription}} ->
        IO.puts("   ✓ Subscription created successfully")
        IO.puts("     - Subscription ID: #{subscription.id}")
        IO.puts("     - Status: #{subscription.status}")

        IO.puts(
          "     - Period: #{subscription.current_period_start} to #{subscription.current_period_end}"
        )

      {:error, error} ->
        IO.puts("   ✗ Subscription creation failed: #{inspect(error)}")
    end
  end

  defp test_webhook_processing do
    IO.puts("\n4. Testing Webhook Processing:")

    # Simulate a subscription created event
    test_event = %{
      "id" => "sub_test_#{System.unique_integer([:positive])}",
      "customer" => "cus_test_123",
      "status" => "active",
      "current_period_start" => System.system_time(:second),
      # 30 days
      "current_period_end" => System.system_time(:second) + 2_592_000,
      "items" => %{
        "data" => [
          %{
            "price" => %{
              "id" => "price_test_123"
            }
          }
        ]
      }
    }

    case StripeTest.test_webhook_event("customer.subscription.created", test_event) do
      {:ok, _} ->
        IO.puts("   ✓ Webhook processing works")

      {:error, error} ->
        IO.puts("   ✗ Webhook processing failed: #{inspect(error)}")
    end
  end
end
