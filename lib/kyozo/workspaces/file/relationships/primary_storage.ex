defmodule Kyozo.Workspaces.File.Relationships.PrimaryStorage do
  @moduledoc """
  Manual relationship to get the primary storage resource for a file.
  
  This relationship finds the storage resource that has a primary FileStorage
  relationship with the file.
  """

  use Ash.Resource.ManualRelationship
  require Ash.Query

  alias Kyozo.Workspaces.FileStorage
  alias Kyozo.Storage.StorageResource

  @impl true
  def load(files, _opts, _context) do
    file_ids = Enum.map(files, & &1.id)

    # Get all file storage relationships for these files
    all_storages = FileStorage
    |> Kyozo.Workspaces.read!()
    |> Enum.filter(fn fs -> 
        fs.file_id in file_ids and fs.is_primary == true
      end)

    # Load the storage resources
    storage_ids = Enum.map(all_storages, & &1.storage_resource_id)
    storages = if length(storage_ids) > 0 do
      Kyozo.Storage.StorageResource
      |> Kyozo.Storage.read!()
      |> Enum.filter(fn s -> s.id in storage_ids end)
    else
      []
    end

    # Create storage lookup map
    storage_lookup = Enum.into(storages, %{}, fn s -> {s.id, s} end)

    # Group by file_id and extract the storage resource
    storage_by_file = all_storages
    |> Enum.group_by(& &1.file_id)
    |> Enum.map(fn {file_id, storages} ->
      # Should only be one primary storage per file
      primary_storage = List.first(storages)
      storage = primary_storage && Map.get(storage_lookup, primary_storage.storage_resource_id)
      {file_id, storage}
    end)
    |> Enum.into(%{})

    {:ok, storage_by_file}
  end
end