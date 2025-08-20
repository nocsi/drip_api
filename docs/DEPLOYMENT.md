# Kyozo API Deployment Guide

This guide covers deploying the Kyozo API application to various environments, with a focus on Fly.io as the primary deployment target.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Fly.io Deployment](#flyio-deployment)
- [Docker Deployment](#docker-deployment)
- [Local Development](#local-development)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before deploying Kyozo API, ensure you have:

- **Elixir 1.16+** and **Erlang/OTP 26+**
- **Node.js 20+** and **pnpm**
- **Docker** and **Docker Compose**
- **PostgreSQL 15+** (for production)
- **Git** for version control

### For Fly.io Deployment

- [Fly.io CLI (flyctl)](https://fly.io/docs/getting-started/installing-flyctl/)
- A Fly.io account (free tier available)

## Environment Setup

### Environment Variables

The application requires several environment variables. Here are the essential ones:

#### Database
```bash
DATABASE_URL=ecto://username:password@hostname:port/database_name
```

#### Application Secrets
```bash
SECRET_KEY_BASE=your_secret_key_base_64_chars_minimum
LIVE_VIEW_SIGNING_SALT=your_live_view_signing_salt_32_chars
GUARDIAN_SECRET_KEY=your_guardian_secret_key_64_chars_minimum
```

#### OAuth Configuration (Optional)
```bash
OAUTH_GITHUB_CLIENT_ID=your_github_oauth_client_id
OAUTH_GITHUB_CLIENT_SECRET=your_github_oauth_client_secret
OAUTH_GOOGLE_CLIENT_ID=your_google_oauth_client_id
OAUTH_GOOGLE_CLIENT_SECRET=your_google_oauth_client_secret
```

#### Email Configuration
```bash
SMTP_HOST=your_smtp_host
SMTP_PORT=587
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
FROM_EMAIL=no-reply@your-domain.com
```

#### File Storage (Optional)
```bash
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_S3_BUCKET=your_s3_bucket_name
AWS_S3_REGION=us-east-1
```

## Fly.io Deployment

Fly.io is the recommended deployment platform for Kyozo API. We provide an automated deployment script that handles the entire process.

### Quick Start

1. **Install flyctl** and authenticate:
   ```bash
   # Install flyctl (macOS)
   brew install flyctl
   
   # Or download from https://fly.io/docs/getting-started/installing-flyctl/
   
   # Authenticate
   flyctl auth login
   ```

2. **Run the deployment script**:
   ```bash
   ./scripts/deploy.sh
   ```

   The script will:
   - Create the Fly.io app if it doesn't exist
   - Set up PostgreSQL database
   - Generate and set required secrets
   - Create persistent volumes
   - Deploy the application

### Manual Fly.io Setup

If you prefer manual setup or need more control:

1. **Create the application**:
   ```bash
   flyctl apps create kyozo-api
   ```

2. **Create PostgreSQL database**:
   ```bash
   flyctl postgres create --name kyozo-api-db --region sea
   flyctl postgres attach kyozo-api-db --app kyozo-api
   ```

3. **Set secrets**:
   ```bash
   # Generate secrets
   SECRET_KEY_BASE=$(mix phx.gen.secret)
   LIVE_VIEW_SALT=$(mix phx.gen.secret 32)
   GUARDIAN_SECRET=$(mix phx.gen.secret 64)
   
   # Set secrets
   flyctl secrets set SECRET_KEY_BASE="$SECRET_KEY_BASE" --app kyozo-api
   flyctl secrets set LIVE_VIEW_SIGNING_SALT="$LIVE_VIEW_SALT" --app kyozo-api
   flyctl secrets set GUARDIAN_SECRET_KEY="$GUARDIAN_SECRET" --app kyozo-api
   ```

4. **Create volumes**:
   ```bash
   flyctl volumes create kyozo_tmp --region sea --size 1 --app kyozo-api
   flyctl volumes create kyozo_uploads --region sea --size 5 --app kyozo-api
   ```

5. **Deploy**:
   ```bash
   flyctl deploy --app kyozo-api
   ```

### Fly.io Configuration

The `fly.toml` file contains the deployment configuration:

- **Auto-scaling**: Configured to scale from 0 to 10 machines based on traffic
- **Health checks**: HTTP health check at `/api/health`
- **Persistent storage**: Volumes for temporary files and uploads
- **Environment**: Production-optimized settings

## Docker Deployment

For Docker-based deployments (Kubernetes, AWS ECS, etc.):

### Production Build

```bash
# Build the production image
docker build -t kyozo-api:latest .

# Run the container
docker run -p 4000:4000 \
  -e DATABASE_URL="your_database_url" \
  -e SECRET_KEY_BASE="your_secret" \
  kyozo-api:latest
```

### Docker Compose Production

Create a `docker-compose.prod.yml`:

```yaml
version: '3.8'
services:
  app:
    build: .
    environment:
      MIX_ENV: prod
      DATABASE_URL: ecto://postgres:password@postgres:5432/kyozo_prod
      SECRET_KEY_BASE: your_secret_key_base
    ports:
      - "4000:4000"
    depends_on:
      - postgres
  
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: kyozo_prod
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Then deploy:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Local Development

For local development with all services:

### Quick Start

```bash
# Clone the repository
git clone https://github.com/your-org/kyozo_api.git
cd kyozo_api

# Copy environment file
cp .env.example .env

# Start all services
docker-compose -f docker-compose.dev.yml up -d

# Set up the database
mix ecto.setup

# Start the Phoenix server
mix phx.server
```

### Development Services

The development setup includes:

- **PostgreSQL**: Database server
- **Redis**: Caching and sessions
- **MinIO**: S3-compatible object storage
- **MailHog**: Email testing server
- **Nginx**: Reverse proxy (optional)

Access the services:
- Application: http://localhost:4000
- MailHog UI: http://localhost:8025
- MinIO Console: http://localhost:9001

### Manual Development Setup

```bash
# Install dependencies
mix deps.get
cd assets && pnpm install && cd ..

# Set up database
mix ecto.setup

# Start the server
mix phx.server
```

## Configuration

### Database Migrations

Migrations run automatically on deployment via the release command in `fly.toml`:

```toml
[deploy]
  release_command = "/app/bin/migrate"
```

For manual migration:
```bash
# Production
/app/bin/kyozo eval "Kyozo.Release.migrate"

# Development
mix ecto.migrate
```

### Asset Compilation

Assets are compiled during the Docker build process:

```dockerfile
# Build frontend assets
RUN cd assets && pnpm run build

# Compile Elixir assets
RUN mix assets.deploy
```

### SSL/TLS

Fly.io provides automatic SSL certificates. For custom domains:

```bash
flyctl certs create your-domain.com --app kyozo-api
```

## Monitoring

### Health Checks

The application provides a health check endpoint:

```
GET /api/health
```

Returns:
```json
{
  "status": "ok",
  "version": "0.1.0",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Logs

View application logs:

```bash
# Fly.io
flyctl logs --app kyozo-api

# Docker
docker-compose logs -f app

# Local development
tail -f phoenix.log
```

### Metrics

The application exposes Prometheus metrics at `/metrics` (port 9091).

### Monitoring Setup

For production monitoring, consider:

- **Prometheus + Grafana**: Metrics collection and visualization
- **Sentry**: Error tracking and performance monitoring
- **LogRocket**: Session replay and debugging
- **Fly.io Metrics**: Built-in monitoring dashboard

## Troubleshooting

### Common Issues

#### 1. Database Connection Issues

```bash
# Check database status (Fly.io)
flyctl postgres list
flyctl postgres connect --app kyozo-api-db

# Verify connection string
flyctl secrets list --app kyozo-api | grep DATABASE_URL
```

#### 2. Asset Loading Issues

```bash
# Rebuild assets
cd assets && pnpm run build && cd ..
mix assets.deploy

# Check static file serving
curl -I https://your-app.fly.dev/static/app.css
```

#### 3. Memory Issues

```bash
# Check memory usage (Fly.io)
flyctl status --app kyozo-api

# Scale up if needed
flyctl scale memory 2048 --app kyozo-api
```

#### 4. Build Failures

```bash
# Check build logs
flyctl logs --app kyozo-api

# Deploy with verbose logging
flyctl deploy --verbose --app kyozo-api
```

### Debug Commands

```bash
# Access running container (Fly.io)
flyctl ssh console --app kyozo-api

# Run Elixir console
/app/bin/kyozo remote

# Check application status
/app/bin/kyozo ping
```

### Performance Tuning

#### Database

```elixir
# config/runtime.exs
config :kyozo, Kyozo.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  queue_target: 500,
  queue_interval: 1000
```

#### Phoenix

```elixir
# config/runtime.exs
config :phoenix, :serve_endpoints, true
config :kyozo, KyozoWeb.Endpoint,
  check_origin: false,
  code_reloader: false,
  server: true
```

## Security Considerations

### Secrets Management

- Use Fly.io secrets for sensitive configuration
- Rotate secrets regularly
- Never commit secrets to version control

### Network Security

- Enable HTTPS redirect in production
- Use secure headers middleware
- Implement rate limiting

### Database Security

- Use SSL connections to database
- Implement proper authentication and authorization
- Regular security updates

## Deployment Checklist

Before deploying to production:

- [ ] All tests pass
- [ ] Environment variables are set
- [ ] Database migrations are ready
- [ ] SSL certificates are configured
- [ ] Monitoring is set up
- [ ] Backup strategy is in place
- [ ] Load testing completed
- [ ] Security review completed

## Support

For deployment issues:

1. Check the [troubleshooting section](#troubleshooting)
2. Review application logs
3. Consult Fly.io documentation
4. Open an issue in the project repository

## References

- [Fly.io Documentation](https://fly.io/docs/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Elixir Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)