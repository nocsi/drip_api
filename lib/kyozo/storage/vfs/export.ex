defmodule Kyozo.Storage.VFS.Export do
  @moduledoc """
  Export virtual files to various formats
  """

  alias Kyozo.Storage.VFS

  @doc """
  Export a virtual file or directory of virtual files
  """
  def export(workspace_id, path, format, opts \\ []) do
    case format do
      :pdf -> export_to_pdf(workspace_id, path, opts)
      :html -> export_to_html(workspace_id, path, opts)
      :epub -> export_to_epub(workspace_id, path, opts)
      :json -> export_to_json(workspace_id, path, opts)
      _ -> {:error, :unsupported_format}
    end
  end

  @doc """
  Export all virtual files in a workspace as a documentation bundle
  """
  def export_workspace_docs(workspace_id, opts \\ []) do
    with {:ok, listing} <- VFS.list_files(workspace_id, "/", opts) do
      virtual_files =
        listing.files
        |> Enum.filter(& &1.virtual)
        |> Enum.map(&read_and_format(&1, workspace_id))
        |> Enum.reject(&is_nil/1)

      {:ok,
       %{
         workspace_id: workspace_id,
         generated_at: DateTime.utc_now(),
         files: virtual_files,
         format: Keyword.get(opts, :format, :markdown)
       }}
    end
  end

  defp export_to_html(workspace_id, path, _opts) do
    with {:ok, content} <- VFS.read_file(workspace_id, path) do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>#{Path.basename(path)}</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
            line-height: 1.6;
          }
          pre {
            background: #f6f8fa;
            padding: 1rem;
            border-radius: 6px;
            overflow-x: auto;
          }
          code {
            background: #f6f8fa;
            padding: 0.2em 0.4em;
            border-radius: 3px;
            font-family: 'Consolas', 'Monaco', monospace;
          }
        </style>
      </head>
      <body>
        #{markdown_to_html(content)}
      </body>
      </html>
      """

      {:ok, html}
    end
  end

  defp export_to_pdf(workspace_id, path, opts) do
    # Would use something like ChromicPDF or wkhtmltopdf
    with {:ok, html} <- export_to_html(workspace_id, path, opts) do
      # Placeholder - would convert HTML to PDF
      {:ok, "PDF content for #{path}"}
    end
  end

  defp export_to_epub(workspace_id, path, opts) do
    require Logger

    try do
      # Read the content to export
      case VFS.read_file(workspace_id, path) do
        {:ok, content} ->
          title = opts[:title] || Path.basename(path, ".md")
          author = opts[:author] || "Kyozo Export"

          # Generate EPUB structure
          epub_content = generate_epub_structure(content, title, author, opts)

          case create_epub_zip(epub_content) do
            {:ok, epub_data} ->
              Logger.info("Successfully exported EPUB",
                workspace_id: workspace_id,
                path: path,
                size: byte_size(epub_data))
              {:ok, epub_data}

            {:error, reason} ->
              Logger.error("Failed to create EPUB ZIP",
                workspace_id: workspace_id,
                path: path,
                reason: reason)
              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Failed to read file for EPUB export",
            workspace_id: workspace_id,
            path: path,
            reason: reason)
          {:error, reason}
      end
    rescue
      exception ->
        Logger.error("Exception during EPUB export",
          workspace_id: workspace_id,
          path: path,
          exception: Exception.message(exception))
        {:error, :export_failed}
    end
  end

  # Generate EPUB file structure with proper metadata and content
  defp generate_epub_structure(markdown_content, title, author, opts) do
    # Convert Markdown to HTML
    html_content = markdown_to_html(markdown_content, opts)

    # Generate unique identifier using Elixir's built-in UUID generation
    uuid = Ecto.UUID.generate()

    %{
      mimetype: "application/epub+zip",
      container_xml: generate_container_xml(),
      content_opf: generate_content_opf(title, author, uuid, opts),
      toc_ncx: generate_toc_ncx(title, uuid),
      chapter_html: html_content,
      stylesheet: generate_epub_css(opts)
    }
  end

  # Create ZIP file from EPUB structure
  defp create_epub_zip(epub_content) do
    try do
      # Create temporary directory for EPUB files
      temp_dir = System.tmp_dir!() |> Path.join("epub_#{System.unique_integer()}")
      File.mkdir_p!(temp_dir)

      # Write EPUB files
      File.write!(Path.join(temp_dir, "mimetype"), epub_content.mimetype)

      meta_dir = Path.join(temp_dir, "META-INF")
      File.mkdir_p!(meta_dir)
      File.write!(Path.join(meta_dir, "container.xml"), epub_content.container_xml)

      oebps_dir = Path.join(temp_dir, "OEBPS")
      File.mkdir_p!(oebps_dir)
      File.write!(Path.join(oebps_dir, "content.opf"), epub_content.content_opf)
      File.write!(Path.join(oebps_dir, "toc.ncx"), epub_content.toc_ncx)
      File.write!(Path.join(oebps_dir, "chapter1.html"), epub_content.chapter_html)
      File.write!(Path.join(oebps_dir, "stylesheet.css"), epub_content.stylesheet)

      # Create ZIP file (EPUB is a ZIP with specific structure)
      zip_path = temp_dir <> ".epub"

      # Use :zip module to create EPUB
      files_to_zip = [
        {'mimetype', String.to_charlist(epub_content.mimetype)},
        {'META-INF/container.xml', String.to_charlist(epub_content.container_xml)},
        {'OEBPS/content.opf', String.to_charlist(epub_content.content_opf)},
        {'OEBPS/toc.ncx', String.to_charlist(epub_content.toc_ncx)},
        {'OEBPS/chapter1.html', String.to_charlist(epub_content.chapter_html)},
        {'OEBPS/stylesheet.css', String.to_charlist(epub_content.stylesheet)}
      ]

      case :zip.create(String.to_charlist(zip_path), files_to_zip, [:memory]) do
        {:ok, {_filename, epub_binary}} ->
          # Cleanup temp directory
          File.rm_rf!(temp_dir)
          {:ok, epub_binary}

        {:error, reason} ->
          # Cleanup temp directory on error
          File.rm_rf!(temp_dir)
          {:error, reason}
      end
    rescue
      exception ->
        {:error, "ZIP creation failed: #{Exception.message(exception)}"}
    end
  end

  # Convert Markdown to HTML for EPUB
  defp markdown_to_html(markdown_content, _opts) do
    # Simple Markdown to HTML conversion for basic formatting
    html_content =
      markdown_content
      |> String.replace(~r/^# (.+)$/m, "<h1>\\1</h1>")
      |> String.replace(~r/^## (.+)$/m, "<h2>\\1</h2>")
      |> String.replace(~r/^### (.+)$/m, "<h3>\\1</h3>")
      |> String.replace(~r/\*\*(.+?)\*\*/m, "<strong>\\1</strong>")
      |> String.replace(~r/\*(.+?)\*/m, "<em>\\1</em>")
      |> String.replace(~r/```(.+?)```/s, "<pre><code>\\1</code></pre>")
      |> String.replace(~r/`([^`]+)`/m, "<code>\\1</code>")
      |> String.replace(~r/^\- (.+)$/m, "<li>\\1</li>")
      |> String.replace(~r/(<li>.*<\/li>)/s, "<ul>\\1</ul>")
      |> String.replace(~r/\n\n+/m, "</p><p>")
      |> then(&("<p>" <> &1 <> "</p>"))
      |> html_escape()

    """
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Chapter 1</title>
      <link rel="stylesheet" type="text/css" href="stylesheet.css"/>
    </head>
    <body>
    #{html_content}
    </body>
    </html>
    """
  end

  # Simple HTML escaping
  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  # Generate META-INF/container.xml
  defp generate_container_xml do
    """
    <?xml version="1.0"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
        </rootfiles>
    </container>
    """
  end

  # Generate OEBPS/content.opf
  defp generate_content_opf(title, author, uuid, opts) do
    language = Keyword.get(opts, :language, "en")
    escaped_title = html_escape(title)
    escaped_author = html_escape(author)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
            <dc:title>#{escaped_title}</dc:title>
            <dc:creator opf:role="aut">#{escaped_author}</dc:creator>
            <dc:language>#{language}</dc:language>
            <dc:identifier id="BookId" opf:scheme="UUID">#{uuid}</dc:identifier>
            <meta name="generator" content="Kyozo EPUB Exporter" />
        </metadata>
        <manifest>
            <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            <item id="chapter1" href="chapter1.html" media-type="application/xhtml+xml"/>
            <item id="stylesheet" href="stylesheet.css" media-type="text/css"/>
        </manifest>
        <spine toc="ncx">
            <itemref idref="chapter1"/>
        </spine>
    </package>
    """
  end

  # Generate OEBPS/toc.ncx
  defp generate_toc_ncx(title, uuid) do
    escaped_title = html_escape(title)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
        <head>
            <meta name="dtb:uid" content="#{uuid}"/>
            <meta name="dtb:depth" content="1"/>
            <meta name="dtb:totalPageCount" content="0"/>
            <meta name="dtb:maxPageNumber" content="0"/>
        </head>
        <docTitle>
            <text>#{escaped_title}</text>
        </docTitle>
        <navMap>
            <navPoint id="navpoint-1" playOrder="1">
                <navLabel>
                    <text>#{escaped_title}</text>
                </navLabel>
                <content src="chapter1.html"/>
            </navPoint>
        </navMap>
    </ncx>
    """
  end

  # Generate basic CSS for EPUB
  defp generate_epub_css(opts) do
    custom_css = Keyword.get(opts, :css, "")

    """
    body {
        font-family: serif;
        margin: 1em;
        line-height: 1.6;
    }

    h1, h2, h3, h4, h5, h6 {
        color: #333;
        margin-top: 1.5em;
        margin-bottom: 0.5em;
    }

    p {
        margin-bottom: 1em;
        text-align: justify;
    }

    pre, code {
        font-family: monospace;
        background-color: #f5f5f5;
        padding: 0.2em;
    }

    pre {
        padding: 1em;
        margin: 1em 0;
        overflow-x: auto;
    }

    blockquote {
        margin: 1em 2em;
        font-style: italic;
        border-left: 3px solid #ccc;
        padding-left: 1em;
    }

    #{custom_css}
    """
  end

  defp export_to_json(workspace_id, path, _opts) do
    with {:ok, content} <- VFS.read_file(workspace_id, path) do
      {:ok,
       %{
         path: path,
         content: content,
         type: "virtual",
         format: "markdown",
         exported_at: DateTime.utc_now()
       }}
    end
  end

  defp read_and_format(file, workspace_id) do
    case VFS.read_file(workspace_id, file.path) do
      {:ok, content} ->
        %{
          path: file.path,
          name: file.name,
          content: content,
          generator: file.generator
        }

      _ ->
        nil
    end
  end

  defp markdown_to_html(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _} -> html
      _ -> "<p>Error rendering markdown</p>"
    end
  end
end
