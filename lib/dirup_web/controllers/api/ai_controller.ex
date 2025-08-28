defmodule DirupWeb.API.AIController do
  use DirupWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias DirupWeb.JSONAPI
  alias OpenApiSpex.Schema

  action_fallback DirupWeb.FallbackController

  # Add usage tracking and rate limiting
  plug DirupWeb.Plugs.AIRateLimit
  plug DirupWeb.Plugs.AIUsageTracking

  defmodule SuggestRequest do
    @moduledoc """
    Request schema for AI text suggestions
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AI Suggest Request",
      description: "Request for AI text suggestions",
      type: :object,
      properties: %{
        text: %Schema{
          type: :string,
          description: "Input text to analyze and provide suggestions for",
          example: "def calculate_total(items) do"
        },
        context: %Schema{
          type: :string,
          description: "Optional context about the text",
          example: "elixir_function",
          enum: ["elixir_function", "markdown", "comment", "documentation", "test", "general"]
        },
        max_suggestions: %Schema{
          type: :integer,
          description: "Maximum number of suggestions to return",
          example: 3,
          minimum: 1,
          maximum: 10,
          default: 3
        }
      },
      required: [:text]
    })
  end

  defmodule SuggestionResponse do
    @moduledoc """
    Response schema for AI text suggestions
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AI Suggestion Response",
      description: "AI-generated text suggestions",
      type: :object,
      properties: %{
        suggestions: %Schema{
          type: :array,
          description: "List of AI-generated suggestions",
          items: %Schema{
            type: :object,
            properties: %{
              text: %Schema{type: :string, description: "Suggested text"},
              confidence: %Schema{type: :number, description: "Confidence score 0-1"},
              type: %Schema{type: :string, enum: ["completion", "improvement", "alternative"]},
              explanation: %Schema{type: :string, description: "Brief explanation"}
            }
          }
        },
        processing_time_ms: %Schema{type: :integer},
        model_used: %Schema{type: :string, example: "mock-ai-v1"}
      }
    })
  end

  defmodule ConfidenceRequest do
    @moduledoc """
    Request schema for AI confidence analysis
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AI Confidence Request",
      description: "Request for AI confidence analysis of code",
      type: :object,
      properties: %{
        text: %Schema{
          type: :string,
          description: "Code or text to analyze",
          example: "def calculate_total(items) do\\n  Enum.sum(items)\\nend"
        },
        language: %Schema{
          type: :string,
          description: "Programming language",
          example: "elixir",
          enum: ["elixir", "javascript", "python", "general"]
        }
      },
      required: [:text]
    })
  end

  defmodule ConfidenceResponse do
    @moduledoc """
    Response schema for AI confidence analysis
    """
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AI Confidence Response",
      description: "AI confidence analysis results",
      type: :object,
      properties: %{
        overall_confidence: %Schema{type: :number, minimum: 0.0, maximum: 1.0},
        line_scores: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              line_number: %Schema{type: :integer},
              confidence: %Schema{type: :number, minimum: 0.0, maximum: 1.0},
              category: %Schema{type: :string, enum: ["high", "medium", "low"]},
              issues: %Schema{type: :array, items: %Schema{type: :string}}
            }
          }
        }
      }
    })
  end

  operation(:suggest,
    summary: "Generate AI text suggestions",
    description: "Analyze input text and generate intelligent suggestions",
    request_body: {"AI Suggest Request", "application/json", SuggestRequest},
    responses: %{
      200 => {"Success", "application/json", SuggestionResponse},
      400 => {"Bad Request", "application/json", JSONAPI.Schemas.Error}
    },
    tags: ["AI"]
  )

  operation(:confidence,
    summary: "Analyze code confidence",
    description: "Analyze code and provide confidence scores",
    request_body: {"AI Confidence Request", "application/json", ConfidenceRequest},
    responses: %{
      200 => {"Success", "application/json", ConfidenceResponse},
      400 => {"Bad Request", "application/json", JSONAPI.Schemas.Error}
    },
    tags: ["AI"]
  )

  def suggest(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    case validate_suggest_params(params) do
      {:ok, validated_params} ->
        suggestions = generate_mock_suggestions(validated_params)
        processing_time = System.monotonic_time(:millisecond) - start_time

        response = %{
          suggestions: suggestions,
          processing_time_ms: processing_time,
          model_used: "mock-ai-v1"
        }

        conn |> put_status(:ok) |> json(response)

      {:error, message} ->
        conn |> put_status(:bad_request) |> json(%{error: message})
    end
  end

  def confidence(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    case validate_confidence_params(params) do
      {:ok, validated_params} ->
        analysis = analyze_mock_confidence(validated_params)
        processing_time = System.monotonic_time(:millisecond) - start_time

        response = Map.put(analysis, :processing_time_ms, processing_time)

        conn |> put_status(:ok) |> json(response)

      {:error, message} ->
        conn |> put_status(:bad_request) |> json(%{error: message})
    end
  end

  # Private helper functions

  defp validate_suggest_params(params) do
    text = params["text"]

    if text && String.trim(text) != "" do
      {:ok,
       %{
         text: text,
         context: params["context"] || "general",
         max_suggestions: params["max_suggestions"] || 3
       }}
    else
      {:error, "text parameter is required"}
    end
  end

  defp validate_confidence_params(params) do
    text = params["text"]

    if text && String.trim(text) != "" do
      {:ok,
       %{
         text: text,
         language: params["language"] || "general"
       }}
    else
      {:error, "text parameter is required"}
    end
  end

  defp generate_mock_suggestions(%{text: text, context: context, max_suggestions: max_count}) do
    base_suggestions =
      case context do
        "elixir_function" ->
          [
            %{
              text: "#{text}\\n  # TODO: Implement function logic\\nend",
              confidence: 0.75,
              type: "completion",
              explanation: "Basic function template"
            },
            %{
              text: "#{text}\\n  Enum.reduce(items, 0, &+/2)\\nend",
              confidence: 0.85,
              type: "completion",
              explanation: "Sum using Enum.reduce"
            }
          ]

        _ ->
          [
            %{
              text: "#{text} - completed",
              confidence: 0.60,
              type: "completion",
              explanation: "General completion"
            }
          ]
      end

    Enum.take(base_suggestions, max_count)
  end

  defp analyze_mock_confidence(%{text: text, language: _language}) do
    lines = String.split(text, "\\n")

    line_scores =
      lines
      |> Enum.with_index(1)
      |> Enum.map(fn {line, line_num} ->
        confidence = if String.contains?(line, ["def ", "end"]), do: 0.9, else: 0.7
        category = if confidence >= 0.8, do: "high", else: "medium"

        %{
          line_number: line_num,
          confidence: confidence,
          category: category,
          issues: []
        }
      end)

    overall_confidence =
      if Enum.empty?(line_scores) do
        0.0
      else
        Enum.reduce(line_scores, 0.0, &(&1.confidence + &2)) / length(line_scores)
      end

    %{
      overall_confidence: overall_confidence,
      line_scores: line_scores
    }
  end
end
