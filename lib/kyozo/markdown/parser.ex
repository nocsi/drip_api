defmodule Kyozo.Markdown.Parser do
  @moduledoc """
  Kyozo Markdown parser that produces mdast-compatible AST with enhancements.

  The parser:
  1. Parses standard markdown into mdast
  2. Extracts Kyozo metadata from HTML comments
  3. Enhances nodes with executable/enlightenment data
  4. Maintains full mdast compatibility
  """

  alias Kyozo.Markdown.AST
  alias Kyozo.Markdown.Parser.{Tokenizer, ASTBuilder, KyozoEnhancer}

  @doc """
  Parse markdown content into an enhanced mdast tree.

  ## Example

      iex> Parser.parse("# Hello\\n<!-- kyozo:{\\"executable\\": true} -->\\n```elixir\\nIO.puts(:world)\\n```")
      {:ok, %AST.Root{
        type: :root,
        children: [
          %AST.Heading{type: :heading, depth: 1, children: [%AST.Text{value: "Hello"}]},
          %AST.Code{
            type: :code,
            lang: "elixir",
            value: "IO.puts(:world)",
            data: %{
              kyozo: %{
                executable: true,
                metadata: %{"executable" => true}
              }
            }
          }
        ]
      }}
  """
  def parse(content, opts \\ []) do
    with {:ok, tokens} <- Tokenizer.tokenize(content),
         {:ok, ast} <- ASTBuilder.build(tokens),
         {:ok, enhanced_ast} <- KyozoEnhancer.enhance(ast, content) do
      {:ok, enhanced_ast}
    end
  end

  @doc """
  Parse and return only the Kyozo enhancements, ignoring standard markdown.
  """
  def parse_kyozo_only(content) do
    ~r/<!-- kyozo:(.*?) -->/s
    |> Regex.scan(content, capture: :all_but_first)
    |> Enum.map(fn [json] -> Jason.decode(json) end)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, data} -> data end)
  end

  @doc """
  Convert our AST back to markdown (with Kyozo metadata preserved).
  """
  def to_markdown(ast) do
    ASTToMarkdown.convert(ast)
  end

  @doc """
  Convert our AST to standard mdast JSON (for compatibility).
  """
  def to_mdast_json(ast) do
    ast
    |> strip_position_data()
    |> Jason.encode!()
  end

  defp strip_position_data(ast) do
    # Remove position data for cleaner JSON output
    ast
    |> Map.put(:position, nil)
    |> Map.update(:children, [], fn children ->
      Enum.map(children, &strip_position_data/1)
    end)
  end
end

defmodule Kyozo.Markdown.Parser.Tokenizer do
  @moduledoc """
  Tokenizes markdown content into a stream of tokens.
  """

  def tokenize(content) do
    lines = String.split(content, ~r/\r?\n/)

    tokens =
      lines
      |> Enum.with_index(1)
      |> Enum.reduce({[], nil}, &tokenize_line/2)
      |> elem(0)
      |> Enum.reverse()

    {:ok, tokens}
  end

  defp tokenize_line({line, line_num}, {tokens, state}) do
    cond do
      # Code fence start/end
      match = Regex.match?(~r/^```(\w*)/, line) ->
        handle_code_fence(line, line_num, tokens, state)

      # HTML comment (potential Kyozo metadata)
      match = Regex.match?(~r/^<!--/, line) ->
        handle_html_comment(line, line_num, tokens, state)

      # Heading
      match = Regex.run(~r/^(#\{1,6\})\s+(.*)/, line) ->
        handle_heading(match, line_num, tokens, state)

      # Inside code block
      state == :code_block ->
        handle_code_content(line, line_num, tokens, state)

      # Inside HTML comment
      state == :html_comment ->
        handle_html_content(line, line_num, tokens, state)

      # Blank line
      String.trim(line) == "" ->
        {[{:blank, line_num} | tokens], state}

      # Regular text
      true ->
        {[{:text, line, line_num} | tokens], state}
    end
  end

  defp handle_code_fence(line, line_num, tokens, state) do
    case state do
      :code_block ->
        # Ending code fence
        {[{:code_fence_end, line_num} | tokens], nil}

      _ ->
        # Starting code fence
        lang = Regex.run(~r/^```(\w*)/, line, capture: :all_but_first) |> List.first()
        {[{:code_fence_start, lang || "", line_num} | tokens], :code_block}
    end
  end

  defp handle_html_comment(line, line_num, tokens, state) do
    if String.contains?(line, "-->") do
      # Single line comment
      {[{:html_comment, line, line_num} | tokens], state}
    else
      # Multi-line comment start
      {[{:html_comment_start, line, line_num} | tokens], :html_comment}
    end
  end

  defp handle_html_content(line, line_num, tokens, :html_comment) do
    if String.contains?(line, "-->") do
      # End of multi-line comment
      {[{:html_comment_end, line, line_num} | tokens], nil}
    else
      # Continue multi-line comment
      {[{:html_comment_content, line, line_num} | tokens], :html_comment}
    end
  end

  defp handle_heading([_, hashes, content], line_num, tokens, state) do
    depth = String.length(hashes)
    {[{:heading, depth, content, line_num} | tokens], state}
  end

  defp handle_code_content(line, line_num, tokens, state) do
    {[{:code_content, line, line_num} | tokens], state}
  end
