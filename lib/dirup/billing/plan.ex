defmodule Dirup.Billing.Plan do
  use Ash.Resource,
    domain: Dirup.Billing,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "billing_plan"

    routes do
      base "/billing/plans"

      index :read
      get :read
      get :by_code, route: "/by_code/:code"
    end
  end

  postgres do
    table "billing_plans"
    repo Dirup.Repo
  end

  code_interface do
    define :read
    define :by_code, args: [:code]
    define :active
    define :by_tier, args: [:tier]
    define :create_with_stripe
    define :sync_stripe
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    read :by_code do
      argument :code, :string do
        allow_nil? false
      end

      get? true
      filter expr(code == ^arg(:code) and active == true)
    end

    read :active do
      filter expr(active == true)
    end

    read :by_tier do
      argument :tier, :atom do
        allow_nil? false
        constraints one_of: [:free, :pro, :team, :enterprise]
      end

      filter expr(tier == ^arg(:tier) and active == true)
    end

    create :create_with_stripe do
      accept [
        :code,
        :name,
        :description,
        :tier,
        :price_cents,
        :currency,
        :interval,
        :trial_days,
        :features,
        :max_notebooks,
        :max_executions_per_month,
        :max_ai_requests_per_month,
        :max_storage_gb,
        :max_collaborators
      ]

      change fn changeset, _context ->
        # Create Stripe product and price
        with {:ok, product} <- create_stripe_product(changeset),
             {:ok, price} <- create_stripe_price(changeset, product) do
          changeset
          |> Ash.Changeset.change_attribute(:stripe_product_id, product.id)
          |> Ash.Changeset.change_attribute(:stripe_price_id, price.id)
        else
          {:error, error} ->
            Ash.Changeset.add_error(changeset,
              field: :base,
              message: "Failed to create Stripe product: #{inspect(error)}"
            )
        end
      end
    end

    update :sync_stripe do
      manual fn changeset, _context ->
        plan = changeset.data

        # Update Stripe product
        case Stripe.Product.update(plan.stripe_product_id, %{
               name: plan.name,
               description: plan.description,
               metadata: %{
                 tier: to_string(plan.tier),
                 code: plan.code
               }
             }) do
          {:ok, _product} ->
            {:ok, plan}

          {:error, error} ->
            {:error, "Failed to sync with Stripe: #{inspect(error)}"}
        end
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :code, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[A-Z0-9_]+$/
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :tier, :atom do
      constraints one_of: [:free, :pro, :team, :enterprise]
      allow_nil? false
      public? true
    end

    attribute :price_cents, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :currency, :string do
      default "USD"
      public? true
    end

    attribute :interval, :atom do
      constraints one_of: [:monthly, :yearly]
      allow_nil? false
      default :monthly
      public? true
    end

    attribute :trial_days, :integer do
      default 0
      public? true
    end

    attribute :active, :boolean do
      default true
      public? true
    end

    # Feature limits
    attribute :max_notebooks, :integer do
      allow_nil? true
      public? true
    end

    attribute :max_executions_per_month, :integer do
      allow_nil? true
      public? true
    end

    attribute :max_ai_requests_per_month, :integer do
      allow_nil? true
      public? true
    end

    attribute :max_storage_gb, :integer do
      allow_nil? true
      public? true
    end

    attribute :max_collaborators, :integer do
      allow_nil? true
      public? true
    end

    # Feature flags
    attribute :features, :map do
      default %{}
      public? true
    end

    # Stripe integration
    attribute :stripe_price_id, :string do
      allow_nil? true
      public? true
    end

    attribute :stripe_product_id, :string do
      allow_nil? true
      public? true
    end

    # Apple integration
    attribute :apple_product_id, :string do
      allow_nil? true
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    timestamps()
  end

  calculations do
    calculate :price_display, :string do
      calculation fn records, _context ->
        Enum.map(records, fn plan ->
          amount = plan.price_cents / 100
          interval = if plan.interval == :yearly, do: "year", else: "month"
          "$#{amount}/#{interval}"
        end)
      end
    end

    calculate :monthly_price, :integer do
      calculation fn records, _context ->
        Enum.map(records, fn plan ->
          case plan.interval do
            :monthly -> plan.price_cents
            :yearly -> div(plan.price_cents, 12)
          end
        end)
      end
    end
  end

  # Private helper functions
  defp create_stripe_product(changeset) do
    name = Ash.Changeset.get_attribute(changeset, :name)
    description = Ash.Changeset.get_attribute(changeset, :description)
    code = Ash.Changeset.get_attribute(changeset, :code)
    tier = Ash.Changeset.get_attribute(changeset, :tier)

    Stripe.Product.create(%{
      name: name,
      description: description,
      metadata: %{
        code: code,
        tier: to_string(tier),
        created_by: "kyozo_api"
      }
    })
  end

  defp create_stripe_price(changeset, product) do
    price_cents = Ash.Changeset.get_attribute(changeset, :price_cents)
    currency = Ash.Changeset.get_attribute(changeset, :currency)
    interval = Ash.Changeset.get_attribute(changeset, :interval)

    Stripe.Price.create(%{
      product: product.id,
      unit_amount: price_cents,
      currency: String.downcase(currency),
      recurring: %{
        interval: to_string(interval)
      }
    })
  end
end
