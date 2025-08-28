defmodule Dirup.Billing.StripeConfig do
  @moduledoc """
  Centralized Stripe configuration and helpers for Ash 3.5 integration
  """

  @doc """
  Get configured Stripe API key
  """
  def api_key do
    Application.get_env(:stripity_stripe, :api_key) ||
      System.get_env("STRIPE_SECRET_KEY")
  end

  @doc """
  Get configured Stripe publishable key
  """
  def publishable_key do
    Application.get_env(:stripity_stripe, :public_key) ||
      System.get_env("STRIPE_PUBLISHABLE_KEY")
  end

  @doc """
  Get configured webhook secret
  """
  def webhook_secret do
    Application.get_env(:stripity_stripe, :webhook_secret) ||
      System.get_env("STRIPE_WEBHOOK_SECRET")
  end

  @doc """
  Check if Stripe is properly configured
  """
  def configured? do
    api_key() != nil && webhook_secret() != nil
  end

  @doc """
  Check if we're in test mode
  """
  def test_mode? do
    key = api_key()
    key && String.starts_with?(key, "sk_test_")
  end

  @doc """
  Configure Stripe client (useful for runtime configuration)
  """
  def configure do
    if key = api_key() do
      Application.put_env(:stripity_stripe, :api_key, key)
    end

    if secret = webhook_secret() do
      Application.put_env(:stripity_stripe, :webhook_secret, secret)
    end

    if pub_key = publishable_key() do
      Application.put_env(:stripity_stripe, :public_key, pub_key)
    end

    :ok
  end

  @doc """
  Create idempotency key for Stripe requests
  """
  def idempotency_key(prefix \\ "kyozo") do
    "#{prefix}_#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}"
  end

  @doc """
  Standard metadata for Stripe objects
  """
  def standard_metadata(additional \\ %{}) do
    Map.merge(
      %{
        "platform" => "kyozo",
        "ash_version" => "3.5",
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      additional
    )
  end

  @doc """
  Convert Stripe amount (cents) to Money
  """
  def stripe_amount_to_money(amount, currency \\ "USD") do
    currency_atom = String.to_atom(String.upcase(currency))
    Money.new(amount, currency_atom)
  end

  @doc """
  Convert Money to Stripe amount (cents)
  """
  def money_to_stripe_amount(%Money{} = money) do
    Money.to_amount(money) |> elem(0) |> trunc()
  end
end
