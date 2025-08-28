# 📧 Email System Configuration Guide

This document provides comprehensive configuration instructions for the Kyozo email system, which supports multiple providers with intelligent failover and production-ready features.

## 🎯 Quick Start

The email system automatically detects available providers based on environment variables. Set up any one of the supported providers below:

### Option 1: SendGrid (Recommended)
```bash
export SENDGRID_API_KEY="SG.your-api-key-here"
```

### Option 2: Mailgun
```bash
export MAILGUN_API_KEY="your-mailgun-api-key"
export MAILGUN_DOMAIN="your-domain.com"
```

### Option 3: AWS SES
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"  # optional, defaults to us-east-1
```

## 🔧 Complete Configuration Reference

### Core Provider Configuration

#### SendGrid (Priority 1 - Recommended for Production)
```bash
# Required
SENDGRID_API_KEY="SG.your-sendgrid-api-key-here"

# SendGrid provides excellent deliverability, analytics, and scaling
# Get your API key from: https://app.sendgrid.com/settings/api_keys
```

#### Mailgun (Priority 2)
```bash
# Required
MAILGUN_API_KEY="key-your-mailgun-api-key-here"
MAILGUN_DOMAIN="mg.yourdomain.com"

# Optional - Mailgun region (default: US)
MAILGUN_REGION="us"  # or "eu" for European data centers

# Get your credentials from: https://app.mailgun.com/app/account/security/api_keys
```

#### AWS SES (Priority 3)
```bash
# Required
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Optional
AWS_REGION="us-east-1"        # Default region
AWS_SES_CONFIGURATION_SET=""   # Optional configuration set name

# Set up SES in AWS Console: https://console.aws.amazon.com/ses/
```

#### Resend (Priority 4)
```bash
# Required
RESEND_API_KEY="re_your-resend-api-key-here"

# Get your API key from: https://resend.com/api-keys
```

#### Generic SMTP (Priority 5 - Fallback)
```bash
# Required
SMTP_HOST="smtp.gmail.com"
SMTP_USERNAME="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"

# Optional SMTP Configuration
SMTP_PORT="587"           # Default: 587 for TLS, 465 for SSL, 25 for plain
SMTP_SSL="false"          # Use SSL encryption (true/false)
SMTP_TLS="true"           # Use TLS encryption (true/false)
SMTP_AUTH="true"          # Use authentication (true/false)
SMTP_RETRIES="2"          # Number of retry attempts

# Common SMTP Providers:
# Gmail: smtp.gmail.com:587 (use app passwords)
# Outlook: smtp-mail.outlook.com:587
# Yahoo: smtp.mail.yahoo.com:587
```

### Email Service Configuration

#### Default Sender Information
```bash
# Email address that appears in "From" field
FROM_EMAIL="noreply@yourdomain.com"

# Name that appears in "From" field
FROM_NAME="Your App Name"
```

#### Delivery & Performance Settings
```bash
# Async delivery (recommended for production)
EMAIL_ASYNC="true"              # Enable background job processing

# Retry configuration
EMAIL_MAX_RETRIES="3"           # Maximum delivery attempts
EMAIL_RETRY_DELAY="5000"        # Base retry delay in milliseconds

# Rate limiting (per recipient)
EMAIL_RATE_LIMIT="60"           # Maximum emails per minute per recipient
```

#### Tracking & Analytics
```bash
# Email tracking features
EMAIL_TRACK_OPENS="true"        # Track email opens
EMAIL_TRACK_CLICKS="true"       # Track link clicks

# Template configuration
EMAIL_TEMPLATE_DIR="priv/templates/email"  # Template directory path
```

#### Development & Debugging
```bash
# Preview emails in browser (development only)
EMAIL_PREVIEW="true"            # Enable local email preview

# Configuration logging
LOG_EMAIL_CONFIG="true"         # Log sanitized email config on startup
```

## 🏗 Provider Priority & Failover

The system checks providers in this order:

1. **SendGrid** - Best for production (high deliverability, analytics)
2. **Mailgun** - Good alternative with EU options
3. **AWS SES** - Cost-effective for high volume
4. **Resend** - Modern API with good developer experience  
5. **SMTP** - Universal fallback for any email provider
6. **Local** - Development fallback (saves to `/dev/mailbox`)

Set environment variables for your preferred provider. The system will automatically use the highest priority provider with complete configuration.

## 📊 Production Deployment Examples

### Docker/Container Deployment
```dockerfile
# In your Dockerfile or docker-compose.yml
ENV SENDGRID_API_KEY=SG.your-api-key
ENV FROM_EMAIL=noreply@yourdomain.com
ENV FROM_NAME="Your App"
ENV EMAIL_ASYNC=true
ENV EMAIL_RATE_LIMIT=100
```

### Kubernetes Deployment
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: email-config
data:
  sendgrid-api-key: <base64-encoded-key>
---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: kyozo-api
        env:
        - name: SENDGRID_API_KEY
          valueFrom:
            secretKeyRef:
              name: email-config
              key: sendgrid-api-key
        - name: FROM_EMAIL
          value: "noreply@yourdomain.com"
```

