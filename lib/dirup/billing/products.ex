defmodule Dirup.Billing.Products do
  @moduledoc """
  Complete product catalog for Kyozo services.
  Each product has usage-based pricing and optional packages/subscriptions.
  """

  @products %{
    # SafeMD Scanning (Sanitization)
    markdown_sanitize: %{
      name: "SafeMD Security Scanning",
      description: "AI-safe markdown sanitization and threat detection",
      # $0.05 per scan
      unit_price: 0.05,
      unit_label: "scan",
      features: [
        "Prompt injection detection",
        "Unicode attack prevention",
        "Zero-width character removal",
        "Security scoring"
      ],
      packages: %{
        # $25 for 1K scans
        starter_1k: {25, 1_000},
        # $200 for 10K scans
        bulk_10k: {200, 10_000},
        # $1,500 for 100K scans
        mega_100k: {1_500, 100_000}
      }
    },

    # Polyglot Injection (Research Mode)
    markdown_inject: %{
      name: "Polyglot Document Creation",
      description: "Create multi-format executable documents",
      # $0.10 per injection
      unit_price: 0.10,
      unit_label: "document",
      features: [
        "Hidden capability injection",
        "Multi-format synthesis",
        "Executable markdown generation",
        "Steganographic encoding"
      ],
      packages: %{
        # $75 for 100 injections
        researcher_100: {75, 100},
        # $500 for 1K injections
        lab_1k: {500, 1_000},
        # $2,500 for 10K injections
        enterprise: {2_500, 10_000}
      }
    },

    # Markdown Execution
    markdown_render: %{
      name: "Markdown Render",
      description: "Render markdown as HTM",
      # $0.02 per execution
      unit_price: 0.07,
      unit_label: "render",
      features: [
        "Multi-language support",
        "Isolated containers",
        "Real-time output",
        "State management"
      ],
      packages: %{
        # $75 for 500 executions
        developer_500: {75, 500},
        # $500 for 5K executions
        team_5k: {500, 5_000},
        # $3,000 for 50K executions
        scale_50k: {3_000, 50_000}
      }
    },

    # AI Requests
    ai_request: %{
      name: "AI API Requests",
      description: "LLM-powered features and enhancements",
      # $0.05 per request
      unit_price: 0.05,
      unit_label: "request",
      features: [
        "Code suggestions",
        "Document analysis",
        "Semantic search",
        "Smart transformations"
      ],
      packages: %{
        # $40 for 1K requests
        starter_1k: {40, 1_000},
        # $350 for 10K requests
        pro_10k: {350, 10_000},
        # $1,500 for 50K requests
        unlimited: {1_500, 50_000}
      }
    },

    # Storage
    storage: %{
      name: "Document Storage",
      description: "Secure, versioned document storage",
      # $0.10 per GB per month
      unit_price: 0.10,
      unit_label: "GB-month",
      features: [
        "Version control",
        "Encryption at rest",
        "Global CDN",
        "Instant retrieval"
      ],
      packages: %{
        # $8/mo for 10GB
        personal_10gb: {8, 10},
        # $50/mo for 100GB
        team_100gb: {50, 100},
        # $300/mo for 1TB
        business_1tb: {300, 1000}
      }
    },

    # Compute Minutes
    compute_minutes: %{
      name: "Compute Time",
      description: "Container runtime for executions",
      # $0.01 per minute
      unit_price: 0.01,
      unit_label: "minute",
      features: [
        "GPU acceleration available",
        "Multiple CPU/RAM tiers",
        "Persistent workspaces",
        "Custom environments"
      ],
      packages: %{
        # $8 for 1K minutes
        hobby_1k: {8, 1_000},
        # $60 for 10K minutes
        pro_10k: {60, 10_000},
        # $400 for 50K minutes
        dedicated: {400, 50_000}
      }
    }
  }

  @subscriptions %{
    # All-in-one plans with included usage
    starter: %{
      name: "Kyozo Plus",
      # $49/month
      price: 19,
      included: %{
        markdown_sanitize: 2_000,
        markdown_execution: 500,
        ai_request: 500,
        # GB
        storage: 10,
        compute_minutes: 1_000
      }
    },
    professional: %{
      name: "Kyozo Professional",
      # $299/month
      price: 49,
      included: %{
        markdown_sanitize: 15_000,
        markdown_execution: 5_000,
        # Research features
        markdown_inject: 100,
        ai_request: 5_000,
        # GB
        storage: 100,
        compute_minutes: 10_000
      }
    },
    enterprise: %{
      name: "Kyozo Enterprise",
      # $999/month
      price: 999,
      included: %{
        markdown_sanitize: 100_000,
        markdown_execution: 50_000,
        markdown_inject: 1_000,
        ai_request: 50_000,
        # GB
        storage: 1_000,
        compute_minutes: 100_000
      },
      features: [
        "Priority support",
        "Custom integrations",
        "SLA guarantee",
        "Dedicated success manager"
      ]
    }
  }

  @doc """
  Get product configuration by key.
  """
  def get_product(key) when is_atom(key) do
    Map.get(@products, key)
  end

  @doc """
  Get subscription configuration by key.
  """
  def get_subscription(key) when is_atom(key) do
    Map.get(@subscriptions, key)
  end

  @doc """
  Calculate price for usage.
  """
  def calculate_usage_cost(product_key, quantity) do
    case get_product(product_key) do
      %{unit_price: price} -> price * quantity
      nil -> {:error, :unknown_product}
    end
  end

  @doc """
  Get all products for API/UI display.
  """
  def list_products do
    @products
  end

  @doc """
  Get pricing matrix for marketing.
  """
  def pricing_matrix do
    %{
      products:
        Enum.map(@products, fn {key, product} ->
          %{
            key: key,
            name: product.name,
            unit_price: product.unit_price,
            unit_label: product.unit_label,
            packages:
              Enum.map(product.packages, fn {name, {price, quantity}} ->
                %{
                  name: name,
                  price: price,
                  quantity: quantity,
                  unit_price: Float.round(price / quantity, 4)
                }
              end)
          }
        end),
      subscriptions:
        Enum.map(@subscriptions, fn {key, sub} ->
          %{
            key: key,
            name: sub.name,
            price: sub.price,
            included: sub.included,
            overage_rates: calculate_overage_rates(key)
          }
        end)
    }
  end

  defp calculate_overage_rates(subscription_key) do
    # Discounted rates for overages based on tier
    discount =
      case subscription_key do
        # 10% off
        :starter -> 0.9
        # 20% off
        :professional -> 0.8
        # 30% off
        :enterprise -> 0.7
      end

    @products
    |> Enum.map(fn {key, product} ->
      {key, Float.round(product.unit_price * discount, 4)}
    end)
    |> Map.new()
  end
end
