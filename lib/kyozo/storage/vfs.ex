defmodule Kyozo.Storage.VFS do
  @moduledoc """
  Virtual File System that generates helpful Markdown files based on directory contents.
  No execution - just documentation generation.
  """

  alias Kyozo.Workspaces
  alias Kyozo.Storage.VFS.{Generator, Cache}

  @doc """
  List files in a directory with virtual files included
  """
  def list_files(workspace_id, path, opts \\ %{}) do
    with {:ok, workspace} <- Workspaces.get_workspace(workspace_id),
         {:ok, real_files} <- Workspaces.list_files(workspace_id, path) do
      virtual_files = generate_virtual_files(workspace, path, real_files)
      all_files = merge_and_sort(real_files, virtual_files)

      {:ok,
       %{
         files: all_files,
         path: path,
         virtual_count: length(virtual_files)
       }}
    end
  end

  @doc """
  Read a virtual file's content
  """
  def read_file(workspace_id, path) do
    # Check cache first
    case Cache.get(workspace_id, path) do
      {:ok, content} ->
        {:ok, content}

      :miss ->
        generate_and_cache(workspace_id, path)
    end
  end

  @doc """
  Check if a path is a virtual file
  """
  def virtual?(workspace_id, path) do
    # Quick check based on naming patterns
    String.ends_with?(path, ".md") and
      path =~ ~r/(guide|deploy|overview|monitoring)\.md$/
  end

  # Private functions

  defp generate_virtual_files(workspace, path, real_files) do
    context = %{
      workspace: workspace,
      path: path,
      files: real_files,
      timestamp: DateTime.utc_now()
    }

    enabled_generators()
    |> Enum.flat_map(& &1.generate(context))
    |> Enum.uniq_by(& &1.name)
  end

  defp enabled_generators do
    Application.get_env(:kyozo, Kyozo.Storage.VFS, [])
    |> Keyword.get(:generators, [
      Kyozo.Storage.VFS.Generators.ElixirProject,
      Kyozo.Storage.VFS.Generators.NodeProject,
      Kyozo.Storage.VFS.Generators.PythonProject,
      Kyozo.Storage.VFS.Generators.DockerProject,
      Kyozo.Storage.VFS.Generators.WorkspaceOverview
    ])
  end

  defp merge_and_sort(real_files, virtual_files) do
    # Convert virtual files to same format as real files
    virtual_as_files =
      Enum.map(virtual_files, fn vf ->
        %{
          id: "virtual_#{:crypto.hash(:md5, vf.path) |> Base.encode16()}",
          name: vf.name,
          path: vf.path,
          type: "file",
          virtual: true,
          generator: vf.generator,
          icon: vf.icon,
          size: 0,
          content_type: "text/markdown",
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    (real_files ++ virtual_as_files)
    |> Enum.sort_by(fn f ->
      # Sort: directories, real files, virtual files
      {f.type != "directory", f[:virtual] || false, f.name}
    end)
  end

  defp generate_and_cache(workspace_id, path) do
    # Extract generator type from path
    with {:ok, generator_type} <- detect_generator(path),
         {:ok, context} <- build_context(workspace_id, path),
         content <- generate_content(generator_type, context) do
      Cache.put(workspace_id, path, content)
      {:ok, content}
    else
      _ -> {:error, :not_found}
    end
  end

  defp detect_generator(path) do
    cond do
      String.ends_with?(path, "guide.md") -> {:ok, :guide}
      String.ends_with?(path, "deploy.md") -> {:ok, :deploy}
      String.ends_with?(path, "overview.md") -> {:ok, :overview}
      String.ends_with?(path, "monitoring.md") -> {:ok, :monitoring}
      true -> {:error, :unknown_generator}
    end
  end

  defp build_context(workspace_id, path) do
    dir_path = Path.dirname(path)

    with {:ok, workspace} <- Workspaces.get_workspace(workspace_id),
         {:ok, files} <- Workspaces.list_files(workspace_id, dir_path) do
      {:ok,
       %{
         workspace: workspace,
         path: path,
         dir_path: dir_path,
         files: files,
         timestamp: DateTime.utc_now()
       }}
    end
  end

  defp generate_content(generator_type, context) do
    # Find the appropriate generator
    generator =
      Enum.find(enabled_generators(), fn gen ->
        gen.handles_type?(generator_type)
      end)

    if generator do
      generator.generate_content(generator_type, context)
    else
      "# Virtual File\n\nContent generation not implemented for type: #{generator_type}"
    end
  end
end
