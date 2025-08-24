defmodule Kyozo.Marketing.SafeMDConfig do
  @moduledoc """
  SafeMD marketing configuration and positioning.

  Defines the public-facing security brand while maintaining
  the powerful underlying capabilities for gradual revelation.
  """

  @doc """
  Get SafeMD public marketing configuration.
  """
  def public_config do
    %{
      name: "SafeMD",
      tagline: "Protect Your AI from Markdown Attacks",
      description:
        "Enterprise-grade markdown security scanning to protect AI systems from prompt injection, hidden scripts, and malicious content.",

      # Public API pricing
      pricing: %{
        scan: %{
          price_per_scan: "$0.03",
          description: "Per security scan",
          free_tier: 10
        },
        enterprise: %{
          price: "Custom",
          description: "Volume discounts available",
          features: ["SLA guarantees", "Custom deployment", "Priority support"]
        }
      },

      # Public feature set (security-focused)
      features: %{
        security: [
          "Prompt injection detection",
          "Hidden script scanning",
          "Unicode attack prevention",
          "Malicious link detection",
          "Zero-width character removal"
        ],
        performance: [
          "50MB/s processing speed",
          "Real-time streaming analysis",
          "10,000+ concurrent connections",
          "Sub-second response times"
        ],
        integration: [
          "REST API endpoints",
          "WebSocket streaming",
          "Async processing",
          "OpenAPI specification"
        ]
      },

      # Use cases (security-first)
      use_cases: [
        %{
          title: "AI Safety",
          description: "Protect language models from markdown-based prompt injection attacks",
          icon: "shield-check"
        },
        %{
          title: "Content Moderation",
          description: "Scan user-generated markdown content for hidden malicious elements",
          icon: "eye"
        },
        %{
          title: "Enterprise Security",
          description: "Validate markdown documents before processing in business systems",
          icon: "building"
        },
        %{
          title: "Developer Tools",
          description: "Integrate security scanning into markdown processing pipelines",
          icon: "code"
        }
      ]
    }
  end

  @doc """
  Get research mode configuration (gradual capability revelation).
  """
  def research_config do
    %{
      name: "SafeMD Research",
      tagline: "Advanced Markdown Analysis & Research",
      description:
        "Deep analysis capabilities for understanding complex markdown structures and polyglot documents.",

      # Research mode features (reveals more capabilities)
      additional_features: %{
        detection: [
          "Polyglot document detection",
          "Multi-language capability extraction",
          "Hidden functionality discovery",
          "Template syntax analysis",
          "Encoding pattern recognition"
        ],
        analysis: [
          "Semantic structure mapping",
          "AI-optimized content parsing",
          "Capability confidence scoring",
          "Cross-language correlation",
          "Advanced metadata extraction"
        ]
      },

      # Pricing tier for research features
      pricing: %{
        research_scan: %{
          price_per_scan: "$0.15",
          description: "Per advanced analysis scan",
          minimum_tier: "Pro"
        }
      }
    }
  end

  @doc """
  Get enterprise configuration (full capability revelation).
  """
  def enterprise_config do
    %{
      name: "Kyozo Platform",
      tagline: "The Complete Executable Documentation System",
      description:
        "Transform markdown into executable infrastructure with AI-powered analysis and polyglot capabilities.",

      # Full feature set revealed
      enterprise_features: %{
        transformation: [
          "Document-to-infrastructure conversion",
          "Multi-format code execution",
          "Container service deployment",
          "Infrastructure as Code generation"
        ],
        ai_optimization: [
          "Semantic markdown enhancement",
          "AI-first document structuring",
          "Context-aware transformations",
          "Machine learning integration"
        ],
        collaboration: [
          "Real-time collaborative editing",
          "Team workspace management",
          "Version control integration",
          "Enterprise authentication"
        ]
      },

      # Enterprise pricing
      pricing: %{
        enterprise: %{
          price: "Custom",
          description: "Full platform access with transformation capabilities",
          contact_required: true
        }
      }
    }
  end

  @doc """
  Get API documentation configuration.
  """
  def api_docs_config do
    %{
      endpoints: %{
        scan: %{
          path: "/api/v1/scan",
          method: "POST",
          description: "Synchronous markdown security scanning",
          rate_limit: "100 requests/minute",
          max_content_size: "10MB"
        },
        async_scan: %{
          path: "/api/v1/ascan",
          method: "POST",
          description: "Asynchronous scanning for large documents",
          rate_limit: "20 requests/minute",
          max_content_size: "100MB"
        },
        stream_scan: %{
          path: "/scan/websocket",
          method: "WebSocket",
          description: "Real-time streaming analysis",
          connection_limit: "10 concurrent streams per user"
        }
      },

      # Example requests/responses
      examples: %{
        basic_scan: %{
          request: %{
            content: "# Hello World\n\n[Click here](javascript:alert('xss'))",
            mode: "sanitize"
          },
          response: %{
            safe: false,
            threat_level: "high",
            threats_detected: 1,
            threats: [
              %{
                type: "suspicious_link",
                severity: "high",
                description: "JavaScript URL detected - potential XSS vector"
              }
            ]
          }
        }
      }
    }
  end

  @doc """
  Get competitive positioning.
  """
  def competitive_positioning do
    %{
      vs_manual_review: %{
        advantage: "100x faster than manual security review",
        details: "Automated scanning vs hours of manual analysis"
      },
      vs_generic_sanitizers: %{
        advantage: "Markdown-specific threat detection",
        details: "Purpose-built for markdown attack vectors"
      },
      vs_basic_validators: %{
        advantage: "AI-powered deep analysis",
        details: "Advanced pattern recognition beyond regex matching"
      }
    }
  end

  @doc """
  Get onboarding flow configuration.
  """
  def onboarding_config do
    %{
      steps: [
        %{
          title: "Security Assessment",
          description: "Start with basic markdown security scanning",
          cta: "Try Free Scan",
          tier: "free"
        },
        %{
          title: "Research Capabilities",
          description: "Discover hidden document capabilities and polyglot features",
          cta: "Upgrade to Research",
          tier: "pro"
        },
        %{
          title: "Full Platform Access",
          description: "Transform documents into executable infrastructure",
          cta: "Contact Enterprise",
          tier: "enterprise"
        }
      ]
    }
  end

  @doc """
  Get current tier features based on user subscription.
  """
  def get_tier_features(tier) when tier in [:free, "free"] do
    public_config()
  end

  def get_tier_features(tier) when tier in [:pro, "pro", :research, "research"] do
    public_config()
    |> Map.merge(research_config())
  end

  def get_tier_features(tier) when tier in [:enterprise, "enterprise"] do
    public_config()
    |> Map.merge(research_config())
    |> Map.merge(enterprise_config())
  end

  def get_tier_features(_), do: public_config()

  @doc """
  Get marketing messaging for different contexts.
  """
  def get_messaging(:security_focused) do
    %{
      headline: "Stop Markdown Attacks Before They Reach Your AI",
      subheadline: "Enterprise-grade security scanning for markdown content",
      cta: "Protect Your AI Now"
    }
  end

  def get_messaging(:capability_discovery) do
    %{
      headline: "Discover Hidden Capabilities in Your Documents",
      subheadline: "Advanced analysis reveals polyglot features and embedded functionality",
      cta: "Analyze Your Content"
    }
  end

  def get_messaging(:developer_tools) do
    %{
      headline: "Build Secure Markdown Processing Pipelines",
      subheadline: "API-first security scanning for developers and enterprises",
      cta: "View API Docs"
    }
  end
end
