defmodule Dirup.Markdown.Handlers do
  @moduledoc """
  Handlers for single-purpose markdown files.
  Each handler knows how to make a markdown file act as its declared type.
  """

  alias Dirup.Markdown.{Parser, Types}

  # Define basic AST structs for compatibility
  defmodule AST do
    defmodule Code do
      defstruct [:lang, :value, :type]
    end
  end

  # Basic transform utilities
  defmodule Transform do
    def find_all(ast, matcher) when is_function(matcher) do
      # Simple traversal - would need proper implementation
      []
    end
  end

  @doc """
  Handle a markdown file based on its declared type.
  """
  def handle(content, action \\ :default) do
    with {:ok, ast} <- Parser.parse(content),
         {type, opts} <- Types.detect_type(content) do
      handler = get_handler(type)
      handler.handle(ast, action, opts)
    else
      error -> {:error, error}
    end
  end

  defp get_handler(:dockerfile), do: __MODULE__.Dockerfile
  defp get_handler(:config), do: __MODULE__.Configuration
  defp get_handler(:git_repo), do: __MODULE__.GitRepository
  defp get_handler(:executable), do: __MODULE__.Executable
  defp get_handler(:database), do: __MODULE__.Database
  defp get_handler(_), do: __MODULE__.Documentation
end

defmodule Dirup.Markdown.Handlers.Dockerfile do
  @moduledoc "Makes a markdown file act as a Dockerfile"

  def handle(_ast, action, _opts) do
    # Simplified implementation - just return action acknowledgment
    {:ok, "Dockerfile handler: #{action}"}
  end
end

defmodule Dirup.Markdown.Handlers.Configuration do
  @moduledoc "Makes a markdown file act as a config file"

  def handle(_ast, action, _opts) do
    # Simplified implementation - just return action acknowledgment
    {:ok, "Configuration handler: #{action}"}
  end
end

defmodule Dirup.Markdown.Handlers.GitRepository do
  @moduledoc "Makes a markdown file act as a git repository"

  def handle(_ast, action, _opts) do
    # Simplified implementation - just return action acknowledgment
    {:ok, "GitRepository handler: #{action}"}
  end
end

defmodule Dirup.Markdown.Handlers.Executable do
  @moduledoc "Makes a markdown file directly executable"

  def handle(_ast, action, _opts) do
    # Simplified implementation - just return action acknowledgment
    {:ok, "Executable handler: #{action}"}
  end
end

defmodule Dirup.Markdown.Handlers.Database do
  @moduledoc "Makes a markdown file act as an embedded database"

  def handle(_ast, action, _opts) do
    # Simplified implementation - just return action acknowledgment
    {:ok, "Database handler: #{action}"}
  end
end

defmodule Dirup.Markdown.Handlers.Documentation do
  @moduledoc "Default handler - just a normal markdown doc"

  def handle(ast, action, _opts) do
    # Default documentation handler
    {:ok, "Documentation handler: #{action}, AST processed"}
  end
end
