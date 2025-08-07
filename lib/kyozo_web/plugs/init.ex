defmodule KyozoWeb.Plugs.Init do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign(:env, Application.fetch_env!(:kyozo, :env))
  end
end
