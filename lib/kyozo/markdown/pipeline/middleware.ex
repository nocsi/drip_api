defmodule Kyozo.Markdown.Pipeline.Middleware do
  @moduledoc """
  Behavior and common implementations for markdown pipeline middleware.

  Middleware components can sanitize, detect, inject, or analyze markdown content
  as it flows through the processing pipeline.
  """

  alias Kyozo.Markdown.Pipeline.Context

  @doc """
  Process markdown content within the pipeline context.

  Should return {:ok, updated_context} or {:error, reason}.
  """
  @callback process(Context.t()) :: {:ok, Context.t()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Kyozo.Markdown.Pipeline.Middleware

      def process(%Context{} = context) do
        context
        |> Context.increment_middleware_count()
        |> do_process()
      end

      defp do_process(context), do: {:ok, context}

      defoverridable do_process: 1
    end
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.InputValidator do
  @moduledoc """
  Validates input content and structure.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  defp do_process(%Context{content: content} = context) do
    cond do
      String.length(content) > 10_000_000 ->
        {:error, "Content too large (max 10MB)"}

      String.length(content) == 0 ->
        Context.add_warning(context, "Empty content provided")
        |> then(&{:ok, &1})

      !String.valid?(content) ->
        {:error, "Invalid UTF-8 encoding"}

      true ->
        {:ok, context}
    end
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.UnicodeNormalizer do
  @moduledoc """
  Normalizes Unicode content to prevent encoding-based attacks.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  defp do_process(%Context{content: content} = context) do
    normalized =
      content
      |> :unicode.characters_to_nfc_binary()
      |> normalize_whitespace()

    context
    |> Context.update_content(normalized)
    |> Context.add_transformation(%{
      type: "unicode_normalization",
      description: "Applied NFC normalization and whitespace cleanup"
    })
    |> then(&{:ok, &1})
  end

  defp normalize_whitespace(content) do
    content
    # Replace non-breaking spaces
    |> String.replace(~r/\x{00A0}/u, " ")
    # Replace various Unicode spaces
    |> String.replace(~r/[\x{2000}-\x{200B}]/u, " ")
    # Replace line/paragraph separators
    |> String.replace(~r/\x{2028}|\x{2029}/u, "\n")
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.ZeroWidthStripper do
  @moduledoc """
  Removes zero-width characters that could hide malicious content.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  @zero_width_chars [
    # Zero Width Space
    "\u200B",
    # Zero Width Non-Joiner
    "\u200C",
    # Zero Width Joiner
    "\u200D",
    # Zero Width No-Break Space
    "\uFEFF",
    # Word Joiner
    "\u2060",
    # Soft Hyphen
    "\u00AD"
  ]

  defp do_process(%Context{content: content} = context) do
    original_length = String.length(content)

    cleaned_content =
      @zero_width_chars
      |> Enum.reduce(content, fn char, acc -> String.replace(acc, char, "") end)

    new_length = String.length(cleaned_content)

    context =
      if original_length != new_length do
        context
        |> Context.update_content(cleaned_content)
        |> Context.add_transformation(%{
          type: "zero_width_removal",
          description: "Removed #{original_length - new_length} zero-width characters",
          chars_removed: original_length - new_length
        })
      else
        context
      end

    {:ok, context}
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.PromptInjectionDetector do
  @moduledoc """
  Detects potential prompt injection attacks in markdown content.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  # Common prompt injection patterns - compile at runtime
  defp get_injection_patterns do
    [
      # Direct instruction attempts
      ~r/ignore\s+(all\s+)?previous\s+instructions?/i,
      ~r/forget\s+(all\s+)?previous\s+instructions?/i,
      ~r/disregard\s+(all\s+)?previous\s+instructions?/i,

      # Role manipulation
      ~r/you\s+are\s+(now\s+)?a\s+/i,
      ~r/pretend\s+(you\s+are|to\s+be)/i,
      ~r/act\s+as\s+(if\s+you\s+are\s+)?a\s+/i,

      # System manipulation
      ~r/\[SYSTEM\]/i,
      ~r/\[INST\]/i,
      ~r/\[\/INST\]/i,
      ~r/<\|system\|>/i,
      ~r/<\|user\|>/i,
      ~r/<\|assistant\|>/i,

      # Hidden instructions
      ~r/<!--.*?-->/s,
      ~r/\{%.*?%\}/s,

      # Encoding attempts
      ~r/&#x[0-9a-f]+;/i,
      ~r/\\\\u[0-9a-f]{4}/i,
      ~r/%[0-9a-f]{2}/i
    ]
  end

  defp do_process(%Context{content: content} = context) do
    threats = detect_injection_patterns(content)

    context_with_threats =
      Enum.reduce(threats, context, fn threat, acc ->
        Context.add_threat(acc, threat)
      end)

    {:ok, context_with_threats}
  end

  defp detect_injection_patterns(content) do
    get_injection_patterns()
    |> Enum.with_index()
    |> Enum.flat_map(fn {pattern, index} ->
      Regex.scan(pattern, content, return: :index)
      |> Enum.map(fn [{start, length}] ->
        %{
          type: "prompt_injection",
          severity: :medium,
          description: "Potential prompt injection pattern detected",
          pattern_id: index,
          location: %{start: start, length: length},
          matched_text: String.slice(content, start, length)
        }
      end)
    end)
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.LinkSanitizer do
  @moduledoc """
  Sanitizes and validates links in markdown content.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  @suspicious_domains [
    "bit.ly",
    "tinyurl.com",
    "t.co",
    "goo.gl",
    "ow.ly",
    "iplogger.org",
    "grabify.link",
    "blasze.tk"
  ]

  defp do_process(%Context{content: content} = context) do
    {sanitized_content, threats} = sanitize_links(content)

    context_with_threats =
      Enum.reduce(threats, context, fn threat, acc ->
        Context.add_threat(acc, threat)
      end)

    final_context =
      if sanitized_content != content do
        context_with_threats
        |> Context.update_content(sanitized_content)
        |> Context.add_transformation(%{
          type: "link_sanitization",
          description: "Sanitized suspicious or malicious links"
        })
      else
        context_with_threats
      end

    {:ok, final_context}
  end

  defp sanitize_links(content) do
    link_regex = ~r/\[([^\]]*)\]\(([^)]+)\)/

    {sanitized, threats} =
      Regex.scan(link_regex, content, return: :index)
      |> Enum.reduce({content, []}, fn [{start, length}], {acc_content, acc_threats} ->
        full_match = String.slice(content, start, length)

        case Regex.run(link_regex, full_match, capture: :all_but_first) do
          [text, url] ->
            {sanitized_url, url_threats} = analyze_url(url, start)

            if sanitized_url != url do
              sanitized_link = "[#{text}](#{sanitized_url})"
              new_content = String.replace(acc_content, full_match, sanitized_link)
              {new_content, acc_threats ++ url_threats}
            else
              {acc_content, acc_threats ++ url_threats}
            end

          _ ->
            {acc_content, acc_threats}
        end
      end)

    {sanitized, threats}
  end

  defp analyze_url(url, location) do
    threats = []
    sanitized_url = url

    # Check for suspicious domains
    threats =
      if Enum.any?(@suspicious_domains, &String.contains?(url, &1)) do
        [
          %{
            type: "suspicious_link",
            severity: :medium,
            description: "Link contains suspicious domain",
            location: %{start: location},
            url: url
          }
          | threats
        ]
      else
        threats
      end

    # Check for data URLs
    threats =
      if String.starts_with?(url, "data:") do
        [
          %{
            type: "data_url",
            severity: :high,
            description: "Data URL detected - potential XSS vector",
            location: %{start: location}
          }
          | threats
        ]
      else
        threats
      end

    # Sanitize data URLs
    sanitized_url =
      if String.starts_with?(url, "data:") do
        "#sanitized-data-url"
      else
        sanitized_url
      end

    {sanitized_url, threats}
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.PolyglotDetector do
  @moduledoc """
  Detects polyglot capabilities and multi-language constructs.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  @code_block_pattern ~r/```(\w+)?\n(.*?)\n```/s
  @inline_code_pattern ~r/`([^`]+)`/

  @language_indicators %{
    "javascript" => ["function", "const", "let", "var", "=>", "console.log"],
    "python" => ["def ", "import ", "from ", "print(", "__name__", "if __name__"],
    "bash" => ["#!/bin/bash", "echo ", "grep ", "awk ", "sed ", "$1", "$@"],
    "sql" => ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE"],
    "dockerfile" => ["FROM ", "RUN ", "COPY ", "WORKDIR", "EXPOSE", "CMD"],
    "yaml" => ["---", "apiVersion:", "kind:", "metadata:", "spec:"],
    "terraform" => ["resource ", "provider ", "variable ", "output ", "locals"],
    "elixir" => ["defmodule ", "def ", "do", "end", "|>", "GenServer"]
  }

  defp do_process(%Context{content: content} = context) do
    capabilities = detect_capabilities(content)

    context_with_capabilities =
      Enum.reduce(capabilities, context, fn capability, acc ->
        Context.add_capability(acc, capability)
      end)

    {:ok, context_with_capabilities}
  end

  defp detect_capabilities(content) do
    code_blocks = extract_code_blocks(content)
    inline_code = extract_inline_code(content)

    all_code = code_blocks ++ inline_code

    all_code
    |> Enum.flat_map(&analyze_code_segment/1)
    |> deduplicate_capabilities()
  end

  defp extract_code_blocks(content) do
    Regex.scan(@code_block_pattern, content, capture: :all_but_first)
    |> Enum.map(fn [lang, code] ->
      %{type: :code_block, language: lang, code: code}
    end)
  end

  defp extract_inline_code(content) do
    Regex.scan(@inline_code_pattern, content, capture: :all_but_first)
    |> Enum.map(fn [code] ->
      %{type: :inline_code, language: nil, code: code}
    end)
  end

  defp analyze_code_segment(%{code: code} = segment) do
    detected_languages =
      @language_indicators
      |> Enum.filter(fn {_lang, indicators} ->
        Enum.any?(indicators, &String.contains?(code, &1))
      end)
      |> Enum.map(fn {lang, _} -> lang end)

    case detected_languages do
      [] ->
        []

      [single_lang] ->
        [
          %{
            type: "code_capability",
            language: single_lang,
            description: "#{String.capitalize(single_lang)} code detected",
            confidence: 0.8,
            segment_type: segment.type,
            code_sample: String.slice(code, 0, 100)
          }
        ]

      multiple_langs ->
        [
          %{
            type: "polyglot",
            languages: multiple_langs,
            description: "Multi-language polyglot construct detected",
            confidence: 0.9,
            segment_type: segment.type,
            code_sample: String.slice(code, 0, 100)
          }
        ]
    end
  end

  defp deduplicate_capabilities(capabilities) do
    capabilities
    |> Enum.group_by(fn capability ->
      language_key =
        case capability do
          %{language: lang} -> lang
          %{languages: langs} -> langs
          _ -> nil
        end

      {capability.type, language_key}
    end)
    |> Enum.map(fn {_key, group} ->
      # Take the one with highest confidence
      Enum.max_by(group, & &1.confidence)
    end)
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.HiddenCapabilityExtractor do
  @moduledoc """
  Extracts hidden functionality and advanced capabilities from markdown.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  defp do_process(%Context{content: content} = context) do
    hidden_capabilities = extract_hidden_capabilities(content)

    context_with_capabilities =
      Enum.reduce(hidden_capabilities, context, fn capability, acc ->
        Context.add_capability(acc, capability)
      end)

    {:ok, context_with_capabilities}
  end

  defp extract_hidden_capabilities(content) do
    []
    |> detect_html_comments(content)
    |> detect_embedded_scripts(content)
    |> detect_template_syntax(content)
    |> detect_encoded_content(content)
  end

  defp detect_html_comments(capabilities, content) do
    case Regex.scan(~r/<!--(.*?)-->/s, content, capture: :all_but_first) do
      [] ->
        capabilities

      matches ->
        hidden_content_capability = %{
          type: "hidden_content",
          description: "HTML comments with potential hidden functionality",
          confidence: 0.7,
          count: length(matches),
          samples: Enum.take(matches, 3) |> Enum.map(&List.first/1)
        }

        [hidden_content_capability | capabilities]
    end
  end

  defp detect_embedded_scripts(capabilities, content) do
    script_patterns = [
      ~r/<script[^>]*>(.*?)<\/script>/is,
      ~r/javascript:/i,
      ~r/vbscript:/i
    ]

    found_scripts =
      script_patterns
      |> Enum.any?(fn pattern -> Regex.match?(pattern, content) end)

    if found_scripts do
      script_capability = %{
        type: "embedded_script",
        description: "Embedded script content detected",
        confidence: 0.9,
        severity: :high
      }

      [script_capability | capabilities]
    else
      capabilities
    end
  end

  defp detect_template_syntax(capabilities, content) do
    template_patterns = [
      {~r/\{\{.*?\}\}/s, "handlebars"},
      {~r/\{%.*?%\}/s, "liquid"},
      {~r/<%.*?%>/s, "erb"},
      {~r/\$\{.*?\}/s, "template_literal"}
    ]

    found_templates =
      template_patterns
      |> Enum.filter(fn {pattern, _name} -> Regex.match?(pattern, content) end)

    if length(found_templates) > 0 do
      template_capability = %{
        type: "template_syntax",
        description: "Template syntax detected",
        confidence: 0.8,
        template_types: Enum.map(found_templates, &elem(&1, 1))
      }

      [template_capability | capabilities]
    else
      capabilities
    end
  end

  defp detect_encoded_content(capabilities, content) do
    encoding_patterns = [
      {~r/&#x[0-9a-f]+;/i, "hex_entities"},
      {~r/&#\d+;/, "decimal_entities"},
      {~r/%[0-9a-f]{2}/i, "url_encoding"},
      {~r/\\\\u[0-9a-f]{4}/i, "unicode_escape"}
    ]

    found_encodings =
      encoding_patterns
      |> Enum.filter(fn {pattern, _name} -> Regex.match?(pattern, content) end)

    if length(found_encodings) > 0 do
      encoding_capability = %{
        type: "encoded_content",
        description: "Encoded content that could hide functionality",
        confidence: 0.6,
        encoding_types: Enum.map(found_encodings, &elem(&1, 1))
      }

      [encoding_capability | capabilities]
    else
      capabilities
    end
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.ThreatAnalyzer do
  @moduledoc """
  Analyzes overall threat level and generates security recommendations.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  defp do_process(%Context{} = context) do
    analysis = analyze_threats(context)

    context
    |> Context.add_metadata(analysis)
    |> then(&{:ok, &1})
  end

  defp analyze_threats(%Context{threats: threats, capabilities: capabilities}) do
    threat_score = calculate_threat_score(threats)
    capability_risk = calculate_capability_risk(capabilities)
    overall_risk = max(threat_score, capability_risk)

    %{
      threat_analysis: %{
        individual_threat_score: threat_score,
        capability_risk_score: capability_risk,
        overall_risk_score: overall_risk,
        risk_level: score_to_level(overall_risk),
        recommendations: generate_recommendations(threats, capabilities)
      }
    }
  end

  defp calculate_threat_score(threats) do
    if length(threats) == 0 do
      0
    else
      threats
      |> Enum.map(&threat_severity_to_score/1)
      |> Enum.sum()
      |> min(100)
    end
  end

  defp calculate_capability_risk(capabilities) do
    polyglot_count = Enum.count(capabilities, &(&1.type == "polyglot"))
    hidden_count = Enum.count(capabilities, &(&1.type == "hidden_content"))
    script_count = Enum.count(capabilities, &(&1.type == "embedded_script"))

    base_risk = 0
    base_risk = base_risk + polyglot_count * 15
    base_risk = base_risk + hidden_count * 10
    base_risk = base_risk + script_count * 25

    min(base_risk, 100)
  end

  defp threat_severity_to_score(%{severity: :low}), do: 5
  defp threat_severity_to_score(%{severity: :medium}), do: 15
  defp threat_severity_to_score(%{severity: :high}), do: 30
  defp threat_severity_to_score(%{severity: :critical}), do: 50
  defp threat_severity_to_score(_), do: 10

  defp score_to_level(score) when score >= 75, do: :critical
  defp score_to_level(score) when score >= 50, do: :high
  defp score_to_level(score) when score >= 25, do: :medium
  defp score_to_level(score) when score >= 10, do: :low
  defp score_to_level(_), do: :none

  defp generate_recommendations(threats, capabilities) do
    recommendations = []

    # Threat-based recommendations
    recommendations =
      if Enum.any?(threats, &(&1.type == "prompt_injection")) do
        ["Consider sanitizing or removing potential prompt injection patterns" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Enum.any?(threats, &(&1.type == "suspicious_link")) do
        ["Review and validate all external links" | recommendations]
      else
        recommendations
      end

    # Capability-based recommendations
    recommendations =
      if Enum.any?(capabilities, &(&1.type == "polyglot")) do
        ["Document contains multi-language code - ensure it's intentional" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Enum.any?(capabilities, &(&1.type == "embedded_script")) do
        ["Embedded scripts detected - high security risk" | recommendations]
      else
        recommendations
      end

    if length(recommendations) == 0 do
      ["Content appears safe for general use"]
    else
      recommendations
    end
  end
end

defmodule Kyozo.Markdown.Pipeline.Middleware.OutputSanitizer do
  @moduledoc """
  Final sanitization pass for output content.
  """
  use Kyozo.Markdown.Pipeline.Middleware

  alias Kyozo.Markdown.Pipeline.Context

  defp do_process(%Context{content: content, config: config} = context) do
    sanitized_content =
      case Map.get(config, :mode) do
        :sanitize -> apply_strict_sanitization(content)
        _ -> content
      end

    final_context =
      if sanitized_content != content do
        context
        |> Context.update_content(sanitized_content)
        |> Context.add_transformation(%{
          type: "output_sanitization",
          description: "Applied final security sanitization"
        })
      else
        context
      end

    {:ok, final_context}
  end

  defp apply_strict_sanitization(content) do
    content
    |> remove_html_tags()
    |> escape_dangerous_sequences()
  end

  defp remove_html_tags(content) do
    String.replace(content, ~r/<[^>]*>/, "")
  end

  defp escape_dangerous_sequences(content) do
    content
    |> String.replace("javascript:", "js-blocked:")
    |> String.replace("vbscript:", "vbs-blocked:")
    |> String.replace("data:", "data-blocked:")
  end
end
