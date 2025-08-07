defmodule Kyozo.NodeJS do
  def start_link(opts \\ []), do: Kyozo.NodeJS.Supervisor.start_link(opts)
  def stop(), do: Kyozo.NodeJS.Supervisor.stop()

  def call(module, args \\ [], opts \\ []),
    do: Kyozo.NodeJS.Supervisor.call(module, args, opts)

  def call!(module, args \\ [], opts \\ []),
    do: Kyozo.NodeJS.Supervisor.call!(module, args, opts)
end
