defmodule Dirup.Workspaces.Extensions.RenderMarkdown.PostProcessors.HeadingProcessor do
  @moduledoc """
  Processes HTML headings to add IDs for navigation and linking.

  This processor:
  - Adds unique IDs to all heading elements (h1-h6)
  - Adds anchor links for easy navigation
  - Handles duplicate heading text by appending numbers
  - Generates URL-friendly slugs from heading content
  """

  @doc """
  Processes headings in the HTML AST to add IDs and anchor links.

  ## Parameters

  - `ast` - The HTML AST to process
  - `add_ids?` - Whether to add IDs to headings (default: true)

  ## Returns

  The processed HTML AST with heading IDs and anchor links added
  """
  def process(ast, add_ids? \\ true)

  def process(ast, false), do: ast

  def process(ast, true) do
    {processed_ast, _id_tracker} =
      Floki.traverse_and_update(ast, %{}, fn element, id_tracker ->
        case element do
          {tag, attrs, children} when tag in ["h1", "h2", "h3", "h4", "h5", "h6"] ->
            process_heading(tag, attrs, children, id_tracker)

          other ->
            {other, id_tracker}
        end
      end)

    processed_ast
  end

  defp process_heading(tag, attrs, children, id_tracker) do
    # Extract text content from the heading
    text_content = extract_text_content(children)

    # Generate a unique ID
    {id, updated_tracker} = generate_unique_id(text_content, id_tracker)

    # Remove any existing id attribute and add the new one
    new_attrs =
      attrs
      |> Enum.reject(fn {key, _} -> key == "id" end)
      |> List.insert_at(0, {"id", id})
      |> add_heading_classes(tag)

    # Create the heading with anchor link
    new_children = create_heading_with_anchor(children, id, tag)

    {{tag, new_attrs, new_children}, updated_tracker}
  end

  defp extract_text_content(children) do
    children
    |> Floki.text()
    |> String.trim()
  end

  defp generate_unique_id(text, id_tracker) do
    base_id = text_to_slug(text)

    case Map.get(id_tracker, base_id) do
      nil ->
        # First occurrence of this heading
        {base_id, Map.put(id_tracker, base_id, 1)}

      count ->
        # Duplicate heading - append number
        unique_id = "#{base_id}-#{count + 1}"
        {unique_id, Map.put(id_tracker, base_id, count + 1)}
    end
  end

  defp text_to_slug(text) do
    text
    |> String.downcase()
    # Remove special characters except word chars, spaces, hyphens
    |> String.replace(~r/[^\w\s-]/, "")
    # Replace spaces with hyphens
    |> String.replace(~r/\s+/, "-")
    # Replace multiple hyphens with single hyphen
    |> String.replace(~r/-+/, "-")
    # Remove leading/trailing hyphens
    |> String.trim("-")
    |> case do
      # Fallback for empty slugs
      "" -> "heading"
      slug -> slug
    end
  end

  defp add_heading_classes(attrs, tag) do
    base_classes = "group relative flex items-center gap-2"

    size_classes =
      case tag do
        "h1" -> "text-3xl font-bold mb-6 mt-8"
        "h2" -> "text-2xl font-semibold mb-4 mt-6"
        "h3" -> "text-xl font-semibold mb-3 mt-5"
        "h4" -> "text-lg font-medium mb-2 mt-4"
        "h5" -> "text-base font-medium mb-2 mt-3"
        "h6" -> "text-sm font-medium mb-1 mt-2"
      end

    combined_classes = "#{base_classes} #{size_classes}"

    case List.keyfind(attrs, "class", 0) do
      {"class", existing_class} ->
        List.keyreplace(attrs, "class", 0, {"class", "#{existing_class} #{combined_classes}"})

      nil ->
        [{"class", combined_classes} | attrs]
    end
  end

  defp create_heading_with_anchor(children, id, tag) do
    anchor_classes =
      case tag do
        tag when tag in ["h1", "h2"] ->
          "text-lg opacity-0 group-hover:opacity-100 transition-opacity"

        _ ->
          "text-base opacity-0 group-hover:opacity-100 transition-opacity"
      end

    anchor_link = {
      "a",
      [
        {"href", "##{id}"},
        {"class", anchor_classes},
        {"aria-label", "Link to this heading"},
        {"title", "Link to this heading"}
      ],
      [
        {
          "svg",
          [
            {"xmlns", "http://www.w3.org/2000/svg"},
            {"class", "h-5 w-5"},
            {"fill", "none"},
            {"viewBox", "0 0 24 24"},
            {"stroke", "currentColor"},
            {"stroke-width", "2"}
          ],
          [
            {
              "path",
              [
                {"stroke-linecap", "round"},
                {"stroke-linejoin", "round"},
                {"d",
                 "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"}
              ],
              []
            }
          ]
        }
      ]
    }

    # Wrap the original children in a span for better layout control
    content_span = {
      "span",
      [{"class", "flex-1"}],
      children
    }

    [anchor_link, content_span]
  end
end
