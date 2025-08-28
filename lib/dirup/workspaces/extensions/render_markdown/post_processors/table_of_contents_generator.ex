defmodule Dirup.Workspaces.Extensions.RenderMarkdown.PostProcessors.TableOfContentsGenerator do
  @moduledoc """
  Auto-generates a table of contents to be rendered as part of the HTML.

  This processor:
  - Extracts h2 and h3 headings from the document
  - Groups h3 headings under their parent h2
  - Creates a hierarchical navigation structure
  - Inserts the table of contents at the beginning of the document
  - Adds responsive styling and collapsible behavior
  """

  @doc """
  Generates a table of contents from headings in the HTML AST.

  ## Parameters

  - `ast` - The HTML AST to process
  - `generate?` - Whether to generate a table of contents (default: false)

  ## Returns

  The HTML AST with table of contents prepended if generation is enabled
  """
  def generate(ast, generate? \\ false)

  def generate(ast, false), do: ast

  def generate(ast, true) do
    case extract_headings(ast) do
      # No headings found
      [] ->
        ast

      # Headings found - generate TOC and insert it
      headings ->
        toc_html = generate_toc_html(headings)
        insert_toc_into_ast(ast, toc_html)
    end
  end

  defp extract_headings(ast) do
    {_processed_ast, headings} =
      Floki.traverse_and_update(ast, [], fn element, acc ->
        case element do
          {tag, attrs, children} when tag in ["h2", "h3"] ->
            case extract_heading_info(tag, attrs, children) do
              nil -> {element, acc}
              heading_info -> {element, [heading_info | acc]}
            end

          other ->
            {other, acc}
        end
      end)

    headings
    |> Enum.reverse()
    |> group_by_level()
  end

  defp extract_heading_info(tag, attrs, children) do
    case List.keyfind(attrs, "id", 0) do
      {"id", id} ->
        text = Floki.text(children) |> String.trim()
        level = String.to_integer(String.last(tag))

        %{
          level: level,
          id: id,
          text: text,
          tag: tag
        }

      nil ->
        nil
    end
  end

  defp group_by_level(headings) do
    headings
    |> Enum.chunk_while(
      [],
      fn heading, acc ->
        if heading.level == 2 do
          # New h2 - emit previous group and start new one
          {:cont, Enum.reverse(acc), [heading]}
        else
          # h3 or other - add to current group
          {:cont, [heading | acc]}
        end
      end,
      fn remainder -> {:cont, Enum.reverse(remainder), []} end
    )
    |> Enum.reject(&Enum.empty?/1)
  end

  defp generate_toc_html(grouped_headings) do
    toc_id = "toc-#{System.unique_integer([:positive])}"

    toc_items = Enum.map(grouped_headings, &generate_toc_group/1)

    {
      "div",
      [
        {"id", toc_id},
        {"class",
         "table-of-contents bg-gray-50 border border-gray-200 rounded-lg p-6 mb-8 not-prose"},
        {"role", "navigation"},
        {"aria-labelledby", "#{toc_id}-title"}
      ],
      [
        # TOC Header
        {
          "div",
          [{"class", "flex items-center justify-between mb-4"}],
          [
            {
              "h3",
              [
                {"id", "#{toc_id}-title"},
                {"class", "text-lg font-semibold text-gray-900 flex items-center gap-2 m-0"}
              ],
              [
                {
                  "svg",
                  [
                    {"xmlns", "http://www.w3.org/2000/svg"},
                    {"class", "h-5 w-5 text-blue-600"},
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
                        {"d", "M4 6h16M4 10h16M4 14h16M4 18h16"}
                      ],
                      []
                    }
                  ]
                },
                "Table of Contents"
              ]
            },
            # Collapse/Expand button
            {
              "button",
              [
                {"type", "button"},
                {"class", "md:hidden text-gray-500 hover:text-gray-700 transition-colors"},
                {"onclick", "this.parentElement.nextElementSibling.classList.toggle('hidden')"},
                {"aria-label", "Toggle table of contents"}
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
                        {"d", "M19 9l-7 7-7-7"}
                      ],
                      []
                    }
                  ]
                }
              ]
            }
          ]
        },
        # TOC Content
        {
          "nav",
          [{"class", "toc-content hidden md:block"}],
          [
            {
              "ol",
              [
                {"class", "space-y-2 text-sm"},
                {"role", "list"}
              ],
              toc_items
            }
          ]
        }
      ]
    }
  end

  defp generate_toc_group([]), do: nil

  defp generate_toc_group([h2 | h3s]) do
    h2_item = generate_toc_item(h2, "font-medium text-gray-900 hover:text-blue-600")

    case h3s do
      [] ->
        h2_item

      subsections ->
        {
          "li",
          [{"class", "space-y-1"}],
          [
            h2_item,
            {
              "ol",
              [
                {"class", "mt-2 ml-4 space-y-1 border-l border-gray-200 pl-4"},
                {"role", "list"}
              ],
              Enum.map(
                subsections,
                &generate_toc_item(&1, "text-gray-600 hover:text-blue-600 text-sm")
              )
            }
          ]
        }
    end
  end

  defp generate_toc_item(heading, css_classes) do
    {
      "li",
      [{"role", "listitem"}],
      [
        {
          "a",
          [
            {"href", "##{heading.id}"},
            {"class", "#{css_classes} block py-1 transition-colors duration-150 hover:underline"},
            {"title", "Go to: #{heading.text}"}
          ],
          [heading.text]
        }
      ]
    }
  end

  defp insert_toc_into_ast(ast, toc_html) do
    case ast do
      # If there's a main content wrapper, insert TOC at the beginning
      [first_element | rest] when is_tuple(first_element) ->
        [toc_html, first_element | rest]

      # If it's a list of elements, prepend TOC
      elements when is_list(elements) ->
        [toc_html | elements]

      # If it's a single element, wrap both in a container
      single_element ->
        [
          {
            "div",
            [{"class", "markdown-content"}],
            [toc_html, single_element]
          }
        ]
    end
  end
end
