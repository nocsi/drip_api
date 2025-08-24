defmodule Kyozo.Markdown.Pipeline.Result do
  @moduledoc """
  Result structure for markdown pipeline processing output.

  Contains the processed content, security analysis, detected capabilities,
  and comprehensive metadata about the processing pipeline.
  """

  @type threat_level :: :none | :low | :medium | :high | :critical
  @type processing_mode :: :sanitize | :inject | :detect | :analyze | :custom

  @type t :: %__MODULE__{
          content: String.t(),
          safe: boolean(),
          threat_level: threat_level(),
          threats: [map()],
          capabilities: [map()],
          transformations: [map()],
          metadata: map(),
          metrics: map(),
          errors: [map()],
          warnings: [map()]
        }

  defstruct [
    :content,
    :safe,
    :threat_level,
    :threats,
    :capabilities,
    :transformations,
    :metadata,
    :metrics,
    :errors,
    :warnings
  ]

  @doc """
  Create a new result with safe defaults.
  """
  @spec new(String.t()) :: t()
  def new(content) do
    %__MODULE__{
      content: content,
      safe: true,
      threat_level: :none,
      threats: [],
      capabilities: [],
      transformations: [],
      metadata: %{
        created_at: DateTime.utc_now()
      },
      metrics: %{
        processing_time_ms: 0,
        bytes_processed: byte_size(content)
      },
      errors: [],
      warnings: []
    }
  end

  @doc """
  Convert result to JSON-compatible map for API responses.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = result) do
    %{
      content: result.content,
      safe: result.safe,
      threat_level: result.threat_level,
      summary: %{
        threats_detected: length(result.threats),
        capabilities_found: length(result.capabilities),
        transformations_applied: length(result.transformations),
        has_errors: length(result.errors) > 0,
        has_warnings: length(result.warnings) > 0
      },
      threats: result.threats,
      capabilities: result.capabilities,
      transformations: result.transformations,
      metadata: result.metadata,
      metrics: result.metrics,
      errors: result.errors,
      warnings: result.warnings
    }
  end

  @doc """
  Convert result to SafeMD API format (public security focus).
  """
  @spec to_safemd_json(t()) :: map()
  def to_safemd_json(%__MODULE__{} = result) do
    %{
      safe: result.safe,
      threat_level: result.threat_level,
      threats_detected: length(result.threats),
      content_modified: content_was_modified?(result),
      threats: sanitize_threats_for_public(result.threats),
      processing_time_ms: get_in(result.metrics, [:processing_time_ms]) || 0,
      content_size_bytes: get_in(result.metrics, [:bytes_processed]) || 0
    }
    |> maybe_add_sanitized_content(result)
    |> maybe_add_warnings(result)
  end

  @doc """
  Convert result to research mode format (includes capabilities).
  """
  @spec to_research_json(t()) :: map()
  def to_research_json(%__MODULE__{} = result) do
    base_json = to_safemd_json(result)

    Map.merge(base_json, %{
      capabilities_detected: length(result.capabilities),
      capabilities: sanitize_capabilities_for_research(result.capabilities),
      polyglot_features: extract_polyglot_features(result.capabilities),
      hidden_functionality: extract_hidden_functionality(result.threats)
    })
  end

  @doc """
  Check if the result indicates successful processing.
  """
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{errors: []}), do: true
  def success?(%__MODULE__{}), do: false

  @doc """
  Get highest severity issue (threat or error).
  """
  @spec highest_severity(t()) :: threat_level()
  def highest_severity(%__MODULE__{} = result) do
    threat_severity = result.threat_level

    error_severity =
      result.errors
      |> Enum.map(&Map.get(&1, :severity, :medium))
      |> Enum.max_by(&severity_to_int/1, fn -> :none end)

    max_severity(threat_severity, error_severity)
  end

  @doc """
  Calculate security score (0-100, higher is safer).
  """
  @spec security_score(t()) :: integer()
  def security_score(%__MODULE__{} = result) do
    base_score = 100

    # Deduct points for threats
    threat_deduction =
      case result.threat_level do
        :none -> 0
        :low -> 10
        :medium -> 25
        :high -> 50
        :critical -> 80
      end

    # Deduct points for errors
    error_deduction = min(length(result.errors) * 5, 20)

    # Deduct points for warnings
    warning_deduction = min(length(result.warnings) * 2, 10)

    max(0, base_score - threat_deduction - error_deduction - warning_deduction)
  end

  @doc """
  Get processing summary for logging/monitoring.
  """
  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = result) do
    %{
      safe: result.safe,
      threat_level: result.threat_level,
      security_score: security_score(result),
      threats_count: length(result.threats),
      capabilities_count: length(result.capabilities),
      processing_time_ms: get_in(result.metrics, [:processing_time_ms]) || 0,
      content_size_bytes: get_in(result.metrics, [:bytes_processed]) || 0,
      success: success?(result)
    }
  end

  # Private functions

  defp content_was_modified?(%__MODULE__{transformations: []}), do: false
  defp content_was_modified?(%__MODULE__{transformations: _}), do: true

  defp maybe_add_sanitized_content(json, %__MODULE__{safe: false}) do
    # Don't include content if unsafe
    json
  end

  defp maybe_add_sanitized_content(json, %__MODULE__{content: content}) do
    Map.put(json, :sanitized_content, content)
  end

  defp maybe_add_warnings(json, %__MODULE__{warnings: []}) do
    json
  end

  defp maybe_add_warnings(json, %__MODULE__{warnings: warnings}) do
    public_warnings =
      Enum.map(warnings, fn warning ->
        %{
          message: Map.get(warning, :message, "Processing warning"),
          severity: Map.get(warning, :severity, :warning)
        }
      end)

    Map.put(json, :warnings, public_warnings)
  end

  defp sanitize_threats_for_public(threats) do
    Enum.map(threats, fn threat ->
      %{
        type: Map.get(threat, :type, "unknown"),
        severity: Map.get(threat, :severity, :low),
        description: Map.get(threat, :description, "Potential security issue detected"),
        location: Map.get(threat, :location, %{})
      }
    end)
  end

  defp sanitize_capabilities_for_research(capabilities) do
    Enum.map(capabilities, fn capability ->
      language =
        case capability do
          %{language: lang} -> lang
          %{languages: [first_lang | _]} -> first_lang
          %{languages: langs} when is_list(langs) -> Enum.join(langs, ", ")
          _ -> "unknown"
        end

      %{
        type: Map.get(capability, :type, "unknown"),
        language: language,
        description: Map.get(capability, :description, "Capability detected"),
        confidence: Map.get(capability, :confidence, 0.5)
      }
    end)
  end

  defp extract_polyglot_features(capabilities) do
    capabilities
    |> Enum.filter(&(Map.get(&1, :type) == "polyglot"))
    |> Enum.map(&Map.get(&1, :feature, "unknown"))
    |> Enum.uniq()
  end

  defp extract_hidden_functionality(threats) do
    threats
    |> Enum.filter(&(Map.get(&1, :type) == "hidden_functionality"))
    |> Enum.map(&Map.get(&1, :functionality, "unknown"))
    |> Enum.uniq()
  end

  defp severity_to_int(:none), do: 0
  defp severity_to_int(:low), do: 1
  defp severity_to_int(:medium), do: 2
  defp severity_to_int(:high), do: 3
  defp severity_to_int(:critical), do: 4
  defp severity_to_int(_), do: 1

  defp max_severity(sev1, sev2) do
    if severity_to_int(sev1) >= severity_to_int(sev2), do: sev1, else: sev2
  end
end
