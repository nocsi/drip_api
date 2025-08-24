defmodule KyozoWeb.VFS.SharedController do
  use KyozoWeb, :controller

  alias Kyozo.Storage.VFS.Sharing
  alias Kyozo.Storage.VFS.Export

  def show(conn, %{"id" => share_id}) do
    case Sharing.access_shared(share_id) do
      {:ok, content, share_data} ->
        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header("x-vfs-path", share_data.path)
        |> put_resp_header("x-vfs-expires", DateTime.to_iso8601(share_data.expires_at))
        |> send_resp(200, content)

      {:error, :expired} ->
        conn
        |> put_status(:gone)
        |> put_view(html: KyozoWeb.ErrorHTML)
        |> render("410.html")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: KyozoWeb.ErrorHTML)
        |> render("404.html")
    end
  end

  def show_html(conn, %{"id" => share_id}) do
    case Sharing.access_shared(share_id) do
      {:ok, content, share_data} ->
        # Convert markdown to HTML for nice viewing
        {:ok, html} = Export.export(share_data.workspace_id, share_data.path, :html)

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      {:error, _} = error ->
        handle_error(conn, error)
    end
  end

  defp handle_error(conn, {:error, :expired}) do
    conn
    |> put_status(:gone)
    |> put_view(html: KyozoWeb.ErrorHTML)
    |> render("410.html")
  end

  defp handle_error(conn, _) do
    conn
    |> put_status(:not_found)
    |> put_view(html: KyozoWeb.ErrorHTML)
    |> render("404.html")
  end
end