### Heroku Deployment
```bash
# Set config vars in Heroku
heroku config:set SENDGRID_API_KEY=SG.your-api-key
heroku config:set FROM_EMAIL=noreply@yourdomain.com
heroku config:set FROM_NAME="Your App Name"
heroku config:set EMAIL_ASYNC=true
```

### AWS ECS/Elastic Beanstalk
```json
{
  "environment": [
    {
      "name": "SENDGRID_API_KEY", 
      "value": "SG.your-api-key"
    },
    {
      "name": "FROM_EMAIL",
      "value": "noreply@yourdomain.com"
    }
  ]
}
```

## 🧪 Testing Your Configuration

### 1. Check Configuration on Startup
When the application starts, you should see:
```
📧 Email configured with adapter: Elixir.Swoosh.Adapters.Sendgrid
```

### 2. Test Email Delivery (IEx Console)
```elixir
# Start IEx console
iex -S mix

# Test basic email
Kyozo.EmailService.send_email(%{
  to: "test@example.com",
  subject: "Test Email",
  template: :welcome,
  assigns: %{name: "Test User"}
})

# Check delivery stats
Kyozo.EmailService.get_delivery_stats()
```

### 3. Monitor Email Logs
Look for these log messages:
```
📧 Email configured with adapter: Elixir.Swoosh.Adapters.Sendgrid
[info] Preparing to send email to: user@example.com subject: "Welcome"
[info] Email sent successfully to: user@example.com message_id: "abc123"
```

## 🚨 Troubleshooting

### Common Issues

#### "No email provider configured"
**Solution**: Set environment variables for at least one provider listed above.

#### "Email delivery failed with 401 Unauthorized" 
**Solutions**:
- Verify your API key is correct and has send permissions
- For Gmail SMTP: Use app passwords, not your regular password
- For AWS SES: Ensure IAM user has `ses:SendEmail` permission

#### "Email delivery failed with 403 Forbidden"
**Solutions**:
- For AWS SES: Verify the sender email is verified in SES console
- For SendGrid: Check sender authentication is set up
- Ensure your domain is properly configured with the provider

#### "Rate limiting errors"
**Solutions**:
- Increase `EMAIL_RATE_LIMIT` value
- Enable `EMAIL_ASYNC=true` for better handling
- Consider upgrading your email provider plan

#### Emails going to spam
**Solutions**:
- Set up SPF, DKIM, and DMARC records for your domain
- Use a dedicated IP address (available with most providers)
- Maintain good sender reputation by handling bounces

### Development Mode

For local development, the system falls back to the local adapter which saves emails to `/dev/mailbox`. Access this at:
```
http://localhost:4000/dev/mailbox
```

### Health Checks

The email system provides health check endpoints:
```bash
# Check email system status
curl http://localhost:4000/api/health/email

# Get delivery statistics
curl http://localhost:4000/api/stats/email
```

## 📈 Monitoring & Analytics

### Key Metrics to Monitor

1. **Delivery Rate** - Percentage of emails successfully delivered
2. **Bounce Rate** - Percentage of emails that bounced
3. **Open Rate** - Percentage of emails opened (if tracking enabled)
4. **Click Rate** - Percentage of links clicked (if tracking enabled)
5. **Response Time** - Average time to deliver emails

### Alerting Recommendations

Set up alerts for:
- Delivery rate drops below 95%
- Error rate exceeds 5%
- Rate limiting frequently triggered
- Provider API errors

## 🔐 Security Best Practices

1. **API Keys**: Store in environment variables, never in code
2. **Rotation**: Rotate API keys regularly (quarterly recommended)
3. **Permissions**: Use least-privilege API keys when possible
4. **Monitoring**: Monitor for unusual sending patterns
5. **Rate Limiting**: Keep rate limits appropriate for your use case

## 📞 Support & Provider Resources

- **SendGrid Support**: https://support.sendgrid.com/
- **Mailgun Support**: https://help.mailgun.com/
- **AWS SES Documentation**: https://docs.aws.amazon.com/ses/
- **Resend Documentation**: https://resend.com/docs
- **Kyozo Email Issues**: Create an issue in the project repository

---

**Need Help?** Check the logs first, then refer to your email provider's documentation for specific error codes and solutions.