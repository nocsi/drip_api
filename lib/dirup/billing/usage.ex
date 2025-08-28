defmodule Dirup.Billing.Usage do
  use Ash.Resource,
    domain: Dirup.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "billing_usage"
    repo Dirup.Repo
  end

  code_interface do
    define :create
    define :record_usage
    define :by_user, args: [:user_id]
    define :by_period, args: [:user_id, :start_date, :end_date]
    define :get_monthly_usage, args: [:user_id, :month, :year]
    define :get_monthly_usage_summary, args: [:user_id, :month, :year]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :user_id,
        :subscription_id,
        :resource_type,
        :quantity,
        :unit,
        :metadata,
        :period_start,
        :period_end
      ]
    end

    update :update do
      primary? true
      accept [:quantity, :metadata]
    end

    create :record_usage do
      accept [:user_id, :subscription_id, :resource_type, :quantity, :unit, :metadata]

      change fn changeset, _context ->
        now = DateTime.utc_now()

        changeset
        |> Ash.Changeset.change_attribute(:period_start, now)
        |> Ash.Changeset.change_attribute(:period_end, now)
      end
    end

    read :by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    read :by_period do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :start_date, :utc_datetime_usec do
        allow_nil? false
      end

      argument :end_date, :utc_datetime_usec do
        allow_nil? false
      end

      filter expr(
               user_id == ^arg(:user_id) and
                 period_start >= ^arg(:start_date) and
                 period_end <= ^arg(:end_date)
             )
    end

    read :get_daily_usage do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :date, :date do
        allow_nil? true
        default &Date.utc_today/0
      end

      prepare fn query, context ->
        date = context.arguments.date
        start_datetime = DateTime.new!(date, ~T[00:00:00.000000], "Etc/UTC")
        end_datetime = DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")

        query
        |> Ash.Query.filter(
          expr(
            user_id == ^context.arguments.user_id and
              period_start >= ^start_datetime and
              period_end <= ^end_datetime
          )
        )
      end
    end

    # Add get_monthly_usage action
    read :get_monthly_usage do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :month, :integer do
        allow_nil? true
      end

      argument :year, :integer do
        allow_nil? true
      end

      prepare fn query, context ->
        now = DateTime.utc_now()
        month = context.arguments[:month] || now.month
        year = context.arguments[:year] || now.year
        {:ok, start_date} = Date.new(year, month, 1)
        days_in_month = Date.days_in_month(start_date)
        {:ok, end_date} = Date.new(year, month, days_in_month)

        start_datetime = DateTime.new!(start_date, ~T[00:00:00.000000], "Etc/UTC")
        end_datetime = DateTime.new!(end_date, ~T[23:59:59.999999], "Etc/UTC")

        query
        |> Ash.Query.filter(
          expr(
            user_id == ^context.arguments[:user_id] and
              period_start >= ^start_datetime and
              period_end <= ^end_datetime
          )
        )
      end
    end

    # Add aggregate monthly usage by type
    read :get_monthly_usage_summary do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :month, :integer do
        allow_nil? true
      end

      argument :year, :integer do
        allow_nil? true
      end

      prepare fn query, context ->
        now = DateTime.utc_now()
        month = context.arguments[:month] || now.month
        year = context.arguments[:year] || now.year
        {:ok, start_date} = Date.new(year, month, 1)
        days_in_month = Date.days_in_month(start_date)
        {:ok, end_date} = Date.new(year, month, days_in_month)

        start_datetime = DateTime.new!(start_date, ~T[00:00:00.000000], "Etc/UTC")
        end_datetime = DateTime.new!(end_date, ~T[23:59:59.999999], "Etc/UTC")

        query
        |> Ash.Query.filter(
          expr(
            user_id == ^context.arguments[:user_id] and
              period_start >= ^start_datetime and
              period_end <= ^end_datetime
          )
        )
        |> Ash.Query.group_by([:resource_type, :unit])
        |> Ash.Query.aggregate(:total_quantity, :sum, :quantity)
        |> Ash.Query.aggregate(:usage_count, :count, :id)
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

    attribute :resource_type, :atom do
      constraints one_of: [
                    :markdown_render,
                    :ai_request,
                    :storage,
                    :compute_minutes,
                    :markdown_sanitize,
                    :markdown_inject
                  ]

      allow_nil? false
      public? true
    end

    attribute :quantity, :decimal do
      allow_nil? false
      default 0
      public? true
    end

    attribute :unit, :atom do
      constraints one_of: [:count, :minutes, :gigabytes, :requests]
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    attribute :period_start, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :period_end, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Dirup.Accounts.User do
      attribute_type :uuid
      source_attribute :user_id
      destination_attribute :id
    end

    belongs_to :subscription, Dirup.Billing.Subscription do
      attribute_type :uuid
      source_attribute :subscription_id
      destination_attribute :id
    end
  end

  # Helper function to calculate usage costs
  def calculate_monthly_cost(usage_records) do
    usage_records
    |> Enum.reduce(Decimal.new(0), fn record, acc ->
      cost =
        case record.resource_type do
          :markdown_render -> Decimal.mult(record.quantity, Decimal.new("0.07"))
          :markdown_sanitize -> Decimal.mult(record.quantity, Decimal.new("0.05"))
          :markdown_inject -> Decimal.mult(record.quantity, Decimal.new("0.08"))
          :ai_request -> Decimal.mult(record.quantity, Decimal.new("0.01"))
          :storage -> Decimal.mult(record.quantity, Decimal.new("0.1"))
          :compute_minutes -> Decimal.mult(record.quantity, Decimal.new("0.05"))
          _ -> Decimal.new(0)
        end

      Decimal.add(acc, cost)
    end)
  end
end
