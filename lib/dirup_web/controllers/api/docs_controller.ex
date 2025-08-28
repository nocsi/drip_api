defmodule DirupWeb.API.DocsController do
  use DirupWeb, :controller

  alias DirupWeb.API.OpenAPISpec

  @doc """
  Serves the OpenAPI 3.0 specification
  """
  def openapi(conn, _params) do
    spec = OpenAPISpec.spec()

    conn
    |> put_resp_content_type("application/json")
    |> json(spec)
  end

  @doc """
  Serves a simple HTML page with embedded Swagger UI
  """
  def swagger_ui(conn, _params) do
    html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <title>Kyozo API Documentation</title>
      <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          window.ui = SwaggerUIBundle({
            url: "/api/v1/openapi.json",
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout"
          });
        };
      </script>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end
end
