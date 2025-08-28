#!/usr/bin/env elixir

# Script to rename all module definitions from Kyozo/DirupWeb to Topo/DirupWeb
# This addresses the compilation errors where config expects Topo modules but finds Kyozo definitions

defmodule ModuleRenamer do
  def run do
    # Get all .ex files in lib directory
    lib_files = Path.wildcard("lib/**/*.ex")

    IO.puts("Found #{length(lib_files)} .ex files to process")

    Enum.each(lib_files, &process_file/1)

    IO.puts("✅ Module renaming complete!")
  end

  defp process_file(file_path) do
    content = File.read!(file_path)
    original_content = content

    # Update module definitions
    content =
      content
      # Change defmodule Kyozo to defmodule Topo
      |> String.replace(~r/defmodule Kyozo\./, "defmodule Dirup.")
      |> String.replace(~r/defmodule Kyozo([^\.])/, "defmodule Topo\\1")
      # Change defmodule DirupWeb to defmodule DirupWeb
      |> String.replace(~r/defmodule DirupWeb\./, "defmodule DirupWeb.")
      |> String.replace(~r/defmodule DirupWeb([^\.])/, "defmodule DirupWeb\\1")
      # Update alias statements
      |> String.replace(~r/alias Kyozo\./, "alias Dirup.")
      |> String.replace(~r/alias DirupWeb\./, "alias DirupWeb.")
      # Update import statements  
      |> String.replace(~r/import Kyozo\./, "import Dirup.")
      |> String.replace(~r/import DirupWeb\./, "import DirupWeb.")
      # Update use statements
      |> String.replace(~r/use Kyozo\./, "use Dirup.")
      |> String.replace(~r/use DirupWeb\./, "use DirupWeb.")
      # Update require statements
      |> String.replace(~r/require Kyozo\./, "require Dirup.")
      |> String.replace(~r/require DirupWeb\./, "require DirupWeb.")
      # Update direct module references
      |> String.replace(~r/([^a-zA-Z0-9_])Kyozo\./, "\\1Dirup.")
      |> String.replace(~r/([^a-zA-Z0-9_])DirupWeb\./, "\\1DirupWeb.")
      # Update string references (like in routes, controllers, etc)
      |> String.replace(~r/"Kyozo\./, "\"Dirup.")
      |> String.replace(~r/"DirupWeb\./, "\"DirupWeb.")
      |> String.replace(~r/'Kyozo\./, "'Dirup.")
      |> String.replace(~r/'DirupWeb\./, "'DirupWeb.")

    # Only write if content changed
    if content != original_content do
      File.write!(file_path, content)
      IO.puts("✏️  Updated: #{file_path}")
    end
  end
end

ModuleRenamer.run()
