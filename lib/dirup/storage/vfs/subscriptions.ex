defmodule Dirup.Storage.VFS.Subscriptions do
  @moduledoc """
  Subscribe to VFS changes and virtual file updates
  """

  use GenServer
  alias Phoenix.PubSub

  @pubsub Dirup.PubSub

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{subscriptions: %{}}}
  end

  @doc """
  Subscribe to virtual file changes in a workspace
  """
  def subscribe(workspace_id, opts \\ []) do
    topic = build_topic(workspace_id, opts[:path])
    PubSub.subscribe(@pubsub, topic)
  end

  @doc """
  Unsubscribe from virtual file changes
  """
  def unsubscribe(workspace_id, opts \\ []) do
    topic = build_topic(workspace_id, opts[:path])
    PubSub.unsubscribe(@pubsub, topic)
  end

  @doc """
  Notify subscribers of virtual file changes
  """
  def notify_change(workspace_id, event_type, data) do
    # Broadcast to workspace-level subscribers
    PubSub.broadcast(@pubsub, "vfs:#{workspace_id}", {event_type, data})

    # Broadcast to path-specific subscribers if applicable
    if path = data[:path] do
      PubSub.broadcast(@pubsub, "vfs:#{workspace_id}:#{path}", {event_type, data})
    end
  end

  @doc """
  Events that can be subscribed to
  """
  def event_types do
    [
      # New virtual file created
      :virtual_file_generated,
      # Virtual file content changed
      :virtual_file_updated,
      # Someone accessed a virtual file
      :virtual_file_accessed,
      # New generator registered
      :generator_added,
      # Generator removed
      :generator_removed,
      # Cache cleared for a path
      :cache_invalidated,
      # Virtual file shared
      :share_created,
      # Shared link accessed
      :share_accessed,
      # Export job finished
      :export_completed
    ]
  end

  defp build_topic(workspace_id, nil), do: "vfs:#{workspace_id}"
  defp build_topic(workspace_id, path), do: "vfs:#{workspace_id}:#{path}"
end
