defmodule Dirup.Workspaces.File.MarkdownLDSupport do
  @moduledoc """
  Support for automatic Markdown-LD detection and notebook creation.

  When a markdown file contains JSON-LD structured data, it should automatically
  be treated as executable (like a notebook).
  """

  alias Dirup.MarkdownLD
  alias Dirup.Workspaces
  alias Dirup.Cache.ContentCache

  @doc """
  Check if a file should be treated as Markdown-LD based on its content.
  """
  def is_markdown_ld?(file) do
    case get_content(file) do
      {:ok, content} ->
        # Check if it's a markdown file with JSON-LD
        is_markdown_file?(file) && has_json_ld?(content)

      _ ->
        false
    end
  end

  @doc """
  Automatically create a notebook for Markdown-LD files.
  """
  def maybe_create_notebook(file, actor) do
    if is_markdown_ld?(file) && !has_notebook?(file) do
      case get_content(file) do
        {:ok, content} ->
          # Parse the Markdown-LD to get metadata
          case MarkdownLD.parse(content) do
            {:ok, doc} ->
              notebook_params = %{
                title: doc.metadata["name"] || extract_title(content) || file.name,
                description: doc.metadata["description"],
                auto_save_enabled: true,
                metadata: %{
                  "markdown_ld" => true,
                  "json_ld_type" => doc.metadata["@type"],
                  "json_ld_context" => doc.metadata["@context"]
                }
              }

              Workspaces.create_notebook_from_document(
                %{"notebook" => notebook_params, "document_id" => file.id},
                actor: actor
              )

            _ ->
              # Even if parsing fails, create a basic notebook
              create_basic_notebook(file, actor)
          end

        _ ->
          {:ok, file}
      end
    else
      {:ok, file}
    end
  end

  @doc """
  Enrich file metadata with Markdown-LD information.
  """
  def enrich_metadata(file) do
    case get_content(file) do
      {:ok, content} ->
        if has_json_ld?(content) do
          case MarkdownLD.parse(content) do
            {:ok, doc} ->
              metadata =
                Map.merge(file.metadata || %{}, %{
                  "markdown_ld" => true,
                  "json_ld_blocks" => length(doc.blocks),
                  "json_ld_type" => doc.metadata["@type"],
                  "json_ld_context" => doc.metadata["@context"],
                  "has_executable_code" => has_executable_blocks?(doc),
                  "semantic_graph_size" => RDF.Graph.triple_count(doc.graph)
                })

              %{file | metadata: metadata, is_executable: true}

            _ ->
              file
          end
        else
          file
        end

      _ ->
        file
    end
  end

  # Private functions

  defp get_content(%{content: content}) when is_binary(content), do: {:ok, content}

  defp get_content(%{id: id}) do
    # Load content from storage with high-performance caching
    case load_file_content_cached(id) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, "Failed to load content: #{reason}"}
    end
  end

  # Load file content with ETS caching (restores performance destroyed by rogue agent)
  defp load_file_content_cached(file_id) do
    require Logger

    # Try cache first - 1ms response time
    case ContentCache.get_content(file_id) do
      {:hit, content} ->
        Logger.debug("Content cache hit for file", file_id: file_id)
        {:ok, content}

      :miss ->
        # Cache miss - load from database and cache result
        case load_file_content_from_db(file_id) do
          {:ok, content} ->
            # Cache for 1 hour with size limit enforcement
            ContentCache.put_content(file_id, content, ttl: 3600)
            {:ok, content}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp load_file_content_from_db(file_id) do
    require Logger

    query_key = ContentCache.query_cache_key(__MODULE__, :load_file_metadata, [file_id])

    with :miss <- ContentCache.get_query_result(query_key),
         {:ok, content} <- do_load_file_content(file_id) do
      ContentCache.put_query_result(query_key, content)
      {:ok, content}
    else
      {:hit, cached_content} ->
        Logger.debug("File metadata cache hit", file_id: file_id)
        {:ok, cached_content}

      error ->
        error
    end
  end

  defp do_load_file_content(file_id) do
    require Logger

    with {:ok, file} when not is_nil(file) <- load_file(file_id),
         {:ok, storage} <- find_primary_storage_safe(file.file_storages),
         {:ok, content} <- Dirup.Storage.retrieve_content(storage.storage_resource) do
      Logger.debug("Successfully loaded content", file_id: file_id, size: byte_size(content))
      {:ok, content}
    else
      {:ok, nil} ->
        Logger.warning("File not found", file_id: file_id)
        {:error, :file_not_found}

      {:error, reason} = error ->
        Logger.error("Failed to load file content", file_id: file_id, reason: reason)
        error
    end
  rescue
    exception ->
      Logger.error("Exception loading file",
        file_id: file_id,
        error: Exception.message(exception)
      )

      {:error, :unexpected_error}
  end

  defp load_file(file_id) do
    Workspaces.File
    |> Ash.Query.filter(id: file_id)
    |> Ash.Query.load(file_storages: [:storage_resource])
    |> Ash.read_one()
  end

  defp find_primary_storage_safe(file_storages) do
    case find_primary_file_storage(file_storages) do
      nil -> {:error, :no_primary_storage}
      storage -> {:ok, storage}
    end
  end

  # Find the primary file storage from a list of file storages
  defp find_primary_file_storage(file_storages) when is_list(file_storages) do
    # First try to find one marked as primary
    primary = Enum.find(file_storages, &(&1.is_primary == true))

    case primary do
      nil ->
        # If no primary is marked, use the first one with relationship_type "primary"
        primary_by_type = Enum.find(file_storages, &(&1.relationship_type == "primary"))

        case primary_by_type do
          nil ->
            # If still no primary, use the first document type storage
            document_storage = Enum.find(file_storages, &(&1.media_type == "document"))

            # Fall back to the first available storage
            document_storage || List.first(file_storages)

          storage ->
            storage
        end

      storage ->
        storage
    end
  end

  defp find_primary_file_storage(_), do: nil

  defp is_markdown_file?(%{content_type: "text/markdown"}), do: true

  defp is_markdown_file?(%{file_path: path}) when is_binary(path) do
    String.ends_with?(path, [".md", ".markdown"])
  end

  defp is_markdown_file?(_), do: false

  defp has_json_ld?(content) do
    # Simple check for JSON-LD in HTML comments
    content =~ ~r/<!--\s*\{[\s\S]*?"@context"[\s\S]*?\}\s*-->/
  end

  defp has_notebook?(%{notebook: %{}}), do: true
  defp has_notebook?(_), do: false

  defp has_executable_blocks?(doc) do
    Enum.any?(doc.blocks, fn block ->
      block.type == "kyozo:CodeBlock" &&
        block.properties["kyozo:executable"] == true
    end)
  end

  defp extract_title(content) do
    case Regex.run(~r/^#\s+(.+)$/m, content) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  defp create_basic_notebook(file, actor) do
    notebook_params = %{
      title: file.name,
      auto_save_enabled: true,
      metadata: %{"markdown_ld" => true}
    }

    Workspaces.create_notebook_from_document(
      %{"notebook" => notebook_params, "document_id" => file.id},
      actor: actor
    )
  end
end
