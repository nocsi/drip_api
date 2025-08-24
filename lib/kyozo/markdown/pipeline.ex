defmodule Kyozo.Markdown.Pipeline do
  @moduledoc """
  Core pipeline architecture for markdown processing with middleware support.

  Supports both sanitization (security) and injection (capability enhancement) workflows
  through a flexible middleware system.
  """

  alias Kyozo.Markdown.Pipeline.{Context, Middleware, Result}

  @type pipeline_mode :: :sanitize | :inject | :detect | :analyze
  @type middleware_module :: module()
  @type pipeline_config :: %{
          mode: pipeline_mode(),
          middleware: [middleware_module()],
          options: map()
        }

  @doc """
  Process markdown through a configured pipeline.

  ## Examples

      # Security-first scanning
      Pipeline.process(markdown, :sanitize)

      # Research mode with detection
      Pipeline.process(markdown, :detect, %{include_polyglot: true})

      # Custom middleware chain
      Pipeline.process(markdown, [
        Middleware.UnicodeNormalizer,
        Middleware.PromptInjectionDetector,
        Middleware.PolyglotDetector
      ])
  """
  @spec process(String.t(), pipeline_mode() | [middleware_module()], map()) ::
          {:ok, Result.t()} | {:error, term()}
  def process(markdown, mode_or_middleware, options \\ %{})

  def process(markdown, mode, options) when is_atom(mode) do
    config = build_config(mode, options)
    process_with_config(markdown, config)
  end

  def process(markdown, middleware_list, options) when is_list(middleware_list) do
    config = %{
      mode: :custom,
      middleware: middleware_list,
      options: options
    }

    process_with_config(markdown, config)
  end

  @doc """
  Process markdown with full pipeline configuration.
  """
  @spec process_with_config(String.t(), pipeline_config()) :: {:ok, Result.t()} | {:error, term()}
  def process_with_config(markdown, config) do
    context = Context.new(markdown, config)

    with {:ok, final_context} <- run_middleware_chain(context, config.middleware) do
      result = Context.to_result(final_context)
      {:ok, result}
    end
  end

  @doc """
  Stream process large markdown documents with backpressure.
  """
  @spec process_stream(Enumerable.t(), pipeline_config()) :: Stream.t()
  def process_stream(markdown_stream, config) do
    markdown_stream
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.transform(Context.new("", config), fn chunk, acc_context ->
      updated_context = Context.append_content(acc_context, chunk)

      case run_middleware_chain(updated_context, config.middleware) do
        {:ok, processed_context} ->
          result = Context.to_result(processed_context)
          {[result], Context.reset_for_next_chunk(processed_context)}

        {:error, reason} ->
          {[{:error, reason}], acc_context}
      end
    end)
  end

  # Built-in pipeline configurations

  @doc """
  Build configuration for different pipeline modes.
  """
  @spec build_config(pipeline_mode(), map()) :: pipeline_config()
  def build_config(:sanitize, options) do
    %{
      mode: :sanitize,
      middleware: [
        Middleware.InputValidator,
        Middleware.UnicodeNormalizer,
        Middleware.ZeroWidthStripper,
        Middleware.PromptInjectionDetector,
        Middleware.LinkSanitizer,
        Middleware.OutputSanitizer
      ],
      options: Map.merge(%{strict_mode: true}, options)
    }
  end

  def build_config(:inject, options) do
    %{
      mode: :inject,
      middleware: [
        Middleware.InputValidator,
        Middleware.UnicodeNormalizer,
        Middleware.PolyglotDetector,
        Middleware.CapabilityInjector,
        Middleware.SemanticEnhancer,
        Middleware.OutputFormatter
      ],
      options: Map.merge(%{enhancement_level: :standard}, options)
    }
  end

  def build_config(:detect, options) do
    %{
      mode: :detect,
      middleware: [
        Middleware.InputValidator,
        Middleware.UnicodeNormalizer,
        Middleware.PromptInjectionDetector,
        Middleware.PolyglotDetector,
        Middleware.HiddenCapabilityExtractor,
        Middleware.ThreatAnalyzer
      ],
      options: Map.merge(%{include_polyglot: false, threat_level: :medium}, options)
    }
  end

  def build_config(:analyze, options) do
    %{
      mode: :analyze,
      middleware: [
        Middleware.InputValidator,
        Middleware.UnicodeNormalizer,
        Middleware.StructuralAnalyzer,
        Middleware.SemanticAnalyzer,
        Middleware.AIOptimizer,
        Middleware.MetricsCollector
      ],
      options: Map.merge(%{ai_optimization: true, semantic_depth: 3}, options)
    }
  end

  # Private functions

  defp run_middleware_chain(context, []), do: {:ok, context}

  defp run_middleware_chain(context, [middleware | rest]) do
    case middleware.process(context) do
      {:ok, updated_context} -> run_middleware_chain(updated_context, rest)
      {:error, _reason} = error -> error
    end
  rescue
    error ->
      {:error,
       %{
         middleware: middleware,
         error: error,
         context: context
       }}
  end
end
