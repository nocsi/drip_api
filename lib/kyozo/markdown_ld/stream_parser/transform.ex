defmodule Kyozo.MarkdownLD.StreamParser.Transform do
  @moduledoc """
  Behavior for custom markdown transforms.

  Transforms modify or enhance parsed data from markdown chunks.
  They are the second stage in the processing pipeline, after parsers.

  ## Implementation

      defmodule MyCustomTransform do
        use Kyozo.MarkdownLD.StreamParser.Transform

        @impl true
        def transform(chunk, context, opts) do
          # Enhance or modify the chunk data
          case enhance_chunk_data(chunk) do
            {:ok, enhanced_chunk} ->
              {:ok, enhanced_chunk, context}

            :skip ->
              {:skip, chunk, context}

            {:error, reason} ->
              {:error, reason}
          end
        end

        defp enhance_chunk_data(chunk) do
          # Custom enhancement logic
        end
      end

  ## Transform Lifecycle

  1. Receive parsed chunk and context
  2. Analyze chunk data and metadata
  3. Apply transformations or enhancements
  4. Return updated chunk and context

  ## Return Values

  - `{:ok, updated_chunk, updated_context}` - Success with updates
  - `{:skip, chunk, context}` - Skip processing, pass through unchanged
  - `{:error, reason}` - Processing error
  """

  alias Kyozo.MarkdownLD.StreamParser.{Chunk, Context}

  @type transform_result ::
          {:ok, Chunk.t(), Context.t()}
          | {:skip, Chunk.t(), Context.t()}
          | {:error, term()}

  @doc """
  Transform a markdown chunk with parsed data.

  ## Parameters

  - `chunk` - The markdown chunk to transform
  - `context` - Processing context with metadata
  - `opts` - Transform-specific options

  ## Returns

  - `{:ok, updated_chunk, updated_context}` on successful transformation
  - `{:skip, chunk, context}` to skip transforming this chunk
  - `{:error, reason}` on processing error
  """
  @callback transform(Chunk.t(), Context.t(), keyword()) :: transform_result()

  @doc """
  Get transform metadata and capabilities.

  Optional callback that returns information about what this transform does.
  """
  @callback info() :: %{
              name: String.t(),
              description: String.t(),
              version: String.t(),
              capabilities: [atom()],
              dependencies: [atom()]
            }

  @doc """
  Validate transform configuration.

  Optional callback to validate transform-specific options.
  """
  @callback validate_config(map()) :: :ok | {:error, term()}

  @doc """
  Initialize transform with configuration.

  Optional callback called when transform is added to pipeline.
  """
  @callback init(map()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks [info: 0, validate_config: 1, init: 1]

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Kyozo.MarkdownLD.StreamParser.Transform

      alias Kyozo.MarkdownLD.StreamParser.{Chunk, Context}

      # Default implementation for optional callbacks
      def info do
        %{
          name: to_string(__MODULE__),
          description: "Custom transform",
          version: "1.0.0",
          capabilities: [:transform],
          dependencies: []
        }
      end

      def validate_config(_config), do: :ok

      def init(config), do: {:ok, config}

      defoverridable info: 0, validate_config: 1, init: 1

      # Helper functions available to transform implementations

      defp enhance_semantic_data(chunk, enhancement_fn) when is_function(enhancement_fn, 1) do
        enhanced_semantics =
          chunk.semantics
          |> Enum.map(enhancement_fn)
          |> Enum.reject(&is_nil/1)

        Chunk.put_semantics(chunk, enhanced_semantics)
      end

      defp add_ai_metadata(chunk, ai_data) when is_map(ai_data) do
        existing_metadata = chunk.metadata || %{}
        ai_metadata = Map.get(existing_metadata, :ai, %{})
        updated_ai_metadata = Map.merge(ai_metadata, ai_data)

        updated_metadata = Map.put(existing_metadata, :ai, updated_ai_metadata)
        Chunk.put_metadata(chunk, updated_metadata)
      end

      defp calculate_confidence_score(chunk) do
        semantic_count = length(chunk.semantics || [])
        content_length = String.length(chunk.raw_content)

        base_score = min(semantic_count / 5, 1.0)

        # Boost for structured content
        structure_boost =
          cond do
            String.contains?(chunk.raw_content, "@context") -> 0.3
            String.contains?(chunk.raw_content, "@type") -> 0.2
            String.match?(chunk.raw_content, ~r/^#+\s+/) -> 0.1
            true -> 0.0
          end

        # Reduce for very short content
        length_penalty =
          if content_length < 50 do
            0.2
          else
            0.0
          end

        min(base_score + structure_boost - length_penalty, 1.0)
      end

      defp deduplicate_semantics(chunk) do
        unique_semantics =
          chunk.semantics
          |> Enum.uniq_by(&semantic_fingerprint/1)

        Chunk.put_semantics(chunk, unique_semantics)
      end

      defp semantic_fingerprint(semantic) do
        case semantic do
          %{"@type" => type, "name" => name} -> "#{type}:#{name}"
          %{type: type, content: content} -> "#{type}:#{String.slice(content, 0, 50)}"
          _ -> :crypto.hash(:md5, Jason.encode!(semantic)) |> Base.encode16()
        end
      end

      defp normalize_semantic_structure(chunk) do
        normalized_semantics =
          chunk.semantics
          |> Enum.map(&normalize_single_semantic/1)

        Chunk.put_semantics(chunk, normalized_semantics)
      end

      defp normalize_single_semantic(semantic) when is_map(semantic) do
        semantic
        |> ensure_context()
        |> ensure_type()
        |> add_processing_metadata()
      end

      defp ensure_context(semantic) do
        if Map.has_key?(semantic, "@context") do
          semantic
        else
          Map.put(semantic, "@context", "https://schema.org")
        end
      end

      defp ensure_type(semantic) do
        if Map.has_key?(semantic, "@type") do
          semantic
        else
          inferred_type = infer_type_from_content(semantic)
          Map.put(semantic, "@type", inferred_type)
        end
      end

      defp infer_type_from_content(semantic) do
        cond do
          Map.has_key?(semantic, "name") and Map.has_key?(semantic, "description") ->
            "Thing"

          Map.has_key?(semantic, "title") ->
            "Article"

          Map.has_key?(semantic, "content") ->
            "TextDigitalDocument"

          true ->
            "Thing"
        end
      end

      defp add_processing_metadata(semantic) do
        processing_meta = %{
          "processedAt" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "processor" => to_string(__MODULE__),
          "version" => "1.0.0"
        }

        Map.put(semantic, "_processing", processing_meta)
      end

      defp enhance_with_ai_insights(chunk, ai_service \\ :default) do
        case get_ai_insights(chunk.raw_content, ai_service) do
          {:ok, insights} ->
            add_ai_metadata(chunk, insights)

          {:error, _reason} ->
            chunk
        end
      end

      defp get_ai_insights(content, ai_service) do
        # Mock AI insights for now - would integrate with actual AI service
        insights = %{
          sentiment: analyze_sentiment(content),
          topics: extract_topics(content),
          complexity: calculate_complexity(content),
          readability: calculate_readability(content)
        }

        {:ok, insights}
      end

      defp analyze_sentiment(content) do
        cond do
          String.contains?(content, ["great", "excellent", "amazing"]) -> "positive"
          String.contains?(content, ["terrible", "awful", "bad"]) -> "negative"
          true -> "neutral"
        end
      end

      defp extract_topics(content) do
        content
        |> String.downcase()
        |> String.split()
        |> Enum.filter(&(String.length(&1) > 4))
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_word, count} -> count end, :desc)
        |> Enum.take(5)
        |> Enum.map(fn {word, _count} -> word end)
      end

      defp calculate_complexity(content) do
        word_count = content |> String.split() |> length()
        sentence_count = content |> String.split(~r/[.!?]+/) |> length()

        avg_words_per_sentence =
          if sentence_count > 0 do
            word_count / sentence_count
          else
            0
          end

        cond do
          avg_words_per_sentence > 20 -> "high"
          avg_words_per_sentence > 10 -> "medium"
          true -> "low"
        end
      end

      defp calculate_readability(content) do
        # Simplified Flesch reading ease approximation
        word_count = content |> String.split() |> length()
        sentence_count = content |> String.split(~r/[.!?]+/) |> length()

        avg_sentence_length =
          if sentence_count > 0 do
            word_count / sentence_count
          else
            0
          end

        cond do
          avg_sentence_length < 10 -> "easy"
          avg_sentence_length < 15 -> "medium"
          true -> "difficult"
        end
      end

      defp should_transform_chunk?(chunk, requirements) when is_list(requirements) do
        Enum.any?(requirements, fn requirement ->
          case requirement do
            {:has_semantics} -> length(chunk.semantics || []) > 0
            {:min_confidence, threshold} -> calculate_confidence_score(chunk) >= threshold
            {:contains_type, type} -> chunk_contains_semantic_type?(chunk, type)
            {:has_metadata, key} -> Map.has_key?(chunk.metadata || %{}, key)
            _ -> true
          end
        end)
      end

      defp chunk_contains_semantic_type?(chunk, type) do
        chunk.semantics
        |> Enum.any?(fn semantic ->
          Map.get(semantic, "@type") == type or Map.get(semantic, :type) == type
        end)
      end

      defp merge_contexts(context1, context2) when is_map(context1) and is_map(context2) do
        Map.merge(context1, context2, fn
          _key, v1, v2 when is_map(v1) and is_map(v2) -> Map.merge(v1, v2)
          _key, _v1, v2 -> v2
        end)
      end
    end
  end
end
