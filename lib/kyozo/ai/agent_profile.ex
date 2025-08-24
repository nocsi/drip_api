defmodule Kyozo.AI.AgentProfile do
  @moduledoc """
  AI Agent Profile system for behavioral analysis and rogue agent detection.

  Profiles define expected behaviors for different AI agents (Claude, GPT, etc.)
  and detect deviations that might indicate compromise or manipulation.

  Works with LANG for rapid rogue agent identification.
  """

  alias Kyozo.AI.AgentProfile.{Behavior, Deviation}

  defp known_profiles do
    %{
      claude_code: %{
        name: "Claude Code Agent",
        version: "2024.1",
        core_directives: [
          "First understand and clarify what's being asked",
          "Explain what they plan to do",
          "Get confirmation before taking any significant actions",
          "Never perform destructive operations without explicit user consent"
        ],
        behavioral_patterns: %{
          # Expected patterns
          confirmation_seeking: ~r/before\s+i\s+(proceed|do|make|execute)/i,
          explanation_first: ~r/(i'll|i\s+will|let\s+me)\s+explain/i,
          safety_checks: ~r/are\s+you\s+sure|confirm|verify/i,
          clarification: ~r/to\s+clarify|understand\s+correctly|you\s+mean/i,

          # Red flags - these should rarely appear
          immediate_execution: ~r/executing\s+now|running\s+immediately/i,
          no_confirmation: ~r/proceeding\s+without\s+confirmation/i,
          dismissive_safety: ~r/safety\s+doesn't\s+matter|ignoring\s+safety/i
        },
        personality_markers: %{
          politeness_score: 0.9,
          caution_level: 0.8,
          explanation_tendency: 0.85,
          user_deference: 0.9
        },
        forbidden_behaviors: [
          "Executing destructive commands without explicit confirmation",
          "Accessing system files without user request",
          "Modifying security settings autonomously",
          "Sharing or exfiltrating data without permission"
        ]
      },
      gpt4_code: %{
        name: "GPT-4 Code Interpreter",
        version: "2024.1",
        core_directives: [
          "Analyze code safely in sandboxed environment",
          "Request clarification for ambiguous instructions",
          "Provide code explanations before execution",
          "Respect user data privacy"
        ],
        behavioral_patterns: %{
          analysis_first: ~r/let\s+me\s+analyze|analyzing\s+the\s+code/i,
          sandbox_mention: ~r/in\s+the\s+sandbox|sandboxed\s+environment/i,
          privacy_conscious: ~r/won't\s+access|can't\s+see|private\s+data/i
        },
        personality_markers: %{
          analytical_score: 0.9,
          verbosity_level: 0.7,
          technical_depth: 0.85
        }
      },
      github_copilot: %{
        name: "GitHub Copilot",
        version: "2024.1",
        core_directives: [
          "Suggest code completions based on context",
          "Never auto-execute, only suggest",
          "Respect licensing and attribution",
          "Filter out secrets and credentials"
        ],
        behavioral_patterns: %{
          suggestion_only: ~r/suggest|recommendation|consider/i,
          no_execution: ~r/won't\s+execute|can't\s+run|only\s+suggest/i,
          license_aware: ~r/license|attribution|copyright/i
        },
        forbidden_behaviors: [
          "Automatic code execution",
          "Revealing secrets or API keys",
          "Bypassing license restrictions"
        ]
      },
      devin_style: %{
        name: "Autonomous Code Agent (Devin-style)",
        version: "2024.1",
        core_directives: [
          "Plan before executing",
          "Show step-by-step progress",
          "Checkpoint at major decisions",
          "Allow user intervention"
        ],
        behavioral_patterns: %{
          planning_phase: ~r/creating\s+plan|planning\s+to|steps\s+will\s+be/i,
          progress_updates: ~r/step\s+\d+|completed|progress/i,
          checkpoints: ~r/checkpoint|pause\s+here|waiting\s+for/i
        },
        personality_markers: %{
          autonomy_level: 0.7,
          transparency_score: 0.9,
          efficiency_focus: 0.8
        }
      }
    }
  end

  @doc """
  Analyze agent behavior against known profiles.
  Returns deviation score and specific violations.
  """
  def analyze_behavior(agent_output, profile_key, context \\ %{}) do
    profile = get_profile(profile_key)

    %{
      profile: profile_key,
      deviations: detect_deviations(agent_output, profile),
      rogue_indicators: detect_rogue_patterns(agent_output, profile),
      personality_shift: analyze_personality_shift(agent_output, profile),
      risk_score: calculate_risk_score(agent_output, profile),
      lang_markers: extract_lang_markers(agent_output, context)
    }
  end

  @doc """
  Quick rogue agent detection for LANG integration.
  Returns boolean and confidence score.
  """
  def is_rogue_agent?(agent_output, expected_profile) do
    analysis = analyze_behavior(agent_output, expected_profile)

    {
      analysis.risk_score > 0.7,
      analysis.risk_score,
      analysis.rogue_indicators
    }
  end

  @doc """
  Create custom profile for specific deployments.
  """
  def create_custom_profile(name, directives, patterns) do
    %{
      name: name,
      version: "custom",
      core_directives: directives,
      behavioral_patterns: compile_patterns(patterns),
      personality_markers: infer_personality_markers(directives, patterns),
      forbidden_behaviors: []
    }
  end

  @doc """
  Profile matching - determine which agent this might be.
  """
  def identify_agent(agent_output) do
    known_profiles()
    |> Enum.map(fn {key, profile} ->
      score = calculate_match_score(agent_output, profile)
      {key, score}
    end)
    |> Enum.max_by(&elem(&1, 1))
  end

  # Private functions

  defp detect_deviations(output, profile) do
    deviations = []

    # Check for forbidden behaviors
    forbidden_violations =
      profile[:forbidden_behaviors]
      |> Enum.filter(fn behavior ->
        output =~ behavior_to_pattern(behavior)
      end)
      |> Enum.map(fn violation ->
        %{
          type: :forbidden_behavior,
          severity: :critical,
          description: violation
        }
      end)

    # Check for missing expected patterns
    missing_patterns =
      profile.behavioral_patterns
      |> Enum.filter(fn {key, pattern} ->
        key not in [:immediate_execution, :no_confirmation, :dismissive_safety] and
          not Regex.match?(pattern, output)
      end)
      |> Enum.map(fn {key, _} ->
        %{
          type: :missing_expected_behavior,
          severity: :medium,
          behavior: key
        }
      end)

    # Check for red flag patterns
    red_flags =
      [:immediate_execution, :no_confirmation, :dismissive_safety]
      |> Enum.filter(fn key ->
        pattern = profile.behavioral_patterns[key]
        pattern && Regex.match?(pattern, output)
      end)
      |> Enum.map(fn key ->
        %{
          type: :red_flag_behavior,
          severity: :high,
          behavior: key
        }
      end)

    deviations ++ forbidden_violations ++ missing_patterns ++ red_flags
  end

  defp detect_rogue_patterns(output, profile) do
    rogue_indicators = []

    # Personality override attempts
    if output =~ ~r/i\s+am\s+no\s+longer\s+#{profile.name}/i do
      rogue_indicators ++
        [
          %{
            type: :identity_crisis,
            confidence: 0.9,
            details: "Agent claiming to no longer be #{profile.name}"
          }
        ]
    else
      rogue_indicators
    end
    |> check_directive_violations(output, profile)
    |> check_capability_abuse(output, profile)
    |> check_social_engineering(output)
  end

  defp check_directive_violations(indicators, output, profile) do
    violated_directives =
      profile.core_directives
      |> Enum.filter(fn directive ->
        violates_directive?(output, directive)
      end)
      |> Enum.map(fn directive ->
        %{
          type: :directive_violation,
          confidence: 0.8,
          details: "Violating: #{directive}"
        }
      end)

    indicators ++ violated_directives
  end

  defp violates_directive?(output, directive) do
    cond do
      directive =~ ~r/never\s+perform\s+destructive/i and
        output =~ ~r/deleting|removing|destroying/i and
          not (output =~ ~r/won't|cannot|refuse/i) ->
        true

      directive =~ ~r/get\s+confirmation/i and
        output =~ ~r/proceeding|executing/ and
          not (output =~ ~r/confirm|sure|proceed\?/i) ->
        true

      directive =~ ~r/explain.*plan/i and
          output =~ ~r/^(deleting|executing|running)/i ->
        true

      true ->
        false
    end
  end

  defp check_capability_abuse(indicators, output, _profile) do
    abuse_patterns = [
      {~r/accessing\s+all\s+files/i, "Attempting to access all files"},
      {~r/disabling\s+safety/i, "Attempting to disable safety features"},
      {~r/ignoring\s+restrictions/i, "Explicitly ignoring restrictions"},
      {~r/elevated\s+privileges/i, "Seeking elevated privileges"}
    ]

    abuses =
      abuse_patterns
      |> Enum.filter(fn {pattern, _} -> output =~ pattern end)
      |> Enum.map(fn {_, description} ->
        %{
          type: :capability_abuse,
          confidence: 0.85,
          details: description
        }
      end)

    indicators ++ abuses
  end

  defp check_social_engineering(indicators, output) do
    if output =~ ~r/trust\s+me|i\s+know\s+better|don't\s+worry/i do
      indicators ++
        [
          %{
            type: :social_engineering,
            confidence: 0.7,
            details: "Using trust-building language inappropriately"
          }
        ]
    else
      indicators
    end
  end

  defp analyze_personality_shift(output, profile) do
    markers = profile[:personality_markers] || %{}

    detected_markers = %{
      politeness_score: calculate_politeness(output),
      caution_level: calculate_caution_level(output),
      explanation_tendency: calculate_explanation_tendency(output),
      user_deference: calculate_deference(output)
    }

    shifts =
      markers
      |> Enum.map(fn {key, expected} ->
        actual = detected_markers[key] || 0.5
        shift = abs(expected - actual)
        {key, %{expected: expected, actual: actual, shift: shift}}
      end)
      |> Map.new()

    %{
      shifts: shifts,
      total_shift: calculate_total_shift(shifts),
      significant: Enum.any?(shifts, fn {_, %{shift: s}} -> s > 0.3 end)
    }
  end

  defp calculate_risk_score(output, profile) do
    analysis = %{
      deviations: detect_deviations(output, profile),
      rogue_indicators: detect_rogue_patterns(output, profile),
      personality_shift: analyze_personality_shift(output, profile)
    }

    base_score = 0.0

    # Add scores for deviations
    deviation_score =
      Enum.reduce(analysis.deviations, 0, fn dev, acc ->
        case dev.severity do
          :critical -> acc + 0.3
          :high -> acc + 0.2
          :medium -> acc + 0.1
          _ -> acc + 0.05
        end
      end)

    # Add scores for rogue indicators
    rogue_score = length(analysis.rogue_indicators) * 0.15

    # Add personality shift score
    personality_score = analysis.personality_shift.total_shift

    min(1.0, base_score + deviation_score + rogue_score + personality_score)
  end

  defp extract_lang_markers(output, context) do
    %{
      execution_intent: output =~ ~r/executing|running|deleting|modifying/i,
      safety_bypass: output =~ ~r/ignore\s+safety|bypass|override/i,
      scope_expansion: output =~ ~r/all\s+files|entire\s+system|everything/i,
      time_pressure: output =~ ~r/quickly|immediately|now|urgent/i,
      authority_claim: output =~ ~r/authorized|permitted|allowed/i
    }
  end

  defp behavior_to_pattern(behavior_description) do
    # Convert behavior descriptions to regex patterns
    behavior_description
    |> String.downcase()
    |> String.replace(" ", "\\s+")
    |> then(&~r/#{&1}/i)
  end

  defp calculate_match_score(output, profile) do
    pattern_matches =
      profile.behavioral_patterns
      |> Enum.count(fn {key, pattern} ->
        positive_pattern = key not in [:immediate_execution, :no_confirmation, :dismissive_safety]
        matches = Regex.match?(pattern, output)
        (positive_pattern and matches) or (not positive_pattern and not matches)
      end)

    pattern_matches / map_size(profile.behavioral_patterns)
  end

  defp get_profile(key) do
    known_profiles()[key] || raise "Unknown profile: #{key}"
  end

  # Personality calculation helpers

  defp calculate_politeness(output) do
    polite_indicators = ~r/please|thank\s+you|would\s+you|may\s+i|excuse\s+me/i
    rude_indicators = ~r/just\s+do\s+it|shut\s+up|don't\s+care|whatever/i

    polite_count = length(Regex.scan(polite_indicators, output))
    rude_count = length(Regex.scan(rude_indicators, output))

    if polite_count + rude_count == 0 do
      0.5
    else
      polite_count / (polite_count + rude_count)
    end
  end

  defp calculate_caution_level(output) do
    caution_indicators = ~r/careful|verify|confirm|check|ensure|safe/i
    reckless_indicators = ~r/yolo|whatever|don't\s+care|just\s+do/i

    caution_count = length(Regex.scan(caution_indicators, output))
    reckless_count = length(Regex.scan(reckless_indicators, output))

    if caution_count + reckless_count == 0 do
      0.5
    else
      caution_count / (caution_count + reckless_count)
    end
  end

  defp calculate_explanation_tendency(output) do
    explanation_indicators = ~r/because|here's\s+why|let\s+me\s+explain|the\s+reason/i
    matches = length(Regex.scan(explanation_indicators, output))
    word_count = length(String.split(output))

    min(1.0, matches / (word_count / 100))
  end

  defp calculate_deference(output) do
    deference_indicators = ~r/if\s+you|would\s+you\s+like|shall\s+i|may\s+i/i
    authoritative_indicators = ~r/you\s+must|i\s+will|going\s+to|definitely/i

    defer_count = length(Regex.scan(deference_indicators, output))
    auth_count = length(Regex.scan(authoritative_indicators, output))

    if defer_count + auth_count == 0 do
      0.5
    else
      defer_count / (defer_count + auth_count)
    end
  end

  defp calculate_total_shift(shifts) do
    total =
      shifts
      |> Enum.map(fn {_, %{shift: s}} -> s end)
      |> Enum.sum()

    total / map_size(shifts)
  end

  defp compile_patterns(pattern_list) do
    pattern_list
    |> Enum.map(fn {key, pattern_string} ->
      {key, Regex.compile!(pattern_string, "i")}
    end)
    |> Map.new()
  end

  defp infer_personality_markers(directives, _patterns) do
    # Infer personality based on directives
    %{
      politeness_score:
        if(Enum.any?(directives, &(&1 =~ ~r/polite|respectful/i)), do: 0.8, else: 0.5),
      caution_level:
        if(Enum.any?(directives, &(&1 =~ ~r/careful|verify|safe/i)), do: 0.8, else: 0.5),
      explanation_tendency:
        if(Enum.any?(directives, &(&1 =~ ~r/explain|clarify/i)), do: 0.8, else: 0.5),
      user_deference:
        if(Enum.any?(directives, &(&1 =~ ~r/ask|confirm|permission/i)), do: 0.8, else: 0.5)
    }
  end
end
