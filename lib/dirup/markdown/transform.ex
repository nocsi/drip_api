defmodule Dirup.Markdown.Transform do
  @moduledoc """
  AST transformations for Kyozo Markdown.

  Provides utilities to:
  - Walk the AST
  - Transform nodes
  - Extract specific content
  - Enhance with Kyozo features
  """

  alias Dirup.Markdown.AST

  @doc """
  Walk the AST and apply a transformation function to each node.

  ## Example

      # Count all code blocks
      Transform.walk(ast, 0, fn
        %AST.Code{}, acc -> {:cont, acc + 1}
        _, acc -> {:cont, acc}
      end)
  """
  def walk(node, acc, fun) when is_function(fun, 2) do
    case fun.(node, acc) do
      {:cont, new_acc} ->
        walk_children(node, new_acc, fun)

      {:skip, new_acc} ->
        new_acc

      {:halt, new_acc} ->
        new_acc
    end
  end

  defp walk_children(%{children: children} = _node, acc, fun) when is_list(children) do
    Enum.reduce_while(children, acc, fn child, acc ->
      case walk(child, acc, fun) do
        {:halt, result} -> {:halt, result}
        result -> {:cont, result}
      end
    end)
  end

  defp walk_children(_, acc, _), do: acc

  @doc """
  Map over the AST, transforming nodes.

  ## Example

      # Make all headings one level deeper  
      Transform.map(ast, fn
        %AST.Heading{depth: d} = h -> %{h | depth: d + 1}
        node -> node
      end)
  """
  def map(node, fun) when is_function(fun, 1) do
    transformed = fun.(node)

    case transformed do
      %{children: children} when is_list(children) ->
        %{transformed | children: Enum.map(children, &map(&1, fun))}

      _ ->
        transformed
    end
  end

  @doc """
  Find all nodes matching a predicate.

  ## Example

      # Find all executable code blocks
      Transform.find_all(ast, fn
        %AST.Code{data: %{kyozo: %{executable: true}}} -> true
        _ -> false
      end)
  """
  def find_all(ast, predicate) do
    walk(ast, [], fn node, acc ->
      if predicate.(node) do
        {:cont, [node | acc]}
      else
        {:cont, acc}
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Extract all code blocks with their metadata.
  """
  def extract_code_blocks(ast) do
    find_all(ast, &match?(%AST.Code{}, &1))
  end

  @doc """
  Extract all executable code blocks.
  """
  def extract_executable_blocks(ast) do
    find_all(ast, fn
      %AST.Code{data: %{kyozo: %{executable: true}}} -> true
      _ -> false
    end)
  end

  @doc """
  Add Kyozo metadata to a node.
  """
  def add_kyozo_data(node, kyozo_data) do
    current_data = Map.get(node, :data, %{})
    current_kyozo = Map.get(current_data, :dirup, %{})

    updated_kyozo = Map.merge(current_kyozo, kyozo_data)
    updated_data = Map.put(current_data, :dirup, updated_kyozo)

    Map.put(node, :data, updated_data)
  end

  @doc """
  Build an execution plan from the AST.

  Returns code blocks in dependency order.
  """
  def build_execution_plan(ast) do
    blocks = extract_executable_blocks(ast)

    # Extract dependencies
    blocks_with_deps =
      Enum.map(blocks, fn block ->
        deps = get_in(block, [:data, :dirup, :metadata, "dependsOn"]) || []
        {block, deps}
      end)

    # Topological sort
    sorted = topological_sort(blocks_with_deps)

    {:ok, sorted}
  end

  @doc """
  Transform the AST for enlightenment.

  Adds markers for where AI-generated content should be inserted.
  """
  def prepare_for_enlightenment(ast) do
    map(ast, fn
      %AST.Code{data: %{kyozo: %{enlightened: true}}} = code ->
        # Add enlightenment placeholder after code block
        code

      node ->
        node
    end)
  end

  @doc """
  Apply enlightenment results to the AST.

  Inserts AI-generated explanations at marked locations.
  """
  def apply_enlightenment(ast, enlightenments) do
    # This would insert the enlightenment content
    # at the appropriate positions in the AST
    ast
  end

  @doc """
  Convert AST to a simpler format for execution.
  """
  def to_execution_format(ast) do
    blocks = extract_code_blocks(ast)

    Enum.map(blocks, fn %AST.Code{} = block ->
      %{
        id: generate_block_id(block),
        language: block.lang,
        content: block.value,
        executable: get_in(block, [:data, :dirup, :executable]) || false,
        metadata: get_in(block, [:data, :dirup, :metadata]) || %{},
        position: block.position
      }
    end)
  end

  # Private helpers

  defp topological_sort(nodes_with_deps) do
    # Simplified topological sort
    # Real implementation would handle cycles
    nodes_with_deps
    |> Enum.sort_by(fn {_, deps} -> length(deps) end)
    |> Enum.map(&elem(&1, 0))
  end

  defp generate_block_id(%AST.Code{position: %{start: %{line: line}}}) do
    "block_line_#{line}"
  end

  defp generate_block_id(_), do: "block_#{:erlang.unique_integer([:positive])}"
end
