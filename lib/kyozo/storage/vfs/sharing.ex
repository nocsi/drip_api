defmodule Kyozo.Storage.VFS.Sharing do
  @moduledoc """
  VFS Sharing capabilities - make virtual files shareable via URLs
  """

  alias Kyozo.Storage.VFS
  alias Kyozo.Storage.VFS.Cache

  @share_ttl :timer.hours(24)

  @doc """
  Create a shareable link for a virtual file
  """
  def create_share_link(workspace_id, path, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @share_ttl)

    # Verify it's a virtual file
    if VFS.virtual?(workspace_id, path) do
      share_id = generate_share_id()

      share_data = %{
        workspace_id: workspace_id,
        path: path,
        created_at: DateTime.utc_now(),
        expires_at: DateTime.add(DateTime.utc_now(), ttl, :millisecond),
        access_count: 0,
        creator_id: opts[:creator_id]
      }

      Cache.put("vfs:share:#{share_id}", share_data, ttl: ttl)

      {:ok,
       %{
         id: share_id,
         url: build_share_url(share_id),
         expires_at: share_data.expires_at
       }}
    else
      {:error, :not_virtual_file}
    end
  end

  @doc """
  Access a shared virtual file
  """
  def access_shared(share_id) do
    case Cache.get("vfs:share:#{share_id}") do
      {:ok, share_data} ->
        if DateTime.compare(DateTime.utc_now(), share_data.expires_at) == :lt do
          # Update access count
          updated = Map.update!(share_data, :access_count, &(&1 + 1))
          Cache.put("vfs:share:#{share_id}", updated)

          # Get the virtual file content
          case VFS.read_file(share_data.workspace_id, share_data.path) do
            {:ok, content} ->
              {:ok, content, share_data}

            error ->
              error
          end
        else
          {:error, :expired}
        end

      :miss ->
        {:error, :not_found}
    end
  end

  @doc """
  List all active shares for a workspace
  """
  def list_shares(workspace_id) do
    # In production, this would query a database
    # For now, we'll return a placeholder
    {:ok, []}
  end

  @doc """
  Revoke a share link
  """
  def revoke_share(share_id) do
    Cache.delete("vfs:share:#{share_id}")
    :ok
  end

  defp generate_share_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp build_share_url(share_id) do
    base_url = Application.get_env(:kyozo, :base_url, "http://localhost:4000")
    "#{base_url}/vfs/shared/#{share_id}"
  end
end
