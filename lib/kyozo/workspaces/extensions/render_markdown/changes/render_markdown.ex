defmodule Kyozo.Workspaces.Extensions.RenderMarkdown.Changes.RenderMarkdown do
  @moduledoc """
  Writes a markdown text attribute to its corresponding html attribute using MDEx.
  
  This change automatically converts markdown content to HTML whenever the source
  attribute changes, with support for syntax highlighting, header IDs, table of
  contents, and task extraction.
  """

  require Logger
  use Ash.Resource.Change

  def change(changeset, opts, context) do
    source_attr = opts[:source]
    destination_attr = opts[:destination]
    extract_tasks? = opts[:extract_tasks?] || false

    Ash.Changeset.before_action(changeset, fn changeset ->
      if Ash.Changeset.changing_attribute?(changeset, source_attr) do
        source_content = Ash.Changeset.get_attribute(changeset, source_attr)
        
        # Get extension options from the resource
        resource = changeset.resource
        add_ids? = Kyozo.Workspaces.Extensions.RenderMarkdown.header_ids?(resource)
        add_table_of_contents? = Kyozo.Workspaces.Extensions.RenderMarkdown.table_of_contents?(resource)
        syntax_highlighting? = Kyozo.Workspaces.Extensions.RenderMarkdown.syntax_highlighting?(resource)
        allowed_languages = Kyozo.Workspaces.Extensions.RenderMarkdown.allowed_languages(resource)
        mdx_options = Kyozo.Workspaces.Extensions.RenderMarkdown.mdx_options(resource)

        # Process the markdown content
        render_opts = [
          add_ids?: add_ids?,
          add_table_of_contents?: add_table_of_contents?,
          syntax_highlighting?: syntax_highlighting?,
          extract_tasks?: extract_tasks?,
          allowed_languages: allowed_languages,
          mdx_options: mdx_options
        ]

        case Kyozo.Workspaces.Extensions.RenderMarkdown.as_html(source_content, render_opts) do
          {:ok, html_content, extracted_tasks} ->
            changeset = 
              changeset
              |> set_html_content(destination_attr, html_content)
              |> handle_extracted_tasks(extracted_tasks, context)
            
            # Store metadata about the rendering
            metadata = %{
              rendered_at: DateTime.utc_now(),
              task_count: length(extracted_tasks),
              has_table_of_contents: add_table_of_contents?,
              syntax_highlighting_enabled: syntax_highlighting?
            }
            
            store_render_metadata(changeset, metadata)

          {:error, reason} ->
            Logger.warning("""
            Error while rendering markdown to HTML: #{inspect(reason)}
            
            Source content: #{inspect(source_content)}
            
            Resource: #{inspect(changeset.resource)}
            Attribute: #{source_attr} -> #{destination_attr}
            """)

            # Set the destination to the original markdown as fallback
            fallback_content = process_fallback_content(source_content)
            set_html_content(changeset, destination_attr, fallback_content)
        end
      else
        changeset
      end
    end)
  end

  defp set_html_content(changeset, destination_attr, content) do
    # Get the destination attribute to check its type
    destination_attribute = Ash.Resource.Info.attribute(changeset.resource, destination_attr)

    formatted_content = 
      case destination_attribute.type do
        {:array, _} ->
          List.wrap(content)
        _ ->
          content
      end

    Ash.Changeset.force_change_attribute(changeset, destination_attr, formatted_content)
  end

  defp handle_extracted_tasks(changeset, [], _context), do: changeset

  defp handle_extracted_tasks(changeset, extracted_tasks, context) do
    # Store extracted tasks in changeset context for potential use by other changes
    Ash.Changeset.put_context(changeset, :extracted_tasks, extracted_tasks)
  end

  defp store_render_metadata(changeset, metadata) do
    # Check if the resource has a metadata attribute to store rendering info
    if Ash.Resource.Info.attribute(changeset.resource, :render_metadata) do
      existing_metadata = Ash.Changeset.get_attribute(changeset, :render_metadata) || %{}
      updated_metadata = Map.merge(existing_metadata, %{markdown_render: metadata})
      Ash.Changeset.change_attribute(changeset, :render_metadata, updated_metadata)
    else
      # Store in changeset context if no metadata attribute exists
      Ash.Changeset.put_context(changeset, :render_metadata, metadata)
    end
  end

  defp process_fallback_content(nil), do: nil
  defp process_fallback_content(""), do: ""

  defp process_fallback_content(content) when is_binary(content) do
    # Simple HTML escaping as fallback
    content
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
    |> then(&"<pre><code>#{&1}</code></pre>")
  end

  defp process_fallback_content(content) when is_list(content) do
    Enum.map(content, &process_fallback_content/1)
  end

  defp process_fallback_content(content), do: content
end