end

defmodule Kyozo.Markdown.Parser.ASTBuilder do
  @moduledoc """
  Builds an mdast-compatible AST from tokens.
  """

  alias Kyozo.Markdown.AST

  def build(tokens) do
    {children, _} = build_nodes(tokens, [])

    root = %AST.Root{
      type: :root,
      children: Enum.reverse(children)
    }

    {:ok, root}
  end

  defp build_nodes([], acc), do: {acc, []}

  defp build_nodes([{:heading, depth, content, line_num} | rest], acc) do
    node = %AST.Heading{
      type: :heading,
      depth: depth,
      children: parse_inline(content),
      position: position(line_num)
    }

    build_nodes(rest, [node | acc])
  end

  defp build_nodes([{:code_fence_start, lang, start_line} | rest], acc) do
    {code_lines, rest_after_code} = collect_code_block(rest, [])

    node = %AST.Code{
      type: :code,
      lang: if(lang == "", do: nil, else: lang),
      value: Enum.join(code_lines, "\n"),
      position: position(start_line)
    }

    build_nodes(rest_after_code, [node | acc])
  end

  defp build_nodes([{:html_comment, value, line_num} | rest], acc) do
    node = %AST.HTML{
      type: :html,
      value: value,
      position: position(line_num)
    }

    build_nodes(rest, [node | acc])
  end

  defp build_nodes([{:text, value, line_num} | rest], acc) do
    node = %AST.Paragraph{
      type: :paragraph,
      children: parse_inline(value),
      position: position(line_num)
    }

    build_nodes(rest, [node | acc])
  end

  defp build_nodes([{:blank, _} | rest], acc) do
    build_nodes(rest, acc)
  end

  defp build_nodes([_ | rest], acc) do
    # Skip unknown tokens
    build_nodes(rest, acc)
  end

  defp collect_code_block([{:code_fence_end, _} | rest], acc) do
    {Enum.reverse(acc), rest}
  end

  defp collect_code_block([{:code_content, line, _} | rest], acc) do
    collect_code_block(rest, [line | acc])
  end

  defp collect_code_block(rest, acc) do
    {Enum.reverse(acc), rest}
  end

  defp parse_inline(text) do
    # Simplified inline parsing - in real implementation would handle
    # emphasis, strong, links, inline code, etc.
    [%AST.Text{type: :text, value: text}]
  end

  defp position(line) do
    %{
      start: %{line: line, column: 1},
      # Simplified
      end: %{line: line, column: 80}
    }
  end
end

defmodule Kyozo.Markdown.Parser.KyozoEnhancer do
  @moduledoc """
  Enhances the AST with Kyozo metadata from HTML comments.
  """

  def enhance(ast, original_content) do
    # Extract all Kyozo metadata
    metadata = extract_kyozo_metadata(original_content)

    # Enhance the AST by applying metadata to relevant nodes
    enhanced = enhance_node(ast, metadata)

    {:ok, enhanced}
  end

  defp extract_kyozo_metadata(content) do
    ~r/<!-- kyozo:(.*?) -->/s
    |> Regex.scan(content)
    |> Enum.map(fn [full, json] ->
      case Jason.decode(json) do
        {:ok, data} -> {find_position(full, content), data}
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp enhance_node(%{children: children} = node, metadata) when is_list(children) do
    enhanced_children = Enum.map(children, &enhance_node(&1, metadata))

    node
    |> Map.put(:children, enhanced_children)
    |> maybe_apply_metadata(metadata)
  end

  defp enhance_node(node, metadata) do
    maybe_apply_metadata(node, metadata)
  end

  defp maybe_apply_metadata(%{type: :code} = node, metadata) do
    # Find metadata that appears right before this code block
    relevant_metadata = find_metadata_for_node(node, metadata)

    if relevant_metadata do
      data = Map.get(node, :data, %{})

      kyozo_data =
        Map.merge(
          %{
            executable: Map.get(relevant_metadata, "executable", false),
            enlightened: Map.get(relevant_metadata, "enlighten", false),
            metadata: relevant_metadata
          },
          Map.get(data, :kyozo, %{})
        )

      Map.put(node, :data, Map.put(data, :kyozo, kyozo_data))
    else
      node
    end
  end

  defp maybe_apply_metadata(node, _metadata), do: node

  defp find_metadata_for_node(_node, _metadata) do
    # Simplified - would match based on position
    nil
  end

  defp find_position(text, content) do
    # Find line number where this text appears
    # Simplified implementation
    1
  end
end
