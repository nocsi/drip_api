defmodule DirupWeb.JSONAPI.Schemas.ResourceObject do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :object,
      properties: %{
        type: %Schema{type: :string, description: "Resource type"},
        id: %Schema{type: :string, description: "Resource identifier"},
        attributes: %Schema{type: :object, description: "Resource attributes"},
        relationships: %Schema{type: :object, description: "Resource relationships"},
        links: %Schema{type: :object, description: "Resource links"},
        meta: %Schema{type: :object, description: "Resource meta information"}
      },
      required: [:type]
    }
  end
end
