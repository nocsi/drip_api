defmodule Dirup.MarkdownLD.StreamParser do
  @moduledoc """
  High-performance Markdown-LD stream parser with plugin architecture.

  This parser is designed to handle unknown streams of markdown content with
  a flexible plugin system supporting custom transforms, listeners, and parsers.

  ## Plugin Architecture

  - **Parsers**: Extract semantic data from markdown streams
  - **Transforms**: Modify or enhance parsed content
  - **Listeners**: React to parsing events and data

  ## Features

  - Stream-based processing for memory efficiency
  - AI-optimized data extraction and injection
  - Plugin-based extensibility
  - Real-time processing capabilities
  - Context-aware semantic understanding
  - Custom transform pipelines

  ## Usage

      # Basic parsing with default plugins
      {:ok, result} = StreamParser.parse(stream)

      # Custom pipeline with plugins
      pipeline = StreamParser.Pipeline.new()
        |> Pipeline.add_parser(SemanticParser)
        |> Pipeline.add_transform(AIEnhancer)
        |> Pipeline.add_listener(MetricsCollector)

      {:ok, result} = StreamParser.parse(stream, pipeline: pipeline)

  ## Creating Custom Plugins

      defmodule MyCustomTransform do
        use StreamParser.Transform

        @impl true
        def transform(chunk, context, opts) do
          # Custom transformation logic
          {:ok, enhanced_chunk, updated_context}
        end
      end
  """

  alias Dirup.MarkdownLD.StreamParser.{
    Pipeline,
    Context,
    Chunk,
    Registry,
    DefaultParsers,
    DefaultTransforms,
    DefaultListeners
  }

  @type stream_chunk :: String.t()
  @type json_ld_data :: map()
  @type plugin :: module()
  @type pipeline :: Pipeline.t()

  @type parse_opts :: [
          pipeline: pipeline(),
          buffer_size: pos_integer(),
          ai_optimization: boolean(),
          async_processing: boolean(),
          max_concurrency: pos_integer(),
          timeout: pos_integer()
        ]

  @type parse_result :: %{
          content: [stream_chunk()],
          semantics: [json_ld_data()],
          metadata: map(),
          performance_stats: map(),
          plugin_results: map()
        }

  # Performance-critical constants
  @default_buffer_size 8192
  @default_timeout 30_000
  @default_concurrency 4

  @doc """
  Parse markdown stream with configurable pipeline.

  ## Options

  - `:pipeline` - Custom processing pipeline (default: built-in pipeline)
  - `:buffer_size` - Size of processing buffer (default: 8192 bytes)
  - `:ai_optimization` - Enable AI-specific optimizations (default: true)
  - `:async_processing` - Enable async plugin execution (default: false)
  - `:max_concurrency` - Max concurrent plugin workers (default: 4)
  - `:timeout` - Processing timeout in ms (default: 30000)
  """
  @spec parse(Enumerable.t(), parse_opts()) :: {:ok, parse_result()} | {:error, term()}
  def parse(stream, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    opts = merge_default_opts(opts)
    pipeline = opts[:pipeline] || create_default_pipeline(opts)

    context = Context.new(opts)

    try do
      result =
        stream
        |> prepare_stream(opts)
        |> process_with_pipeline(pipeline, context)
        |> finalize_results(start_time, opts)

      {:ok, result}
    rescue
      error ->
        {:error, {:processing_error, error}}
    catch
      :exit, reason ->
        {:error, {:exit, reason}}

      :throw, reason ->
        {:error, {:throw, reason}}
    end
  end

  @doc """
  Create a new processing pipeline.
  """
  @spec create_pipeline() :: pipeline()
  def create_pipeline do
    Pipeline.new()
  end

  @doc """
  Register a custom plugin for use in pipelines.
  """
  @spec register_plugin(atom(), plugin()) :: :ok | {:error, term()}
  def register_plugin(name, plugin_module) do
    Registry.register(name, plugin_module)
  end

  @doc """
  Get all registered plugins of a specific type.
  """
  @spec get_plugins(atom()) :: [plugin()]
  def get_plugins(type) do
    Registry.get_by_type(type)
  end

  @doc """
  Extract semantics with custom extraction pipeline.
  """
  @spec extract_semantics(Enumerable.t(), keyword()) :: {:ok, [json_ld_data()]} | {:error, term()}
  def extract_semantics(stream, opts \\ []) do
    pipeline =
      Pipeline.new()
      |> Pipeline.add_parser(DefaultParsers.SemanticExtractor)
      |> Pipeline.add_parser(DefaultParsers.ImplicitSemanticParser)
      |> Pipeline.add_transform(DefaultTransforms.SemanticEnhancer)

    case parse(stream, Keyword.put(opts, :pipeline, pipeline)) do
      {:ok, result} -> {:ok, result.semantics}
      error -> error
    end
  end

  @doc """
  Inject semantics with custom injection pipeline.
  """
  @spec inject_semantics(Enumerable.t(), json_ld_data() | [json_ld_data()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def inject_semantics(stream, semantic_data, opts \\ []) do
    pipeline =
      Pipeline.new()
      |> Pipeline.add_transform(DefaultTransforms.SemanticInjector)
      |> Pipeline.add_listener(DefaultListeners.InjectionTracker)

    context =
      Context.new(opts)
      |> Context.put(:injection_data, semantic_data)

    case process_with_pipeline(stream, pipeline, context) do
      %{content: enhanced_content} -> {:ok, enhanced_content}
      error -> {:error, error}
    end
  end

  @doc """
  Real-time processing with event streaming.
  """
  @spec process_realtime(Enumerable.t(), pipeline(), keyword()) ::
          {:ok, Stream.t()} | {:error, term()}
  def process_realtime(stream, pipeline, opts \\ []) do
    opts = Keyword.put(opts, :streaming, true)
    context = Context.new(opts)

    realtime_stream =
      stream
      |> Stream.transform(context, fn chunk, ctx ->
        case process_chunk_with_pipeline(chunk, pipeline, ctx) do
          {:ok, results, new_ctx} -> {[results], new_ctx}
          {:error, _reason, new_ctx} -> {[], new_ctx}
        end
      end)

    {:ok, realtime_stream}
  end

  # Private implementation

  defp merge_default_opts(opts) do
    [
      buffer_size: @default_buffer_size,
      ai_optimization: true,
      async_processing: false,
      max_concurrency: @default_concurrency,
      timeout: @default_timeout
    ]
    |> Keyword.merge(opts)
  end

  defp create_default_pipeline(opts) do
    pipeline = Pipeline.new()

    # Add default parsers
    pipeline =
      pipeline
      |> Pipeline.add_parser(DefaultParsers.FrontmatterParser)
      |> Pipeline.add_parser(DefaultParsers.HTMLCommentParser)
      |> Pipeline.add_parser(DefaultParsers.CodeBlockParser)
      |> Pipeline.add_parser(DefaultParsers.HeaderParser)
      |> Pipeline.add_parser(DefaultParsers.LinkParser)

    # Add AI-optimized parsers if enabled
    pipeline =
      if opts[:ai_optimization] do
        pipeline
        |> Pipeline.add_parser(DefaultParsers.SemanticExtractor)
        |> Pipeline.add_parser(DefaultParsers.ImplicitSemanticParser)
        |> Pipeline.add_parser(DefaultParsers.ContextAnalyzer)
      else
        pipeline
      end

    # Add default transforms
    pipeline =
      pipeline
      |> Pipeline.add_transform(DefaultTransforms.StructureNormalizer)
      |> Pipeline.add_transform(DefaultTransforms.SemanticEnhancer)

    # Add AI transforms if enabled
    pipeline =
      if opts[:ai_optimization] do
        pipeline
        |> Pipeline.add_transform(DefaultTransforms.AIOptimizer)
        |> Pipeline.add_transform(DefaultTransforms.ConfidenceScorer)
        |> Pipeline.add_transform(DefaultTransforms.RelevanceRanker)
      else
        pipeline
      end

    # Add default listeners
    pipeline
    |> Pipeline.add_listener(DefaultListeners.PerformanceTracker)
    |> Pipeline.add_listener(DefaultListeners.ErrorLogger)
    |> Pipeline.add_listener(DefaultListeners.MetricsCollector)
  end

  defp prepare_stream(stream, opts) do
    buffer_size = opts[:buffer_size]

    stream
    |> Stream.chunk_every(buffer_size)
    |> Stream.map(&Enum.join(&1, ""))
  end

  defp process_with_pipeline(stream, pipeline, context) do
    stream
    |> Enum.reduce(%{content: [], semantics: [], metadata: %{}, plugin_results: %{}}, fn chunk,
                                                                                         acc ->
      case process_chunk_with_pipeline(chunk, pipeline, context) do
        {:ok, results, _new_context} ->
          merge_chunk_results(acc, results)

        {:error, reason, _context} ->
          # Log error but continue processing
          add_error_to_results(acc, reason)
      end
    end)
  end

  defp process_chunk_with_pipeline(chunk, pipeline, context) do
    chunk_data = Chunk.new(chunk, context)

    with {:ok, parsed_chunk, new_context} <- run_parsers(chunk_data, pipeline.parsers, context),
         {:ok, transformed_chunk, new_context} <-
           run_transforms(parsed_chunk, pipeline.transforms, new_context),
         :ok <- notify_listeners(transformed_chunk, pipeline.listeners, new_context) do
      results = compile_chunk_results(transformed_chunk, new_context)
      {:ok, results, new_context}
    else
      error -> {:error, error, context}
    end
  end

  defp run_parsers(chunk, parsers, context) do
    Enum.reduce_while(parsers, {:ok, chunk, context}, fn parser,
                                                         {:ok, current_chunk, current_context} ->
      case apply_parser(parser, current_chunk, current_context) do
        {:ok, updated_chunk, updated_context} ->
          {:cont, {:ok, updated_chunk, updated_context}}

        {:skip, chunk, context} ->
          {:cont, {:ok, chunk, context}}

        {:error, reason} ->
          {:halt, {:error, {:parser_error, parser, reason}}}
      end
    end)
  end

  defp run_transforms(chunk, transforms, context) do
    Enum.reduce_while(transforms, {:ok, chunk, context}, fn transform,
                                                            {:ok, current_chunk, current_context} ->
      case apply_transform(transform, current_chunk, current_context) do
        {:ok, updated_chunk, updated_context} ->
          {:cont, {:ok, updated_chunk, updated_context}}

        {:skip, chunk, context} ->
          {:cont, {:ok, chunk, context}}

        {:error, reason} ->
          {:halt, {:error, {:transform_error, transform, reason}}}
      end
    end)
  end

  defp notify_listeners(chunk, listeners, context) do
    Enum.each(listeners, fn listener ->
      try do
        apply_listener(listener, chunk, context)
      rescue
        error ->
          # Log listener errors but don't halt processing
          require Logger
          Logger.warning("Listener #{listener} failed: #{inspect(error)}")
      end
    end)

    :ok
  end

  defp apply_parser(parser_module, chunk, context) do
    if function_exported?(parser_module, :parse, 3) do
      parser_module.parse(chunk, context, [])
    else
      {:skip, chunk, context}
    end
  end

  defp apply_transform(transform_module, chunk, context) do
    if function_exported?(transform_module, :transform, 3) do
      transform_module.transform(chunk, context, [])
    else
      {:skip, chunk, context}
    end
  end

  defp apply_listener(listener_module, chunk, context) do
    if function_exported?(listener_module, :handle_event, 3) do
      listener_module.handle_event(:chunk_processed, chunk, context)
    end
  end

  defp compile_chunk_results(chunk, context) do
    %{
      content: [chunk.raw_content],
      semantics: chunk.semantics || [],
      metadata: chunk.metadata || %{},
      plugin_results: context.plugin_results || %{}
    }
  end

  defp merge_chunk_results(acc, chunk_results) do
    %{
      content: acc.content ++ chunk_results.content,
      semantics: acc.semantics ++ chunk_results.semantics,
      metadata: Map.merge(acc.metadata, chunk_results.metadata),
      plugin_results: Map.merge(acc.plugin_results, chunk_results.plugin_results)
    }
  end

  defp add_error_to_results(acc, reason) do
    errors = Map.get(acc, :errors, [])
    Map.put(acc, :errors, [reason | errors])
  end

  defp finalize_results(processing_results, start_time, opts) do
    end_time = System.monotonic_time(:microsecond)

    performance_stats = %{
      processing_time_us: end_time - start_time,
      chunks_processed: length(processing_results.content),
      semantics_extracted: length(processing_results.semantics),
      bytes_processed: calculate_bytes_processed(processing_results.content),
      throughput_bps: calculate_throughput(processing_results, end_time - start_time)
    }

    processing_results
    |> Map.put(:performance_stats, performance_stats)
  end

  defp calculate_bytes_processed(content_chunks) do
    content_chunks
    |> Enum.map(&byte_size/1)
    |> Enum.sum()
  end

  defp calculate_throughput(results, time_us) do
    total_bytes = calculate_bytes_processed(results.content)

    case time_us do
      0 -> 0
      _ -> trunc(total_bytes * 1_000_000 / time_us)
    end
  end
end
