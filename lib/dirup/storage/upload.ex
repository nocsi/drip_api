defmodule Dirup.Storage.Upload do
  @moduledoc """
  Struct representing a file upload for storage.
  """

  defstruct [:content, :filename, :content_type, :metadata]

  @type t :: %__MODULE__{
          content: binary(),
          filename: String.t(),
          content_type: String.t(),
          metadata: map()
        }
end

defprotocol Dirup.Storage.UploadProtocol do
  @spec contents(struct()) :: {:ok, iodata()} | {:error, String.t()}
  def contents(upload)

  @spec name(struct()) :: String.t()
  def name(upload)
end

defimpl Dirup.Storage.UploadProtocol, for: Dirup.Storage.Locator do
  def contents(locator), do: Dirup.Storage.storage!(locator).read(locator.id)

  def name(%{metadata: %{name: name}}), do: name
  def name(%{id: id}), do: id
end

defimpl Dirup.Storage.UploadProtocol, for: Dirup.Storage.Upload do
  def contents(%Dirup.Storage.Upload{content: content}), do: {:ok, content}
  def name(%Dirup.Storage.Upload{filename: filename}), do: filename
end
