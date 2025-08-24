defmodule Kyozo.Billing.Customer do
  use Ash.Resource,
    domain: Kyozo.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "billing_customers"
    repo Kyozo.Repo
  end

  code_interface do
    define :create
    define :by_user, args: [:user_id]
    define :sync_stripe
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    read :by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      get? true
      filter expr(user_id == ^arg(:user_id))
    end

    update :sync_stripe do
      manual fn changeset, _context ->
        customer = changeset.data

        case Stripe.Customer.retrieve(customer.stripe_customer_id) do
          {:ok, stripe_customer} ->
            updated =
              customer
              |> Ash.Changeset.for_update(:update, %{
                email: stripe_customer.email,
                name: stripe_customer.name,
                metadata:
                  Map.merge(customer.metadata || %{}, %{
                    "stripe_synced_at" => DateTime.utc_now() |> DateTime.to_iso8601()
                  })
              })
              |> Ash.update!()

            {:ok, updated}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :stripe_customer_id, :string do
      allow_nil? true
      public? true
    end

    attribute :apple_user_id, :string do
      allow_nil? true
      public? true
    end

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      public? true
    end

    attribute :provider, :atom do
      constraints one_of: [:stripe, :apple]
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Kyozo.Accounts.User do
      attribute_type :uuid
      source_attribute :user_id
      destination_attribute :id
    end
  end
end
