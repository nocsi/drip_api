defmodule KyozoWeb.JSONAPI.Schemas.Document do
  @moduledoc """
  JSON:API document response schema
  """

  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          oneOf: [
            %Schema{type: :object, description: "Single resource object"},
            %Schema{
              type: :array,
              items: %Schema{type: :object},
              description: "Array of resource objects"
            }
          ]
        },
        included: %Schema{
          type: :array,
          items: %Schema{type: :object},
          description: "Included resources"
        },
        links: %Schema{
          type: :object,
          description: "Links object"
        },
        meta: %Schema{
          type: :object,
          description: "Meta information"
        }
      }
    }
  end
end
