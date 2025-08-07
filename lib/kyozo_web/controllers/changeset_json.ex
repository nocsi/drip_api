defmodule KyozoWeb.ChangesetJSON do
  @moduledoc """
  This module is used to render JSON responses for Ecto.Changeset errors.
  """

  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  @doc """
  Renders multiple changeset errors.
  """
  def errors(%{changesets: changesets}) when is_list(changesets) do
    %{
      errors: Enum.map(changesets, &translate_errors/1)
    }
  end

  @doc """
  Renders form validation errors with field-specific messages.
  """
  def validation_errors(%{changeset: changeset}) do
    %{
      error: %{
        message: "Validation failed",
        details: translate_errors(changeset)
      }
    }
  end

  @doc """
  Renders nested changeset errors (for embedded schemas).
  """
  def nested_errors(%{changeset: changeset}) do
    %{
      errors: translate_nested_errors(changeset)
    }
  end

  # Private functions

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_nested_errors(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    
    # Handle nested errors from embedded schemas
    nested_errors = 
      changeset.changes
      |> Enum.filter(fn {_field, value} -> is_changeset_or_list_of_changesets?(value) end)
      |> Enum.into(%{}, fn {field, value} ->
        {field, extract_nested_changeset_errors(value)}
      end)

    Map.merge(errors, nested_errors)
  end

  defp is_changeset_or_list_of_changesets?(%Ecto.Changeset{}), do: true
  defp is_changeset_or_list_of_changesets?(list) when is_list(list) do
    Enum.all?(list, &match?(%Ecto.Changeset{}, &1))
  end
  defp is_changeset_or_list_of_changesets?(_), do: false

  defp extract_nested_changeset_errors(%Ecto.Changeset{} = changeset) do
    translate_errors(changeset)
  end

  defp extract_nested_changeset_errors(changesets) when is_list(changesets) do
    Enum.with_index(changesets)
    |> Enum.into(%{}, fn {changeset, index} ->
      {index, translate_errors(changeset)}
    end)
  end

  defp translate_error({msg, opts}) do
    # Handle interpolation of values in error messages
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  defp translate_error(msg) when is_binary(msg) do
    msg
  end

  defp translate_error(msg) do
    # Fallback for any other error format
    inspect(msg)
  end
end