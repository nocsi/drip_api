defmodule Dirup.Storage.VFS.ContentAddressable do
  @moduledoc """
  Content-addressable storage for VFS.

  Files are identified by their content hash rather than location,
  enabling deduplication, integrity verification, and distributed storage.
  """

  alias Dirup.Storage.VFS.Cache

  @hash_algorithm :sha256

  @doc """
  Generate a content address (hash) for given content
  """
  def content_address(content) when is_binary(content) do
    :crypto.hash(@hash_algorithm, content)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Generate a compound address including metadata
  """
  def compound_address(content, metadata \\ %{}) do
    content_hash = content_address(content)

    metadata_str =
      metadata
      |> Map.take([:content_type, :generator, :workspace_id])
      |> Jason.encode!()

    metadata_hash = content_address(metadata_str)

    "#{content_hash}:#{metadata_hash}"
  end

  @doc """
  Store content by its address
  """
  def store(content, metadata \\ %{}) do
    address = compound_address(content, metadata)

    entry = %{
      content: content,
      metadata: metadata,
      size: byte_size(content),
      created_at: DateTime.utc_now(),
      refs: 1
    }

    # Store in cache and persistent storage
    Cache.put("cas:#{address}", entry)

    # TODO: Store in persistent CAS backend (S3, disk, etc.)
    {:ok, address}
  end

  @doc """
  Retrieve content by address
  """
  def retrieve(address) do
    case Cache.get("cas:#{address}") do
      {:ok, entry} -> {:ok, entry.content, entry.metadata}
      :miss -> retrieve_from_backend(address)
    end
  end

  @doc """
  Create a merkle tree for a directory of content addresses
  """
  def merkle_tree(addresses) when is_list(addresses) do
    addresses
    |> Enum.sort()
    |> build_merkle_tree()
  end

  defp build_merkle_tree([]), do: nil
  defp build_merkle_tree([addr]), do: %{hash: addr, leaf: true}

  defp build_merkle_tree(addresses) do
    # Build tree bottom-up
    mid = div(length(addresses), 2)
    {left, right} = Enum.split(addresses, mid)

    left_tree = build_merkle_tree(left)
    right_tree = build_merkle_tree(right)

    combined = "#{left_tree.hash}:#{right_tree.hash}"
    hash = content_address(combined)

    %{
      hash: hash,
      left: left_tree,
      right: right_tree
    }
  end

  defp retrieve_from_backend(address) do
    # TODO: Implement retrieval from S3/disk/distributed storage
    {:error, :not_found}
  end
end
