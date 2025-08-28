defmodule Dirup.NodeJS do
  def start_link(opts \\ []), do: Dirup.NodeJS.Supervisor.start_link(opts)
  def stop(), do: Dirup.NodeJS.Supervisor.stop()

  def call(module, args \\ [], opts \\ []),
    do: Dirup.NodeJS.Supervisor.call(module, args, opts)

  def call!(module, args \\ [], opts \\ []),
    do: Dirup.NodeJS.Supervisor.call!(module, args, opts)
end
