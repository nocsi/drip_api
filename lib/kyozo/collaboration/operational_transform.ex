defmodule Kyozo.Collaboration.OperationalTransform do
  @moduledoc """
  Operational Transformation service for real-time collaborative editing.

  This module implements operational transformation algorithms to handle
  concurrent edits in collaborative documents. It ensures that operations
  from different users can be applied in any order while maintaining
  document consistency and user intentions.

  Supports the following operation types:
  - Insert: Insert text at a position
  - Delete: Delete text from a position with length
  - Retain: Keep existing text (used for formatting)
  - Format: Apply formatting attributes to text ranges
  """

  alias Kyozo.Collaboration.Operation

  @type operation_type :: :insert | :delete | :retain | :format
  @type position :: non_neg_integer()
  @type length :: non_neg_integer()

  @type operation :: %{
          type: operation_type(),
          position: position(),
          length: length() | nil,
          content: String.t() | nil,
          attributes: map() | nil
        }

  @type transform_result :: {:ok, {operation(), operation()}} | {:error, String.t()}

  @doc """
  Transform two concurrent operations against each other.

  Given two operations that were created concurrently against the same document
  state, this function transforms them so they can be applied in either order
  while preserving the intentions of both operations.

  ## Parameters
  - `op1`: First operation (typically from current user)
  - `op2`: Second operation (typically from remote user)
  - `priority`: Which operation has priority in case of conflicts (:left | :right)

  ## Returns
  - `{:ok, {transformed_op1, transformed_op2}}`: Successfully transformed operations
  - `{:error, reason}`: Transformation failed
  """
  @spec transform(operation(), operation(), :left | :right) :: transform_result()
  def transform(op1, op2, priority \\ :left) when is_map(op1) and is_map(op2) do
    try do
      result = do_transform(op1, op2, priority)
      {:ok, result}
    rescue
      error ->
        {:error, "Transformation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Apply a sequence of operations to a document.

  ## Parameters
  - `document`: Original document content
  - `operations`: List of operations to apply in order

  ## Returns
  - `{:ok, new_document}`: Successfully applied operations
  - `{:error, reason}`: Application failed
  """
  @spec apply_operations(String.t(), [operation()]) :: {:ok, String.t()} | {:error, String.t()}
  def apply_operations(document, operations) when is_binary(document) and is_list(operations) do
    try do
      result =
        operations
        |> Enum.reduce(document, fn op, acc_doc ->
          {:ok, new_doc} = apply_operation(acc_doc, op)
          new_doc
        end)

      {:ok, result}
    rescue
      error ->
        {:error, "Failed to apply operations: #{Exception.message(error)}"}
    end
  end

  @doc """
  Apply a single operation to a document.

  ## Parameters
  - `document`: Document content to modify
  - `operation`: Operation to apply

  ## Returns
  - `{:ok, new_document}`: Successfully applied operation
  - `{:error, reason}`: Application failed
  """
  @spec apply_operation(String.t(), operation()) :: {:ok, String.t()} | {:error, String.t()}
  def apply_operation(document, operation) when is_binary(document) and is_map(operation) do
    try do
      result =
        case operation.type do
          :insert -> apply_insert(document, operation)
          :delete -> apply_delete(document, operation)
          # Retain doesn't change document
          :retain -> {:ok, document}
          # Format operations don't change plain text
          :format -> {:ok, document}
          _ -> {:error, "Unknown operation type: #{operation.type}"}
        end

      result
    rescue
      error ->
        {:error, "Failed to apply operation: #{Exception.message(error)}"}
    end
  end

  @doc """
  Compose two operations into a single operation.

  This is useful for optimizing operation sequences by combining
  consecutive operations when possible.
  """
  @spec compose(operation(), operation()) :: {:ok, operation()} | {:error, String.t()}
  def compose(op1, op2) when is_map(op1) and is_map(op2) do
    try do
      result = do_compose(op1, op2)
      {:ok, result}
    rescue
      error ->
        {:error, "Composition failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Invert an operation to create its opposite.

  This is useful for implementing undo functionality.
  """
  @spec invert(operation(), String.t()) :: {:ok, operation()} | {:error, String.t()}
  def invert(operation, document) when is_map(operation) and is_binary(document) do
    try do
      result = do_invert(operation, document)
      {:ok, result}
    rescue
      error ->
        {:error, "Inversion failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Transform a position through an operation.

  This is useful for adjusting cursor positions and selections
  when operations are applied.
  """
  @spec transform_position(position(), operation()) :: position()
  def transform_position(position, operation) when is_integer(position) and is_map(operation) do
    case operation.type do
      :insert ->
        if position >= operation.position do
          position + String.length(operation.content || "")
        else
          position
        end

      :delete ->
        cond do
          position <= operation.position ->
            position

          position >= operation.position + operation.length ->
            position - operation.length

          true ->
            # Position is within deleted range
            operation.position
        end

      _ ->
        position
    end
  end

  # Private implementation functions

  defp do_transform(op1, op2, priority) do
    case {op1.type, op2.type} do
      {:insert, :insert} -> transform_insert_insert(op1, op2, priority)
      {:insert, :delete} -> transform_insert_delete(op1, op2)
      {:insert, :retain} -> transform_insert_retain(op1, op2)
      {:insert, :format} -> transform_insert_format(op1, op2)
      {:delete, :insert} -> transform_delete_insert(op1, op2)
      {:delete, :delete} -> transform_delete_delete(op1, op2, priority)
      {:delete, :retain} -> transform_delete_retain(op1, op2)
      {:delete, :format} -> transform_delete_format(op1, op2)
      {:retain, :insert} -> transform_retain_insert(op1, op2)
      {:retain, :delete} -> transform_retain_delete(op1, op2)
      {:retain, :retain} -> {op1, op2}
      {:retain, :format} -> transform_retain_format(op1, op2)
      {:format, :insert} -> transform_format_insert(op1, op2)
      {:format, :delete} -> transform_format_delete(op1, op2)
      {:format, :retain} -> transform_format_retain(op1, op2)
      {:format, :format} -> transform_format_format(op1, op2, priority)
      _ -> raise "Unknown operation type combination"
    end
  end

  # Insert vs Insert transformations
  defp transform_insert_insert(op1, op2, priority) do
    cond do
      op1.position < op2.position ->
        # op1 comes before op2
        new_op2 = %{op2 | position: op2.position + String.length(op1.content || "")}
        {op1, new_op2}

      op1.position > op2.position ->
        # op1 comes after op2
        new_op1 = %{op1 | position: op1.position + String.length(op2.content || "")}
        {new_op1, op2}

      true ->
        # Same position - use priority
        case priority do
          :left ->
            new_op2 = %{op2 | position: op2.position + String.length(op1.content || "")}
            {op1, new_op2}

          :right ->
            new_op1 = %{op1 | position: op1.position + String.length(op2.content || "")}
            {new_op1, op2}
        end
    end
  end

  # Insert vs Delete transformations
  defp transform_insert_delete(op1, op2) do
    cond do
      op1.position <= op2.position ->
        # Insert before delete
        new_op2 = %{op2 | position: op2.position + String.length(op1.content || "")}
        {op1, new_op2}

      op1.position >= op2.position + op2.length ->
        # Insert after delete
        new_op1 = %{op1 | position: op1.position - op2.length}
        {new_op1, op2}

      true ->
        # Insert within delete range
        new_op1 = %{op1 | position: op2.position}
        new_op2 = %{op2 | length: op2.length + String.length(op1.content || "")}
        {new_op1, new_op2}
    end
  end

  # Delete vs Insert transformations
  defp transform_delete_insert(op1, op2) do
    {new_op2, new_op1} = transform_insert_delete(op2, op1)
    {new_op1, new_op2}
  end

  # Delete vs Delete transformations
  defp transform_delete_delete(op1, op2, priority) do
    cond do
      op1.position + op1.length <= op2.position ->
        # op1 completely before op2
        new_op2 = %{op2 | position: op2.position - op1.length}
        {op1, new_op2}

      op2.position + op2.length <= op1.position ->
        # op2 completely before op1
        new_op1 = %{op1 | position: op1.position - op2.length}
        {new_op1, op2}

      op1.position >= op2.position and op1.position + op1.length <= op2.position + op2.length ->
        # op1 completely contained in op2
        new_op2 = %{op2 | length: op2.length - op1.length}
        noop_op1 = %{op1 | type: :retain, length: 0}
        {noop_op1, new_op2}

      op2.position >= op1.position and op2.position + op2.length <= op1.position + op1.length ->
        # op2 completely contained in op1
        new_op1 = %{op1 | length: op1.length - op2.length}
        noop_op2 = %{op2 | type: :retain, length: 0}
        {new_op1, noop_op2}

      true ->
        # Overlapping deletes - complex case
        handle_overlapping_deletes(op1, op2, priority)
    end
  end

  defp handle_overlapping_deletes(op1, op2, priority) do
    # Calculate overlap region
    overlap_start = max(op1.position, op2.position)
    overlap_end = min(op1.position + op1.length, op2.position + op2.length)
    overlap_length = overlap_end - overlap_start

    case priority do
      :left ->
        # op1 has priority, adjust op2
        new_op2_pos = min(op2.position, op1.position)
        new_op2_length = op2.length - overlap_length
        new_op2 = %{op2 | position: new_op2_pos, length: max(0, new_op2_length)}
        {op1, new_op2}

      :right ->
        # op2 has priority, adjust op1
        new_op1_pos = min(op1.position, op2.position)
        new_op1_length = op1.length - overlap_length
        new_op1 = %{op1 | position: new_op1_pos, length: max(0, new_op1_length)}
        {new_op1, op2}
    end
  end

  # Insert vs Retain transformations
  defp transform_insert_retain(op1, op2) do
    if op1.position <= op2.position do
      new_op2 = %{op2 | position: op2.position + String.length(op1.content || "")}
      {op1, new_op2}
    else
      {op1, op2}
    end
  end

  defp transform_retain_insert(op1, op2) do
    {new_op2, new_op1} = transform_insert_retain(op2, op1)
    {new_op1, new_op2}
  end

  # Delete vs Retain transformations
  defp transform_delete_retain(op1, op2) do
    cond do
      op2.position >= op1.position + op1.length ->
        new_op2 = %{op2 | position: op2.position - op1.length}
        {op1, new_op2}

      op2.position <= op1.position ->
        {op1, op2}

      true ->
        new_op2 = %{op2 | position: op1.position}
        {op1, new_op2}
    end
  end

  defp transform_retain_delete(op1, op2) do
    {new_op2, new_op1} = transform_delete_retain(op2, op1)
    {new_op1, new_op2}
  end

  # Format operation transformations (simplified)
  defp transform_insert_format(op1, op2) do
    if op1.position <= op2.position do
      new_op2 = %{op2 | position: op2.position + String.length(op1.content || "")}
      {op1, new_op2}
    else
      {op1, op2}
    end
  end

  defp transform_format_insert(op1, op2) do
    {new_op2, new_op1} = transform_insert_format(op2, op1)
    {new_op1, new_op2}
  end

  defp transform_delete_format(op1, op2) do
    # Format is affected by delete
    cond do
      op2.position + op2.length <= op1.position ->
        # Format entirely before delete
        {op1, op2}

      op2.position >= op1.position + op1.length ->
        # Format entirely after delete
        new_op2 = %{op2 | position: op2.position - op1.length}
        {op1, new_op2}

      true ->
        # Format overlaps with delete - adjust format range
        new_start = max(op2.position, op1.position)
        new_end = min(op2.position + op2.length, op1.position + op1.length)

        if new_start >= new_end do
          # Format completely deleted
          noop_op2 = %{op2 | type: :retain, length: 0}
          {op1, noop_op2}
        else
          new_op2 = %{op2 | position: new_start - op1.length, length: new_end - new_start}
          {op1, new_op2}
        end
    end
  end

  defp transform_format_delete(op1, op2) do
    {new_op2, new_op1} = transform_delete_format(op2, op1)
    {new_op1, new_op2}
  end

  defp transform_retain_format(op1, op2), do: {op1, op2}
  defp transform_format_retain(op1, op2), do: {op1, op2}

  defp transform_format_format(op1, op2, _priority) do
    # Formatting operations don't conflict in the same way
    # Both can be applied independently
    {op1, op2}
  end

  # Operation application functions

  defp apply_insert(document, operation) do
    position = operation.position
    content = operation.content || ""

    if position > String.length(document) do
      {:error, "Insert position #{position} exceeds document length #{String.length(document)}"}
    else
      {before, after_text} = String.split_at(document, position)
      {:ok, before <> content <> after_text}
    end
  end

  defp apply_delete(document, operation) do
    position = operation.position
    length = operation.length

    doc_length = String.length(document)

    cond do
      position > doc_length ->
        {:error, "Delete position #{position} exceeds document length #{doc_length}"}

      position + length > doc_length ->
        {:error, "Delete range #{position}+#{length} exceeds document length #{doc_length}"}

      true ->
        {before, rest} = String.split_at(document, position)
        {_deleted, after_text} = String.split_at(rest, length)
        {:ok, before <> after_text}
    end
  end

  # Operation composition functions

  defp do_compose(op1, op2) do
    case {op1.type, op2.type} do
      {:insert, :delete} -> compose_insert_delete(op1, op2)
      {:delete, :insert} -> compose_delete_insert(op1, op2)
      {:insert, :insert} -> compose_insert_insert(op1, op2)
      {:delete, :delete} -> compose_delete_delete(op1, op2)
      # Default: second operation takes precedence
      _ -> op2
    end
  end

  defp compose_insert_delete(insert_op, delete_op) do
    # Check if delete affects the inserted content
    if delete_op.position >= insert_op.position and
         delete_op.position + delete_op.length <=
           insert_op.position + String.length(insert_op.content || "") do
      # Delete is within inserted content
      content = insert_op.content || ""
      {before_delete, rest} = String.split_at(content, delete_op.position - insert_op.position)
      {_deleted, after_delete} = String.split_at(rest, delete_op.length)

      %{
        type: :insert,
        position: insert_op.position,
        content: before_delete <> after_delete
      }
    else
      # Operations don't directly compose
      delete_op
    end
  end

  defp compose_delete_insert(delete_op, insert_op) do
    # Insert after delete at same position
    if insert_op.position == delete_op.position do
      %{
        type: :insert,
        position: delete_op.position,
        content: insert_op.content,
        length: delete_op.length
      }
    else
      insert_op
    end
  end

  defp compose_insert_insert(op1, op2) do
    # Combine adjacent inserts
    if op2.position == op1.position + String.length(op1.content || "") do
      %{
        type: :insert,
        position: op1.position,
        content: (op1.content || "") <> (op2.content || "")
      }
    else
      op2
    end
  end

  defp compose_delete_delete(op1, op2) do
    # Combine adjacent deletes
    if op2.position == op1.position do
      %{
        type: :delete,
        position: op1.position,
        length: op1.length + op2.length
      }
    else
      op2
    end
  end

  # Operation inversion functions

  defp do_invert(operation, document) do
    case operation.type do
      :insert ->
        %{
          type: :delete,
          position: operation.position,
          length: String.length(operation.content || "")
        }

      :delete ->
        # Extract the content that was deleted
        {_before, rest} = String.split_at(document, operation.position)
        {deleted_content, _after_text} = String.split_at(rest, operation.length)

        %{
          type: :insert,
          position: operation.position,
          content: deleted_content
        }

      :format ->
        # Invert formatting by removing attributes
        %{
          type: :format,
          position: operation.position,
          length: operation.length,
          attributes: invert_attributes(operation.attributes || %{})
        }

      _ ->
        operation
    end
  end

  defp invert_attributes(attributes) do
    # Simple attribute inversion - in practice this would be more sophisticated
    Map.new(attributes, fn {key, _value} -> {key, nil} end)
  end

  @doc """
  Convert an Operation record to the internal operation format.
  """
  def from_operation_record(%Operation{} = record) do
    %{
      type: record.operation_type,
      position: record.position,
      length: record.length,
      content: record.content,
      attributes: Map.get(record.operation_data || %{}, "attributes")
    }
  end

  @doc """
  Convert internal operation format to Operation record attributes.
  """
  def to_operation_attributes(operation) when is_map(operation) do
    operation_data = %{
      "position" => operation.position,
      "length" => operation.length,
      "content" => operation.content
    }

    operation_data =
      if operation.attributes do
        Map.put(operation_data, "attributes", operation.attributes)
      else
        operation_data
      end

    %{
      operation_type: operation.type,
      operation_data: operation_data,
      position: operation.position,
      length: operation.length,
      content: operation.content
    }
  end
end
