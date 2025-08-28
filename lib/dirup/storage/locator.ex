defmodule Dirup.Storage.Locator do
  @moduledoc """
  Storage locator for managing file locations across different storage backends.

  Provides unique identifiers for stored content and tracks which backend
  is responsible for each piece of content.
  """

  defstruct [:id, :storage, metadata: %{}]

  @type t() :: %__MODULE__{
          id: String.t(),
          storage: String.t(),
          metadata: map()
        }

  @doc """
  Generates a new unique storage locator.

  Creates a UUIDv7 for time-ordered identifiers that work well
  with database indexing and provide some temporal ordering.
  """
  def generate do
    Ash.UUID.generate()
  end

  @doc """
  Creates a new locator struct from attributes.
  Raises on invalid data.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, locator} -> locator
      {:error, error} -> raise(Dirup.Storage.Errors.InvalidLocator, error)
    end
  end

  @doc """
  Creates a new locator struct from attributes.
  Returns {:ok, locator} or {:error, reason}.
  """
  def new(attrs) when is_list(attrs),
    do: attrs |> Map.new() |> new()

  def new(map = %{"id" => id, "storage" => storage}),
    do: new(%{id: id, storage: storage, metadata: Map.get(map, "metadata")})

  def new(map) when is_map_key(map, :id) and is_map_key(map, :storage) do
    __MODULE__
    |> struct(map)
    |> validate()
  end

  def new(_), do: {:error, "data must contain id and storage keys"}

  defp validate(%{id: id}) when not is_binary(id), do: {:error, "id must be binary"}

  defp validate(%{storage: storage})
       when (not is_binary(storage) and not is_atom(storage)) or is_nil(storage),
       do: {:error, "storage must be string or atom"}

  defp validate(struct), do: {:ok, struct}

  @doc """
  Converts a locator to a map representation.
  """
  def to_map(%__MODULE__{} = locator) do
    Map.from_struct(locator)
  end

  @doc """
  Extracts the backend type from a locator.
  """
  def get_backend(%__MODULE__{storage: storage}) when is_atom(storage), do: storage

  def get_backend(%__MODULE__{storage: storage}) when is_binary(storage),
    do: String.to_existing_atom(storage)

  @doc """
  Updates locator metadata.
  """
  def put_metadata(%__MODULE__{} = locator, key, value) do
    %{locator | metadata: Map.put(locator.metadata, key, value)}
  end

  @doc """
  Gets a value from locator metadata.
  """
  def get_metadata(%__MODULE__{metadata: metadata}, key, default \\ nil) do
    Map.get(metadata, key, default)
  end
end
