defmodule Dirup.Markdown.Stream do
  @moduledoc """
  Streaming markdown parser with injection and extraction capabilities.

  Parse markdown as a stream of events, allowing for:
  - Lazy parsing of large files
  - Stream transformations
  - Content injection
  - Metadata extraction
  - Real-time processing
  """

  alias Dirup.Markdown.Stream.{Parser, Event}

  @doc """
  Parse markdown content as a stream of events.

  ## Example

      "# Hello\\n\\nWorld"
      |> Dirup.Markdown.Stream.parse()
      |> Enum.to_list()

      # => [
      #   {:start_document, %{}},
      #   {:start_heading, %{level: 1}},
      #   {:text, "Hello"},
      #   {:end_heading, %{level: 1}},
      #   {:start_paragraph, %{}},
      #   {:text, "World"},
      #   {:end_paragraph, %{}},
      #   {:end_document, %{}}
      # ]
  """
  def parse(input, opts \\ []) when is_binary(input) do
    input
    |> String.split("\n")
    |> Stream.transform(Parser.initial_state(), &Parser.parse_line/2)
    |> Stream.concat([{:end_document, %{}}])
  end

  @doc """
  Parse a file as a stream.
  """
  def parse_file(path, opts \\ []) do
    path
    |> File.stream!()
    |> Stream.transform(Parser.initial_state(), &Parser.parse_line/2)
    |> Stream.concat([{:end_document, %{}}])
  end

  @doc """
  Extract specific content from markdown stream.

  ## Examples

      # Extract all code blocks
      stream
      |> Dirup.Markdown.Stream.extract(:code_blocks)
      |> Enum.to_list()

      # Extract headings
      stream
      |> Dirup.Markdown.Stream.extract(:headings)

      # Extract Kyozo metadata
      stream
      |> Dirup.Markdown.Stream.extract(:dirup_metadata)
  """
  def extract(stream, type) do
    stream
    |> Stream.transform(Event.extractor_state(type), &Event.extract/2)
    |> Stream.filter(&(&1 != :skip))
  end

  @doc """
  Inject content into markdown stream.

  ## Examples

      # Inject TOC after first heading
      stream
      |> Dirup.Markdown.Stream.inject_after(:heading, &generate_toc/1)

      # Inject enlightenment after code blocks
      stream
      |> Dirup.Markdown.Stream.inject_after(:code_block, &enlighten/1)
  """
  def inject_after(stream, target, injector) when is_function(injector) do
    stream
    |> Stream.flat_map(fn event ->
      case Event.matches_target?(event, target) do
        true -> [event | injector.(event)]
        false -> [event]
      end
    end)
  end

  def inject_before(stream, target, injector) when is_function(injector) do
    stream
    |> Stream.flat_map(fn event ->
      case Event.matches_target?(event, target) do
        true -> injector.(event) ++ [event]
        false -> [event]
      end
    end)
  end

  @doc """
  Transform markdown stream events.

  ## Examples

      # Make all headings one level deeper
      stream
      |> Dirup.Markdown.Stream.transform(fn
        {:start_heading, %{level: n} = meta} ->
          {:start_heading, %{meta | level: n + 1}}
        {:end_heading, %{level: n} = meta} ->
          {:end_heading, %{meta | level: n + 1}}
        event ->
          event
      end)
  """
  def transform(stream, transformer) when is_function(transformer) do
    Stream.map(stream, transformer)
  end

  @doc """
  Filter stream events.
  """
  def filter(stream, predicate) when is_function(predicate) do
    Stream.filter(stream, predicate)
  end

  @doc """
  Render stream back to markdown.
  """
  def to_markdown(stream) do
    stream
    |> Stream.transform([], &Event.render/2)
    |> Enum.join()
  end

  @doc """
  Collect stream into AST.
  """
  def to_ast(stream) do
    stream
    |> Enum.reduce({[], []}, &Event.build_ast/2)
    |> elem(0)
    |> Enum.reverse()
  end

  @doc """
  Stream markdown with Kyozo enhancements detection.
  """
  def parse_kyozo(input, opts \\ []) do
    input
    |> parse(opts)
    |> enhance_with_kyozo_metadata()
  end

  defp enhance_with_kyozo_metadata(stream) do
    stream
    |> Stream.transform(%{}, fn event, state ->
      case event do
        {:comment, content} ->
          case parse_kyozo_comment(content) do
            {:ok, metadata} ->
              {[{:dirup_metadata, metadata}], Map.put(state, :last_metadata, metadata)}

            :error ->
              {[event], state}
          end

        {:start_code_block, meta} when is_map_key(state, :last_metadata) ->
          enhanced_meta = Map.put(meta, :dirup, state.last_metadata)
          {[{:start_code_block, enhanced_meta}], Map.delete(state, :last_metadata)}

        _ ->
          {[event], state}
      end
    end)
  end

  defp parse_kyozo_comment(content) do
    case Regex.run(~r/kyozo:({.*?})/, content) do
      [_, json] -> Jason.decode(json)
      _ -> :error
    end
  end
end

