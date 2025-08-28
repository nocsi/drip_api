defmodule DirupWeb.ErrorJSON do
  @moduledoc """
  This module is used to render JSON error responses.
  """

  @doc """
  Renders a generic error.
  """
  def error(%{error: error}) when is_map(error) do
    %{error: error}
  end

  def error(%{error: error}) when is_binary(error) do
    %{error: %{message: error}}
  end

  def error(%{error: error}) do
    %{error: %{message: inspect(error)}}
  end

  @doc """
  Renders validation errors.
  """
  def validation_error(%{errors: errors}) when is_list(errors) do
    %{
      error: %{
        message: "Validation failed",
        details: format_validation_errors(errors)
      }
    }
  end

  def validation_error(%{errors: errors}) when is_map(errors) do
    %{
      error: %{
        message: "Validation failed",
        details: errors
      }
    }
  end

  @doc """
  Renders changeset errors.
  """
  def changeset_error(%{changeset: changeset}) do
    %{
      error: %{
        message: "Validation failed",
        details: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
      }
    }
  end

  @doc """
  Renders authentication errors.
  """
  def auth_error(%{message: message}) do
    %{error: %{message: message, code: "authentication_required"}}
  end

  def auth_error(_params) do
    %{error: %{message: "Authentication required", code: "authentication_required"}}
  end

  @doc """
  Renders authorization errors.
  """
  def forbidden_error(%{message: message}) do
    %{error: %{message: message, code: "access_denied"}}
  end

  def forbidden_error(_params) do
    %{error: %{message: "Access denied", code: "access_denied"}}
  end

  @doc """
  Renders not found errors.
  """
  def not_found_error(%{resource: resource}) do
    %{error: %{message: "#{resource} not found", code: "not_found"}}
  end

  def not_found_error(_params) do
    %{error: %{message: "Resource not found", code: "not_found"}}
  end

  @doc """
  Renders rate limiting errors.
  """
  def rate_limit_error(%{retry_after: retry_after}) do
    %{
      error: %{
        message: "Rate limit exceeded",
        code: "rate_limit_exceeded",
        retry_after: retry_after
      }
    }
  end

  def rate_limit_error(_params) do
    %{error: %{message: "Rate limit exceeded", code: "rate_limit_exceeded"}}
  end

  @doc """
  Renders timeout errors.
  """
  def timeout_error(%{timeout: timeout}) do
    %{
      error: %{
        message: "Request timeout after #{timeout}ms",
        code: "timeout"
      }
    }
  end

  def timeout_error(_params) do
    %{error: %{message: "Request timeout", code: "timeout"}}
  end

  @doc """
  Renders server errors.
  """
  def server_error(%{message: message}) do
    %{error: %{message: message, code: "internal_server_error"}}
  end

  def server_error(_params) do
    %{error: %{message: "Internal server error", code: "internal_server_error"}}
  end

  @doc """
  Renders bad request errors.
  """
  def bad_request_error(%{message: message}) do
    %{error: %{message: message, code: "bad_request"}}
  end

  def bad_request_error(_params) do
    %{error: %{message: "Bad request", code: "bad_request"}}
  end

  @doc """
  Renders conflict errors.
  """
  def conflict_error(%{message: message}) do
    %{error: %{message: message, code: "conflict"}}
  end

  def conflict_error(_params) do
    %{error: %{message: "Resource conflict", code: "conflict"}}
  end

  # Private functions

  defp format_validation_errors(errors) when is_list(errors) do
    Enum.map(errors, &format_single_validation_error/1)
  end

  defp format_single_validation_error(error) when is_map(error) do
    case error do
      %{field: field, message: message} ->
        %{field: to_string(field), message: message}

      %{path: path, message: message} when is_list(path) ->
        %{field: Enum.join(path, "."), message: message}

      %{message: message} ->
        %{message: message}

      error ->
        %{message: inspect(error)}
    end
  end

  defp format_single_validation_error(error) do
    %{message: inspect(error)}
  end

  defp translate_error({msg, opts}) do
    # You can customize error message translation here
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  defp translate_error(msg) when is_binary(msg) do
    msg
  end

  defp translate_error(msg) do
    inspect(msg)
  end
end
