defmodule Kyozo.Workspaces.File.Changes.DetectMarkdownLD do
  @moduledoc """
  Detects if a file is Markdown-LD and sets appropriate metadata.
  """
  use Ash.Resource.Change

  alias Kyozo.Workspaces.File.MarkdownLDSupport

  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.after_action(fn changeset, file ->
      if should_check?(file, changeset) do
        enriched_file = MarkdownLDSupport.enrich_metadata(file)

        # If it's Markdown-LD, mark it as executable
        if enriched_file.metadata["markdown_ld"] do
          {:ok, %{enriched_file | is_executable: true}}
        else
          {:ok, file}
        end
      else
        {:ok, file}
      end
    end)
  end

  defp should_check?(file, changeset) do
    # Check if it's a markdown file and content has changed
    is_markdown?(file) &&
      (Ash.Changeset.changing_attribute?(changeset, :content) ||
         Ash.Changeset.get_change(changeset, :action) == :create)
  end

  defp is_markdown?(%{content_type: "text/markdown"}), do: true

  defp is_markdown?(%{file_path: path}) when is_binary(path) do
    String.ends_with?(path, [".md", ".markdown"])
  end

  defp is_markdown?(_), do: false
end
