defmodule Dirup.Emails do
  @moduledoc """
  Email module for Kyozo billing and system notifications.

  Handles:
  - Stripe billing notifications (payment success, failure, subscription updates)
  - User onboarding and welcome emails
  - System alerts and security notifications
  - Team collaboration invitations
  """

  use Phoenix.Component
  import Swoosh.Email
  alias Dirup.Mailer

  @from_email {"Kyozo", "noreply@kyozo.store"}
  @reply_to "support@kyozo.store"

  # ===============================
  # BILLING & STRIPE NOTIFICATIONS
  # ===============================

  @doc """
  Send subscription welcome email after successful Stripe checkout.
  """
  def send_subscription_welcome(user) do
    email =
      new()
      |> from(@from_email)
      |> to({user.name || user.email, user.email})
      |> reply_to(@reply_to)
      |> subject("Welcome to Kyozo Pro! 🚀")
      |> html_body(subscription_welcome_html(user))
      |> text_body(subscription_welcome_text(user))

    Mailer.deliver(email)
  end

  @doc """
  Send payment failed notification.
  """
  def send_payment_failed(user, invoice) do
    email =
      new()
      |> from(@from_email)
      |> to({user.name || user.email, user.email})
      |> reply_to(@reply_to)
      |> subject("Payment Issue - Action Required")
      |> html_body(payment_failed_html(user, invoice))
      |> text_body(payment_failed_text(user, invoice))

    Mailer.deliver(email)
  end

  @doc """
  Send subscription cancelled notification.
  """
  def send_subscription_cancelled(user, subscription) do
    email =
      new()
      |> from(@from_email)
      |> to({user.name || user.email, user.email})
      |> reply_to(@reply_to)
      |> subject("Subscription Cancelled - We'll Miss You")
      |> html_body(subscription_cancelled_html(user, subscription))
      |> text_body(subscription_cancelled_text(user, subscription))

    Mailer.deliver(email)
  end

  @doc """
  Send usage limit warning (approaching billing limits).
  """
  def send_usage_warning(user, usage_data) do
    email =
      new()
      |> from(@from_email)
      |> to({user.name || user.email, user.email})
      |> reply_to(@reply_to)
      |> subject("Usage Limit Warning - #{usage_data.percentage}% Used")
      |> html_body(usage_warning_html(user, usage_data))
      |> text_body(usage_warning_text(user, usage_data))

    Mailer.deliver(email)
  end

  @doc """
  Send invoice generated notification.
  """
  def send_invoice_generated(user, invoice) do
    email =
      new()
      |> from(@from_email)
      |> to({user.name || user.email, user.email})
      |> reply_to(@reply_to)
      |> subject("New Invoice ##{invoice.number}")
      |> html_body(invoice_generated_html(user, invoice))
      |> text_body(invoice_generated_text(user, invoice))

    Mailer.deliver(email)
  end

  # ===============================
  # TEAM & COLLABORATION
  # ===============================

  @doc """
  Send team invitation email.
  """
  def send_team_invitation(invitee_email, inviter, team, invitation_url) do
    email =
      new()
      |> from(@from_email)
      |> to(invitee_email)
      |> reply_to(@reply_to)
      |> subject("You've been invited to join #{team.name} on Kyozo")
      |> html_body(team_invitation_html(invitee_email, inviter, team, invitation_url))
      |> text_body(team_invitation_text(invitee_email, inviter, team, invitation_url))

    Mailer.deliver(email)
  end

  # ===============================
  # SYSTEM NOTIFICATIONS
  # ===============================

  @doc """
  Send security alert email.
  """
  def send_security_alert(user, alert_data) do
    email =
      new()
      |> from(@from_email)
      |> to({user.name || user.email, user.email})
      |> reply_to(@reply_to)
      |> subject("🚨 Security Alert - #{alert_data.type}")
      |> html_body(security_alert_html(user, alert_data))
      |> text_body(security_alert_text(user, alert_data))

    Mailer.deliver(email)
  end

  # ===============================
  # EMAIL TEMPLATES - HTML
  # ===============================

  defp subscription_welcome_html(user) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Welcome to Kyozo Pro</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: white; padding: 30px; border: 1px solid #e1e5e9; border-top: none; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .feature-list { background: #f8fafc; padding: 20px; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🚀 Welcome to Kyozo Pro!</h1>
            <p>Your AI-powered development platform is ready</p>
        </div>
        <div class="content">
            <p>Hi #{user.name || "there"},</p>

            <p>Thank you for subscribing to <strong>Kyozo Pro</strong>! You now have access to our complete suite of AI-powered development tools.</p>

            <div class="feature-list">
                <h3>✨ Your Pro Features Include:</h3>
                <ul>
                    <li><strong>AI Code Suggestions</strong> - Intelligent code completions and recommendations</li>
                    <li><strong>Advanced Security Scanning</strong> - Real-time threat detection</li>
                    <li><strong>Team Collaboration</strong> - Shared workspaces and projects</li>
                    <li><strong>Priority Support</strong> - Get help when you need it most</li>
                    <li><strong>3,000 Monthly AI Requests</strong> - Generous usage allowance</li>
                </ul>
            </div>

            <p>Ready to get started? Access your dashboard and start building:</p>

            <a href="https://kyozo.store/dashboard" class="button">Open Dashboard</a>

            <p>If you have any questions, just reply to this email or visit our <a href="https://kyozo.store">documentation</a>.</p>

            <p>Happy coding!<br>The Kyozo Team</p>
        </div>
        <div class="footer">
            <p>Kyozo - AI-Powered Development Platform</p>
            <p>Questions? Email us at support@kyozo.store</p>
        </div>
    </body>
    </html>
    """
  end

  defp payment_failed_html(user, invoice) do
    amount = format_amount(invoice.amount_due || 0, invoice.currency || "usd")

    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Payment Issue</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #ef4444; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: white; padding: 30px; border: 1px solid #e1e5e9; border-top: none; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background: #ef4444; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .alert-box { background: #fef2f2; border-left: 4px solid #ef4444; padding: 16px; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>⚠️ Payment Issue</h1>
            <p>Action required for your Kyozo account</p>
        </div>
        <div class="content">
            <p>Hi #{user.name || "there"},</p>

            <p>We had trouble processing your payment for <strong>#{amount}</strong>.</p>

            <div class="alert-box">
                <p><strong>What happens next:</strong></p>
                <ul>
                    <li>Your service will continue for a few more days</li>
                    <li>We'll retry the payment automatically</li>
                    <li>You can update your payment method anytime</li>
                </ul>
            </div>

            <p>To avoid any service interruption, please update your payment method:</p>

            <a href="https://kyozo.store/billing" class="button">Update Payment Method</a>

            <p>If you have questions about this charge or need help, please don't hesitate to contact us.</p>

            <p>Thanks for being a Kyozo customer,<br>The Kyozo Team</p>
        </div>
        <div class="footer">
            <p>Kyozo - AI-Powered Development Platform</p>
            <p>Need help? Email us at support@kyozo.store</p>
        </div>
    </body>
    </html>
    """
  end

  defp usage_warning_html(user, usage_data) do
    percentage = usage_data.percentage || 0
    current = usage_data.current || 0
    limit = usage_data.limit || 0

    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Usage Warning</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #f59e0b; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: white; padding: 30px; border: 1px solid #e1e5e9; border-top: none; border-radius: 0 0 8px 8px; }
            .usage-bar { background: #e5e7eb; border-radius: 10px; overflow: hidden; height: 20px; margin: 20px 0; }
            .usage-fill { background: #{if percentage >= 90, do: "#ef4444", else: "#f59e0b"}; height: 100%; width: #{percentage}%; }
            .stats { background: #f8fafc; padding: 20px; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>📊 Usage Warning</h1>
            <p>You've used #{percentage}% of your monthly allowance</p>
        </div>
        <div class="content">
            <p>Hi #{user.name || "there"},</p>

            <p>Just a heads up - you're approaching your monthly usage limit.</p>

            <div class="usage-bar">
                <div class="usage-fill"></div>
            </div>

            <div class="stats">
                <p><strong>Current Usage:</strong> #{current} / #{limit} requests</p>
                <p><strong>Remaining:</strong> #{limit - current} requests</p>
                <p><strong>Resets:</strong> In #{days_until_reset()} days</p>
            </div>

            <p>#{if percentage >= 95 do
      "⚠️ <strong>Important:</strong> Once you reach 100%, additional requests will be charged at $0.03 each."
    else
      "No action needed right now, but you might want to consider upgrading if you regularly hit this limit."
    end}</p>

            <p>Need more requests? Check out our plans or contact us for custom pricing.</p>

            <p>Happy coding!<br>The Kyozo Team</p>
        </div>
        <div class="footer">
            <p>Kyozo - AI-Powered Development Platform</p>
            <p>Questions? Email us at support@kyozo.store</p>
        </div>
    </body>
    </html>
    """
  end

  defp team_invitation_html(invitee_email, inviter, team, invitation_url) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Team Invitation</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #10b981; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: white; padding: 30px; border: 1px solid #e1e5e9; border-top: none; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background: #10b981; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .team-info { background: #f0fdf4; padding: 20px; border-radius: 6px; margin: 20px 0; border-left: 4px solid #10b981; }
            .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🎉 You're Invited!</h1>
            <p>Join #{team.name} on Kyozo</p>
        </div>
        <div class="content">
            <p>Hi there,</p>

            <p><strong>#{inviter.name || inviter.email}</strong> has invited you to join their team on Kyozo!</p>

            <div class="team-info">
                <h3>Team: #{team.name}</h3>
                #{if team.description do
      "<p>#{team.description}</p>"
    else
      ""
    end}
                <p><strong>Invited by:</strong> #{inviter.name || inviter.email}</p>
            </div>

            <p>Kyozo is an AI-powered development platform that helps teams build better software faster. As a team member, you'll have access to:</p>

            <ul>
                <li>Shared workspaces and projects</li>
                <li>AI-powered code assistance</li>
                <li>Real-time collaboration tools</li>
                <li>Advanced security scanning</li>
            </ul>

            <p>Ready to join the team?</p>

            <a href="#{invitation_url}" class="button">Accept Invitation</a>

            <p><small>This invitation will expire in 7 days. If you don't want to receive invitations like this, you can <a href="#">unsubscribe</a>.</small></p>

            <p>Welcome to the team!<br>The Kyozo Team</p>
        </div>
        <div class="footer">
            <p>Kyozo - AI-Powered Development Platform</p>
            <p>Questions? Email us at support@kyozo.store</p>
        </div>
    </body>
    </html>
    """
  end

  # ===============================
  # EMAIL TEMPLATES - TEXT
  # ===============================

  defp subscription_welcome_text(user) do
    """
    Welcome to Kyozo Pro!

    Hi #{user.name || "there"},

    Thank you for subscribing to Kyozo Pro! You now have access to our complete suite of AI-powered development tools.

    Your Pro Features Include:
    • AI Code Suggestions - Intelligent code completions and recommendations
    • Advanced Security Scanning - Real-time threat detection
    • Team Collaboration - Shared workspaces and projects
    • Priority Support - Get help when you need it most
    • 3,000 Monthly AI Requests - Generous usage allowance

    Get started: https://app.kyozo.store/dashboard

    Questions? Just reply to this email or visit https://docs.kyozo.store

    Happy coding!
    The Kyozo Team

    ---
    Kyozo - AI-Powered Development Platform
    Questions? Email us at support@kyozo.store
    """
  end

  defp payment_failed_text(user, invoice) do
    amount = format_amount(invoice.amount_due || 0, invoice.currency || "usd")

    """
    Payment Issue - Action Required

    Hi #{user.name || "there"},

    We had trouble processing your payment for #{amount}.

    What happens next:
    • Your service will continue for a few more days
    • We'll retry the payment automatically
    • You can update your payment method anytime

    To avoid service interruption, please update your payment method:
    https://kyozo.store/billing

    If you have questions about this charge or need help, please contact us.

    Thanks for being a Kyozo customer,
    The Kyozo Team

    ---
    Kyozo - AI-Powered Development Platform
    Need help? Email us at support@kyozo.store
    """
  end

  defp usage_warning_text(user, usage_data) do
    percentage = usage_data.percentage || 0
    current = usage_data.current || 0
    limit = usage_data.limit || 0

    """
    Usage Warning - #{percentage}% Used

    Hi #{user.name || "there"},

    You're approaching your monthly usage limit.

    Current Usage: #{current} / #{limit} requests
    Remaining: #{limit - current} requests
    Resets: In #{days_until_reset()} days

    #{if percentage >= 95 do
      "⚠️ Important: Once you reach 100%, additional requests will be charged at $0.03 each."
    else
      "No action needed right now, but consider upgrading if you regularly hit this limit."
    end}

    Need more requests? Check out our plans or contact us for custom pricing.

    Happy coding!
    The Kyozo Team

    ---
    Kyozo - AI-Powered Development Platform
    Questions? Email us at support@kyozo.store
    """
  end

  defp team_invitation_text(invitee_email, inviter, team, invitation_url) do
    """
    You're Invited to Join #{team.name} on Kyozo!

    Hi there,

    #{inviter.name || inviter.email} has invited you to join their team on Kyozo!

    Team: #{team.name}
    #{if team.description, do: team.description <> "\n", else: ""}Invited by: #{inviter.name || inviter.email}

    Kyozo is an AI-powered development platform that helps teams build better software faster.

    As a team member, you'll have access to:
    • Shared workspaces and projects
    • AI-powered code assistance
    • Real-time collaboration tools
    • Advanced security scanning

    Accept your invitation: #{invitation_url}

    This invitation will expire in 7 days.

    Welcome to the team!
    The Kyozo Team

    ---
    Kyozo - AI-Powered Development Platform
    Questions? Email us at support@kyozo.store
    """
  end

  defp security_alert_html(user, alert_data) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Security Alert</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #dc2626; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: white; padding: 30px; border: 1px solid #e1e5e9; border-top: none; border-radius: 0 0 8px 8px; }
            .alert-box { background: #fef2f2; border-left: 4px solid #dc2626; padding: 16px; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🚨 Security Alert</h1>
            <p>#{alert_data.type}</p>
        </div>
        <div class="content">
            <p>Hi #{user.name || "there"},</p>

            <div class="alert-box">
                <p><strong>Alert Details:</strong></p>
                <p>#{alert_data.description || "Security event detected on your account"}</p>
                #{if alert_data.timestamp do
      "<p><strong>Time:</strong> #{alert_data.timestamp}</p>"
    else
      ""
    end}
            </div>

            <p>We've detected unusual activity and wanted to alert you immediately.</p>

            <p><strong>Recommended Actions:</strong></p>
            <ul>
                <li>Review your recent account activity</li>
                <li>Change your password if you suspect compromise</li>
                <li>Contact support if you didn't initiate this activity</li>
            </ul>

            <p>Your account security is our top priority. If you have any concerns, please contact us immediately.</p>

            <p>Stay safe,<br>The Kyozo Security Team</p>
        </div>
        <div class="footer">
            <p>Kyozo - AI-Powered Development Platform</p>
            <p>Security concerns? Email us at security@kyozo.store</p>
        </div>
    </body>
    </html>
    """
  end

  defp security_alert_text(user, alert_data) do
    """
    🚨 Security Alert - #{alert_data.type}

    Hi #{user.name || "there"},

    We've detected unusual activity and wanted to alert you immediately.

    Alert Details:
    #{alert_data.description || "Security event detected on your account"}
    #{if alert_data.timestamp, do: "Time: #{alert_data.timestamp}", else: ""}

    Recommended Actions:
    • Review your recent account activity
    • Change your password if you suspect compromise
    • Contact support if you didn't initiate this activity

    Your account security is our top priority. If you have any concerns, please contact us immediately.

    Stay safe,
    The Kyozo Security Team

    ---
    Kyozo - AI-Powered Development Platform
    Security concerns? Email us at security@kyozo.store
    """
  end

  defp subscription_cancelled_html(user, subscription) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Subscription Cancelled</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #6b7280; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: white; padding: 30px; border: 1px solid #e1e5e9; border-top: none; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>👋 Subscription Cancelled</h1>
            <p>We'll miss you!</p>
        </div>
        <div class="content">
            <p>Hi #{user.name || "there"},</p>

            <p>Your Kyozo subscription has been cancelled as requested.</p>

            <p><strong>What this means:</strong></p>
            <ul>
                <li>You'll continue to have access until #{format_date(subscription.current_period_end)}</li>
                <li>No further charges will be made</li>
                <li>Your data will be preserved for 30 days</li>
            </ul>

            <p>We're sorry to see you go! If there's anything we could have done better, we'd love to hear from you.</p>

            <p>Want to come back? You can reactivate anytime:</p>

            <a href="https://kyozo.store/billing" class="button">Reactivate Subscription</a>

            <p>Thank you for being part of the Kyozo community!</p>

            <p>Best regards,<br>The Kyozo Team</p>
        </div>
        <div class="footer">
            <p>Kyozo - AI-Powered Development Platform</p>
            <p>Questions? Email us at support@kyozo.store</p>
        </div>
    </body>
    </html>
    """
  end

  defp subscription_cancelled_text(user, subscription) do
    """
    Subscription Cancelled - We'll Miss You!

    Hi #{user.name || "there"},

    Your Kyozo subscription has been cancelled as requested.

    What this means:
    • You'll continue to have access until #{format_date(subscription.current_period_end)}
    • No further charges will be made
    • Your data will be preserved for 30 days

    We're sorry to see you go! If there's anything we could have done better, we'd love to hear from you.

    Want to come back? You can reactivate anytime:
    https://kyozo.store/billing

    Thank you for being part of the Kyozo community!

    Best regards,
    The Kyozo Team

    ---
    Kyozo - AI-Powered Development Platform
    Questions? Email us at support@kyozo.store
    """
  end

  defp invoice_generated_html(user, invoice) do
    amount = format_amount(invoice.amount_due || 0, invoice.currency || "usd")

    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>New Invoice</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #3b82f6; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: white; padding: 30px; border: 1px solid #e1e5e9; border-top: none; border-radius: 0 0 8px 8px; }
            .invoice-box { background: #f8fafc; padding: 20px; border-radius: 6px; margin: 20px 0; }
            .button { display: inline-block; background: #3b82f6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>📄 New Invoice</h1>
            <p>Invoice ##{invoice.number || "N/A"}</p>
        </div>
        <div class="content">
            <p>Hi #{user.name || "there"},</p>

            <p>A new invoice has been generated for your Kyozo account.</p>

            <div class="invoice-box">
                <p><strong>Invoice ##{invoice.number || "N/A"}</strong></p>
                <p><strong>Amount:</strong> #{amount}</p>
                <p><strong>Due Date:</strong> #{format_date(invoice.due_date)}</p>
            </div>

            <p>You can view and pay your invoice online:</p>

            <a href="https://kyozo.store/billing/invoices/#{invoice.id}" class="button">View Invoice</a>

            <p>Payment will be automatically attempted using your default payment method.</p>

            <p>Questions about this invoice? Just reply to this email.</p>

            <p>Thank you,<br>The Kyozo Team</p>
        </div>
        <div class="footer">
            <p>Kyozo - AI-Powered Development Platform</p>
            <p>Questions? Email us at support@kyozo.store</p>
        </div>
    </body>
    </html>
    """
  end

  defp invoice_generated_text(user, invoice) do
    amount = format_amount(invoice.amount_due || 0, invoice.currency || "usd")

    """
    New Invoice ##{invoice.number || "N/A"}

    Hi #{user.name || "there"},

    A new invoice has been generated for your Kyozo account.

    Invoice ##{invoice.number || "N/A"}
    Amount: #{amount}
    Due Date: #{format_date(invoice.due_date)}

    View and pay online: https://kyozo.store/billing/invoices/#{invoice.id}

    Payment will be automatically attempted using your default payment method.

    Questions about this invoice? Just reply to this email.

    Thank you,
    The Kyozo Team

    ---
    Kyozo - AI-Powered Development Platform
    Questions? Email us at support@kyozo.store
    """
  end

  # ===============================
  # HELPER FUNCTIONS
  # ===============================

  defp format_amount(amount_cents, currency) when is_integer(amount_cents) do
    case String.upcase(currency) do
      "USD" -> "$#{Float.round(amount_cents / 100, 2)}"
      "EUR" -> "€#{Float.round(amount_cents / 100, 2)}"
      "GBP" -> "£#{Float.round(amount_cents / 100, 2)}"
      _ -> "#{Float.round(amount_cents / 100, 2)} #{String.upcase(currency)}"
    end
  end

  defp format_amount(amount_cents, _currency) when amount_cents == nil, do: "$0.00"

  defp format_amount(amount_cents, currency) when is_float(amount_cents),
    do: format_amount(round(amount_cents), currency)

  defp format_date(nil), do: "N/A"

  defp format_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_string()
  end

  defp format_date(%Date{} = date) do
    Date.to_string(date)
  end

  defp format_date(timestamp) when is_integer(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> format_date()
  end

  defp days_until_reset do
    now = Date.utc_today()
    end_of_month = Date.end_of_month(now)
    Date.diff(end_of_month, now) + 1
  end
end
