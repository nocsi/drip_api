defmodule Dirup.Billing.Subscription do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "billing_subscriptions"
    repo Dirup.Repo

    identity_wheres_to_sql unique_apple_transaction: "provider = 'apple'",
                           unique_stripe_subscription: "provider = 'stripe'",
                           unique_google_purchase: "provider = 'google'"

    references do
      reference :customer, on_delete: :delete
      reference :user, on_delete: :delete
      reference :plan, on_delete: :restrict
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :user_id,
        :customer_id,
        :plan_id,
        :provider,
        :stripe_subscription_id,
        :apple_transaction_id,
        :apple_original_transaction_id,
        :apple_product_id,
        :apple_receipt_data,
        :google_purchase_token,
        :google_product_id,
        :status,
        :current_period_start,
        :current_period_end,
        :trial_start,
        :trial_end,
        :canceled_at,
        :expires_at,
        :auto_renew_enabled,
        :quantity,
        :apple_auto_renew_status,
        :apple_expiration_intent,
        :apple_grace_period_expires_date,
        :metadata
      ]

      change relate_actor(:user)

      validate fn changeset, _context ->
        provider = Ash.Changeset.get_attribute(changeset, :provider)
        stripe_id = Ash.Changeset.get_attribute(changeset, :stripe_subscription_id)
        apple_transaction = Ash.Changeset.get_attribute(changeset, :apple_transaction_id)
        google_token = Ash.Changeset.get_attribute(changeset, :google_purchase_token)

        case provider do
          :stripe when is_nil(stripe_id) ->
            {:error, "stripe_subscription_id required for Stripe subscriptions"}

          :apple when is_nil(apple_transaction) ->
            {:error, "apple_transaction_id required for Apple subscriptions"}

          :google when is_nil(google_token) ->
            {:error, "google_purchase_token required for Google subscriptions"}

          _ ->
            :ok
        end
      end
    end

    create :create_from_apple_receipt do
      argument :apple_receipt, :string, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        receipt = Ash.Changeset.get_argument(changeset, :apple_receipt)
        user_id = Ash.Changeset.get_argument(changeset, :user_id)

        case Dirup.Billing.AppleReceiptValidator.validate_and_parse(receipt) do
          {:ok, receipt_data} ->
            changeset
            |> Ash.Changeset.change_attribute(:provider, :apple)
            |> Ash.Changeset.change_attribute(:user_id, user_id)
            |> Ash.Changeset.change_attribute(:apple_receipt_data, receipt)
            |> Ash.Changeset.change_attribute(
              :apple_transaction_id,
              receipt_data.latest_transaction_id
            )
            |> Ash.Changeset.change_attribute(
              :apple_original_transaction_id,
              receipt_data.original_transaction_id
            )
            |> Ash.Changeset.change_attribute(:apple_product_id, receipt_data.product_id)
            |> Ash.Changeset.change_attribute(:current_period_start, receipt_data.purchase_date)
            |> Ash.Changeset.change_attribute(:current_period_end, receipt_data.expires_date)
            |> Ash.Changeset.change_attribute(:status, parse_apple_status(receipt_data))
            |> Ash.Changeset.change_attribute(:auto_renew_enabled, receipt_data.auto_renew_status)
            |> Ash.Changeset.change_attribute(
              :apple_auto_renew_status,
              receipt_data.auto_renew_status
            )

          {:error, reason} ->
            Ash.Changeset.add_error(changeset, "Invalid Apple receipt: #{reason}")
        end
      end
    end

    update :update do
      primary? true

      accept [
        :status,
        :current_period_start,
        :current_period_end,
        :trial_start,
        :trial_end,
        :canceled_at,
        :expires_at,
        :cancel_at_period_end,
        :auto_renew_enabled,
        :quantity,
        :apple_auto_renew_status,
        :apple_expiration_intent,
        :apple_grace_period_expires_date,
        :metadata
      ]
    end

    read :by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :by_apple_transaction do
      argument :transaction_id, :string, allow_nil?: false
      get? true
      filter expr(apple_transaction_id == ^arg(:transaction_id) and provider == :apple)
    end

    read :active_subscriptions do
      filter expr(
               (status in [:active, :trialing] and current_period_end > now()) or
                 (provider == :apple and apple_grace_period_expires_date > now())
             )
    end

    update :cancel do
      argument :cancel_at_period_end, :boolean, default: true
      argument :cancel_reason, :string

      change fn changeset, _context ->
        cancel_at_period_end = Ash.Changeset.get_argument(changeset, :cancel_at_period_end)
        cancel_reason = Ash.Changeset.get_argument(changeset, :cancel_reason)

        changeset
        |> Ash.Changeset.change_attribute(:cancel_at_period_end, cancel_at_period_end)
        |> Ash.Changeset.change_attribute(:canceled_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:metadata, %{
          cancel_reason: cancel_reason,
          canceled_by: "user"
        })
      end

      change after_action(fn changeset, subscription, _context ->
               # Handle cancellation per provider
               case subscription.provider do
                 :stripe ->
                   cancel_stripe_subscription(subscription, changeset)

                 :apple ->
                   # Apple subscriptions are canceled through the App Store
                   # We just update our local status
                   {:ok, subscription}

                 :google ->
                   cancel_google_subscription(subscription, changeset)

                 _ ->
                   {:ok, subscription}
               end
             end)
    end

    update :sync_apple_receipt do
      argument :receipt_data, :string, allow_nil?: false

      change fn changeset, _context ->
        receipt = Ash.Changeset.get_argument(changeset, :receipt_data)

        case Dirup.Billing.AppleReceiptValidator.validate_and_parse(receipt) do
          {:ok, receipt_data} ->
            changeset
            |> Ash.Changeset.change_attribute(:apple_receipt_data, receipt)
            |> Ash.Changeset.change_attribute(:current_period_end, receipt_data.expires_date)
            |> Ash.Changeset.change_attribute(:status, parse_apple_status(receipt_data))
            |> Ash.Changeset.change_attribute(
              :apple_auto_renew_status,
              receipt_data.auto_renew_status
            )
            |> Ash.Changeset.change_attribute(
              :apple_grace_period_expires_date,
              receipt_data.grace_period_expires_date
            )

          {:error, reason} ->
            Ash.Changeset.add_error(changeset, "Invalid Apple receipt: #{reason}")
        end
      end
    end

    update :sync_stripe do
      argument :stripe_data, :map, allow_nil?: false

      change fn changeset, _context ->
        stripe_data = Ash.Changeset.get_argument(changeset, :stripe_data)

        changeset
        |> Ash.Changeset.change_attribute(
          :status,
          stripe_status_to_subscription_status(stripe_data["status"])
        )
        |> Ash.Changeset.change_attribute(
          :current_period_start,
          DateTime.from_unix!(stripe_data["current_period_start"])
        )
        |> Ash.Changeset.change_attribute(
          :current_period_end,
          DateTime.from_unix!(stripe_data["current_period_end"])
        )
        |> Ash.Changeset.change_attribute(
          :metadata,
          Map.merge(changeset.data.metadata || %{}, %{
            "stripe_synced_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          })
        )
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :atom do
      allow_nil? false
      default :stripe
      constraints one_of: [:stripe, :apple, :google, :direct]
    end

    # Stripe-specific fields
    attribute :stripe_subscription_id, :string do
      constraints max_length: 255
    end

    # Apple-specific fields
    attribute :apple_transaction_id, :string do
      constraints max_length: 255
    end

    attribute :apple_original_transaction_id, :string do
      constraints max_length: 255
    end

    attribute :apple_product_id, :string do
      constraints max_length: 255
    end

    attribute :apple_receipt_data, :string do
      # Base64 encoded receipt can be large
      constraints max_length: 10000
    end

    # Google Play specific fields
    attribute :google_purchase_token, :string do
      constraints max_length: 500
    end

    attribute :google_product_id, :string do
      constraints max_length: 255
    end

    # Common subscription fields
    attribute :status, :atom do
      allow_nil? false
      default :active

      constraints one_of: [
                    :active,
                    :past_due,
                    :canceled,
                    :incomplete,
                    :incomplete_expired,
                    :trialing,
                    :unpaid,
                    :expired,
                    :pending_renewal,
                    :billing_retry
                  ]
    end

    attribute :current_period_start, :utc_datetime do
      allow_nil? false
    end

    attribute :current_period_end, :utc_datetime do
      allow_nil? false
    end

    attribute :trial_start, :utc_datetime
    attribute :trial_end, :utc_datetime

    attribute :canceled_at, :utc_datetime
    attribute :expires_at, :utc_datetime

    attribute :cancel_at_period_end, :boolean do
      default false
    end

    attribute :auto_renew_enabled, :boolean do
      default true
    end

    attribute :quantity, :integer do
      default 1
    end

    # Apple-specific renewal info
    attribute :apple_auto_renew_status, :boolean
    attribute :apple_expiration_intent, :integer
    attribute :apple_grace_period_expires_date, :utc_datetime

    attribute :metadata, :map do
      default %{}
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Dirup.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :customer, Dirup.Billing.Customer do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :plan, Dirup.Billing.Plan do
      allow_nil? false
      attribute_writable? true
    end

    has_many :usage_records, Dirup.Billing.Usage
  end

  calculations do
    calculate :is_active,
              :boolean,
              expr(
                (status in [:active, :trialing] and current_period_end > now()) or
                  (provider == :apple and apple_grace_period_expires_date > now() and
                     apple_auto_renew_status == true)
              )

    calculate :days_until_renewal,
              :integer,
              expr(fragment("EXTRACT(DAY FROM ? - ?)", current_period_end, now()))

    calculate :is_in_grace_period,
              :boolean,
              expr(
                provider == :apple and
                  status == :expired and
                  apple_grace_period_expires_date > now()
              )
  end

  identities do
    identity :unique_stripe_subscription, [:stripe_subscription_id],
      where: expr(provider == :stripe)

    identity :unique_apple_transaction, [:apple_original_transaction_id],
      where: expr(provider == :apple)

    identity :unique_google_purchase, [:google_purchase_token], where: expr(provider == :google)
  end

  # Private functions for the module
  defp parse_apple_status(receipt_data) do
    cond do
      receipt_data.expires_date > DateTime.utc_now() ->
        :active

      receipt_data.grace_period_expires_date &&
          receipt_data.grace_period_expires_date > DateTime.utc_now() ->
        :past_due

      true ->
        :expired
    end
  end

  defp cancel_stripe_subscription(subscription, changeset) do
    cancel_at_period_end = Ash.Changeset.get_argument(changeset, :cancel_at_period_end)

    case Stripe.Subscription.update(subscription.stripe_subscription_id, %{
           cancel_at_period_end: cancel_at_period_end
         }) do
      {:ok, _stripe_subscription} -> {:ok, subscription}
      {:error, error} -> {:error, error}
    end
  end

  defp cancel_google_subscription(_subscription, _changeset) do
    # Implement Google Play subscription cancellation
    # This would typically involve the Google Play Developer API
    {:ok, "Google Play cancellation not implemented"}
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
