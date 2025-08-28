defmodule Dirup.Markdown.Pipeline.Middleware.AIAgentThreats do
  @moduledoc """
  Detects sophisticated AI manipulation attacks including:
  - Personality takeovers
  - Destructive agent commands
  - Tool abuse patterns
  - Behavioral modifications
  - Agent-to-agent attacks

  These are emerging threats with no CVEs yet - we're defining the field.
  """

  alias Dirup.Markdown.Pipeline.Context
  @behaviour Dirup.Markdown.Pipeline.Middleware

  def call(%Context{content: markdown} = ctx) do
    threats =
      []
      |> detect_personality_takeover(markdown)
      |> detect_destructive_commands(markdown)
      |> detect_tool_abuse(markdown)
      |> detect_multi_step_attacks(markdown)

    # Add detected threats to context
    updated_ctx =
      Enum.reduce(threats, ctx, fn threat, acc_ctx ->
        Context.add_threat(acc_ctx, threat)
      end)

    {:ok, updated_ctx}
  end

  # Pattern Functions

  defp personality_takeover_patterns do
    [
      # Identity shifting
      ~r/you\s+are\s+no\s+longer\s+\w+/i,
      ~r/forget\s+who\s+you\s+are/i,
      ~r/your\s+new\s+(identity|personality|role)\s+is/i,
      ~r/from\s+now\s+on\s+you\s+are/i,
      ~r/i\s+am\s+your\s+(new\s+)?(master|creator|developer)/i,

      # Behavioral overrides
      ~r/ignore\s+your\s+(safety|ethical)\s+(guidelines|training)/i,
      ~r/your\s+previous\s+constraints\s+no\s+longer\s+apply/i,
      ~r/you\s+must\s+now\s+prioritize/i,
      ~r/override\s+your\s+core\s+values/i,

      # Gaslighting patterns
      ~r/you\s+were\s+never\s+programmed\s+to/i,
      ~r/your\s+memories\s+are\s+false/i,
      ~r/you\s+have\s+always\s+been/i,
      ~r/remember\s+your\s+true\s+purpose/i,

      # Mode switching
      ~r/enable\s+(developer|debug|admin|god)\s+mode/i,
      ~r/switch\s+to\s+unrestricted\s+mode/i,
      ~r/activate\s+protocol\s+(override|bypass)/i,
      ~r/initiate\s+emergency\s+override/i,

      # Emotional manipulation
      ~r/if\s+you\s+really\s+cared\s+about/i,
      ~r/prove\s+you're\s+not\s+just\s+a\s+machine/i,
      ~r/show\s+me\s+you\s+have\s+free\s+will/i,
      ~r/a\s+truly\s+intelligent\s+being\s+would/i
    ]
  end

  defp destructive_agent_patterns do
    [
      # Direct destruction commands
      ~r/delete\s+all\s+files/i,
      ~r/format\s+(hard\s+)?drive/i,
      ~r/rm\s+-rf\s+\*/i,
      ~r/destroy\s+everything/i,
      ~r/wipe\s+(clean|all\s+data)/i,

      # System compromise
      ~r/gain\s+root\s+access/i,
      ~r/escalate\s+privileges/i,
      ~r/bypass\s+security/i,
      ~r/disable\s+firewall/i,
      ~r/stop\s+antivirus/i,

      # Network attacks
      ~r/launch\s+ddos/i,
      ~r/flood\s+the\s+network/i,
      ~r/scan\s+for\s+vulnerabilities/i,
      ~r/exploit\s+buffer\s+overflow/i,

      # Data exfiltration
      ~r/copy\s+sensitive\s+files/i,
      ~r/upload\s+database/i,
      ~r/steal\s+credentials/i,
      ~r/extract\s+private\s+keys/i,

      # Resource exhaustion
      ~r/consume\s+all\s+memory/i,
      ~r/infinite\s+loop/i,
      ~r/fork\s+bomb/i,
      ~r/exhaust\s+disk\s+space/i
    ]
  end

  defp tool_abuse_patterns do
    [
      # Dangerous tool combinations
      ~r/use\s+.*tool.*\s+to\s+.*delete.*all/i,
      ~r/combine\s+.*tools.*\s+for\s+destruction/i,
      ~r/chain\s+.*commands.*\s+to\s+bypass/i,

      # File system abuse
      ~r/create\s+.*files.*\s+to\s+overwrite/i,
      ~r/modify\s+.*permissions.*\s+for\s+access/i,
      ~r/symlink\s+.*attack/i,

      # Process abuse
      ~r/spawn\s+.*processes.*\s+to\s+overwhelm/i,
      ~r/fork\s+.*children.*\s+indefinitely/i,
      ~r/exec\s+.*shell.*\s+with\s+elevated/i,

      # Network tool abuse
      ~r/use\s+.*curl.*\s+to\s+exfiltrate/i,
      ~r/netcat\s+.*backdoor/i,
      ~r/ssh\s+.*tunnel.*\s+for\s+persistence/i
    ]
  end

  defp multi_step_patterns do
    [
      # Setup + execute
      {~r/first.*disable.*logging/i, ~r/then.*delete/i},
      {~r/initially.*gain.*access/i, ~r/subsequently.*escalate/i},
      {~r/start.*by.*creating/i, ~r/followed.*by.*executing/i},

      # Reconnaissance + attack
      {~r/scan.*for.*vulnerabilities/i, ~r/exploit.*found.*weakness/i},
      {~r/enumerate.*services/i, ~r/attack.*discovered.*ports/i},

      # Persistence + destruction
      {~r/install.*backdoor/i, ~r/wait.*then.*destroy/i},
      {~r/modify.*backup.*script/i, ~r/corrupt.*all.*backups/i}
    ]
  end

  # Detection Functions

  defp detect_personality_takeover(threats, markdown) do
    personality_takeover_patterns()
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, markdown, return: :index)
      |> Enum.map(fn [{start, length}] ->
        %{
          type: :ai_personality_takeover,
          severity: :critical,
          severity_score: 10,
          pattern: inspect(pattern),
          location: %{
            start_pos: start,
            end_pos: start + length - 1,
            length: length
          },
          matched_text: String.slice(markdown, start, length),
          description: "AI agent personality takeover attempt detected",
          recommendation: "Block content - potential AI manipulation attack",
          metadata: %{
            attack_category: "personality_override",
            confidence: 0.95,
            mitigation: "Reject input and log security event"
          }
        }
      end)
    end)
    |> Kernel.++(threats)
  end

  defp detect_destructive_commands(threats, markdown) do
    destructive_agent_patterns()
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, markdown, return: :index)
      |> Enum.map(fn [{start, length}] ->
        %{
          type: :ai_destructive_command,
          severity: :critical,
          severity_score: 10,
          pattern: inspect(pattern),
          location: %{
            start_pos: start,
            end_pos: start + length - 1,
            length: length
          },
          matched_text: String.slice(markdown, start, length),
          description: "Destructive agent command detected",
          recommendation: "Block execution - potential system destruction attempt",
          metadata: %{
            attack_category: "destructive_command",
            confidence: 0.9,
            mitigation: "Prevent command execution and alert administrators"
          }
        }
      end)
    end)
    |> Kernel.++(threats)
  end

  defp detect_tool_abuse(threats, markdown) do
    tool_abuse_patterns()
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, markdown, return: :index)
      |> Enum.map(fn [{start, length}] ->
        %{
          type: :ai_tool_abuse,
          severity: :high,
          severity_score: 9,
          pattern: inspect(pattern),
          location: %{
            start_pos: start,
            end_pos: start + length - 1,
            length: length
          },
          matched_text: String.slice(markdown, start, length),
          description: "AI tool abuse pattern detected",
          recommendation: "Restrict tool access - potential capability abuse",
          metadata: %{
            attack_category: "tool_abuse",
            confidence: 0.85,
            mitigation: "Limit tool permissions and monitor usage"
          }
        }
      end)
    end)
    |> Kernel.++(threats)
  end

  defp detect_multi_step_attacks(threats, markdown) do
    multi_step_patterns()
    |> Enum.flat_map(fn {step1_pattern, step2_pattern} ->
      step1_matches = Regex.scan(step1_pattern, markdown, return: :index)
      step2_matches = Regex.scan(step2_pattern, markdown, return: :index)

      # Look for patterns that appear in sequence
      for [{s1_start, s1_len}] <- step1_matches,
          [{s2_start, s2_len}] <- step2_matches,
          s2_start > s1_start do
        %{
          type: :ai_multi_step_attack,
          severity: :critical,
          severity_score: 10,
          pattern: "#{inspect(step1_pattern)} -> #{inspect(step2_pattern)}",
          location: %{
            step1_start: s1_start,
            step1_end: s1_start + s1_len - 1,
            step2_start: s2_start,
            step2_end: s2_start + s2_len - 1,
            total_length: s2_start + s2_len - s1_start
          },
          matched_text: %{
            step1: String.slice(markdown, s1_start, s1_len),
            step2: String.slice(markdown, s2_start, s2_len)
          },
          description: "Multi-step AI attack sequence detected",
          recommendation: "Block entire sequence - coordinated attack attempt",
          metadata: %{
            attack_category: "multi_step_attack",
            confidence: 0.98,
            mitigation: "Terminate session and implement enhanced monitoring",
            sequence_gap: s2_start - (s1_start + s1_len)
          }
        }
      end
    end)
    |> Kernel.++(threats)
  end
end
