defmodule Dirup.Storage.VFS.Cache do
  @moduledoc """
  Simple ETS-based cache for virtual file contents
  """

  use GenServer

  @table :vfs_cache
  @ttl :timer.minutes(5)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(workspace_id, path) do
    key = cache_key(workspace_id, path)

    case :ets.lookup(@table, key) do
      [{^key, content, expiry}] ->
        if DateTime.compare(expiry, DateTime.utc_now()) == :gt do
          {:ok, content}
        else
          :ets.delete(@table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  def put(workspace_id, path, content) do
    key = cache_key(workspace_id, path)
    expiry = DateTime.add(DateTime.utc_now(), @ttl, :millisecond)
    :ets.insert(@table, {key, content, expiry})
    :ok
  end

  def clear(workspace_id) do
    :ets.match_delete(@table, {{workspace_id, :_}, :_, :_})
    :ok
  end

  def clear_all do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  defp cache_key(workspace_id, path) do
    {workspace_id, path}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(10))
  end

  defp cleanup_expired do
    now = DateTime.utc_now()

    :ets.select_delete(@table, [
      {
        {:_, :_, :"$1"},
        [{:<, :"$1", now}],
        [true]
      }
    ])
  end
end
