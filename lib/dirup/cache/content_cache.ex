defmodule Dirup.Cache.ContentCache do
  @moduledoc """
  High-performance ETS-based content caching system.

  Restores the caching layer that was destroyed by a rogue agent.
  Provides multi-tier caching for file content, query results, and search operations.
  """

  use GenServer
  require Logger

  # Cache configuration
  @cache_table :dirup_content_cache
  @search_cache_table :dirup_search_cache
  @query_cache_table :dirup_query_cache

  # TTL settings (seconds)
  # 1 hour for file content
  @content_ttl 3600
  # 30 minutes for search results
  @search_ttl 1800
  # 5 minutes for query results
  @query_ttl 300
  # 5 minutes cleanup cycle
  @cleanup_interval 300_000

  # Cache size limits
  @max_cache_entries 50_000
  @max_content_size_mb 100

  ## Public API

  @doc """
  Starts the content cache system.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets cached file content by file ID.
  Returns {:hit, content} or :miss
  """
  def get_content(file_id) when is_binary(file_id) do
    case :ets.lookup(@cache_table, {:content, file_id}) do
      [{_key, content, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          Logger.debug("Content cache hit", file_id: file_id)
          {:hit, content}
        else
          :ets.delete(@cache_table, {:content, file_id})
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Caches file content with automatic expiration.
  """
  def put_content(file_id, content, opts \\ []) when is_binary(file_id) do
    ttl = Keyword.get(opts, :ttl, @content_ttl)
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)

    # Check content size limit
    content_size_mb = byte_size(content) / (1024 * 1024)

    if content_size_mb <= @max_content_size_mb do
      :ets.insert(@cache_table, {{:content, file_id}, content, expires_at})

      Logger.debug("Cached file content",
        file_id: file_id,
        size_mb: Float.round(content_size_mb, 2),
        ttl: ttl
      )

      :ok
    else
      Logger.warning("Content too large for cache",
        file_id: file_id,
        size_mb: Float.round(content_size_mb, 2),
        limit_mb: @max_content_size_mb
      )

      :too_large
    end
  end

  @doc """
  Gets cached search results.
  """
  def get_search_results(query_hash) when is_binary(query_hash) do
    case :ets.lookup(@search_cache_table, {:search, query_hash}) do
      [{_key, results, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          Logger.debug("Search cache hit", query_hash: String.slice(query_hash, 0, 8))
          {:hit, results}
        else
          :ets.delete(@search_cache_table, {:search, query_hash})
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Caches search results.
  """
  def put_search_results(query_hash, results, opts \\ []) when is_binary(query_hash) do
    ttl = Keyword.get(opts, :ttl, @search_ttl)
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)

    :ets.insert(@search_cache_table, {{:search, query_hash}, results, expires_at})

    Logger.debug("Cached search results",
      query_hash: String.slice(query_hash, 0, 8),
      results_count: length(results),
      ttl: ttl
    )

    :ok
  end

  @doc """
  Gets cached query results.
  """
  def get_query_result(query_key) when is_binary(query_key) do
    case :ets.lookup(@query_cache_table, {:query, query_key}) do
      [{_key, result, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          Logger.debug("Query cache hit", query_key: String.slice(query_key, 0, 8))
          {:hit, result}
        else
          :ets.delete(@query_cache_table, {:query, query_key})
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Caches query results.
  """
  def put_query_result(query_key, result, opts \\ []) when is_binary(query_key) do
    ttl = Keyword.get(opts, :ttl, @query_ttl)
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)

    :ets.insert(@query_cache_table, {{:query, query_key}, result, expires_at})

    Logger.debug("Cached query result",
      query_key: String.slice(query_key, 0, 8),
      ttl: ttl
    )

    :ok
  end

  @doc """
  Invalidates content cache for a specific file.
  """
  def invalidate_content(file_id) when is_binary(file_id) do
    :ets.delete(@cache_table, {:content, file_id})
    Logger.debug("Invalidated content cache", file_id: file_id)
    :ok
  end

  @doc """
  Invalidates all search results (used when content changes).
  """
  def invalidate_all_searches do
    :ets.match_delete(@search_cache_table, {{:search, :_}, :_, :_})
    Logger.info("Invalidated all search caches")
    :ok
  end

  @doc """
  Generates a cache key for search queries.
  """
  def search_cache_key(query, options) do
    content = "#{query}:#{inspect(options)}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  @doc """
  Generates a cache key for database queries.
  """
  def query_cache_key(module, function, args) do
    content = "#{module}:#{function}:#{inspect(args)}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  @doc """
  Returns cache statistics.
  """
  def cache_stats do
    content_size = :ets.info(@cache_table, :size) || 0
    search_size = :ets.info(@search_cache_table, :size) || 0
    query_size = :ets.info(@query_cache_table, :size) || 0

    content_memory = (:ets.info(@cache_table, :memory) || 0) * :erlang.system_info(:wordsize)

    search_memory =
      (:ets.info(@search_cache_table, :memory) || 0) * :erlang.system_info(:wordsize)

    query_memory = (:ets.info(@query_cache_table, :memory) || 0) * :erlang.system_info(:wordsize)

    total_memory_mb = (content_memory + search_memory + query_memory) / (1024 * 1024)

    %{
      content_entries: content_size,
      search_entries: search_size,
      query_entries: query_size,
      total_entries: content_size + search_size + query_size,
      memory_mb: Float.round(total_memory_mb, 2),
      max_entries: @max_cache_entries,
      utilization_pct:
        Float.round((content_size + search_size + query_size) / @max_cache_entries * 100, 1)
    }
  end

  ## GenServer Callbacks

  def init(_opts) do
    # Create ETS tables with optimized settings
    :ets.new(@cache_table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true,
      compressed: true
    ])

    :ets.new(@search_cache_table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true,
      compressed: true
    ])

    :ets.new(@query_cache_table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true,
      compressed: true
    ])

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)

    Logger.info("Content cache system initialized",
      tables: [@cache_table, @search_cache_table, @query_cache_table],
      cleanup_interval_min: @cleanup_interval / 60_000
    )

    {:ok,
     %{
       last_cleanup: DateTime.utc_now(),
       cleanup_count: 0
     }}
  end

  def handle_info(:cleanup, state) do
    start_time = System.monotonic_time(:millisecond)

    # Clean expired entries from all tables
    now = DateTime.utc_now()

    content_deleted = cleanup_expired_entries(@cache_table, now)
    search_deleted = cleanup_expired_entries(@search_cache_table, now)
    query_deleted = cleanup_expired_entries(@query_cache_table, now)

    total_deleted = content_deleted + search_deleted + query_deleted
    cleanup_time = System.monotonic_time(:millisecond) - start_time

    # Enforce cache size limits
    enforce_size_limits()

    Logger.info("Cache cleanup completed",
      expired_removed: total_deleted,
      cleanup_time_ms: cleanup_time,
      stats: cache_stats()
    )

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)

    {:noreply,
     %{state | last_cleanup: DateTime.utc_now(), cleanup_count: state.cleanup_count + 1}}
  end

  ## Private Functions

  defp cleanup_expired_entries(table, now) do
    # Match all entries where expires_at < now
    match_spec = [
      {{:_, :_, :"$1"}, [{:<, :"$1", {:const, now}}], [true]}
    ]

    :ets.select_delete(table, match_spec)
  end

  defp enforce_size_limits do
    total_entries =
      :ets.info(@cache_table, :size) +
        :ets.info(@search_cache_table, :size) +
        :ets.info(@query_cache_table, :size)

    if total_entries > @max_cache_entries do
      excess = total_entries - @max_cache_entries

      Logger.warning("Cache size limit exceeded",
        current: total_entries,
        limit: @max_cache_entries,
        removing: excess
      )

      # Remove oldest entries from content cache (largest table typically)
      remove_oldest_entries(@cache_table, div(excess, 2))
      remove_oldest_entries(@search_cache_table, div(excess, 4))
      remove_oldest_entries(@query_cache_table, div(excess, 4))
    end
  end

  defp remove_oldest_entries(table, count) do
    # Get all entries sorted by expiration time
    entries =
      :ets.tab2list(table)
      |> Enum.sort_by(fn {_key, _value, expires_at} -> expires_at end)
      |> Enum.take(count)

    # Delete the oldest entries
    Enum.each(entries, fn {key, _value, _expires_at} ->
      :ets.delete(table, key)
    end)

    length(entries)
  end
end
