defmodule KyozoWeb.API.Storage.VFSAdvancedController do
  use KyozoWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Kyozo.Storage.VFS.{Sharing, Export, Templates}
  alias Kyozo.Workspaces

  action_fallback KyozoWeb.FallbackController

  tags(["VFS Advanced"])

  operation(:create_share,
    summary: "Create a shareable link for a virtual file",
    parameters: [
      workspace_id: [in: :path, type: :string, required: true]
    ],
    request_body:
      {"Share request", "application/json",
       %{
         path: %{type: :string, required: true},
         ttl: %{type: :integer, description: "TTL in seconds", required: false}
       }},
    responses: [
      created:
        {"Share created", "application/json",
         %{
           id: %{type: :string},
           url: %{type: :string},
           expires_at: %{type: :string, format: :datetime}
         }}
    ]
  )

  def create_share(conn, %{"workspace_id" => workspace_id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, _workspace} <- authorize_workspace(conn, workspace_id),
         {:ok, share} <-
           Sharing.create_share_link(
             workspace_id,
             params["path"],
             creator_id: current_user.id,
             ttl: params["ttl"]
           ) do
      conn
      |> put_status(:created)
      |> json(share)
    end
  end

  operation(:export,
    summary: "Export virtual files",
    parameters: [
      workspace_id: [in: :path, type: :string, required: true],
      format: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string, enum: ["pdf", "html", "epub", "json"]}
      ]
    ],
    responses: [
      ok: {"Export successful", "application/json", %{}}
    ]
  )

  def export(conn, %{"workspace_id" => workspace_id} = params) do
    format = String.to_atom(params["format"] || "html")
    path = params["path"] || "/"

    with {:ok, _workspace} <- authorize_workspace(conn, workspace_id),
         {:ok, content} <- Export.export(workspace_id, path, format) do
      case format do
        :json ->
          json(conn, content)

        :html ->
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, content)

        _ ->
          # For PDF/EPUB, would send as download
          conn
          |> put_resp_content_type("application/octet-stream")
          |> put_resp_header("content-disposition", "attachment; filename=\"export.#{format}\"")
          |> send_resp(200, content)
      end
    end
  end

  operation(:register_template,
    summary: "Register a custom template",
    parameters: [
      workspace_id: [in: :path, type: :string, required: true]
    ],
    request_body:
      {"Template", "application/json",
       %{
         generator_type: %{type: :string, required: true},
         template_name: %{type: :string, required: true},
         content: %{type: :string, required: true}
       }},
    responses: [
      created: {"Template created", "application/json", %{}}
    ]
  )

  def register_template(conn, %{"workspace_id" => workspace_id} = params) do
    with {:ok, _workspace} <- authorize_workspace(conn, workspace_id),
         {:ok, template} <-
           Templates.register_template(
             workspace_id,
             String.to_atom(params["generator_type"]),
             String.to_atom(params["template_name"]),
             params["content"]
           ) do
      conn
      |> put_status(:created)
      |> json(%{
        generator_type: template.generator_type,
        name: template.name,
        variables: template.variables
      })
    end
  end

  defp authorize_workspace(conn, workspace_id) do
    user = conn.assigns[:current_user]

    if user do
      Workspaces.get_workspace(workspace_id, actor: user)
    else
      {:error, :unauthorized}
    end
  end
end
