#!/bin/bash

# Kyozo API Deployment Script
# This script automates the deployment process to Fly.io

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="kyozo-api"
REGION="sea"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if flyctl is installed
check_flyctl() {
    if ! command -v flyctl &> /dev/null; then
        log_error "flyctl is not installed. Please install it from https://fly.io/docs/getting-started/installing-flyctl/"
        exit 1
    fi
    log_info "flyctl is installed: $(flyctl version)"
}

# Check if user is authenticated with Fly.io
check_auth() {
    if ! flyctl auth whoami &> /dev/null; then
        log_error "Not authenticated with Fly.io. Please run 'flyctl auth login'"
        exit 1
    fi
    log_info "Authenticated with Fly.io as: $(flyctl auth whoami)"
}

# Check if app exists, create if it doesn't
check_or_create_app() {
    if flyctl apps show "$APP_NAME" &> /dev/null; then
        log_info "App '$APP_NAME' exists"
    else
        log_warning "App '$APP_NAME' does not exist. Creating it..."
        flyctl apps create "$APP_NAME" --org personal
        log_success "Created app '$APP_NAME'"
    fi
}

# Set up PostgreSQL database
setup_database() {
    log_info "Checking PostgreSQL database..."
    
    if flyctl postgres list | grep -q "${APP_NAME}-db"; then
        log_info "PostgreSQL database '${APP_NAME}-db' already exists"
    else
        log_warning "Creating PostgreSQL database..."
        flyctl postgres create --name "${APP_NAME}-db" --region "$REGION" --vm-size shared-cpu-1x --volume-size 10
        log_success "Created PostgreSQL database '${APP_NAME}-db'"
    fi
    
    # Attach database to app
    log_info "Attaching database to app..."
    flyctl postgres attach "${APP_NAME}-db" --app "$APP_NAME" || true
}

# Set up Redis (optional, for caching and sessions)
setup_redis() {
    log_info "Checking Redis..."
    
    if flyctl redis list | grep -q "${APP_NAME}-redis"; then
        log_info "Redis '${APP_NAME}-redis' already exists"
    else
        log_warning "Creating Redis instance..."
        flyctl redis create --name "${APP_NAME}-redis" --region "$REGION" --plan free
        log_success "Created Redis '${APP_NAME}-redis'"
    fi
}

# Set required secrets
setup_secrets() {
    log_info "Setting up secrets..."
    
    # Check if secrets exist
    secrets_output=$(flyctl secrets list --app "$APP_NAME" 2>/dev/null || echo "")
    
    # Generate SECRET_KEY_BASE if not exists
    if ! echo "$secrets_output" | grep -q "SECRET_KEY_BASE"; then
        log_warning "Generating SECRET_KEY_BASE..."
        secret_key_base=$(mix phx.gen.secret)
        flyctl secrets set SECRET_KEY_BASE="$secret_key_base" --app "$APP_NAME"
        log_success "Set SECRET_KEY_BASE"
    fi
    
    # Generate LIVE_VIEW_SIGNING_SALT if not exists
    if ! echo "$secrets_output" | grep -q "LIVE_VIEW_SIGNING_SALT"; then
        log_warning "Generating LIVE_VIEW_SIGNING_SALT..."
        live_view_salt=$(mix phx.gen.secret 32)
        flyctl secrets set LIVE_VIEW_SIGNING_SALT="$live_view_salt" --app "$APP_NAME"
        log_success "Set LIVE_VIEW_SIGNING_SALT"
    fi
    
    # Generate GUARDIAN_SECRET_KEY if not exists
    if ! echo "$secrets_output" | grep -q "GUARDIAN_SECRET_KEY"; then
        log_warning "Generating GUARDIAN_SECRET_KEY..."
        guardian_secret=$(mix phx.gen.secret 64)
        flyctl secrets set GUARDIAN_SECRET_KEY="$guardian_secret" --app "$APP_NAME"
        log_success "Set GUARDIAN_SECRET_KEY"
    fi
    
    log_info "Secrets are configured. Add OAuth secrets manually if needed:"
    log_info "  flyctl secrets set OAUTH_GITHUB_CLIENT_ID=your_github_client_id --app $APP_NAME"
    log_info "  flyctl secrets set OAUTH_GITHUB_CLIENT_SECRET=your_github_client_secret --app $APP_NAME"
    log_info "  flyctl secrets set OAUTH_GOOGLE_CLIENT_ID=your_google_client_id --app $APP_NAME"
    log_info "  flyctl secrets set OAUTH_GOOGLE_CLIENT_SECRET=your_google_client_secret --app $APP_NAME"
}

# Create volumes for persistent storage
setup_volumes() {
    log_info "Setting up persistent volumes..."
    
    # Check if volumes exist
    volumes_output=$(flyctl volumes list --app "$APP_NAME" 2>/dev/null || echo "")
    
    if ! echo "$volumes_output" | grep -q "kyozo_tmp"; then
        log_warning "Creating temporary storage volume..."
        flyctl volumes create kyozo_tmp --region "$REGION" --size 1 --app "$APP_NAME"
        log_success "Created kyozo_tmp volume"
    fi
    
    if ! echo "$volumes_output" | grep -q "kyozo_uploads"; then
        log_warning "Creating uploads storage volume..."
        flyctl volumes create kyozo_uploads --region "$REGION" --size 5 --app "$APP_NAME"
        log_success "Created kyozo_uploads volume"
    fi
}

# Run tests before deployment
run_tests() {
    log_info "Running tests..."
    if MIX_ENV=test mix test; then
        log_success "All tests passed"
    else
        log_error "Tests failed. Deployment aborted."
        exit 1
    fi
}

# Deploy the application
deploy_app() {
    log_info "Deploying application to Fly.io..."
    
    # Deploy with no-cache to ensure fresh build
    if flyctl deploy --no-cache --app "$APP_NAME"; then
        log_success "Deployment successful!"
        log_info "Your app is available at: https://${APP_NAME}.fly.dev"
    else
        log_error "Deployment failed!"
        exit 1
    fi
}

# Show app status
show_status() {
    log_info "App status:"
    flyctl status --app "$APP_NAME"
    
    log_info "Recent logs:"
    flyctl logs --app "$APP_NAME" | head -20
}

# Main deployment flow
main() {
    log_info "Starting Kyozo API deployment to Fly.io..."
    
    # Parse command line arguments
    SKIP_TESTS=false
    FORCE_DEPLOY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --force)
                FORCE_DEPLOY=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --skip-tests    Skip running tests before deployment"
                echo "  --force         Force deployment even if tests fail"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Pre-flight checks
    check_flyctl
    check_auth
    check_or_create_app
    
    # Infrastructure setup
    setup_database
    # setup_redis  # Uncomment if you need Redis
    setup_secrets
    setup_volumes
    
    # Run tests unless skipped
    if [ "$SKIP_TESTS" = false ]; then
        run_tests
    else
        log_warning "Skipping tests as requested"
    fi
    
    # Deploy
    deploy_app
    
    # Show final status
    show_status
    
    log_success "Deployment complete!"
    log_info "Next steps:"
    log_info "1. Set up your domain: flyctl certs create your-domain.com"
    log_info "2. Configure OAuth secrets if needed"
    log_info "3. Set up monitoring and alerts"
    log_info "4. Configure CDN if needed"
}

# Handle script interruption
trap 'log_error "Deployment interrupted!"; exit 1' INT TERM

# Run main function
main "$@"