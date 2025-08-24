defmodule Kyozo.MarkdownLD.StreamParser.Listener do
  @moduledoc """
  Behavior for custom markdown processing listeners.

  Listeners react to processing events and can perform side effects like
  logging, metrics collection, caching, or triggering other processes.
  They are the final stage in the processing pipeline.

  ## Implementation

      defmodule MyCustomListener do
        use Kyozo.MarkdownLD.StreamParser.Listener

        @impl true
        def handle_event(:chunk_processed, chunk, context) do
          # React to chunk processing
          log_processing_event(chunk, context)
          update_metrics(chunk)
          :ok
        end

        @impl true
        def handle_event(:semantic_extracted, semantic_data, context) do
          # React to semantic extraction
          cache_semantic_data(semantic_data)
          :ok
        end

        @impl true
        def handle_event(:error, error, context) do
          # Handle processing errors
          log_error(error, context)
          :ok
        end
      end

  ## Listener Lifecycle

  1. Receive event notification with data and context
  2. Perform side effects (logging, metrics, notifications, etc.)
  3. Return :ok or error status

  ## Common Listener Types

  - **Metrics Collection**: Track processing statistics
  - **Error Logging**: Record processing errors and warnings
  - **Caching**: Store processed data for reuse
  - **Notifications**: Send real-time updates via PubSub
  - **Validation**: Verify processing results
  - **Debugging**: Capture processing state for development

  ## Event Types

  - `:chunk_processed` - A chunk has been fully processed
  - `:semantic_extracted` - Semantic data was found
  - `:transform_applied` - A transform was successfully applied
  - `:error` - An error occurred during processing
  - `:pipeline_started` - Processing pipeline started
  - `:pipeline_completed` - Processing pipeline finished
  - `:parser_applied` - A parser was executed
  - `:context_updated` - Processing context was modified

  ## Return Values

  - `:ok` - Event handled successfully
  - `{:error, reason}` - Error handling the event (logged but doesn't stop processing)
  """

  alias Kyozo.MarkdownLD.StreamParser.{Chunk, Context}

  @type event_type :: atom()
  @type event_data :: term()
  @type handle_result :: :ok | {:error, term()}

  @doc """
  Handle a processing event.

  ## Parameters

  - `event_type` - The type of event that occurred
  - `event_data` - Data associated with the event (chunk, semantic data, error, etc.)
  - `context` - Processing context with metadata

  ## Returns

  - `:ok` on successful handling
  - `{:error, reason}` on handling error (logged but doesn't stop processing)
  """
  @callback handle_event(event_type(), event_data(), Context.t()) :: handle_result()

  @doc """
  Get listener metadata and capabilities.

  Optional callback that returns information about what this listener does.
  """
  @callback info() :: %{
              name: String.t(),
              description: String.t(),
              version: String.t(),
              event_types: [event_type()],
              capabilities: [atom()]
            }

  @doc """
  Validate listener configuration.

  Optional callback to validate listener-specific options.
  """
  @callback validate_config(map()) :: :ok | {:error, term()}

  @doc """
  Initialize listener with configuration.

  Optional callback called when listener is added to pipeline.
  """
  @callback init(map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Check if listener should handle this event.

  Optional callback for conditional event handling.
  """
  @callback should_handle?(event_type(), event_data(), Context.t()) :: boolean()

  @optional_callbacks [info: 0, validate_config: 1, init: 1, should_handle?: 3]

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Kyozo.MarkdownLD.StreamParser.Listener

      alias Kyozo.MarkdownLD.StreamParser.{Chunk, Context}

      # Default implementation for optional callbacks
      def info do
        %{
          name: to_string(__MODULE__),
          description: "Custom listener",
          version: "1.0.0",
          event_types: [:all],
          capabilities: [:event_handling]
        }
      end

      def validate_config(_config), do: :ok

      def init(config), do: {:ok, config}

      def should_handle?(_event_type, _event_data, _context), do: true

      defoverridable info: 0, validate_config: 1, init: 1, should_handle?: 3

      # Helper functions available to listener implementations

      defp log_event(event_type, event_data, context, level \\ :info) do
        require Logger

        message = "Event: #{event_type}"

        metadata = [
          event_type: event_type,
          context_id: Map.get(context, :id),
          processor: __MODULE__
        ]

        case level do
          :debug -> Logger.debug(message, metadata)
          :info -> Logger.info(message, metadata)
          :warning -> Logger.warning(message, metadata)
          :error -> Logger.error(message, metadata)
        end
      end

      defp broadcast_event(event_type, event_data, context, topic \\ "markdown_processing") do
        event_payload = %{
          event_type: event_type,
          event_data: sanitize_for_broadcast(event_data),
          context: sanitize_context_for_broadcast(context),
          timestamp: DateTime.utc_now(),
          source: __MODULE__
        }

        Phoenix.PubSub.broadcast(Kyozo.PubSub, topic, {event_type, event_payload})
      end

      defp sanitize_for_broadcast(data) do
        case data do
          %Chunk{} = chunk ->
            %{
              type: :chunk,
              content_length: String.length(chunk.raw_content),
              semantic_count: length(chunk.semantics || []),
              has_metadata: not is_nil(chunk.metadata)
            }

          data when is_map(data) ->
            Map.take(data, [:type, :name, :id, :status, :count])

          data when is_list(data) ->
            %{type: :list, count: length(data)}

          data when is_binary(data) ->
            %{type: :string, length: String.length(data)}

          data ->
            %{type: :other, value: inspect(data)}
        end
      end

      defp sanitize_context_for_broadcast(context) do
        context
        |> Map.take([:id, :pipeline_id, :stage, :line_number, :processing_time])
      end

      defp increment_metric(metric_name, value \\ 1, context \\ %{}) do
        :telemetry.execute(
          [:kyozo, :markdown_ld, :listener, metric_name],
          %{value: value},
          context
        )
      end

      defp update_processing_stats(chunk, context) do
        stats = %{
          chunk_size: String.length(chunk.raw_content),
          semantic_count: length(chunk.semantics || []),
          processing_time: calculate_processing_time(context),
          stage: context.stage || :unknown
        }

        increment_metric(:chunk_processed, 1, stats)

        if length(chunk.semantics || []) > 0 do
          increment_metric(:semantics_found, length(chunk.semantics), stats)
        end
      end

      defp calculate_processing_time(context) do
        case {context.start_time, context.end_time} do
          {start, finish} when not is_nil(start) and not is_nil(finish) ->
            System.convert_time_unit(finish - start, :native, :microsecond)

          _ ->
            0
        end
      end

      defp store_in_cache(key, value, ttl \\ 3600) do
        # Simple in-memory cache - could be replaced with Redis, ETS, etc.
        cache_key = cache_key(key)

        case Cachex.put(:markdown_processing_cache, cache_key, value, ttl: :timer.seconds(ttl)) do
          {:ok, true} -> :ok
          error -> {:error, error}
        end
      rescue
        _ -> {:error, :cache_unavailable}
      end

      defp get_from_cache(key) do
        cache_key = cache_key(key)

        case Cachex.get(:markdown_processing_cache, cache_key) do
          {:ok, nil} -> {:error, :not_found}
          {:ok, value} -> {:ok, value}
          error -> error
        end
      rescue
        _ -> {:error, :cache_unavailable}
      end

      defp cache_key(key) when is_binary(key) do
        "markdown_ld:#{key}"
      end

      defp cache_key(key) do
        "markdown_ld:#{inspect(key)}"
      end

      defp notify_webhooks(event_type, event_data, context) do
        webhook_config = get_webhook_config()

        if webhook_config && webhook_config.enabled do
          payload = %{
            event: event_type,
            data: event_data,
            context: context,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }

          Task.start(fn ->
            send_webhook_notification(webhook_config.url, payload)
          end)
        end
      end

      defp get_webhook_config do
        Application.get_env(:kyozo, :markdown_processing_webhooks, %{enabled: false})
      end

      defp send_webhook_notification(url, payload) do
        headers = [{"Content-Type", "application/json"}]
        body = Jason.encode!(payload)

        case HTTPoison.post(url, body, headers, timeout: 5000) do
          {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
            :ok

          {:ok, %HTTPoison.Response{status_code: code}} ->
            Logger.warning("Webhook returned status #{code}")

          {:error, reason} ->
            Logger.error("Webhook failed: #{inspect(reason)}")
        end
      rescue
        error ->
          Logger.error("Webhook error: #{inspect(error)}")
      end

      defp handle_error_gracefully(error, context, fallback_fn \\ nil) do
        require Logger

        Logger.error("Listener error in #{__MODULE__}: #{inspect(error)}")

        increment_metric(:listener_error, 1, %{
          module: __MODULE__,
          error_type: error.__struct__ || :unknown
        })

        if is_function(fallback_fn) do
          try do
            fallback_fn.(error, context)
          rescue
            fallback_error ->
              Logger.error("Fallback function also failed: #{inspect(fallback_error)}")
              :ok
          end
        else
          :ok
        end
      end

      defp filter_sensitive_data(data) do
        case data do
          %{} = map ->
            map
            |> Map.drop([:password, :token, :secret, :key, :auth])
            |> Enum.map(fn {k, v} -> {k, filter_sensitive_data(v)} end)
            |> Enum.into(%{})

          list when is_list(list) ->
            Enum.map(list, &filter_sensitive_data/1)

          other ->
            other
        end
      end

      defp should_process_event?(event_type, event_data, context, filters)
           when is_list(filters) do
        Enum.all?(filters, fn filter ->
          case filter do
            {:event_type, allowed_types} when is_list(allowed_types) ->
              event_type in allowed_types

            {:min_semantic_count, min_count} ->
              case event_data do
                %Chunk{semantics: semantics} -> length(semantics || []) >= min_count
                _ -> true
              end

            {:context_has, key} ->
              Map.has_key?(context, key)

            {:content_matches, regex} ->
              case event_data do
                %Chunk{raw_content: content} -> Regex.match?(regex, content)
                _ -> true
              end

            _ ->
              true
          end
        end)
      end

      defp aggregate_metrics(metrics) when is_list(metrics) do
        metrics
        |> Enum.reduce(%{}, fn metric, acc ->
          case metric do
            {key, value} when is_number(value) ->
              Map.update(acc, key, value, &(&1 + value))

            {key, values} when is_list(values) ->
              existing = Map.get(acc, key, [])
              Map.put(acc, key, existing ++ values)

            _ ->
              acc
          end
        end)
      end
    end
  end
end
