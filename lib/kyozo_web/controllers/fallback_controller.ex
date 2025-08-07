defmodule KyozoWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use KyozoWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: KyozoWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause handles Ash errors
  def call(conn, {:error, %Ash.Error.Invalid{} = error}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: format_ash_error(error))
  end

  def call(conn, {:error, %Ash.Error.Forbidden{} = error}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: format_ash_error(error))
  end

  def call(conn, {:error, %Ash.Error.Query.NotFound{} = error}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: format_ash_error(error))
  end

  def call(conn, {:error, %Ash.Error.Framework{} = error}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: format_ash_error(error))
  end

  def call(conn, {:error, %Ash.Error.Unknown{} = error}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: format_ash_error(error))
  end

  # This clause handles generic Ash errors
  def call(conn, {:error, error}) when is_exception(error) and error.__struct__ in [Ash.Error.Invalid, Ash.Error.Forbidden, Ash.Error.Query.NotFound, Ash.Error.Framework, Ash.Error.Unknown] do
    status = case error.__struct__ do
      Ash.Error.Invalid -> :unprocessable_entity
      Ash.Error.Forbidden -> :forbidden
      Ash.Error.Query.NotFound -> :not_found
      Ash.Error.Framework -> :internal_server_error
      Ash.Error.Unknown -> :internal_server_error
      _ -> :internal_server_error
    end

    conn
    |> put_status(status)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: format_ash_error(error))
  end

  # This clause handles validation errors
  def call(conn, {:error, :validation_failed, errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:validation_error, errors: errors)
  end

  # This clause handles authorization errors
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: "Authentication required"})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: "Access denied"})
  end

  # This clause handles not found errors
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: "Resource not found"})
  end

  # This clause handles timeout errors
  def call(conn, {:error, :timeout}) do
    conn
    |> put_status(:request_timeout)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: "Request timeout"})
  end

  # This clause handles rate limiting errors
  def call(conn, {:error, :rate_limited}) do
    conn
    |> put_status(:too_many_requests)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: "Rate limit exceeded"})
  end

  # This clause handles generic string errors
  def call(conn, {:error, error_message}) when is_binary(error_message) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: error_message})
  end

  # This clause handles generic atom errors
  def call(conn, {:error, error_atom}) when is_atom(error_atom) do
    message = case error_atom do
      :invalid_params -> "Invalid parameters"
      :missing_params -> "Missing required parameters"
      :invalid_format -> "Invalid format"
      :conflict -> "Resource conflict"
      :gone -> "Resource no longer available"
      _ -> "An error occurred"
    end

    status = case error_atom do
      :invalid_params -> :bad_request
      :missing_params -> :bad_request
      :invalid_format -> :bad_request
      :conflict -> :conflict
      :gone -> :gone
      _ -> :internal_server_error
    end

    conn
    |> put_status(status)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: message})
  end

  # This clause handles generic map errors
  def call(conn, {:error, error}) when is_map(error) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: error)
  end

  # Fallback for any other error format
  def call(conn, _error) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(json: KyozoWeb.ErrorJSON)
    |> render(:error, error: %{message: "Internal server error"})
  end

  # Helper function to format Ash errors
  defp format_ash_error(error) do
    case error do
      %{errors: errors} when is_list(errors) ->
        %{
          message: "Validation failed",
          errors: Enum.map(errors, &format_single_ash_error/1)
        }
      
      %{message: message} ->
        %{message: message}
      
      error ->
        %{message: Exception.message(error)}
    end
  end

  defp format_single_ash_error(error) do
    case error do
      %{field: field, message: message} ->
        %{field: field, message: message}
      
      %{path: path, message: message} ->
        %{field: Enum.join(path, "."), message: message}
      
      %{message: message} ->
        %{message: message}
      
      error ->
        %{message: Exception.message(error)}
    end
  end
end