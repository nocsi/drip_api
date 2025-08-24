defmodule Kyozo.MarkdownLD.StreamParser.Context do
  @moduledoc """
  Processing context for the markdown stream parser.

  The context maintains state throughout the processing pipeline,
  tracking metadata, counters, and other processing information.

  ## Usage

      context = Context.new()
        |> Context.put(:line_number, 1)
        |> Context.increment(:chunks_processed)

  """

  @type t :: %__MODULE__{
          id: String.t(),
          pipeline_id: String.t() | nil,
          stage: atom(),
          line_number: non_neg_integer(),
          chunk_count: non_neg_integer(),
          start_time: integer() | nil,
          end_time: integer() | nil,
          metadata: map(),
          counters: map(),
          plugin_results: map(),
          processing_options: map(),
          error_count: non_neg_integer(),
          warnings: [map()]
        }

  defstruct id: nil,
            pipeline_id: nil,
            stage: :init,
            line_number: 0,
            chunk_count: 0,
            start_time: nil,
            end_time: nil,
            metadata: %{},
            counters: %{},
            plugin_results: %{},
            processing_options: %{},
            error_count: 0,
            warnings: []

  @doc """
  Create a new processing context.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      id: generate_context_id(),
      start_time: System.monotonic_time(),
      metadata: Keyword.get(opts, :metadata, %{}),
      processing_options: Enum.into(opts, %{})
    }
  end

  @doc """
  Put a value in the context metadata.
  """
  @spec put(t(), atom(), term()) :: t()
  def put(%__MODULE__{} = context, key, value) do
    %{context | metadata: Map.put(context.metadata, key, value)}
  end

  @doc """
  Get a value from the context metadata.
  """
  @spec get(t(), atom(), term()) :: term()
  def get(%__MODULE__{} = context, key, default \\ nil) do
    Map.get(context.metadata, key, default)
  end

  @doc """
  Increment a counter in the context.
  """
  @spec increment(t(), atom(), integer()) :: t()
  def increment(%__MODULE__{} = context, counter_name, amount \\ 1) do
    new_counters = Map.update(context.counters, counter_name, amount, &(&1 + amount))
    %{context | counters: new_counters}
  end

  @doc """
  Get a counter value from the context.
  """
  @spec get_counter(t(), atom()) :: integer()
  def get_counter(%__MODULE__{} = context, counter_name) do
    Map.get(context.counters, counter_name, 0)
  end

  @doc """
  Update the processing stage.
  """
  @spec set_stage(t(), atom()) :: t()
  def set_stage(%__MODULE__{} = context, stage) do
    %{context | stage: stage}
  end

  @doc """
  Set the pipeline ID for tracking.
  """
  @spec set_pipeline_id(t(), String.t()) :: t()
  def set_pipeline_id(%__MODULE__{} = context, pipeline_id) do
    %{context | pipeline_id: pipeline_id}
  end

  @doc """
  Add a plugin result to the context.
  """
  @spec add_plugin_result(t(), module(), term()) :: t()
  def add_plugin_result(%__MODULE__{} = context, plugin_module, result) do
    plugin_results = Map.put(context.plugin_results, plugin_module, result)
    %{context | plugin_results: plugin_results}
  end

  @doc """
  Get a plugin result from the context.
  """
  @spec get_plugin_result(t(), module()) :: term()
  def get_plugin_result(%__MODULE__{} = context, plugin_module) do
    Map.get(context.plugin_results, plugin_module)
  end

  @doc """
  Record a processing error.
  """
  @spec add_error(t(), term()) :: t()
  def add_error(%__MODULE__{} = context, error) do
    error_entry = %{
      error: error,
      timestamp: DateTime.utc_now(),
      stage: context.stage
    }

    warnings = [error_entry | context.warnings]
    %{context | warnings: warnings, error_count: context.error_count + 1}
  end

  @doc """
  Record a processing warning.
  """
  @spec add_warning(t(), String.t(), map()) :: t()
  def add_warning(%__MODULE__{} = context, message, details \\ %{}) do
    warning_entry = %{
      type: :warning,
      message: message,
      details: details,
      timestamp: DateTime.utc_now(),
      stage: context.stage
    }

    warnings = [warning_entry | context.warnings]
    %{context | warnings: warnings}
  end

  @doc """
  Mark processing as completed.
  """
  @spec mark_completed(t()) :: t()
  def mark_completed(%__MODULE__{} = context) do
    %{context | end_time: System.monotonic_time(), stage: :completed}
  end

  @doc """
  Calculate processing duration in microseconds.
  """
  @spec duration_us(t()) :: integer()
  def duration_us(%__MODULE__{start_time: start_time, end_time: end_time})
      when not is_nil(start_time) and not is_nil(end_time) do
    System.convert_time_unit(end_time - start_time, :native, :microsecond)
  end

  def duration_us(%__MODULE__{start_time: start_time}) when not is_nil(start_time) do
    now = System.monotonic_time()
    System.convert_time_unit(now - start_time, :native, :microsecond)
  end

  def duration_us(%__MODULE__{}), do: 0

  @doc """
  Get processing statistics.
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = context) do
    %{
      id: context.id,
      pipeline_id: context.pipeline_id,
      stage: context.stage,
      duration_us: duration_us(context),
      chunks_processed: context.chunk_count,
      errors: context.error_count,
      warnings: length(context.warnings),
      counters: context.counters,
      plugin_count: map_size(context.plugin_results)
    }
  end

  @doc """
  Reset counters in the context.
  """
  @spec reset_counters(t()) :: t()
  def reset_counters(%__MODULE__{} = context) do
    %{context | counters: %{}}
  end

  @doc """
  Merge metadata from another map.
  """
  @spec merge_metadata(t(), map()) :: t()
  def merge_metadata(%__MODULE__{} = context, metadata) when is_map(metadata) do
    merged_metadata = Map.merge(context.metadata, metadata)
    %{context | metadata: merged_metadata}
  end

  @doc """
  Check if context has errors.
  """
  @spec has_errors?(t()) :: boolean()
  def has_errors?(%__MODULE__{error_count: count}), do: count > 0

  @doc """
  Check if context has warnings.
  """
  @spec has_warnings?(t()) :: boolean()
  def has_warnings?(%__MODULE__{warnings: warnings}), do: length(warnings) > 0

  @doc """
  Get all errors and warnings.
  """
  @spec get_issues(t()) :: [map()]
  def get_issues(%__MODULE__{warnings: warnings}), do: Enum.reverse(warnings)

  @doc """
  Clone context with optional modifications.
  """
  @spec clone(t(), keyword()) :: t()
  def clone(%__MODULE__{} = context, modifications \\ []) do
    Enum.reduce(modifications, context, fn
      {:stage, stage}, ctx -> set_stage(ctx, stage)
      {:pipeline_id, id}, ctx -> set_pipeline_id(ctx, id)
      {:metadata, meta}, ctx -> merge_metadata(ctx, meta)
      {:reset_counters, true}, ctx -> reset_counters(ctx)
      {key, value}, ctx -> put(ctx, key, value)
    end)
  end

  @doc """
  Convert context to a serializable map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = context) do
    %{
      id: context.id,
      pipeline_id: context.pipeline_id,
      stage: context.stage,
      line_number: context.line_number,
      chunk_count: context.chunk_count,
      start_time: context.start_time,
      end_time: context.end_time,
      metadata: context.metadata,
      counters: context.counters,
      error_count: context.error_count,
      warnings_count: length(context.warnings),
      duration_us: duration_us(context)
    }
  end

  # Private helper functions

  defp generate_context_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end
end
