defmodule KyozoWeb.JSONAPI.Schemas.Timestamp do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :string,
      format: :datetime,
      description: "ISO 8601 timestamp",
      example: "2024-01-01T12:00:00Z"
    }
  end
end

defmodule KyozoWeb.JSONAPI.Schemas.Meta do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :object,
      description: "Meta information object"
    }
  end
end

defmodule KyozoWeb.JSONAPI.Schemas.ResourceLinkage do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      oneOf: [
        %Schema{type: :object, description: "Single resource identifier"},
        %Schema{
          type: :array,
          items: %Schema{type: :object},
          description: "Array of resource identifiers"
        }
      ]
    }
  end
end

defmodule KyozoWeb.JSONAPI.Schemas.ResourceIdentifierObject do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :object,
      properties: %{
        type: %Schema{type: :string, description: "Resource type"},
        id: %Schema{type: :string, description: "Resource identifier"},
        meta: %Schema{type: :object, description: "Meta information"}
      },
      required: [:type, :id]
    }
  end
end

defmodule KyozoWeb.JSONAPI.Schemas.RelationshipObject do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :object,
      properties: %{
        links: %Schema{type: :object, description: "Relationship links"},
        data: %Schema{type: :object, description: "Resource linkage"},
        meta: %Schema{type: :object, description: "Meta information"}
      }
    }
  end
end

defmodule KyozoWeb.JSONAPI.Schemas.Link do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      oneOf: [
        %Schema{type: :string, description: "Link URL"},
        %Schema{
          type: :object,
          properties: %{
            href: %Schema{type: :string, description: "Link URL"},
            meta: %Schema{type: :object, description: "Link meta information"}
          },
          required: [:href]
        }
      ]
    }
  end
end
