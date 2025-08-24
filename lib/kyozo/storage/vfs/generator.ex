defmodule Kyozo.Storage.VFS.Generator do
  @moduledoc """
  Behaviour for VFS file generators
  """

  @type virtual_file :: %{
          name: String.t(),
          path: String.t(),
          generator: atom(),
          icon: String.t() | nil,
          content_generator: fun()
        }

  @type context :: %{
          workspace: any(),
          path: String.t(),
          files: [any()],
          timestamp: DateTime.t()
        }

  @doc """
  Generate virtual files for a given context
  """
  @callback generate(context()) :: [virtual_file()]

  @doc """
  Check if this generator handles a specific type
  """
  @callback handles_type?(atom()) :: boolean()

  @doc """
  Generate content for a specific type
  """
  @callback generate_content(atom(), context()) :: String.t()
end
