defmodule Dirup.Billing.AshStripeHelpers do
  @moduledoc """
  Helper functions to work around Ash 3.5 edge cases with Stripe integration
  """

  alias Dirup.Billing

  @doc """
  Find a resource by a specific attribute value.
  Works around Ash 3.5 query limitations.
  """
  def find_by_attribute(resource_module, attribute, value) do
    case resource_module.read() do
      {:ok, records} ->
        record =
          Enum.find(records, fn r ->
            Map.get(r, attribute) == value
          end)

        if record do
          {:ok, record}
        else
          {:error, :not_found}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Create or update a resource based on a unique attribute.
  """
  def upsert_by_attribute(resource_module, attribute, value, params) do
    case find_by_attribute(resource_module, attribute, value) do
      {:ok, existing} ->
        # Update existing record
        update_resource(existing, params)

      {:error, :not_found} ->
        # Create new record
        create_resource(resource_module, Map.put(params, attribute, value))
    end
  end

  @doc """
  Safely create a resource with error handling
  """
  def create_resource(resource_module, params) do
    action = get_create_action(resource_module)

    resource_module
    |> Ash.Changeset.for_create(action, params)
    |> Ash.create()
  end

  @doc """
  Safely update a resource with error handling
  """
  def update_resource(record, params) do
    action = get_update_action(record.__struct__)

    record
    |> Ash.Changeset.for_update(action, params)
    |> Ash.update()
  end

  @doc """
  Batch find resources by attribute values
  """
  def find_all_by_attribute(resource_module, attribute, values) when is_list(values) do
    case resource_module.read() do
      {:ok, records} ->
        found =
          Enum.filter(records, fn r ->
            Map.get(r, attribute) in values
          end)

        {:ok, found}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Transaction wrapper for Stripe operations
  """
  def with_stripe_transaction(fun) do
    Ash.Changeset.with_hooks(fn ->
      try do
        fun.()
      rescue
        e in Stripe.Error ->
          {:error, format_stripe_error(e)}

        e ->
          {:error, Exception.message(e)}
      end
    end)
  end

  @doc """
  Format Stripe errors for consistent handling
  """
  def format_stripe_error(%Stripe.Error{} = error) do
    %{
      type: error.extra.error_type || "api_error",
      code: error.extra.error_code,
      message: error.message,
      param: error.extra.error_param,
      request_id: error.extra.request_id
    }
  end

  @doc """
  Safe Stripe API call with retries
  """
  def safe_stripe_call(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    retry_delay = Keyword.get(opts, :retry_delay, 1000)

    do_safe_stripe_call(fun, 0, max_retries, retry_delay)
  end

  # Private functions

  defp do_safe_stripe_call(fun, attempt, max_retries, retry_delay) do
    case fun.() do
      {:ok, _} = success ->
        success

      {:error, %Stripe.Error{extra: %{error_code: code}}} = error
      when code in ["rate_limit", "api_connection_error"] and attempt < max_retries ->
        Process.sleep(retry_delay * (attempt + 1))
        do_safe_stripe_call(fun, attempt + 1, max_retries, retry_delay)

      error ->
        error
    end
  end

  defp get_create_action(resource_module) do
    # Get the primary create action or default to :create
    resource_module.__ash_resource__().actions
    |> Enum.find(fn action ->
      action.type == :create && action.primary?
    end)
    |> case do
      nil -> :create
      action -> action.name
    end
  end

  defp get_update_action(resource_module) do
    # Get the primary update action or default to :update
    resource_module.__ash_resource__().actions
    |> Enum.find(fn action ->
      action.type == :update && action.primary?
    end)
    |> case do
      nil -> :update
      action -> action.name
    end
  end
end
