defmodule KyozoWeb.JSONAPI.Schemas.Error do
  @moduledoc """
  JSON:API error response schema
  """

  alias OpenApiSpex.Schema

  def schema() do
    %Schema{
      type: :object,
      properties: %{
        errors: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, description: "Unique identifier for the error"},
              status: %Schema{type: :string, description: "HTTP status code as string"},
              code: %Schema{type: :string, description: "Application-specific error code"},
              title: %Schema{type: :string, description: "Human-readable summary"},
              detail: %Schema{type: :string, description: "Human-readable explanation"},
              source: %Schema{
                type: :object,
                properties: %{
                  pointer: %Schema{type: :string, description: "JSON Pointer to the problem"},
                  parameter: %Schema{type: :string, description: "Query parameter name"}
                }
              },
              meta: %Schema{
                type: :object,
                description: "Additional meta information"
              }
            },
            required: [:title]
          }
        }
      },
      required: [:errors],
      example: %{
        errors: [
          %{
            status: "400",
            title: "Validation Error",
            detail: "name can't be blank",
            source: %{
              pointer: "/data/attributes/name"
            }
          }
        ]
      }
    }
  end
end
