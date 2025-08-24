defmodule KyozoWeb.API.Storage.VFSJSON do
  alias Kyozo.Storage.VFS

  @doc """
  Renders a list of files including virtual files.
  """
  def index(%{listing: listing}) do
    %{
      data: %{
        path: listing.path,
        virtual_count: listing.virtual_count,
        files: Enum.map(listing.files, &file_json/1)
      }
    }
  end

  @doc """
  Renders virtual file content.
  """
  def show(%{content: content, path: path}) do
    %{
      data: %{
        path: path,
        content: content,
        virtual: true,
        content_type: "text/markdown"
      }
    }
  end

  defp file_json(file) do
    %{
      id: file.id,
      name: file.name,
      path: file.path,
      type: file.type,
      size: file.size,
      content_type: file.content_type,
      created_at: file.created_at,
      updated_at: file.updated_at,
      virtual: Map.get(file, :virtual, false),
      icon: Map.get(file, :icon),
      generator: Map.get(file, :generator)
    }
  end
end
