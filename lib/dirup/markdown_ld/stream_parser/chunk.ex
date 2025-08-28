defmodule Dirup.MarkdownLD.StreamParser.Chunk do
  @moduledoc """
  Represents a chunk of markdown content being processed through the pipeline.

  A chunk contains the raw markdown content along with any extracted semantics,
  metadata, and processing state accumulated during pipeline execution.

  ## Usage

      chunk = Chunk.new("# Hello World\\n\\nThis is content.")
        |> Chunk.add_semantic(%{"@type" => "Article", "name" => "Hello World"})
        |> Chunk.put_metadata(:confidence, 0.9)

  """

  @type t :: %__MODULE__{
          raw_content: String.t(),
          semantics: [map()],
          metadata: map(),
          line_number: non_neg_integer() | nil,
          byte_offset: non_neg_integer() | nil,
          processing_state: map(),
          errors: [term()],
          created_at: DateTime.t()
        }

  defstruct raw_content: "",
            semantics: [],
            metadata: %{},
            line_number: nil,
            byte_offset: nil,
            processing_state: %{},
            errors: [],
            created_at: nil

  @doc """
  Create a new chunk from raw markdown content.
  """
  @spec new(String.t(), keyword()) :: t()
  def new(raw_content, opts \\ []) when is_binary(raw_content) do
    %__MODULE__{
      raw_content: raw_content,
      line_number: Keyword.get(opts, :line_number),
      byte_offset: Keyword.get(opts, :byte_offset),
      metadata: Keyword.get(opts, :metadata, %{}) |> Enum.into(%{}),
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Add semantic data to the chunk.
  """
  @spec add_semantic(t(), map()) :: t()
  def add_semantic(%__MODULE__{} = chunk, semantic_data) when is_map(semantic_data) do
    updated_semantics = [semantic_data | chunk.semantics]
    %{chunk | semantics: updated_semantics}
  end

  @doc """
  Add multiple semantic data entries to the chunk.
  """
  @spec add_semantics(t(), [map()]) :: t()
  def add_semantics(%__MODULE__{} = chunk, semantic_list) when is_list(semantic_list) do
    updated_semantics = semantic_list ++ chunk.semantics
    %{chunk | semantics: updated_semantics}
  end

  @doc """
  Replace all semantic data in the chunk.
  """
  @spec put_semantics(t(), [map()]) :: t()
  def put_semantics(%__MODULE__{} = chunk, semantic_list) when is_list(semantic_list) do
    %{chunk | semantics: semantic_list}
  end

  @doc """
  Put metadata value in the chunk.
  """
  @spec put_metadata(t(), atom() | String.t(), term()) :: t()
  def put_metadata(%__MODULE__{} = chunk, key, value) do
    updated_metadata = Map.put(chunk.metadata, key, value)
    %{chunk | metadata: updated_metadata}
  end

  @doc """
  Get metadata value from the chunk.
  """
  @spec get_metadata(t(), atom() | String.t(), term()) :: term()
  def get_metadata(%__MODULE__{} = chunk, key, default \\ nil) do
    Map.get(chunk.metadata, key, default)
  end

  @doc """
  Merge metadata into the chunk.
  """
  @spec merge_metadata(t(), map()) :: t()
  def merge_metadata(%__MODULE__{} = chunk, metadata) when is_map(metadata) do
    updated_metadata = Map.merge(chunk.metadata, metadata)
    %{chunk | metadata: updated_metadata}
  end

  @doc """
  Update processing state for the chunk.
  """
  @spec put_state(t(), atom(), term()) :: t()
  def put_state(%__MODULE__{} = chunk, key, value) do
    updated_state = Map.put(chunk.processing_state, key, value)
    %{chunk | processing_state: updated_state}
  end

  @doc """
  Get processing state from the chunk.
  """
  @spec get_state(t(), atom(), term()) :: term()
  def get_state(%__MODULE__{} = chunk, key, default \\ nil) do
    Map.get(chunk.processing_state, key, default)
  end

  @doc """
  Add an error to the chunk.
  """
  @spec add_error(t(), term()) :: t()
  def add_error(%__MODULE__{} = chunk, error) do
    error_entry = %{
      error: error,
      timestamp: DateTime.utc_now()
    }

    updated_errors = [error_entry | chunk.errors]
    %{chunk | errors: updated_errors}
  end

  @doc """
  Check if chunk has any errors.
  """
  @spec has_errors?(t()) :: boolean()
  def has_errors?(%__MODULE__{errors: errors}), do: length(errors) > 0

  @doc """
  Get all errors from the chunk.
  """
  @spec get_errors(t()) :: [map()]
  def get_errors(%__MODULE__{errors: errors}), do: Enum.reverse(errors)

  @doc """
  Check if chunk has semantic data.
  """
  @spec has_semantics?(t()) :: boolean()
  def has_semantics?(%__MODULE__{semantics: semantics}), do: length(semantics) > 0

  @doc """
  Get semantic data count.
  """
  @spec semantic_count(t()) :: non_neg_integer()
  def semantic_count(%__MODULE__{semantics: semantics}), do: length(semantics)

  @doc """
  Get content length in bytes.
  """
  @spec content_size(t()) :: non_neg_integer()
  def content_size(%__MODULE__{raw_content: content}), do: byte_size(content)

  @doc """
  Check if chunk is empty (no content).
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{raw_content: content}), do: String.trim(content) == ""

  @doc """
  Filter semantic data by type.
  """
  @spec filter_semantics_by_type(t(), String.t()) :: [map()]
  def filter_semantics_by_type(%__MODULE__{semantics: semantics}, type) do
    Enum.filter(semantics, fn semantic ->
      Map.get(semantic, "@type") == type or Map.get(semantic, :type) == type
    end)
  end

  @doc """
  Find first semantic data by type.
  """
  @spec find_semantic_by_type(t(), String.t()) :: map() | nil
  def find_semantic_by_type(%__MODULE__{} = chunk, type) do
    chunk
    |> filter_semantics_by_type(type)
    |> List.first()
  end

  @doc """
  Remove semantic data by predicate function.
  """
  @spec remove_semantics(t(), (map() -> boolean())) :: t()
  def remove_semantics(%__MODULE__{} = chunk, predicate_fn) when is_function(predicate_fn, 1) do
    filtered_semantics = Enum.reject(chunk.semantics, predicate_fn)
    %{chunk | semantics: filtered_semantics}
  end

  @doc """
  Update semantic data by predicate function.
  """
  @spec update_semantics(t(), (map() -> boolean()), (map() -> map())) :: t()
  def update_semantics(%__MODULE__{} = chunk, predicate_fn, update_fn)
      when is_function(predicate_fn, 1) and is_function(update_fn, 1) do
    updated_semantics =
      Enum.map(chunk.semantics, fn semantic ->
        if predicate_fn.(semantic) do
          update_fn.(semantic)
        else
          semantic
        end
      end)

    %{chunk | semantics: updated_semantics}
  end

  @doc """
  Clone chunk with optional modifications.
  """
  @spec clone(t(), keyword()) :: t()
  def clone(%__MODULE__{} = chunk, modifications \\ []) do
    Enum.reduce(modifications, chunk, fn
      {:metadata, meta}, c -> merge_metadata(c, meta)
      {:semantics, sems}, c -> put_semantics(c, sems)
      {:content, content}, c -> %{c | raw_content: content}
      {:line_number, line}, c -> %{c | line_number: line}
      {:byte_offset, offset}, c -> %{c | byte_offset: offset}
      {key, value}, c -> put_metadata(c, key, value)
    end)
  end

  @doc """
  Convert chunk to a summary map for logging/debugging.
  """
  @spec to_summary(t()) :: map()
  def to_summary(%__MODULE__{} = chunk) do
    %{
      content_length: content_size(chunk),
      semantic_count: semantic_count(chunk),
      has_errors: has_errors?(chunk),
      line_number: chunk.line_number,
      byte_offset: chunk.byte_offset,
      metadata_keys: Map.keys(chunk.metadata),
      processing_state_keys: Map.keys(chunk.processing_state),
      created_at: chunk.created_at
    }
  end

  @doc """
  Convert chunk to a serializable map (without functions or large content).
  """
  @spec to_map(t(), keyword()) :: map()
  def to_map(%__MODULE__{} = chunk, opts \\ []) do
    include_content = Keyword.get(opts, :include_content, false)
    max_content_length = Keyword.get(opts, :max_content_length, 200)

    content =
      if include_content do
        if content_size(chunk) > max_content_length do
          String.slice(chunk.raw_content, 0, max_content_length) <> "..."
        else
          chunk.raw_content
        end
      else
        nil
      end

    %{
      content: content,
      content_length: content_size(chunk),
      semantics: chunk.semantics,
      metadata: chunk.metadata,
      line_number: chunk.line_number,
      byte_offset: chunk.byte_offset,
      processing_state: chunk.processing_state,
      error_count: length(chunk.errors),
      created_at: chunk.created_at
    }
  end

  @doc """
  Calculate a confidence score for the chunk based on semantic data.
  """
  @spec calculate_confidence(t()) :: float()
  def calculate_confidence(%__MODULE__{} = chunk) do
    semantic_count = semantic_count(chunk)
    content_length = content_size(chunk)

    # Base score from semantic density
    base_score = min(semantic_count / 3.0, 1.0)

    # Boost for explicit JSON-LD structures
    jsonld_boost = if has_jsonld_semantics?(chunk), do: 0.3, else: 0.0

    # Boost for structured content
    structure_boost = if has_structured_content?(chunk), do: 0.2, else: 0.0

    # Penalty for very short content
    length_penalty = if content_length < 20, do: 0.2, else: 0.0

    # Final confidence score
    min(base_score + jsonld_boost + structure_boost - length_penalty, 1.0)
  end

  @doc """
  Extract text content from code blocks in the chunk.
  """
  @spec extract_code_blocks(t()) :: [%{language: String.t() | nil, content: String.t()}]
  def extract_code_blocks(%__MODULE__{raw_content: content}) do
    ~r/```(\w*)\n(.*?)```/s
    |> Regex.scan(content)
    |> Enum.map(fn
      [_, "", code_content] -> %{language: nil, content: String.trim(code_content)}
      [_, language, code_content] -> %{language: language, content: String.trim(code_content)}
    end)
  end

  @doc """
  Extract headers from the chunk content.
  """
  @spec extract_headers(t()) :: [%{level: pos_integer(), title: String.t()}]
  def extract_headers(%__MODULE__{raw_content: content}) do
    ~r/^(#+)\s+(.+)$/m
    |> Regex.scan(content)
    |> Enum.map(fn [_, hashes, title] ->
      %{
        level: String.length(hashes),
        title: String.trim(title)
      }
    end)
  end

  @doc """
  Extract links from the chunk content.
  """
  @spec extract_links(t()) :: [%{text: String.t(), url: String.t(), type: atom()}]
  def extract_links(%__MODULE__{raw_content: content}) do
    ~r/\[([^\]]+)\]\(([^)]+)\)/
    |> Regex.scan(content)
    |> Enum.map(fn [_, text, url] ->
      %{
        text: text,
        url: url,
        type: detect_link_type(url)
      }
    end)
  end

  # Private helper functions

  defp has_jsonld_semantics?(%__MODULE__{semantics: semantics}) do
    Enum.any?(semantics, fn semantic ->
      Map.has_key?(semantic, "@context") or Map.has_key?(semantic, "@type")
    end)
  end

  defp has_structured_content?(%__MODULE__{raw_content: content}) do
    # Headers
    # Code blocks
    # Tables
    # Lists
    # Comments
    content =~ ~r/^#+\s+/ or
      content =~ ~r/```\w*/ or
      content =~ ~r/^\s*\|/ or
      content =~ ~r/^\s*[-*+]\s+/ or
      content =~ ~r/<!--.*-->/s
  end

  defp detect_link_type(url) do
    cond do
      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") -> :external
      String.starts_with?(url, "#") -> :anchor
      String.starts_with?(url, "/") -> :absolute
      String.contains?(url, "@") -> :email
      true -> :relative
    end
  end
end
