defmodule Kyozo.MarkdownLD.StreamParser.Parser do
  @moduledoc """
  Behavior for custom markdown parsers.

  Parsers extract semantic data and structure from markdown chunks.
  They are the first stage in the processing pipeline.

  ## Implementation

      defmodule MyCustomParser do
        use Kyozo.MarkdownLD.StreamParser.Parser

        @impl true
        def parse(chunk, context, opts) do
          # Extract data from chunk
          case extract_my_data(chunk.raw_content) do
            {:ok, data} ->
              updated_chunk = Chunk.add_semantic(chunk, data)
              {:ok, updated_chunk, context}

            :skip ->
              {:skip, chunk, context}

            {:error, reason} ->
              {:error, reason}
          end
        end

        defp extract_my_data(content) do
          # Custom extraction logic
        end
      end

  ## Parser Lifecycle

  1. Receive chunk and context
  2. Analyze chunk content
  3. Extract relevant data
  4. Update chunk with findings
  5. Return updated chunk and context

  ## Return Values

  - `{:ok, updated_chunk, updated_context}` - Success with updates
  - `{:skip, chunk, context}` - Skip processing, pass through unchanged
  - `{:error, reason}` - Processing error
  """

  alias Kyozo.MarkdownLD.StreamParser.{Chunk, Context}

  @type parse_result ::
          {:ok, Chunk.t(), Context.t()}
          | {:skip, Chunk.t(), Context.t()}
          | {:error, term()}

  @doc """
  Parse a markdown chunk and extract relevant data.

  ## Parameters

  - `chunk` - The markdown chunk to process
  - `context` - Processing context with metadata
  - `opts` - Parser-specific options

  ## Returns

  - `{:ok, updated_chunk, updated_context}` on successful processing
  - `{:skip, chunk, context}` to skip processing this chunk
  - `{:error, reason}` on processing error
  """
  @callback parse(Chunk.t(), Context.t(), keyword()) :: parse_result()

  @doc """
  Get parser metadata and capabilities.

  Optional callback that returns information about what this parser does.
  """
  @callback info() :: %{
              name: String.t(),
              description: String.t(),
              version: String.t(),
              capabilities: [atom()],
              dependencies: [atom()]
            }

  @doc """
  Validate parser configuration.

  Optional callback to validate parser-specific options.
  """
  @callback validate_config(map()) :: :ok | {:error, term()}

  @doc """
  Initialize parser with configuration.

  Optional callback called when parser is added to pipeline.
  """
  @callback init(map()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks [info: 0, validate_config: 1, init: 1]

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Kyozo.MarkdownLD.StreamParser.Parser

      alias Kyozo.MarkdownLD.StreamParser.{Chunk, Context}

      # Default implementation for optional callbacks
      def info do
        %{
          name: to_string(__MODULE__),
          description: "Custom parser",
          version: "1.0.0",
          capabilities: [:parse],
          dependencies: []
        }
      end

      def validate_config(_config), do: :ok

      def init(config), do: {:ok, config}

      defoverridable info: 0, validate_config: 1, init: 1

      # Helper functions available to parser implementations
      defp extract_frontmatter(content) when is_binary(content) do
        case Regex.run(~r/^---\s*\n(.*?)\n---\s*\n/s, content) do
          [_, yaml_content] ->
            case YamlElixir.read_from_string(yaml_content) do
              {:ok, data} -> {:ok, data, String.replace(content, ~r/^---\s*\n.*?\n---\s*\n/s, "")}
              error -> error
            end

          nil ->
            {:ok, %{}, content}
        end
      rescue
        _ -> {:ok, %{}, content}
      end

      defp extract_html_comments(content) when is_binary(content) do
        ~r/<!--\s*(.*?)\s*-->/s
        |> Regex.scan(content, capture: :all_but_first)
        |> Enum.flat_map(fn [comment_content] ->
          case parse_comment_content(String.trim(comment_content)) do
            {:ok, data} -> [data]
            _ -> []
          end
        end)
      end

      defp parse_comment_content(content) do
        cond do
          # JSON-LD detection
          String.contains?(content, "@context") or String.contains?(content, "@type") ->
            case Jason.decode(content) do
              {:ok, json_data} when is_map(json_data) -> {:ok, {:json_ld, json_data}}
              _ -> :error
            end

          # Kyozo directive detection
          String.starts_with?(content, "kyozo:") ->
            parse_kyozo_directive(content)

          # YAML frontmatter in comments
          String.contains?(content, ":") and not String.contains?(content, "{") ->
            case YamlElixir.read_from_string(content) do
              {:ok, yaml_data} -> {:ok, {:yaml, yaml_data}}
              _ -> :error
            end

          true ->
            :error
        end
      rescue
        _ -> :error
      end

      defp parse_kyozo_directive(content) do
        case Regex.run(~r/kyozo:(\w+)(?:\s+(.+))?/, content) do
          [_, directive] ->
            {:ok, {:kyozo_directive, %{type: directive, params: %{}}}}

          [_, directive, params_string] ->
            params = parse_directive_params(params_string)
            {:ok, {:kyozo_directive, %{type: directive, params: params}}}

          _ ->
            :error
        end
      end

      defp parse_directive_params(params_string) do
        params_string
        |> String.split()
        |> Enum.map(&String.split(&1, "=", parts: 2))
        |> Enum.reduce(%{}, fn
          [key, value] -> Map.put(%{}, key, parse_param_value(value))
          [key] -> Map.put(%{}, key, true)
        end)
      end

      defp parse_param_value(value) do
        cond do
          value == "true" ->
            true

          value == "false" ->
            false

          String.match?(value, ~r/^\d+$/) ->
            String.to_integer(value)

          String.match?(value, ~r/^\d+\.\d+$/) ->
            String.to_float(value)

          String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
            String.slice(value, 1..-2)

          true ->
            value
        end
      end

      defp extract_code_blocks(content) when is_binary(content) do
        ~r/```(\w*)\n(.*?)```/s
        |> Regex.scan(content)
        |> Enum.map(fn
          [_, "", code_content] -> %{language: nil, content: code_content}
          [_, language, code_content] -> %{language: language, content: code_content}
        end)
      end

      defp extract_headers(content) when is_binary(content) do
        ~r/^(#+)\s+(.+)$/m
        |> Regex.scan(content)
        |> Enum.map(fn [_, hashes, title] ->
          %{
            level: String.length(hashes),
            title: String.trim(title),
            raw: "#{hashes} #{title}"
          }
        end)
      end

      defp extract_links(content) when is_binary(content) do
        ~r/\[([^\]]+)\]\(([^)]+)\)/
        |> Regex.scan(content)
        |> Enum.map(fn [_, text, url] ->
          %{text: text, url: url, type: detect_link_type(url)}
        end)
      end

      defp detect_link_type(url) do
        cond do
          String.starts_with?(url, "http://") or String.starts_with?(url, "https://") -> :external
          String.starts_with?(url, "#") -> :anchor
          String.starts_with?(url, "/") -> :absolute
          true -> :relative
        end
      end

      defp calculate_semantic_confidence(indicators) when is_list(indicators) do
        base_confidence = length(indicators) / 10
        min(base_confidence, 1.0)
      end

      defp should_process_chunk?(chunk, requirements) when is_list(requirements) do
        content = chunk.raw_content

        Enum.any?(requirements, fn requirement ->
          case requirement do
            {:contains, text} -> String.contains?(content, text)
            {:matches, regex} -> Regex.match?(regex, content)
            {:min_length, length} -> String.length(content) >= length
            {:has_semantic_markers} -> has_semantic_markers?(content)
            _ -> true
          end
        end)
      end

      defp has_semantic_markers?(content) do
        semantic_patterns = [
          ~r/@context/,
          ~r/@type/,
          ~r/schema\.org/,
          ~r/<!--.*kyozo:/,
          ~r/^---\s*$/m,
          ~r/```\w+/
        ]

        Enum.any?(semantic_patterns, &Regex.match?(&1, content))
      end
    end
  end
end
