defmodule Kyozo.Changes.Slugify do
  use Ash.Resource.Change

  @doc """
  Generate and populate a `slug` attribute while inserting new records.
  """
  def change(changeset, _opts, context) do
    if changeset.action_type == :create do
      changeset
      |> Ash.Changeset.force_change_attribute(:slug, generate_slug(changeset, context))
    else
      changeset
    end
  end

  # Generates a slug based on the name attribute. If the slug already exists,
  # make it unique by appending "-count" to the end of the slug.
  defp generate_slug(%{attributes: %{name: name}} = changeset, context) when not is_nil(name) do
    # 1. Generate a slug based on the name
    slug = get_slug_from_name(name)

    # Add the count if the slug exists
    case count_similar_slugs(changeset, slug, context) do
      {:ok, 0} ->
        slug

      {:ok, count} ->
        "#{slug}-#{count}"

      {:error, error} ->
        raise error
    end
  end

  defp generate_slug(_changeset, _context), do: Ash.UUIDv7

  # Generate a lowercase slug based on the string passed
  defp get_slug_from_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
  end

  # Get the number of existing slugs
  defp count_similar_slugs(changeset, slug, context) do
    require Ash.Query

    changeset.resource
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.count(Ash.Context.to_opts(context))
  end
end
