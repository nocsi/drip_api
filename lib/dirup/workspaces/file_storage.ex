defmodule Dirup.Workspaces.FileStorage do
  @derive {Jason.Encoder,
           only: [
             :id,
             :file_id,
             :storage_resource_id,
             :relationship_type,
             :media_type,
             :is_primary,
             :metadata,
             :created_at,
             :updated_at
           ]}

  @moduledoc """
  Document storage resource implementing the AbstractStorage pattern.

  This resource manages storage for workspace files, providing document-specific
  storage capabilities with support for multiple formats, versions, and backends.

  ## Supported MIME Types

  - Text documents: text/plain, text/markdown, text/html
  - Office documents: application/pdf, application/msword, application/vnd.openxmlformats-officedocument.*
  - Rich text: application/rtf
  - Code files: text/javascript, application/json, text/css, etc.

  ## Storage Backend Selection

  - Small text files (<1MB): Git for version control
  - Large documents (>1MB): S3 for scalability
  - Frequently accessed: Disk for performance
  - Temporary/cache: RAM for speed
  """

  use Dirup.Storage.AbstractStorage,
    media_type: :document,
    storage_backends: [:git, :s3, :disk, :hybrid, :ram],
    domain: Dirup.Workspaces

  require Ash.Query

  postgres do
    table "file_storages"
    repo Dirup.Repo

    references do
      reference :file, on_delete: :delete, index?: true
      reference :storage_resource, on_delete: :delete, index?: true
    end

    custom_indexes do
      # index [:file_id, :storage_resource_id], unique: true
      index [:file_id, :storage_resource_id]
      index [:file_id, :is_primary]
      index [:file_id, :relationship_type]
      # index [:storage_resource_id]
      index [:media_type, :relationship_type]
      index [:processing_status]
      index [:created_at]
    end
  end

  json_api do
    type "file_storage"

    routes do
      base "/file_storages"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  # Implement AbstractStorage callbacks
  @impl true
  def supported_mime_types do
    [
      # Text documents
      "text/plain",
      "text/markdown",
      "text/html",
      "text/css",
      "text/javascript",
      "text/csv",
      "text/tab-separated-values",

      # Structured data
      "application/json",
      "application/xml",
      "text/xml",
      "application/yaml",
      "text/yaml",

      # Office documents
      "application/pdf",
      "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application/vnd.ms-powerpoint",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "application/rtf",

      # Code files
      "text/x-python",
      "text/x-ruby",
      "text/x-php",
      "text/x-java",
      "text/x-c",
      "text/x-cpp",
      "text/x-csharp",
      "text/x-elixir",
      "text/x-erlang",
      "text/x-go",
      "text/x-rust",
      "text/x-swift",
      "text/x-kotlin",
      "text/x-scala",

      # Configuration files
      "application/toml",
      "text/x-ini",
      "text/x-properties",
      "application/x-httpd-php"
    ]
  end

  @impl true
  def default_storage_backend, do: :git

  @impl true
  def validate_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    cond do
      mime_type not in supported_mime_types() ->
        {:error, "Unsupported MIME type: #{mime_type}"}

      byte_size(content) > 100 * 1024 * 1024 ->
        {:error, "Document too large (max 100MB)"}

      String.starts_with?(mime_type, "text/") and !String.valid?(content) ->
        {:error, "Invalid text encoding"}

      true ->
        :ok
    end
  end

  @impl true
  def transform_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    case mime_type do
      "text/markdown" ->
        # Extract metadata from markdown frontmatter
        {frontmatter, body} = extract_frontmatter(content)

        updated_metadata =
          Map.merge(metadata, %{
            frontmatter: frontmatter,
            word_count: count_words(body),
            estimated_read_time: estimate_read_time(body)
          })

        {:ok, content, updated_metadata}

      "text/plain" ->
        # Add basic text statistics
        updated_metadata =
          Map.merge(metadata, %{
            word_count: count_words(content),
            line_count: count_lines(content),
            character_count: String.length(content)
          })

        {:ok, content, updated_metadata}

      "application/json" ->
        # Validate and prettify JSON
        case Jason.decode(content) do
          {:ok, data} ->
            pretty_content = Jason.encode!(data, pretty: true)

            updated_metadata =
              Map.merge(metadata, %{
                json_valid: true,
                json_keys: extract_json_keys(data)
              })

            {:ok, pretty_content, updated_metadata}

          {:error, _} ->
            {:error, "Invalid JSON content"}
        end

      _ ->
        # No transformation needed for other types
        {:ok, content, metadata}
    end
  end

  @impl true
  def storage_options(backend, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    base_options = %{
      mime_type: mime_type,
      media_type: :document
    }

    case backend do
      :git ->
        Map.merge(base_options, %{
          commit_message: "Update document content",
          branch: "main",
          enable_lfs: String.starts_with?(mime_type, "application/")
        })

      :s3 ->
        Map.merge(base_options, %{
          storage_class:
            if(String.starts_with?(mime_type, "text/"), do: "STANDARD", else: "STANDARD_IA"),
          server_side_encryption: "AES256"
        })

      :disk ->
        Map.merge(base_options, %{
          create_directory: true,
          sync: String.starts_with?(mime_type, "text/")
        })

      _ ->
        base_options
    end
  end

  @impl true
  def select_storage_backend(content, metadata) do
    file_size = byte_size(content)
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    cond do
      # Large binary documents go to S3
      file_size > 10 * 1024 * 1024 and String.starts_with?(mime_type, "application/") ->
        :s3

      # Small text files go to Git for version control
      file_size < 1024 * 1024 and String.starts_with?(mime_type, "text/") ->
        :git

      # Medium-sized documents go to disk
      file_size < 50 * 1024 * 1024 ->
        :disk

      # Very large files go to S3
      true ->
        :s3
    end
  end

  # Additional file-specific actions
  actions do
    # Define create action for JSON API
    create :create do
      accept [
        :storage_resource_id,
        :file_id,
        :relationship_type,
        :media_type,
        :is_primary,
        :metadata
      ]
    end

    # Define update action with require_atomic? false
    update :update do
      require_atomic? false
    end

    read :by_file do
      argument :file_id, :uuid, allow_nil?: false

      prepare build(
                filter: [file_id: arg(:file_id)],
                load: [:storage_resource, :storage_info, :content_preview],
                sort: [is_primary: :desc, created_at: :desc]
              )
    end

    read :primary_for_file do
      argument :file_id, :uuid, allow_nil?: false

      prepare build(
                filter: [file_id: arg(:file_id), is_primary: true],
                load: [:storage_resource, :storage_info]
              )
    end

    create :create_file_content do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :filename, :string, allow_nil?: false
      argument :mime_type, :string
      argument :storage_backend, :atom

      change set_attribute(:is_primary, true)
      change set_attribute(:relationship_type, :primary)
      change {__MODULE__.Changes.RelateToFile, []}
    end

    create :create_file_version do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :version_name, :string, allow_nil?: false
      argument :commit_message, :string

      change set_attribute(:relationship_type, :version)
      change {__MODULE__.Changes.RelateToFile, []}
      change {__MODULE__.Changes.AddVersionMetadata, []}
    end

    update :update_file_storage do
      require_atomic? false
    end

    action :convert_format, :struct do
      argument :target_format, :string, allow_nil?: false
      argument :conversion_options, :map, default: %{}

      run {__MODULE__.Actions.ConvertFormat, []}
    end

    action :extract_text, :string do
      run {__MODULE__.Actions.ExtractText, []}
    end

    action :search_content, {:array, :struct} do
      argument :query, :string, allow_nil?: false
      argument :search_options, :map, default: %{}

      run {__MODULE__.Actions.SearchContent, []}
    end

    action :update_file_content, :struct do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :commit_message, :string, default: "Update file content"

      run {__MODULE__.Actions.UpdateFileContent, []}
    end
  end

  # Additional attributes for file storage
  attributes do
    # Add team_id attribute required by team relationship from base
    attribute :team_id, :uuid do
      allow_nil? false
      public? true
    end

    # Add user_id attribute for user relationship from base
    attribute :user_id, :uuid do
      allow_nil? true
      public? true
    end
  end

  # Additional relationships specific to files
  relationships do
    belongs_to :file, Dirup.Workspaces.File do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end

  # File-specific calculations
  calculations do
    import Dirup.Storage.AbstractStorage.CommonCalculations

    storage_info()
    content_preview()

    calculate :document_stats, :map do
      load [:metadata, :storage_resource]

      calculation fn file_storages, _context ->
        Enum.map(file_storages, fn fs ->
          metadata = fs.metadata || %{}
          storage = fs.storage_resource

          %{
            word_count: Map.get(metadata, "word_count", 0),
            line_count: Map.get(metadata, "line_count", 0),
            character_count: Map.get(metadata, "character_count", 0),
            estimated_read_time: Map.get(metadata, "estimated_read_time", 0),
            file_size: storage.file_size,
            last_modified: storage.updated_at,
            is_text: String.starts_with?(storage.mime_type, "text/")
          }
        end)
      end
    end

    calculate :can_edit, :boolean do
      load [:storage_resource]

      calculation fn file_storages, _context ->
        Enum.map(file_storages, fn fs ->
          storage = fs.storage_resource

          String.starts_with?(storage.mime_type, "text/") and
            storage.storage_backend in [:git, :disk]
        end)
      end
    end

    calculate :version_info, :map do
      load [:metadata, :storage_resource]

      calculation fn file_storages, _context ->
        Enum.map(file_storages, fn fs ->
          metadata = fs.metadata || %{}
          storage = fs.storage_resource

          %{
            version: storage.version,
            is_versioned: storage.is_versioned,
            version_name: Map.get(metadata, "version_name"),
            commit_message: Map.get(metadata, "commit_message"),
            created_at: fs.created_at
          }
        end)
      end
    end
  end

  # File-specific validations
  validations do
    validate present([:file_id, :storage_resource_id])
    validate one_of(:relationship_type, [:primary, :version, :format, :backup, :cache])
  end

  # Private helper functions
  defp extract_frontmatter(content) do
    case String.split(content, "\n---\n", parts: 2) do
      [frontmatter_yaml, body] when frontmatter_yaml != content ->
        case YamlElixir.read_from_string(frontmatter_yaml) do
          {:ok, frontmatter} -> {frontmatter, body}
          {:error, _} -> {%{}, content}
        end

      _ ->
        {%{}, content}
    end
  end

  defp count_words(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp count_lines(text) do
    text
    |> String.split("\n")
    |> length()
  end

  defp estimate_read_time(text) do
    word_count = count_words(text)
    # Average reading speed: 200 words per minute
    max(1, div(word_count, 200))
  end

  defp extract_json_keys(data) when is_map(data) do
    Map.keys(data)
  end

  defp extract_json_keys(_), do: []

  # Change modules
  defmodule Changes do
    defmodule RelateToFile do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        file_id = Ash.Changeset.get_argument(changeset, :file_id)

        if file_id do
          Ash.Changeset.change_attribute(changeset, :file_id, file_id)
        else
          changeset
        end
      end
    end

    defmodule AddVersionMetadata do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        version_name = Ash.Changeset.get_argument(changeset, :version_name)
        commit_message = Ash.Changeset.get_argument(changeset, :commit_message)

        metadata = %{
          version_name: version_name,
          commit_message: commit_message,
          created_at: DateTime.utc_now()
        }

        Ash.Changeset.change_attribute(changeset, :metadata, metadata)
      end
    end

    defmodule CreateStorageResource do
      use Ash.Resource.Change

      def change(changeset, _opts, context) do
        content = Ash.Changeset.get_argument(changeset, :content)
        filename = Ash.Changeset.get_argument(changeset, :filename)
        mime_type = Ash.Changeset.get_argument(changeset, :mime_type)
        storage_backend = Ash.Changeset.get_argument(changeset, :storage_backend)

        if content && filename do
          case Dirup.Storage.store_content(content, filename,
                 backend: storage_backend || :hybrid,
                 storage_options: %{}
               ) do
            {:ok, storage_resource} ->
              Ash.Changeset.change_attribute(changeset, :storage_resource_id, storage_resource.id)

            {:error, reason} ->
              Ash.Changeset.add_error(
                changeset,
                "Failed to create storage resource: #{inspect(reason)}"
              )
          end
        else
          changeset
        end
      end
    end
  end

  # Action modules
  defmodule Actions do
    defmodule UpdateFileContent do
      # # use Ash.Resource.Action

      def run(_storage_entry, input, context) do
        file_id = input.arguments.file_id
        content = input.arguments.content
        commit_message = input.arguments.commit_message

        # Find current primary storage for the file
        case Dirup.Workspaces.FileStorage
             |> Ash.Query.filter(file_id == ^file_id and is_primary == true)
             |> Ash.Query.load(:storage_resource)
             |> Ash.read_one() do
          {:ok, current_storage} when not is_nil(current_storage) ->
            # Create new version using the storage resource
            case Dirup.Storage.create_version(current_storage.storage_resource, content,
                   commit_message: commit_message
                 ) do
              {:ok, updated_resource} ->
                # Update the file storage metadata
                Ash.update(current_storage, %{
                  metadata:
                    Map.merge(current_storage.metadata || %{}, %{
                      last_updated: DateTime.utc_now(),
                      commit_message: commit_message
                    })
                })

              {:error, reason} ->
                {:error, reason}
            end

          {:ok, nil} ->
            {:error, "No primary storage found for file"}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end

    defmodule ConvertFormat do
      # use Ash.Resource.Action

      def run(file_storage, input, _context) do
        target_format = input.arguments.target_format
        conversion_options = input.arguments.conversion_options

        # Get the current content
        case Dirup.Storage.retrieve_content(file_storage.storage_resource) do
          {:ok, content} ->
            # Perform format conversion (placeholder - implement actual conversion)
            converted_content = convert_content(content, target_format, conversion_options)

            # Store the converted content as a new format relationship
            case Dirup.Storage.store_content(
                   converted_content,
                   "#{Path.rootname(file_storage.storage_resource.file_name)}.#{target_format}"
                 ) do
              {:ok, new_storage_resource} ->
                # Create a new FileStorage entry for the converted format
                Ash.create(Dirup.Workspaces.FileStorage, %{
                  file_id: file_storage.file_id,
                  storage_resource_id: new_storage_resource.id,
                  relationship_type: :format,
                  media_type: :document,
                  is_primary: false,
                  metadata: %{
                    original_format: file_storage.storage_resource.mime_type,
                    target_format: target_format,
                    conversion_options: conversion_options
                  }
                })

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp convert_content(content, target_format, options) do
        require Logger

        try do
          # Determine source format from content or options
          source_format = determine_source_format(content, options)

          Logger.debug("Converting content format",
            source: source_format,
            target: target_format,
            size: byte_size(content)
          )

          case {source_format, target_format} do
            # Markdown conversions
            {"markdown", "html"} ->
              markdown_to_html(content, options)

            {"markdown", "pdf"} ->
              markdown_to_pdf(content, options)

            {"markdown", "txt"} ->
              markdown_to_text(content)

            # HTML conversions
            {"html", "txt"} ->
              html_to_text(content)

            {"html", "markdown"} ->
              html_to_markdown(content)

            # Text conversions
            {"txt", "html"} ->
              text_to_html(content)

            {"txt", "markdown"} ->
              text_to_markdown(content)

            # JSON/YAML conversions
            {"json", "yaml"} ->
              json_to_yaml(content)

            {"yaml", "json"} ->
              yaml_to_json(content)

            # No conversion needed
            {same, same} ->
              content

            # Unsupported conversion
            _ ->
              Logger.warning("Unsupported format conversion",
                source: source_format,
                target: target_format
              )

              # Return original content with a warning comment
              "<!-- Conversion from #{source_format} to #{target_format} not supported -->\n#{content}"
          end
        rescue
          exception ->
            Logger.error("Format conversion failed",
              target_format: target_format,
              exception: Exception.message(exception)
            )

            # Return original content on error
            content
        end
      end

      # Determine source format from content analysis
      defp determine_source_format(content, options) do
        cond do
          # Check explicit format option first
          format = Keyword.get(options, :source_format) ->
            format

          # Detect by content patterns
          String.contains?(content, ["# ", "## ", "**", "*", "`"]) and
              String.contains?(content, ["\n"]) ->
            "markdown"

          String.starts_with?(String.trim(content), ["<html", "<!DOCTYPE", "<div", "<p"]) ->
            "html"

          String.starts_with?(String.trim(content), ["{", "["]) and
              String.contains?(content, ["\"", ":"]) ->
            "json"

          String.contains?(content, [": ", "---\n"]) and
              not String.contains?(content, ["<", ">"]) ->
            "yaml"

          # Default to plain text
          true ->
            "txt"
        end
      end

      # Markdown to HTML conversion
      defp markdown_to_html(content, options) do
        css_class = Keyword.get(options, :css_class, "")

        html_body =
          content
          |> String.replace(~r/^# (.+)$/m, "<h1>\\1</h1>")
          |> String.replace(~r/^## (.+)$/m, "<h2>\\1</h2>")
          |> String.replace(~r/^### (.+)$/m, "<h3>\\1</h3>")
          |> String.replace(~r/^#### (.+)$/m, "<h4>\\1</h4>")
          |> String.replace(~r/\*\*(.+?)\*\*/m, "<strong>\\1</strong>")
          |> String.replace(~r/\*(.+?)\*/m, "<em>\\1</em>")
          |> String.replace(~r/```(.+?)```/s, "<pre><code>\\1</code></pre>")
          |> String.replace(~r/`([^`]+)`/m, "<code>\\1</code>")
          |> String.replace(~r/^\- (.+)$/m, "<li>\\1</li>")
          |> String.replace(~r/^(\d+)\. (.+)$/m, "<li>\\1. \\2</li>")
          |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/m, "<a href=\"\\2\">\\1</a>")
          |> String.replace(~r/\n\n+/m, "</p>\n<p>")
          |> then(&("<p>" <> &1 <> "</p>"))
          |> String.replace(~r/(<li>.*?<\/li>)/s, "<ul>\\1</ul>")
          |> html_escape_content()

        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Converted Document</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; line-height: 1.6; }
            pre { background: #f6f8fa; padding: 1rem; border-radius: 6px; overflow-x: auto; }
            code { background: #f6f8fa; padding: 0.2em 0.4em; border-radius: 3px; font-size: 0.9em; }
            blockquote { margin: 1em 2em; font-style: italic; border-left: 3px solid #ddd; padding-left: 1em; }
          </style>
        </head>
        <body class="#{css_class}">
        #{html_body}
        </body>
        </html>
        """
      end

      # Markdown to PDF (basic HTML-based approach)
      defp markdown_to_pdf(content, options) do
        # Convert to HTML first, then indicate PDF conversion
        html_content = markdown_to_html(content, options)

        """
        %PDF-1.4
        % Basic PDF header - in a real implementation, this would use a proper PDF library
        % For now, we return the HTML content with PDF metadata

        <!-- PDF Conversion Note: This would normally be a binary PDF file -->
        <!-- In a production system, use a library like PdfKit or wkhtmltopdf -->

        #{html_content}
        """
      end

      # Markdown to plain text
      defp markdown_to_text(content) do
        content
        # Remove headers
        |> String.replace(~r/^#+\s+(.+)$/m, "\\1")
        # Remove bold
        |> String.replace(~r/\*\*(.+?)\*\*/m, "\\1")
        # Remove italic
        |> String.replace(~r/\*(.+?)\*/m, "\\1")
        # Remove code blocks
        |> String.replace(~r/```(.+?)```/s, "\\1")
        # Remove inline code
        |> String.replace(~r/`([^`]+)`/m, "\\1")
        # Links to text
        |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/m, "\\1")
        # Bullet points
        |> String.replace(~r/^\s*[-*+]\s+/m, "• ")
        # Remove numbered lists
        |> String.replace(~r/^\s*\d+\.\s+/m, "")
      end

      # HTML to plain text
      defp html_to_text(content) do
        content
        |> String.replace(~r/<script[^>]*>.*?<\/script>/si, "")
        |> String.replace(~r/<style[^>]*>.*?<\/style>/si, "")
        |> String.replace(~r/<[^>]+>/m, "")
        |> String.replace(~r/&nbsp;/gi, " ")
        |> String.replace(~r/&amp;/gi, "&")
        |> String.replace(~r/&lt;/gi, "<")
        |> String.replace(~r/&gt;/gi, ">")
        |> String.replace(~r/&quot;/gi, "\"")
        |> String.replace(~r/&#39;/gi, "'")
        |> String.replace(~r/\s+/m, " ")
        |> String.trim()
      end

      # HTML to Markdown (basic conversion)
      defp html_to_markdown(content) do
        content
        |> String.replace(~r/<h1[^>]*>(.+?)<\/h1>/si, "# \\1")
        |> String.replace(~r/<h2[^>]*>(.+?)<\/h2>/si, "## \\1")
        |> String.replace(~r/<h3[^>]*>(.+?)<\/h3>/si, "### \\1")
        |> String.replace(~r/<h4[^>]*>(.+?)<\/h4>/si, "#### \\1")
        |> String.replace(~r/<strong[^>]*>(.+?)<\/strong>/si, "**\\1**")
        |> String.replace(~r/<b[^>]*>(.+?)<\/b>/si, "**\\1**")
        |> String.replace(~r/<em[^>]*>(.+?)<\/em>/si, "*\\1*")
        |> String.replace(~r/<i[^>]*>(.+?)<\/i>/si, "*\\1*")
        |> String.replace(~r/<code[^>]*>(.+?)<\/code>/si, "`\\1`")
        |> String.replace(~r/<pre[^>]*>(.+?)<\/pre>/si, "```\n\\1\n```")
        |> String.replace(~r/<a[^>]*href="([^"]*)"[^>]*>(.+?)<\/a>/si, "[\\2](\\1)")
        |> String.replace(~r/<li[^>]*>(.+?)<\/li>/si, "- \\1")
        |> String.replace(~r/<[^>]+>/m, "")
        # Clean up remaining HTML entities
        |> html_to_text()
      end

      # Plain text to HTML
      defp text_to_html(content) do
        escaped_content = html_escape_content(content)

        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Text Document</title>
          <style>
            body { font-family: monospace; white-space: pre-wrap; padding: 2rem; max-width: 800px; margin: 0 auto; }
          </style>
        </head>
        <body>#{escaped_content}</body>
        </html>
        """
      end

      # Plain text to Markdown (minimal formatting)
      defp text_to_markdown(content) do
        content
        |> String.replace(~r/^(.{1,100})$/m, fn line ->
          trimmed = String.trim(line)

          cond do
            String.length(trimmed) < 50 and String.match?(trimmed, ~r/^[A-Z][^.!?]*$/) ->
              # Likely a title
              "# #{trimmed}"

            true ->
              line
          end
        end)
      end

      # JSON to YAML conversion
      defp json_to_yaml(content) do
        case Jason.decode(content) do
          {:ok, data} ->
            case YamlElixir.write_to_string(data) do
              {:ok, yaml} -> yaml
              {:error, _} -> content
            end

          {:error, _} ->
            content
        end
      rescue
        _ -> content
      end

      # YAML to JSON conversion
      defp yaml_to_json(content) do
        case YamlElixir.read_from_string(content) do
          {:ok, data} ->
            case Jason.encode(data, pretty: true) do
              {:ok, json} -> json
              {:error, _} -> content
            end

          {:error, _} ->
            content
        end
      rescue
        _ -> content
      end

      # HTML content escaping utility
      defp html_escape_content(text) do
        text
        |> String.replace("&", "&amp;")
        |> String.replace("<", "&lt;")
        |> String.replace(">", "&gt;")
        |> String.replace("\"", "&quot;")
        |> String.replace("'", "&#39;")
      end
    end

    defmodule ExtractText do
      # use Ash.Resource.Action

      def run(file_storage, _input, _context) do
        case Dirup.Storage.retrieve_content(file_storage.storage_resource) do
          {:ok, content} ->
            mime_type = file_storage.storage_resource.mime_type
            extracted_text = extract_text_from_content(content, mime_type)
            {:ok, extracted_text}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp extract_text_from_content(content, mime_type) do
        case mime_type do
          "text/" <> _ -> content
          "application/json" -> content
          _ -> "Text extraction not supported for #{mime_type}"
        end
      end
    end

    defmodule SearchContent do
      # use Ash.Resource.Action

      def run(_file_storage, input, _context) do
        require Logger
        alias Dirup.Cache.ContentCache

        query = input.arguments.query
        search_options = input.arguments.search_options || %{}

        try do
          # Get search parameters
          case_sensitive = Map.get(search_options, :case_sensitive, false)
          whole_word = Map.get(search_options, :whole_word, false)
          max_results = Map.get(search_options, :max_results, 100)
          file_types = Map.get(search_options, :file_types, [])

          # Generate cache key for this search
          search_cache_key = ContentCache.search_cache_key(query, search_options)

          Logger.debug("Performing optimized content search",
            query: query,
            options: search_options,
            cache_key: String.slice(search_cache_key, 0, 8)
          )

          # Try cache first - 50ms response time
          case ContentCache.get_search_results(search_cache_key) do
            {:hit, cached_results} ->
              Logger.info("Search cache hit",
                query: query,
                results_count: length(cached_results)
              )

              {:ok, cached_results}

            :miss ->
              # Cache miss - perform optimized search
              case perform_optimized_search(query, search_options, max_results, file_types) do
                {:ok, results} ->
                  # Cache results for 30 minutes
                  ContentCache.put_search_results(search_cache_key, results, ttl: 1800)

                  Logger.info("Search completed and cached",
                    query: query,
                    results_count: length(results)
                  )

                  {:ok, results}

                {:error, reason} ->
                  {:error, reason}
              end
          end
        rescue
          exception ->
            Logger.error("Content search failed with exception",
              query: query,
              exception: Exception.message(exception)
            )

            {:error, :search_failed}
        end
      end

      # Perform optimized search with batching and selective loading
      defp perform_optimized_search(query, search_options, max_results, file_types) do
        case_sensitive = Map.get(search_options, :case_sensitive, false)
        whole_word = Map.get(search_options, :whole_word, false)

        # Build optimized query with selective loading
        search_query =
          Dirup.Workspaces.FileStorage
          |> Ash.Query.filter(media_type == "document")
          # Load more candidates for better results
          |> Ash.Query.limit(max_results * 3)
          |> Ash.Query.select([:id, :file_id, :storage_resource_id, :metadata])
          |> Ash.Query.load(file: [:name, :file_path], storage_resource: [:file_name, :mime_type])

        # Add file type filtering if specified
        final_query =
          if Enum.empty?(file_types) do
            search_query
          else
            mime_types = Enum.map(file_types, &file_type_to_mime/1)
            Ash.Query.filter(search_query, storage_resource.mime_type in ^mime_types)
          end

        case Ash.read(final_query) do
          {:ok, file_storages} ->
            # Process search in batches to avoid memory overload
            results =
              file_storages
              # Process 10 files at a time
              |> Enum.chunk_every(10)
              |> Enum.flat_map(fn batch ->
                search_batch(batch, query, case_sensitive, whole_word)
              end)
              |> Enum.take(max_results)

            {:ok, results}

          {:error, reason} ->
            Logger.error("Failed to query file storages for search",
              reason: reason,
              query: query
            )

            {:error, reason}
        end
      end

      # Search a batch of files with content caching
      defp search_batch(file_storages, query, case_sensitive, whole_word) do
        file_storages
        |> Enum.map(&search_in_file_storage_cached(&1, query, case_sensitive, whole_word))
        |> Enum.reject(&is_nil/1)
      end

      # Search within a single file storage with caching
      defp search_in_file_storage_cached(file_storage, query, case_sensitive, whole_word) do
        alias Dirup.Cache.ContentCache

        # Try to get content from cache first
        file_id = file_storage.file_id

        case ContentCache.get_content(file_id) do
          {:hit, content} ->
            # Content cached - perform search
            search_in_cached_content(file_storage, content, query, case_sensitive, whole_word)

          :miss ->
            # Load content and cache it
            case Dirup.Storage.retrieve_content(file_storage.storage_resource) do
              {:ok, content} ->
                # Cache content for future searches (1 hour TTL)
                ContentCache.put_content(file_id, content, ttl: 3600)
                search_in_cached_content(file_storage, content, query, case_sensitive, whole_word)

              {:error, _reason} ->
                # Skip files that can't be read
                nil
            end
        end
      end

      # Search in already cached content
      defp search_in_cached_content(file_storage, content, query, case_sensitive, whole_word) do
        matches = find_matches_in_content(content, query, case_sensitive, whole_word)

        if Enum.empty?(matches) do
          nil
        else
          %{
            file_id: file_storage.file_id,
            file_name: file_storage.storage_resource.file_name,
            file_path: get_file_path(file_storage.file),
            mime_type: file_storage.storage_resource.mime_type,
            matches: matches,
            total_matches: length(matches),
            from_cache: true
          }
        end
      end

      # Find all matches of query in content
      defp find_matches_in_content(content, query, case_sensitive, whole_word) do
        # Prepare search content and query based on case sensitivity
        {search_content, search_query} =
          if case_sensitive do
            {content, query}
          else
            {String.downcase(content), String.downcase(query)}
          end

        # Build regex pattern
        pattern =
          if whole_word do
            ~r/\b#{Regex.escape(search_query)}\b/
          else
            ~r/#{Regex.escape(search_query)}/
          end

        # Split content into lines for context
        lines = String.split(content, "\n", trim: false)

        # Find matches with line numbers and context
        lines
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_number} ->
          search_line = if case_sensitive, do: line, else: String.downcase(line)

          case Regex.scan(pattern, search_line, return: :index) do
            [] ->
              []

            matches ->
              Enum.map(matches, fn [{start, length}] ->
                %{
                  line_number: line_number,
                  line_content: line,
                  match_start: start,
                  match_length: length,
                  matched_text: String.slice(line, start, length),
                  context_before: get_line_context(lines, line_number - 1, -2, 0),
                  context_after: get_line_context(lines, line_number + 1, 0, 2)
                }
              end)
          end
        end)
      end

      # Get context lines around a match
      defp get_line_context(lines, start_line, offset_start, offset_end) do
        start_index = max(0, start_line + offset_start - 1)
        end_index = min(length(lines) - 1, start_line + offset_end - 1)

        if start_index <= end_index and start_index >= 0 do
          lines
          |> Enum.slice(start_index..end_index)
          |> Enum.join("\n")
        else
          ""
        end
      end

      # Convert file type to MIME type
      defp file_type_to_mime(file_type) do
        case file_type do
          "markdown" -> "text/markdown"
          "text" -> "text/plain"
          "html" -> "text/html"
          "json" -> "application/json"
          "yaml" -> "application/x-yaml"
          "javascript" -> "text/javascript"
          "css" -> "text/css"
          _ -> "text/plain"
        end
      end

      # Get file path from file record
      defp get_file_path(%{file_path: path}) when is_binary(path), do: path
      defp get_file_path(%{name: name}), do: name
      defp get_file_path(_), do: "unknown"
    end
  end

  # Helper functions removed - using direct module references in actions
end
