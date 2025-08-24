defmodule KyozoWeb.API.Storage.VFSSchemas do
  @moduledoc """
  OpenAPI schemas for VFS operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule VFSFile do
    OpenApiSpex.schema(%{
      title: "VFS File",
      description: "A file or directory entry, possibly virtual",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Unique identifier"},
        name: %Schema{type: :string, description: "File or directory name"},
        path: %Schema{type: :string, description: "Full path"},
        type: %Schema{type: :string, enum: ["file", "directory"], description: "Entry type"},
        size: %Schema{type: :integer, description: "File size in bytes"},
        content_type: %Schema{type: :string, description: "MIME type"},
        created_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"},
        virtual: %Schema{type: :boolean, description: "Whether this is a virtual file"},
        icon: %Schema{type: :string, nullable: true, description: "Icon emoji for virtual files"},
        generator: %Schema{
          type: :string,
          nullable: true,
          description: "Generator that created this virtual file"
        }
      },
      required: [
        :id,
        :name,
        :path,
        :type,
        :size,
        :content_type,
        :created_at,
        :updated_at,
        :virtual
      ]
    })
  end

  defmodule VFSListing do
    OpenApiSpex.schema(%{
      title: "VFS Listing",
      description: "Directory listing with virtual files included",
      type: :object,
      properties: %{
        path: %Schema{type: :string, description: "Directory path"},
        virtual_count: %Schema{type: :integer, description: "Number of virtual files"},
        files: %Schema{type: :array, items: VFSFile}
      },
      required: [:path, :virtual_count, :files]
    })
  end

  defmodule VFSContent do
    OpenApiSpex.schema(%{
      title: "VFS Content",
      description: "Content of a virtual file",
      type: :object,
      properties: %{
        path: %Schema{type: :string, description: "File path"},
        content: %Schema{type: :string, description: "File content"},
        virtual: %Schema{type: :boolean, description: "Always true for VFS content"},
        content_type: %Schema{type: :string, description: "MIME type"}
      },
      required: [:path, :content, :virtual, :content_type]
    })
  end

  defmodule VFSListingResponse do
    OpenApiSpex.schema(%{
      title: "VFS Listing Response",
      type: :object,
      properties: %{
        data: VFSListing
      },
      required: [:data]
    })
  end

  defmodule VFSContentResponse do
    OpenApiSpex.schema(%{
      title: "VFS Content Response",
      type: :object,
      properties: %{
        data: VFSContent
      },
      required: [:data]
    })
  end

  defmodule ErrorResponse do
    OpenApiSpex.schema(%{
      title: "Error Response",
      type: :object,
      properties: %{
        error: %Schema{type: :string},
        message: %Schema{type: :string}
      },
      required: [:error]
    })
  end
end
