defmodule Kyozo.Workspaces.File.Relationships.PrimaryMedia do
  @moduledoc """
  Manual relationship to get the primary Media resource for a file.
  
  This relationship finds the Media resource that has a primary FileMedia
  relationship with the file, providing direct access to the specialized
  media content without going through the intermediary.
  """

  use Ash.Resource.ManualRelationship
  require Ash.Query

  alias Kyozo.Workspaces.{FileMedia, Media}

  @impl true
  def load(files, _opts, _context) do
    file_ids = Enum.map(files, & &1.id)

    # Get all file media relationships for these files
    all_file_media = FileMedia
    |> Ash.Query.filter(file_id in ^file_ids and is_primary == true)
    |> Kyozo.Workspaces.read!()

    # Get the media IDs from the file_media relationships
    media_ids = all_file_media
    |> Enum.map(& &1.media_id)
    |> Enum.reject(&is_nil/1)

    # Load the Media resources
    media_resources = if length(media_ids) > 0 do
      Media
      |> Ash.Query.filter(id in ^media_ids)
      |> Kyozo.Workspaces.read!()
    else
      []
    end

    # Create media lookup map
    media_lookup = Enum.into(media_resources, %{}, fn m -> {m.id, m} end)

    # Group by file_id and extract the media resource
    media_by_file = all_file_media
    |> Enum.group_by(& &1.file_id)
    |> Enum.map(fn {file_id, file_media_list} ->
      # Should only be one primary file_media per file
      primary_file_media = List.first(file_media_list)
      media = primary_file_media && primary_file_media.media_id && Map.get(media_lookup, primary_file_media.media_id)
      {file_id, media}
    end)
    |> Enum.into(%{})

    {:ok, media_by_file}
  end
end