defmodule Dirup.Markdown.SecurityReport do
  @moduledoc """
  Generate comprehensive security reports for scanned markdown.
  Includes OWASP classifications, remediation steps, and risk scoring.
  """

  alias Dirup.Markdown.Pipeline.Result

  @owasp_mapping %{
    xss: "A03:2021 - Injection",
    sql_injection: "A03:2021 - Injection",
    command_injection: "A03:2021 - Injection",
    prompt_injection: "A03:2021 - Injection",
    file_inclusion: "A01:2021 - Broken Access Control",
    ssrf: "A10:2021 - Server-Side Request Forgery",
    xxe: "A05:2021 - Security Misconfiguration",
    polyglot_file: "A04:2021 - Insecure Design",
    homograph_attack: "A07:2021 - Identification and Authentication Failures"
  }

  @doc """
  Generate a full security report from scan results.
  """
  def generate_report(%Result{} = result, options \\ []) do
    %{
      summary: generate_summary(result),
      risk_score: calculate_risk_score(result),
      threats: format_threats(result.threats, options),
      statistics: generate_statistics(result),
      recommendations: generate_recommendations(result),
      compliance: check_compliance(result),
      metadata: %{
        scan_date: DateTime.utc_now(),
        scanner_version: "1.0.0",
        total_threats: length(result.threats)
      }
    }
  end

  @doc """
  Generate HTML report for web display.
  """
  def generate_html_report(result, options \\ []) do
    report = generate_report(result, options)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>SafeMD Security Report</title>
      <style>
        body { font-family: -apple-system, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        .critical { color: #d32f2f; }
        .high { color: #f57c00; }
        .medium { color: #fbc02d; }
        .low { color: #388e3c; }
        .threat { border: 1px solid #e0e0e0; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .code { background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto; }
        .summary { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .score { font-size: 48px; font-weight: bold; }
      </style>
    </head>
    <body>
      <h1>SafeMD Security Report</h1>
      
      <div class="summary">
        <h2>Risk Score: <span class="score #{risk_class(report.risk_score)}">#{report.risk_score}/100</span></h2>
        <p>#{report.summary}</p>
      </div>
      
      <h2>Threats Detected (#{length(report.threats)})</h2>
      #{format_threats_html(report.threats)}
      
      <h2>Recommendations</h2>
      <ul>
        #{Enum.map(report.recommendations, &"<li>#{&1}</li>") |> Enum.join("\n")}
      </ul>
      
      <h2>Compliance</h2>
      #{format_compliance_html(report.compliance)}
      
      <footer>
        <p>Generated: #{report.metadata.scan_date}</p>
      </footer>
    </body>
    </html>
    """
  end

  @doc """
  Generate JSON report for API responses.
  """
  def generate_json_report(result, options \\ []) do
    report = generate_report(result, options)

    # Add additional API-specific fields
    Map.merge(report, %{
      api_version: "1.0",
      threats_grouped: group_threats_by_type(result.threats),
      actionable_items: generate_actionable_items(result)
    })
  end

  # Private functions

  defp generate_summary(result) do
    threat_count = length(result.threats)
    critical_count = Enum.count(result.threats, &(&1.severity == :critical))
    high_count = Enum.count(result.threats, &(&1.severity == :high))

    cond do
      critical_count > 0 ->
        "CRITICAL: Found #{critical_count} critical security threats that require immediate attention."

      high_count > 0 ->
        "HIGH RISK: Found #{high_count} high-severity threats that should be addressed."

      threat_count > 0 ->
        "MODERATE RISK: Found #{threat_count} security issues that should be reviewed."

      true ->
        "SECURE: No security threats detected in this document."
    end
  end

  defp calculate_risk_score(result) do
    # Base score starts at 100 (perfect)
    base_score = 100

    # Deduct points based on threat severity
    deductions =
      Enum.reduce(result.threats, 0, fn threat, acc ->
        case threat.severity do
          :critical -> acc + 30
          :high -> acc + 20
          :medium -> acc + 10
          :low -> acc + 5
        end
      end)

    # Additional deductions for specific threat types
    type_deductions =
      result.threats
      |> Enum.map(& &1.type)
      |> Enum.uniq()
      |> Enum.reduce(0, fn type, acc ->
        case type do
          :command_injection -> acc + 10
          :sql_injection -> acc + 8
          :xss -> acc + 8
          :prompt_injection -> acc + 5
          _ -> acc + 2
        end
      end)

    max(0, base_score - deductions - type_deductions)
  end

  defp format_threats(threats, options) do
    threats
    |> maybe_filter_by_severity(options[:min_severity])
    |> Enum.map(&format_single_threat/1)
    |> Enum.sort_by(& &1.severity_score, :desc)
  end

  defp format_single_threat(threat) do
    %{
      type: threat.type,
      severity: threat.severity,
      severity_score: threat.severity_score,
      description: threat.description,
      location: format_location(threat.location),
      details: threat.details,
      remediation: threat.remediation,
      owasp_category: @owasp_mapping[threat.type],
      cwe: threat[:cwe]
    }
  end

  defp format_location(location) do
    %{
      line: location[:line] || 0,
      column: location[:column] || 0,
      start: location.start,
      end: location.end
    }
  end

  defp generate_statistics(result) do
    threats_by_type = Enum.frequencies_by(result.threats, & &1.type)
    threats_by_severity = Enum.frequencies_by(result.threats, & &1.severity)

    %{
      total_threats: length(result.threats),
      by_type: threats_by_type,
      by_severity: threats_by_severity,
      unique_patterns: result.threats |> Enum.map(& &1[:pattern]) |> Enum.uniq() |> length(),
      affected_lines: result.threats |> Enum.map(& &1.location[:line]) |> Enum.uniq() |> length()
    }
  end

  defp generate_recommendations(result) do
    recommendations = ["Always validate and sanitize user input"]

    threat_types = result.threats |> Enum.map(& &1.type) |> Enum.uniq()

    (recommendations ++
       Enum.flat_map(threat_types, fn type ->
         case type do
           :xss ->
             [
               "Use Content Security Policy (CSP) headers",
               "Escape HTML entities in user content",
               "Consider using a markdown renderer with XSS protection"
             ]

           :sql_injection ->
             [
               "Use parameterized queries exclusively",
               "Implement strict input validation",
               "Apply principle of least privilege to database users"
             ]

           :command_injection ->
             [
               "Never pass user input to system commands",
               "Use language-specific APIs instead of shell commands",
               "Implement strict whitelisting for any command execution"
             ]

           :prompt_injection ->
             [
               "Implement prompt validation before AI processing",
               "Use instruction separation techniques",
               "Consider prompt sandboxing or guards"
             ]

           :file_inclusion ->
             [
               "Validate file paths against a whitelist",
               "Use chroot or containerization",
               "Disable dynamic file inclusion where possible"
             ]

           :ssrf ->
             [
               "Whitelist allowed URLs and protocols",
               "Implement network segmentation",
               "Use a proxy for external requests"
             ]

           _ ->
             []
         end
       end))
    |> Enum.uniq()
  end

  defp check_compliance(result) do
    %{
      pci_dss: check_pci_compliance(result),
      hipaa: check_hipaa_compliance(result),
      gdpr: check_gdpr_compliance(result),
      owasp_top_10: check_owasp_compliance(result)
    }
  end

  defp check_pci_compliance(result) do
    # PCI DSS Requirement 6.5 - Common vulnerabilities
    critical_issues = Enum.filter(result.threats, &(&1.severity in [:critical, :high]))

    %{
      compliant: Enum.empty?(critical_issues),
      issues: Enum.map(critical_issues, & &1.type),
      requirement: "PCI DSS 6.5 - Protect against common vulnerabilities"
    }
  end

  defp check_hipaa_compliance(result) do
    # HIPAA Security Rule - Technical Safeguards
    security_issues =
      Enum.filter(result.threats, &(&1.type in [:xss, :sql_injection, :file_inclusion]))

    %{
      compliant: Enum.empty?(security_issues),
      issues: Enum.map(security_issues, & &1.type),
      requirement: "HIPAA Security Rule 164.312 - Technical safeguards"
    }
  end

  defp check_gdpr_compliance(result) do
    # GDPR Article 32 - Security of processing
    data_risks = Enum.filter(result.threats, &(&1.severity_score >= 7))

    %{
      compliant: Enum.empty?(data_risks),
      issues: Enum.map(data_risks, & &1.type),
      requirement: "GDPR Article 32 - Security of processing"
    }
  end

  defp check_owasp_compliance(result) do
    covered_categories =
      result.threats
      |> Enum.map(&@owasp_mapping[&1.type])
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    %{
      covered: covered_categories,
      score: length(covered_categories),
      max_score: 10
    }
  end

  defp group_threats_by_type(threats) do
    Enum.group_by(threats, & &1.type)
  end

  defp generate_actionable_items(result) do
    result.threats
    |> Enum.map(fn threat ->
      %{
        action: "Fix #{threat.type} vulnerability",
        priority: threat.severity,
        location: "Line #{threat.location[:line] || "unknown"}",
        effort: estimate_fix_effort(threat)
      }
    end)
    |> Enum.sort_by(& &1.priority)
  end

  defp estimate_fix_effort(threat) do
    case threat.type do
      :xss -> "medium"
      :sql_injection -> "high"
      :command_injection -> "high"
      :prompt_injection -> "medium"
      _ -> "low"
    end
  end

  defp maybe_filter_by_severity(threats, nil), do: threats

  defp maybe_filter_by_severity(threats, min_severity) do
    severity_order = [:low, :medium, :high, :critical]
    min_index = Enum.find_index(severity_order, &(&1 == min_severity)) || 0

    Enum.filter(threats, fn threat ->
      threat_index = Enum.find_index(severity_order, &(&1 == threat.severity)) || 0
      threat_index >= min_index
    end)
  end

  defp risk_class(score) when score >= 80, do: "low"
  defp risk_class(score) when score >= 60, do: "medium"
  defp risk_class(score) when score >= 40, do: "high"
  defp risk_class(_), do: "critical"

  defp format_threats_html(threats) do
    threats
    |> Enum.map(fn threat ->
      """
      <div class="threat">
        <h3 class="#{threat.severity}">#{String.upcase(to_string(threat.type))} - #{threat.severity}</h3>
        <p><strong>Description:</strong> #{threat.description}</p>
        <p><strong>Location:</strong> Line #{threat.location.line}</p>
        <div class="code">#{html_escape(threat.details)}</div>
        <p><strong>Remediation:</strong> #{threat.remediation}</p>
        <p><small>OWASP: #{threat.owasp_category || "N/A"} | CWE: #{threat.cwe || "N/A"}</small></p>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp format_compliance_html(compliance) do
    compliance
    |> Enum.map(fn {standard, result} ->
      status = if result.compliant, do: "✅", else: "❌"

      """
      <div>
        <h3>#{String.upcase(to_string(standard))} #{status}</h3>
        <p>#{result[:requirement] || "Compliance check"}</p>
        #{if result[:issues], do: "<p>Issues: #{Enum.join(result.issues, ", ")}</p>", else: ""}
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
