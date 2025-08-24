defmodule KyozoWeb.API.MarkdownController do
  use KyozoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias KyozoWeb.JSONAPI
  alias OpenApiSpex.Schema

  action_fallback KyozoWeb.FallbackController

  # Add usage tracking and rate limiting
  plug KyozoWeb.Plugs.AIRateLimit
  plug KyozoWeb.Plugs.AIUsageTracking

  defmodule ScanRequest do
    @moduledoc """
    Request schema for PromptSpect markdown scanning
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PromptSpect Scan Request",
      description: "Scan markdown for prompt injection and security issues",
      type: :object,
      properties: %{
        markdown: %Schema{
          type: :string,
          description: "Markdown content to scan",
          example: "# Title\n\nSome content with `code` blocks"
        },
        context: %Schema{
          type: :string,
          description: "Context for the scan",
          enum: ["documentation", "user_input", "ai_prompt", "code_comment"],
          default: "user_input"
        },
        strict_mode: %Schema{
          type: :boolean,
          description: "Enable strict security checks",
          default: false
        }
      },
      required: [:markdown]
    })
  end

  defmodule ScanResponse do
    @moduledoc """
    Response schema for PromptSpect scan results
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PromptSpect Scan Response",
      description: "Security scan results for markdown content",
      type: :object,
      properties: %{
        safe: %Schema{type: :boolean, description: "Whether the content is safe"},
        threat_level: %Schema{
          type: :string,
          enum: ["safe", "low", "medium", "high", "critical"]
        },
        issues: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              type: %Schema{
                type: :string,
                enum: ["injection", "xss", "command", "data_leak", "resource_abuse"]
              },
              severity: %Schema{type: :string, enum: ["low", "medium", "high", "critical"]},
              location: %Schema{type: :string, description: "Where in the markdown"},
              description: %Schema{type: :string},
              remediation: %Schema{type: :string}
            }
          }
        },
        scan_id: %Schema{type: :string, format: :uuid},
        processing_time_ms: %Schema{type: :integer}
      }
    })
  end

  defmodule ImpromptuRequest do
    @moduledoc """
    Request schema for Impromptu prompt optimization and enhancement
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Impromptu Optimization Request",
      description: "Optimize prompts for cost, quality, or speed with intelligent caching",
      type: :object,
      properties: %{
        prompt: %Schema{
          type: :string,
          description: "User's original prompt",
          example: "Write a function to calculate tax"
        },
        optimization_goal: %Schema{
          type: :string,
          description: "What to optimize for",
          enum: ["cost", "quality", "speed", "balanced"],
          default: "balanced"
        },
        model_preference: %Schema{
          type: :string,
          description: "Preferred model tier",
          enum: ["economy", "standard", "premium", "auto"],
          default: "auto"
        },
        cache_strategy: %Schema{
          type: :string,
          description: "How aggressively to use cached responses",
          enum: ["strict", "fuzzy", "semantic", "disabled"],
          default: "semantic"
        },
        max_cost_cents: %Schema{
          type: :integer,
          description: "Maximum cost in cents for this query",
          minimum: 1,
          maximum: 100,
          nullable: true
        },
        context: %Schema{
          type: :object,
          description: "Additional context for better optimization",
          properties: %{
            user_tier: %Schema{type: :string, enum: ["free", "pro", "enterprise"]},
            previous_queries: %Schema{type: :integer, description: "Number of similar queries"},
            domain: %Schema{type: :string, description: "Business domain"}
          }
        }
      },
      required: [:prompt]
    })
  end

  defmodule ImpromptuResponse do
    @moduledoc """
    Response schema for Impromptu enhancements
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Impromptu Enhancement Response",
      description: "Enhanced prompt with intelligent additions",
      type: :object,
      properties: %{
        enhanced_prompt: %Schema{
          type: :string,
          description: "The enhanced prompt ready for AI consumption"
        },
        additions: %Schema{
          type: :array,
          description: "What was added and why",
          items: %Schema{
            type: :object,
            properties: %{
              type: %Schema{
                type: :string,
                enum: ["context", "constraints", "examples", "format", "quality"]
              },
              content: %Schema{type: :string},
              reasoning: %Schema{type: :string}
            }
          }
        },
        detected_intent: %Schema{type: :string},
        confidence: %Schema{type: :number, minimum: 0.0, maximum: 1.0},
        processing_time_ms: %Schema{type: :integer}
      }
    })
  end

  defmodule PolyglotRequest do
    @moduledoc """
    Request schema for Polyglot translation service
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Polyglot Translation Request",
      description: "Add multilingual support to markdown content",
      type: :object,
      properties: %{
        markdown: %Schema{
          type: :string,
          description: "Markdown content to enhance with translations"
        },
        target_languages: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "ISO 639-1 language codes",
          example: ["es", "fr", "ja"],
          default: ["es", "fr", "de"]
        },
        translation_scope: %Schema{
          type: :string,
          enum: ["comments_only", "documentation", "ui_strings", "everything"],
          default: "documentation"
        },
        preserve_original: %Schema{
          type: :boolean,
          description: "Keep original text alongside translations",
          default: true
        }
      },
      required: [:markdown]
    })
  end

  defmodule PolyglotResponse do
    @moduledoc """
    Response schema for Polyglot translations
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Polyglot Translation Response",
      description: "Markdown enhanced with multilingual content",
      type: :object,
      properties: %{
        enhanced_markdown: %Schema{
          type: :string,
          description: "Markdown with embedded translations"
        },
        translations_added: %Schema{
          type: :integer,
          description: "Number of translations added"
        },
        languages_processed: %Schema{
          type: :array,
          items: %Schema{type: :string}
        },
        processing_time_ms: %Schema{type: :integer}
      }
    })
  end

  # PromptSpect Operations

  operation(:scan,
    summary: "Scan markdown for security issues",
    description:
      "PromptSpect: Analyze markdown for prompt injection and security vulnerabilities",
    request_body: {"Scan Request", "application/json", ScanRequest},
    responses: %{
      200 => {"Scan Results", "application/json", ScanResponse},
      400 => {"Bad Request", "application/json", JSONAPI.Schemas.Error}
    },
    tags: ["PromptSpect"]
  )

  operation(:rally,
    summary: "Enhance prompt with intelligent additions",
    description: "Impromptu: Automatically enhance prompts with context-aware improvements",
    request_body: {"Enhancement Request", "application/json", ImpromptuRequest},
    responses: %{
      200 => {"Enhanced Prompt", "application/json", ImpromptuResponse},
      400 => {"Bad Request", "application/json", JSONAPI.Schemas.Error}
    },
    tags: ["Impromptu"]
  )

  operation(:polyglot,
    summary: "Add multilingual support to markdown",
    description: "Polyglot: Enhance markdown with intelligent translations",
    request_body: {"Translation Request", "application/json", PolyglotRequest},
    responses: %{
      200 => {"Enhanced Markdown", "application/json", PolyglotResponse},
      400 => {"Bad Request", "application/json", JSONAPI.Schemas.Error}
    },
    tags: ["Polyglot"]
  )

  # Controller Actions

  def scan(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, validated} <- validate_scan_params(params),
         {:ok, scan_result} <- perform_security_scan(validated) do
      # Track usage for billing
      track_usage(conn, "promptspect_scan", byte_size(validated.markdown))

      response =
        Map.put(
          scan_result,
          :processing_time_ms,
          System.monotonic_time(:millisecond) - start_time
        )

      json(conn, response)
    else
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: reason})
    end
  end

  def rally(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, validated} <- validate_rally_params(params),
         {:ok, enhanced} <- enhance_prompt(validated) do
      # Track usage for billing
      track_usage(conn, "impromptu_enhancement", byte_size(validated.prompt))

      response =
        Map.put(enhanced, :processing_time_ms, System.monotonic_time(:millisecond) - start_time)

      json(conn, response)
    else
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: reason})
    end
  end

  def polyglot(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, validated} <- validate_polyglot_params(params),
         {:ok, translated} <- add_translations(validated) do
      # Track usage for billing
      track_usage(
        conn,
        "polyglot_translation",
        byte_size(validated.markdown) * length(validated.target_languages)
      )

      response =
        Map.put(translated, :processing_time_ms, System.monotonic_time(:millisecond) - start_time)

      json(conn, response)
    else
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: reason})
    end
  end

  # Private Functions

  defp validate_scan_params(params) do
    markdown = params["markdown"]

    if markdown && String.trim(markdown) != "" do
      {:ok,
       %{
         markdown: markdown,
         context: params["context"] || "user_input",
         strict_mode: params["strict_mode"] || false
       }}
    else
      {:error, "markdown parameter is required"}
    end
  end

  defp validate_rally_params(params) do
    prompt = params["prompt"]

    if prompt && String.trim(prompt) != "" do
      {:ok,
       %{
         prompt: prompt,
         intent: params["intent"],
         language: params["language"],
         enhancement_level: params["enhancement_level"] || "standard"
       }}
    else
      {:error, "prompt parameter is required"}
    end
  end

  defp validate_polyglot_params(params) do
    markdown = params["markdown"]

    if markdown && String.trim(markdown) != "" do
      {:ok,
       %{
         markdown: markdown,
         target_languages: params["target_languages"] || ["es", "fr", "de"],
         translation_scope: params["translation_scope"] || "documentation",
         preserve_original: params["preserve_original"] != false
       }}
    else
      {:error, "markdown parameter is required"}
    end
  end

  defp perform_security_scan(%{markdown: markdown, context: context, strict_mode: strict}) do
    # Simulate security scanning
    issues = detect_security_issues(markdown, context, strict)
    threat_level = calculate_threat_level(issues)

    {:ok,
     %{
       safe: threat_level == "safe",
       threat_level: threat_level,
       issues: issues,
       scan_id: Ecto.UUID.generate()
     }}
  end

  defp enhance_prompt(%{prompt: prompt, enhancement_level: level} = params) do
    # Detect intent if not provided
    intent = params.intent || detect_intent(prompt)

    # Generate enhancements based on intent and level
    additions = generate_prompt_additions(prompt, intent, level)
    enhanced = build_enhanced_prompt(prompt, additions)

    {:ok,
     %{
       enhanced_prompt: enhanced,
       additions: additions,
       detected_intent: intent,
       confidence: 0.85
     }}
  end

  defp add_translations(%{markdown: markdown, target_languages: languages} = params) do
    # Extract translatable content
    translatable = extract_translatable_content(markdown, params.translation_scope)

    # Generate translations (mock for now)
    translations = generate_translations(translatable, languages)

    # Build enhanced markdown
    enhanced =
      if params.preserve_original do
        embed_translations_with_original(markdown, translations)
      else
        replace_with_translations(markdown, translations)
      end

    {:ok,
     %{
       enhanced_markdown: enhanced,
       translations_added: map_size(translations),
       languages_processed: languages
     }}
  end

  # Mock implementation helpers

  defp detect_security_issues(markdown, _context, strict) do
    issues = []

    # Check for script tags
    if String.contains?(markdown, ["<script", "javascript:"]) do
      issues ++
        [
          %{
            type: "xss",
            severity: "high",
            location: "embedded script",
            description: "Potential XSS via script injection",
            remediation: "Remove or escape script tags"
          }
        ]
    end

    # Check for command injection in code blocks
    if Regex.match?(~r/```.*\n.*rm\s+-rf|curl.*\|.*sh/s, markdown) do
      issues ++
        [
          %{
            type: "command",
            severity: "critical",
            location: "code block",
            description: "Potential command injection",
            remediation: "Review and sanitize code blocks"
          }
        ]
    end

    # Strict mode additional checks
    if strict && String.contains?(markdown, ["<!--", "hidden", "ignore"]) do
      issues ++
        [
          %{
            type: "injection",
            severity: "medium",
            location: "html comment",
            description: "Hidden content that could alter AI behavior",
            remediation: "Remove HTML comments"
          }
        ]
    end

    issues
  end

  defp calculate_threat_level(issues) do
    cond do
      Enum.any?(issues, &(&1.severity == "critical")) -> "critical"
      Enum.any?(issues, &(&1.severity == "high")) -> "high"
      Enum.any?(issues, &(&1.severity == "medium")) -> "medium"
      length(issues) > 0 -> "low"
      true -> "safe"
    end
  end

  defp detect_intent(prompt) do
    cond do
      String.contains?(prompt, ["function", "def", "class", "implement"]) -> "code_generation"
      String.contains?(prompt, ["fix", "error", "bug", "issue"]) -> "debugging"
      String.contains?(prompt, ["test", "spec", "assert"]) -> "testing"
      String.contains?(prompt, ["refactor", "improve", "optimize"]) -> "refactoring"
      true -> "documentation"
    end
  end

  defp generate_prompt_additions(prompt, intent, level) do
    base_additions =
      case intent do
        "code_generation" ->
          [
            %{
              type: "constraints",
              content: "Follow language best practices and idioms",
              reasoning: "Ensures high-quality code output"
            },
            %{
              type: "format",
              content: "Include comprehensive error handling",
              reasoning: "Improves code robustness"
            }
          ]

        "debugging" ->
          [
            %{
              type: "context",
              content: "Explain the root cause before providing the fix",
              reasoning: "Helps understanding and prevents future issues"
            }
          ]

        _ ->
          []
      end

    case level do
      "minimal" ->
        Enum.take(base_additions, 1)

      "comprehensive" ->
        base_additions ++
          [
            %{
              type: "examples",
              content: "Provide 2-3 usage examples",
              reasoning: "Clarifies implementation details"
            },
            %{
              type: "quality",
              content: "Include performance considerations",
              reasoning: "Ensures scalable solutions"
            }
          ]

      _ ->
        base_additions
    end
  end

  defp build_enhanced_prompt(original, additions) do
    addition_text =
      additions
      |> Enum.map(& &1.content)
      |> Enum.join(". ")

    "#{original}\n\n[Requirements: #{addition_text}]"
  end

  defp extract_translatable_content(markdown, scope) do
    case scope do
      "comments_only" ->
        Regex.scan(~r/(?:#|\/\/|--)\s*(.+)$/m, markdown)
        |> Enum.map(&List.last/1)

      "documentation" ->
        Regex.scan(~r/(?:^|\n)([^#\n]+)(?=\n|$)/m, markdown)
        |> Enum.map(&List.last/1)
        |> Enum.filter(&(String.length(&1) > 20))

      _ ->
        [markdown]
    end
  end

  defp generate_translations(content, languages) do
    # Mock translations
    Enum.reduce(languages, %{}, fn lang, acc ->
      translations =
        Enum.map(content, fn text ->
          case lang do
            "es" -> "ES: " <> text
            "fr" -> "FR: " <> text
            "ja" -> "JA: " <> text
            _ -> lang <> ": " <> text
          end
        end)

      Map.put(acc, lang, translations)
    end)
  end

  defp embed_translations_with_original(markdown, translations) do
    # Add translations as expandable sections
    translation_block =
      translations
      |> Enum.map(fn {lang, texts} ->
        "<details>\n<summary>#{String.upcase(lang)}</summary>\n\n" <>
          Enum.join(texts, "\n\n") <>
          "\n</details>"
      end)
      |> Enum.join("\n\n")

    markdown <> "\n\n---\n\n## Translations\n\n" <> translation_block
  end

  defp replace_with_translations(markdown, _translations) do
    # For demo, just return original
    markdown
  end

  defp track_usage(conn, service, size_bytes) do
    # Extract user from conn (would come from auth)
    user_id = get_session(conn, :user_id) || "anonymous"

    Task.start(fn ->
      Kyozo.Billing.record_usage(%{
        user_id: user_id,
        service: service,
        operation: service,
        content_size_bytes: size_bytes,
        processing_time_ms: 0,
        threat_level: "safe",
        timestamp: DateTime.utc_now()
      })
    end)
  end
end
