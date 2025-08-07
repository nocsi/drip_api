defmodule Kyozo.Workspaces.Extensions.RenderMarkdown.PostProcessor do
  @moduledoc """
  Takes HTML content and runs a set of post-processor transformations on it.
  
  This module handles:
  - Adding IDs to headers for linking
  - Generating table of contents
  - Syntax highlighting for code blocks
  - Processing code blocks for task extraction
  - Adding custom CSS classes and attributes
  """

  alias Kyozo.Workspaces.Extensions.RenderMarkdown.PostProcessors.{
    HeadingProcessor,
    TableOfContentsGenerator,
    CodeBlockProcessor,
    TaskExtractor
  }

  @doc """
  Runs all post-processing steps on HTML content.
  
  ## Parameters
  
  - `html` - The HTML content to process (string or list of strings)
  - `add_ids?` - Whether to add IDs to headers
  - `add_table_of_contents?` - Whether to generate table of contents
  - `syntax_highlighting?` - Whether to enable syntax highlighting
  - `allowed_languages` - List of allowed programming languages
  - `extract_tasks?` - Whether to extract tasks from code blocks
  
  ## Returns
  
  Processed HTML content as a string or list of strings
  """
  def run(html, add_ids? \\ true, add_table_of_contents? \\ false, syntax_highlighting? \\ true, allowed_languages \\ [], extract_tasks? \\ false)

  def run(html, add_ids?, add_table_of_contents?, syntax_highlighting?, allowed_languages, extract_tasks?) when is_list(html) do
    Enum.map(html, &run(&1, add_ids?, add_table_of_contents?, syntax_highlighting?, allowed_languages, extract_tasks?))
  end

  def run(nil, _, _, _, _, _), do: nil
  def run("", _, _, _, _, _), do: ""

  def run(html, add_ids?, add_table_of_contents?, syntax_highlighting?, allowed_languages, extract_tasks?) when is_binary(html) do
    try do
      html
      |> parse_html()
      |> HeadingProcessor.process(add_ids?)
      |> CodeBlockProcessor.process(syntax_highlighting?, allowed_languages)
      |> TaskExtractor.process(extract_tasks?)
      |> TableOfContentsGenerator.generate(add_table_of_contents?)
      |> add_custom_classes()
      |> render_html()
    rescue
      error ->
        require Logger
        Logger.warning("Error in post-processing HTML: #{inspect(error)}")
        html
    end
  end

  defp parse_html(html) do
    case Floki.parse_document(html) do
      {:ok, parsed} -> parsed
      {:error, _reason} ->
        # Fallback to fragment parsing if document parsing fails
        Floki.parse_fragment!(html)
    end
  end

  defp add_custom_classes(ast) do
    Floki.traverse_and_update(ast, fn
      # Add classes to tables for better styling
      {"table", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "table table-auto w-full border-collapse border border-gray-300")
        {"table", new_attrs, children}

      # Add classes to table headers
      {"th", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "border border-gray-300 px-4 py-2 bg-gray-50 font-semibold text-left")
        {"th", new_attrs, children}

      # Add classes to table cells
      {"td", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "border border-gray-300 px-4 py-2")
        {"td", new_attrs, children}

      # Add classes to blockquotes
      {"blockquote", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "border-l-4 border-blue-500 pl-4 italic text-gray-700 bg-gray-50 py-2 my-4")
        {"blockquote", new_attrs, children}

      # Add classes to code elements (inline code)
      {"code", attrs, children} ->
        # Only add classes if this is not inside a pre block
        case get_class(attrs) do
          class when is_binary(class) and class != "" ->
            # This is likely a syntax-highlighted code block, don't modify
            {"code", attrs, children}
          _ ->
            # This is inline code
            new_attrs = add_or_update_class(attrs, "bg-gray-100 text-red-600 px-1 py-0.5 rounded text-sm font-mono")
            {"code", new_attrs, children}
        end

      # Add classes to pre elements
      {"pre", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "bg-gray-50 border border-gray-200 rounded-lg p-4 overflow-x-auto my-4")
        {"pre", new_attrs, children}

      # Add classes to task lists
      {"ul", attrs, children} ->
        if has_task_list_items?(children) do
          new_attrs = add_or_update_class(attrs, "task-list list-none space-y-2")
          {"ul", new_attrs, children}
        else
          new_attrs = add_or_update_class(attrs, "list-disc pl-6 space-y-1")
          {"ul", new_attrs, children}
        end

      {"ol", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "list-decimal pl-6 space-y-1")
        {"ol", new_attrs, children}

      # Handle task list items
      {"li", attrs, children} ->
        if is_task_list_item?(children) do
          new_attrs = add_or_update_class(attrs, "task-list-item flex items-start space-x-2")
          {"li", new_attrs, children}
        else
          {"li", attrs, children}
        end

      # Add responsive classes to images
      {"img", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "max-w-full h-auto rounded-lg shadow-sm")
        {"img", new_attrs, children}

      # Add classes to horizontal rules
      {"hr", attrs, children} ->
        new_attrs = add_or_update_class(attrs, "border-t border-gray-300 my-8")
        {"hr", new_attrs, children}

      # Default case - don't modify
      element ->
        element
    end)
  end

  defp add_or_update_class(attrs, new_class) do
    case List.keyfind(attrs, "class", 0) do
      {"class", existing_class} ->
        combined_class = combine_classes(existing_class, new_class)
        List.keyreplace(attrs, "class", 0, {"class", combined_class})
      
      nil ->
        [{"class", new_class} | attrs]
    end
  end

  defp get_class(attrs) do
    case List.keyfind(attrs, "class", 0) do
      {"class", class} -> class
      nil -> nil
    end
  end

  defp combine_classes(existing, new) do
    existing_classes = String.split(existing, " ", trim: true)
    new_classes = String.split(new, " ", trim: true)
    
    (existing_classes ++ new_classes)
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  defp has_task_list_items?(children) do
    Enum.any?(children, fn
      {"li", _attrs, li_children} -> is_task_list_item?(li_children)
      _ -> false
    end)
  end

  defp is_task_list_item?(children) do
    case children do
      [{"input", attrs, _} | _] ->
        case List.keyfind(attrs, "type", 0) do
          {"type", "checkbox"} -> true
          _ -> false
        end
      
      _ -> false
    end
  end

  defp render_html(ast) do
    ast
    |> Floki.raw_html(pretty: true, encode: false)
  end
end