defmodule Dirup.Markdown.Stream.Parser do
  @moduledoc """
  Line-by-line streaming parser for markdown.
  """

  def initial_state do
    %{
      mode: :normal,
      fence: nil,
      list_stack: [],
      blockquote_level: 0
    }
  end

  def parse_line(line, state) do
    trimmed = String.trim_trailing(line)

    case state.mode do
      :code_block ->
        handle_code_block_line(trimmed, state)

      :normal ->
        handle_normal_line(trimmed, state)
    end
  end

  # Code block handling
  defp handle_code_block_line(line, %{fence: fence} = state) do
    if String.starts_with?(line, fence) do
      {[{:end_code_block, %{}}], %{state | mode: :normal, fence: nil}}
    else
      {[{:code_line, line}], state}
    end
  end

  # Normal line handling
  defp handle_normal_line(line, state) do
    cond do
      # Blank line
      line == "" ->
        {[{:blank_line, %{}}], state}

      # Code fence start
      match = Regex.run(~r/^(```+|~~~+)(.*)/, line) ->
        handle_code_fence_start(match, state)

      # Heading
      match = Regex.run(~r/^(#\{1,6\})\s+(.*)/, line) ->
        handle_heading(match, state)

      # HTML comment
      String.starts_with?(line, "<!--") ->
        handle_comment(line, state)

      # List item
      match = Regex.run(~r/^(\s*)([-*+]|\d+\.)\s+(.*)/, line) ->
        handle_list_item(match, state)

      # Blockquote
      match = Regex.run(~r/^(>+)\s*(.*)/, line) ->
        handle_blockquote(match, state)

      # Horizontal rule
      line =~ ~r/^([-*_])\1{2,}\s*$/ ->
        {[{:horizontal_rule, %{}}], state}

      # Default paragraph text
      true ->
        {[{:text, line}], state}
    end
  end

  defp handle_code_fence_start([_, fence, lang], state) do
    lang = String.trim(lang)
    events = [{:start_code_block, %{lang: lang, fence: fence}}]
    {events, %{state | mode: :code_block, fence: fence}}
  end

  defp handle_heading([_, hashes, content], state) do
    level = String.length(hashes)

    events = [
      {:start_heading, %{level: level}},
      {:text, content},
      {:end_heading, %{level: level}}
    ]

    {events, state}
  end

  defp handle_comment(line, state) do
    if String.ends_with?(line, "-->") do
      # Single line comment
      content =
        line |> String.trim_leading("<!--") |> String.trim_trailing("-->") |> String.trim()

      {[{:comment, content}], state}
    else
      # Multi-line comment start - would need more complex handling
      {[{:comment_start, String.trim_leading(line, "<!--")}], state}
    end
  end

  defp handle_list_item([_, indent, marker, content], state) do
    depth = div(String.length(indent), 2)
    ordered = marker =~ ~r/\d+\./

    events = [{:list_item, %{depth: depth, ordered: ordered, marker: marker, content: content}}]
    {events, state}
  end

  defp handle_blockquote([_, quotes, content], state) do
    level = String.length(quotes)
    events = [{:blockquote, %{level: level, content: content}}]
    {events, state}
  end
end

defmodule Dirup.Markdown.Stream.Event do
  @moduledoc """
  Event handling and transformations for markdown streams.
  """

  def extractor_state(:code_blocks), do: %{extracting: false, current: nil}
  def extractor_state(:headings), do: %{extracting: false}
  def extractor_state(:dirup_metadata), do: %{}

  def extract({:start_code_block, meta}, %{} = state) do
    {[:skip], %{state | extracting: true, current: %{meta: meta, lines: []}}}
  end

  def extract({:code_line, line}, %{extracting: true, current: current} = state) do
    updated = Map.update!(current, :lines, &(&1 ++ [line]))
    {[:skip], %{state | current: updated}}
  end

  def extract({:end_code_block, _}, %{extracting: true, current: current} = state) do
    code_block = %{
      lang: current.meta.lang,
      content: Enum.join(current.lines, "\n"),
      kyozo: current.meta[:dirup]
    }

    {[code_block], %{state | extracting: false, current: nil}}
  end

  def extract({:dirup_metadata, metadata}, state) do
    {[metadata], state}
  end

  def extract(_, state) do
    {[:skip], state}
  end

  def matches_target?({:end_code_block, _}, :code_block), do: true
  def matches_target?({:end_heading, _}, :heading), do: true
  def matches_target?({event_type, _}, target), do: event_type == target
  def matches_target?(_, _), do: false

  def render({:start_heading, %{level: n}}, acc) do
    prefix = String.duplicate("#", n)
    {["#{prefix} "], acc}
  end

  def render({:end_heading, _}, acc) do
    {["\n"], acc}
  end

  def render({:text, text}, acc) do
    {[text], acc}
  end

  def render({:start_code_block, %{lang: lang}}, acc) do
    {["```#{lang}\n"], acc}
  end

  def render({:code_line, line}, acc) do
    {[line, "\n"], acc}
  end

  def render({:end_code_block, _}, acc) do
    {["```\n"], acc}
  end

  def render({:blank_line, _}, acc) do
    {["\n"], acc}
  end

  def render({:comment, content}, acc) do
    {["<!-- #{content} -->\n"], acc}
  end

  def render(_, acc) do
    {[], acc}
  end

  def build_ast(event, {ast, stack}) do
    # Simplified AST building
    # Would need full implementation for real usage
    {ast, stack}
  end
end
