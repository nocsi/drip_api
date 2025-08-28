defmodule Dirup.Markdown.Pipeline.Context do
  @moduledoc """
  Context state management for markdown pipeline processing.

  Maintains state throughout the middleware chain, including content,
  metadata, detected threats, capabilities, and processing results.
  """

  alias Dirup.Markdown.Pipeline.Result

  @type t :: %__MODULE__{
          content: String.t(),
          original_content: String.t(),
          metadata: map(),
          threats: [map()],
          capabilities: [map()],
          transformations: [map()],
          metrics: map(),
          config: map(),
          errors: [map()],
          warnings: [map()]
        }

  defstruct [
    :content,
    :original_content,
    :metadata,
    :threats,
    :capabilities,
    :transformations,
    :metrics,
    :config,
    :errors,
    :warnings
  ]

  @doc """
  Create a new pipeline context.
  """
  @spec new(String.t(), map()) :: t()
  def new(content, config) do
    %__MODULE__{
      content: content,
      original_content: content,
      metadata: %{
        content_length: String.length(content),
        processing_started_at: DateTime.utc_now(),
        pipeline_mode: Map.get(config, :mode, :unknown)
      },
      threats: [],
      capabilities: [],
      transformations: [],
      metrics: %{
        processing_time_ms: 0,
        bytes_processed: byte_size(content),
        middleware_count: 0
      },
      config: config,
      errors: [],
      warnings: []
    }
  end

  @doc """
  Update content in the context.
  """
  @spec update_content(t(), String.t()) :: t()
  def update_content(%__MODULE__{} = context, new_content) do
    %{
      context
      | content: new_content,
        metadata: Map.put(context.metadata, :content_modified, true)
    }
  end

  @doc """
  Append content to existing content (for streaming).
  """
  @spec append_content(t(), String.t()) :: t()
  def append_content(%__MODULE__{} = context, chunk) do
    new_content = context.content <> chunk

    updated_metrics =
      Map.put(
        context.metrics,
        :bytes_processed,
        context.metrics.bytes_processed + byte_size(chunk)
      )

    %{context | content: new_content, metrics: updated_metrics}
  end

  @doc """
  Add a detected threat to the context.
  """
  @spec add_threat(t(), map()) :: t()
  def add_threat(%__MODULE__{} = context, threat) do
    threat_with_timestamp = Map.put(threat, :detected_at, DateTime.utc_now())
    %{context | threats: [threat_with_timestamp | context.threats]}
  end

  @doc """
  Add a detected capability to the context.
  """
  @spec add_capability(t(), map()) :: t()
  def add_capability(%__MODULE__{} = context, capability) do
    capability_with_timestamp = Map.put(capability, :detected_at, DateTime.utc_now())
    %{context | capabilities: [capability_with_timestamp | context.capabilities]}
  end

  @doc """
  Add a transformation record to the context.
  """
  @spec add_transformation(t(), map()) :: t()
  def add_transformation(%__MODULE__{} = context, transformation) do
    transformation_with_timestamp = Map.put(transformation, :applied_at, DateTime.utc_now())
    %{context | transformations: [transformation_with_timestamp | context.transformations]}
  end

  @doc """
  Add metadata to the context.
  """
  @spec add_metadata(t(), map()) :: t()
  def add_metadata(%__MODULE__{} = context, metadata) do
    %{context | metadata: Map.merge(context.metadata, metadata)}
  end

  @doc """
  Update processing metrics.
  """
  @spec update_metrics(t(), map()) :: t()
  def update_metrics(%__MODULE__{} = context, metrics_update) do
    %{context | metrics: Map.merge(context.metrics, metrics_update)}
  end

  @doc """
  Increment middleware processing count.
  """
  @spec increment_middleware_count(t()) :: t()
  def increment_middleware_count(%__MODULE__{} = context) do
    update_metrics(context, %{
      middleware_count: context.metrics.middleware_count + 1
    })
  end

  @doc """
  Add an error to the context.
  """
  @spec add_error(t(), map() | String.t()) :: t()
  def add_error(%__MODULE__{} = context, error) when is_binary(error) do
    add_error(context, %{message: error, severity: :error})
  end

  def add_error(%__MODULE__{} = context, error) when is_map(error) do
    error_with_timestamp = Map.put(error, :occurred_at, DateTime.utc_now())
    %{context | errors: [error_with_timestamp | context.errors]}
  end

  @doc """
  Add a warning to the context.
  """
  @spec add_warning(t(), map() | String.t()) :: t()
  def add_warning(%__MODULE__{} = context, warning) when is_binary(warning) do
    add_warning(context, %{message: warning, severity: :warning})
  end

  def add_warning(%__MODULE__{} = context, warning) when is_map(warning) do
    warning_with_timestamp = Map.put(warning, :occurred_at, DateTime.utc_now())
    %{context | warnings: [warning_with_timestamp | context.warnings]}
  end

  @doc """
  Check if context has any errors.
  """
  @spec has_errors?(t()) :: boolean()
  def has_errors?(%__MODULE__{errors: errors}), do: length(errors) > 0

  @doc """
  Check if context has any threats.
  """
  @spec has_threats?(t()) :: boolean()
  def has_threats?(%__MODULE__{threats: threats}), do: length(threats) > 0

  @doc """
  Check if context has any capabilities.
  """
  @spec has_capabilities?(t()) :: boolean()
  def has_capabilities?(%__MODULE__{capabilities: capabilities}), do: length(capabilities) > 0

  @doc """
  Get threat level based on detected threats.
  """
  @spec threat_level(t()) :: :none | :low | :medium | :high | :critical
  def threat_level(%__MODULE__{threats: []}), do: :none

  def threat_level(%__MODULE__{threats: threats}) do
    max_severity =
      threats
      |> Enum.map(&Map.get(&1, :severity, :low))
      |> Enum.max_by(&severity_to_int/1)

    max_severity
  end

  @doc """
  Convert context to result for API response.
  """
  @spec to_result(t()) :: Result.t()
  def to_result(%__MODULE__{} = context) do
    processing_time = calculate_processing_time(context)

    %Result{
      content: context.content,
      safe: not has_threats?(context) and not has_errors?(context),
      threat_level: threat_level(context),
      threats: Enum.reverse(context.threats),
      capabilities: Enum.reverse(context.capabilities),
      transformations: Enum.reverse(context.transformations),
      metadata: Map.put(context.metadata, :processing_completed_at, DateTime.utc_now()),
      metrics: Map.put(context.metrics, :total_processing_time_ms, processing_time),
      errors: Enum.reverse(context.errors),
      warnings: Enum.reverse(context.warnings)
    }
  end

  @doc """
  Reset context for next chunk in streaming (keeps configuration).
  """
  @spec reset_for_next_chunk(t()) :: t()
  def reset_for_next_chunk(%__MODULE__{} = context) do
    %{
      context
      | content: "",
        threats: [],
        capabilities: [],
        transformations: [],
        errors: [],
        warnings: [],
        metadata: %{
          content_length: 0,
          processing_started_at: DateTime.utc_now(),
          pipeline_mode: context.metadata.pipeline_mode,
          chunk_number: Map.get(context.metadata, :chunk_number, 0) + 1
        },
        metrics: %{
          processing_time_ms: 0,
          bytes_processed: 0,
          middleware_count: 0
        }
    }
  end

  # Private functions

  defp severity_to_int(:none), do: 0
  defp severity_to_int(:low), do: 1
  defp severity_to_int(:medium), do: 2
  defp severity_to_int(:high), do: 3
  defp severity_to_int(:critical), do: 4
  defp severity_to_int(_), do: 1

  defp calculate_processing_time(%__MODULE__{metadata: metadata}) do
    started_at = Map.get(metadata, :processing_started_at)

    if started_at do
      DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
    else
      0
    end
  end
end
