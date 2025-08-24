defmodule Kyozo.Workspaces.File.MarkdownLDSupport do
  @moduledoc """
  Support for automatic Markdown-LD detection and notebook creation.

  When a markdown file contains JSON-LD structured data, it should automatically
  be treated as executable (like a notebook).
  """

  alias Kyozo.MarkdownLD
  alias Kyozo.Workspaces

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
    # Load content from storage through FileStorage relationship
    case load_file_content(id) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, "Failed to load content: #{reason}"}
    end
  end

  # Load file content through the storage system
  defp load_file_content(file_id) do
    require Logger

    try do
      # Get the file with its primary storage relationship loaded
      case Workspaces.File
           |> Ash.Query.filter(id == ^file_id)
           |> Ash.Query.load(file_storages: [:storage_resource])
           |> Ash.read_one() do
        {:ok, nil} ->
          {:error, :file_not_found}

        {:ok, file} ->
          # Find the primary storage resource
          primary_storage = find_primary_file_storage(file.file_storages)

          case primary_storage do
            nil ->
              Logger.warning("No primary storage found for file", file_id: file_id)
              {:error, :no_primary_storage}

            file_storage ->
              # Retrieve content from storage resource
              case Kyozo.Storage.retrieve_content(file_storage.storage_resource) do
                {:ok, content} ->
                  Logger.debug("Successfully loaded content for file",
                    file_id: file_id,
                    content_size: byte_size(content))
                  {:ok, content}

                {:error, reason} ->
                  Logger.error("Failed to retrieve content from storage",
                    file_id: file_id,
                    storage_resource_id: file_storage.storage_resource.id,
                    reason: reason)
                  {:error, reason}
              end
          end

        {:error, reason} ->
          Logger.error("Failed to load file from database", file_id: file_id, reason: reason)
          {:error, reason}
      end
    rescue
      exception ->
        Logger.error("Exception while loading file content",
          file_id: file_id,
          exception: Exception.message(exception))
        {:error, :unexpected_error}
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

          storage -> storage
        end

      storage -> storage
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
