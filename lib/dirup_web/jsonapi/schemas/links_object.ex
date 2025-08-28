defmodule DirupWeb.JSONAPI.Schemas.LinksObject do
  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :object,
      properties: %{
        self: %Schema{type: :string, description: "Self link"},
        related: %Schema{type: :string, description: "Related link"},
        first: %Schema{type: :string, description: "First page link"},
        last: %Schema{type: :string, description: "Last page link"},
        prev: %Schema{type: :string, description: "Previous page link"},
        next: %Schema{type: :string, description: "Next page link"}
      }
    }
  end
end
