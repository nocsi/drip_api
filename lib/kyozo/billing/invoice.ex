defmodule Kyozo.Billing.Invoice do
  use Ash.Resource,
    domain: Kyozo.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "billing_invoices"
    repo Kyozo.Repo
  end

  code_interface do
    define :create
    define :by_user, args: [:user_id]
    define :unpaid
    define :overdue
    define :mark_paid
    define :cancel
    define :refund
    define :generate_from_usage, args: [:user_id, :month, :year]

    # Add this
    # define :sync_stripe
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :subscription_id, :due_date, :billing_period_start, :billing_period_end]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:invoice_number, generate_invoice_number())
        |> calculate_totals()
      end
    end

    update :update do
      primary? true
      accept [:status, :line_items, :metadata, :stripe_invoice_id, :payment_method]

      change fn changeset, _context ->
        calculate_totals(changeset)
      end
    end

    update :mark_paid do
      accept [:payment_method, :stripe_invoice_id]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :paid)
        |> Ash.Changeset.change_attribute(:paid_at, DateTime.utc_now())
      end
    end

    update :cancel do
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :status, :cancelled)
      end
    end

    update :refund do
      accept [:metadata]

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :status, :refunded)
      end
    end

    # Removed sync_stripe action due to atomicity issues in Ash 3.5
    # This functionality can be implemented at the domain level instead

    read :by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    read :unpaid do
      filter expr(status in [:pending, :overdue])
    end

    read :overdue do
      prepare fn query, _context ->
        today = Date.utc_today()

        query
        |> Ash.Query.filter(
          expr(
            status == :pending and
              due_date < ^today
          )
        )
      end
    end

    read :for_period do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :start_date, :date do
        allow_nil? false
      end

      argument :end_date, :date do
        allow_nil? false
      end

      filter expr(
               user_id == ^arg(:user_id) and
                 billing_period_start >= ^arg(:start_date) and
                 billing_period_end <= ^arg(:end_date)
             )
    end

    create :generate_from_usage do
      accept [:user_id, :subscription_id, :customer_id]

      argument :month, :integer do
        allow_nil? false
      end

      argument :year, :integer do
        allow_nil? false
      end

      change fn changeset, context ->
        {:ok, start_date} = Date.new(context.arguments.year, context.arguments.month, 1)
        days_in_month = Date.days_in_month(start_date)
        {:ok, end_date} = Date.new(context.arguments.year, context.arguments.month, days_in_month)

        # Due 15 days after period end
        due_date = Date.add(end_date, 15)

        changeset
        |> Ash.Changeset.change_attribute(:billing_period_start, start_date)
        |> Ash.Changeset.change_attribute(:billing_period_end, end_date)
        |> Ash.Changeset.change_attribute(:due_date, due_date)
        |> Ash.Changeset.change_attribute(:invoice_number, generate_invoice_number())
        |> Ash.Changeset.change_attribute(:status, :pending)
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :subscription_id, :uuid do
      allow_nil? true
      public? true
    end

    attribute :customer_id, :uuid do
      allow_nil? true
      public? true
    end

    attribute :invoice_number, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :pending, :paid, :overdue, :cancelled, :refunded]
      default :draft
      public? true
    end

    attribute :currency, :string do
      default "USD"
      public? true
    end

    attribute :subtotal, :decimal do
      allow_nil? false
      default 0
      public? true
    end

    attribute :tax_amount, :decimal do
      allow_nil? false
      default 0
      public? true
    end

    attribute :total, :decimal do
      allow_nil? false
      default 0
      public? true
    end

    attribute :due_date, :date do
      allow_nil? false
      public? true
    end

    attribute :paid_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :billing_period_start, :date do
      allow_nil? false
      public? true
    end

    attribute :billing_period_end, :date do
      allow_nil? false
      public? true
    end

    attribute :line_items, {:array, :map} do
      default []
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    attribute :stripe_invoice_id, :string do
      allow_nil? true
      public? true
    end

    attribute :stripe_payment_intent_id, :string do
      allow_nil? true
      public? true
    end

    attribute :payment_method, :atom do
      constraints one_of: [:stripe, :apple_pay, :bank_transfer, :credit]
      allow_nil? true
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

    belongs_to :subscription, Kyozo.Billing.Subscription do
      attribute_type :uuid
      source_attribute :subscription_id
      destination_attribute :id
    end

    belongs_to :customer, Kyozo.Billing.Customer do
      attribute_type :uuid
      source_attribute :customer_id
      destination_attribute :id
    end
  end

  # Private functions
  defp generate_invoice_number do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
    "INV-#{timestamp}-#{random}"
  end

  defp calculate_totals(changeset) do
    line_items = Ash.Changeset.get_attribute(changeset, :line_items) || []

    subtotal =
      line_items
      |> Enum.reduce(Decimal.new(0), fn item, acc ->
        amount = Decimal.new(to_string(item["amount"] || 0))
        Decimal.add(acc, amount)
      end)

    # 10% tax
    tax_rate = Decimal.new("0.1")
    tax_amount = Decimal.mult(subtotal, tax_rate)
    total = Decimal.add(subtotal, tax_amount)

    changeset
    |> Ash.Changeset.change_attribute(:subtotal, subtotal)
    |> Ash.Changeset.change_attribute(:tax_amount, tax_amount)
    |> Ash.Changeset.change_attribute(:total, total)
  end

  def sync_with_stripe(invoice, user, opts \\ []) do
    # TODO: Implement actual Stripe API call
    # This is a placeholder implementation
    if invoice.stripe_invoice_id do
      # Fetch invoice from Stripe
      {:ok,
       %{
         "id" => invoice.stripe_invoice_id,
         "status" => "paid",
         "payment_intent" => ("pi_" <> :crypto.strong_rand_bytes(16)) |> Base.encode16(),
         "amount_paid" => Decimal.to_float(invoice.total) * 100,
         "amount_due" => 0
       }}
    else
      {:error, "No Stripe invoice ID found"}
    end
  end

  defp stripe_status_to_atom(status) do
    case status do
      "draft" -> :draft
      "open" -> :pending
      "paid" -> :paid
      "uncollectible" -> :cancelled
      "void" -> :cancelled
      _ -> :pending
    end
  end
end
