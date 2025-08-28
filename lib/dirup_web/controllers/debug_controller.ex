defmodule DirupWeb.DebugController do
  use DirupWeb, :controller

  def test(conn, _params) do
    conn
    |> put_layout(false)
    |> put_root_layout(false)
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!DOCTYPE html>
    <html>
    <head><title>Template Debug</title></head>
    <body>
      <h1>Template Debug Test</h1>
      <p>If you see this, basic controller rendering works.</p>
      <p>Current time: #{DateTime.utc_now()}</p>
    </body>
    </html>
    """)
  end

  def heex_test(conn, _params) do
    assigns = %{
      test_var: "Hello World",
      page_title: "HEEX Debug Test"
    }

    conn
    |> assign(:test_var, "Hello World")
    |> assign(:page_title, "HEEX Debug Test")
    |> render(:heex_test, layout: false)
  end
end
