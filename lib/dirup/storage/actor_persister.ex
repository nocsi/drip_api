defmodule Dirup.Storage.ActorPersister do
  @moduledoc """
  Actor persister for AshOban storage jobs.

  This module handles persisting and retrieving actor information for background jobs
  in the storage domain, ensuring that the original actor context is preserved
  when jobs are executed asynchronously.
  """

  use AshOban.ActorPersister

  @doc """
  Stores an actor for later retrieval in a background job.

  Converts the actor into a JSON-serializable format that can be stored
  with the job and later used to reconstruct the actor context.
  """
  def store(actor)

  # Handle User actors (assuming you have a User resource)
  def store(%{__struct__: user_module, id: id} = _actor)
      when user_module in [Dirup.Accounts.User, Dirup.Accounts.ApiKey] do
    %{
      "type" => module_to_string(user_module),
      "id" => id
    }
  end

  # Handle system/admin actors
  def store(%{system: true} = actor) do
    %{
      "type" => "system",
      "data" => Map.from_struct(actor)
    }
  end

  # Handle nil actors (no authentication)
  def store(nil) do
    nil
  end

  # Handle other actor types - convert to map representation
  def store(actor) when is_map(actor) do
    %{
      "type" => "generic",
      "data" => actor
    }
  end

  # Handle any other actor type
  def store(actor) do
    %{
      "type" => "unknown",
      "data" => inspect(actor)
    }
  end

  @doc """
  Looks up an actor from stored data.

  Reconstructs the actor from the stored JSON data, typically by fetching
  the full actor record from the database.
  """
  def lookup(stored_data)

  # Lookup User actors
  def lookup(%{"type" => user_type, "id" => id})
      when user_type in ["Dirup.Accounts.User"] do
    case Dirup.Accounts.get_user_by_id(id) do
      {:ok, user} -> {:ok, user}
      {:error, _} -> {:error, "User not found: #{id}"}
    end
  end

  # Lookup API Key actors
  def lookup(%{"type" => "Dirup.Accounts.ApiKey", "id" => id}) do
    case Dirup.Accounts.get_api_key_by_id(id) do
      {:ok, api_key} -> {:ok, api_key}
      {:error, _} -> {:error, "API key not found: #{id}"}
    end
  end

  # Lookup system actors
  def lookup(%{"type" => "system", "data" => data}) do
    {:ok, data}
  end

  # Lookup generic actors
  def lookup(%{"type" => "generic", "data" => data}) do
    {:ok, data}
  end

  # Handle nil/no actor
  def lookup(nil) do
    {:ok, nil}
  end

  # Handle unknown actor types
  def lookup(%{"type" => "unknown", "data" => data}) do
    {:ok, %{unknown_actor: data}}
  end

  # Handle unexpected data
  def lookup(other) do
    {:error, "Cannot lookup actor from: #{inspect(other)}"}
  end

  # Private helper functions

  defp module_to_string(module) when is_atom(module) do
    module |> Module.split() |> Enum.join(".")
  end
end
