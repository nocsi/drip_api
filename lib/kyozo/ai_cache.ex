defmodule Kyozo.AICache do
  @moduledoc """
  Intelligent caching for AI responses to reduce costs and improve performance
  """
  use GenServer
  require Logger

  # Cache similar requests for 1 hour, exact matches for 24 hours
  @similarity_cache_ttl 3600
  @exact_cache_ttl 86400
  @cache_table :ai_cache

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_cached_suggestion(request) do
    cache_key = generate_cache_key(request)

    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, response, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          Logger.debug("AI cache hit for key: #{cache_key}")
          {:hit, response}
        else
          :ets.delete(@cache_table, cache_key)
          {:miss, :expired}
        end

      [] ->
        # Check for similar requests
        check_similar_requests(request)
    end
  end

  def cache_suggestion(request, response, opts \\ []) do
    cache_key = generate_cache_key(request)
    ttl = Keyword.get(opts, :ttl, @exact_cache_ttl)
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)

    :ets.insert(@cache_table, {cache_key, response, expires_at})

    Logger.debug("Cached AI response for key: #{cache_key}, TTL: #{ttl}s")
    :ok
  end

  def get_cached_confidence(request) do
    # Confidence analysis is more cacheable since code doesn't change often
    cache_key = generate_confidence_cache_key(request)

    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, response, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:hit, response}
        else
          :ets.delete(@cache_table, cache_key)
          {:miss, :expired}
        end

      [] ->
        {:miss, :not_found}
    end
  end

  def cache_confidence(request, response) do
    cache_key = generate_confidence_cache_key(request)
    # Confidence analysis cached longer since code structure is more stable
    expires_at = DateTime.add(DateTime.utc_now(), @exact_cache_ttl * 3, :second)

    :ets.insert(@cache_table, {cache_key, response, expires_at})
    :ok
  end

  # GenServer callbacks

  def init(_opts) do
    :ets.new(@cache_table, [:named_table, :public, read_concurrency: true])

    # Schedule periodic cleanup
    # Every hour
    Process.send_after(self(), :cleanup, 3600_000)

    {:ok, %{}}
  end

  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    Process.send_after(self(), :cleanup, 3600_000)
    {:noreply, state}
  end

  # Private functions

  defp generate_cache_key(%{text: text, context: context}) do
    # Normalize text for better cache hits
    normalized_text =
      text
      |> String.trim()
      |> String.downcase()
      |> remove_extra_whitespace()

    :crypto.hash(:sha256, "#{normalized_text}:#{context}")
    |> Base.encode16(case: :lower)
  end

  defp generate_confidence_cache_key(%{text: text, language: language}) do
    # For confidence, we care about exact code structure
    :crypto.hash(:sha256, "confidence:#{text}:#{language}")
    |> Base.encode16(case: :lower)
  end

  defp remove_extra_whitespace(text) do
    String.replace(text, ~r/\s+/, " ")
  end

  defp check_similar_requests(request) do
    # For now, just return miss - could implement fuzzy matching later
    {:miss, :not_found}
  end

  defp cleanup_expired_entries do
    now = DateTime.utc_now()

    match_spec = [
      {{:_, :_, :"$1"}, [{:<, :"$1", {:const, now}}], [true]}
    ]

    deleted_count = :ets.select_delete(@cache_table, match_spec)
    Logger.info("Cleaned up #{deleted_count} expired AI cache entries")
  end

  # Cache statistics for monitoring
  def cache_stats do
    total_entries = :ets.info(@cache_table, :size)
    memory_usage = :ets.info(@cache_table, :memory) * :erlang.system_info(:wordsize)

    %{
      total_entries: total_entries,
      memory_bytes: memory_usage,
      memory_mb: Float.round(memory_usage / 1024 / 1024, 2)
    }
  end
end
