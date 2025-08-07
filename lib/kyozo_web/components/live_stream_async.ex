defmodule LiveStreamAsync do
  alias LiveView.AsyncResult

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :async_streams, accumulate: true)
    end
  end

  defmacro __before_compile__(_env) do
    streams = Module.get_attribute(__CALLER__.module, :async_streams)

    for {stream_id, opts} <- streams do
      quote bind_quoted: [stream: stream_id, opts: opts] do
        def handle_async(stream, {:ok, results}, socket) do
          socket =
            socket
            |> assign(stream, AsyncResult.ok(stream))
            |> stream(stream, results, unquote(opts))

          {:noreply, socket}
        end

        def handle_async(stream, {:exit, reason}, socket) do
          {:noreply,
           update(socket, stream, fn async_result ->
             AsyncResult.failed(async_result, {:exit, reason})
           end)}
        end
      end
    end
  end

  defmacro stream_async(socket, key, func, opts \\ []) do
    Module.put_attribute(__CALLER__.module, :async_streams, {key, opts})

    quote bind_quoted: [socket: socket, key: key, func: func, opts: opts] do
      socket
      |> assign(key, AsyncResult.loading())
      |> start_async(key, func, opts)
    end
  end
end
