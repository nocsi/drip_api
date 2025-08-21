#!/bin/bash

# Kyozo API Deployment Script
# This script automates the deployment process to Fly.io

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="kyozo-api"
REGION="sea"
POSTGRES_VM_SIZE="shared-cpu-1x"
POSTGRES_VOLUME_SIZE="20"
APP_VM_SIZE="shared-cpu-2x"
APP_MEMORY="2gb"

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Progress indicator
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check if flyctl is installed
check_flyctl() {
    log_step "Checking flyctl installation..."
    if ! command -v flyctl &> /dev/null; then
        log_error "flyctl is not installed. Installing it now..."
        curl -L https://fly.io/install.sh | sh
        export PATH="$HOME/.fly/bin:$PATH"
        if ! command -v flyctl &> /dev/null; then
            log_error "Failed to install flyctl. Please install it manually from https://fly.io/docs/getting-started/installing-flyctl/"
            exit 1
        fi
    fi
    log_success "flyctl is installed: $(flyctl version)"
}

# Check if user is authenticated with Fly.io
check_auth() {
    log_step "Checking Fly.io authentication..."
    if ! flyctl auth whoami &> /dev/null; then
        log_error "Not authenticated with Fly.io. Please run 'flyctl auth login'"
        exit 1
    fi
    log_success "Authenticated with Fly.io as: $(flyctl auth whoami)"
}

# Check if app exists, create if it doesn't
check_or_create_app() {
    log_step "Checking if app '$APP_NAME' exists..."
    if flyctl apps show "$APP_NAME" &> /dev/null; then
        log_success "App '$APP_NAME' exists"
    else
        log_warning "App '$APP_NAME' does not exist. Creating it..."
        flyctl apps create "$APP_NAME" --org personal --region "$REGION"
        log_success "Created app '$APP_NAME'"
    fi
}

# Set up PostgreSQL database
setup_database() {
    log_step "Setting up PostgreSQL database..."
    
    if flyctl postgres list | grep -q "${APP_NAME}-db"; then
        log_success "PostgreSQL database '${APP_NAME}-db' already exists"
    else
        log_warning "Creating PostgreSQL database..."
        flyctl postgres create \
            --name "${APP_NAME}-db" \
            --region "$REGION" \
            --vm-size "$POSTGRES_VM_SIZE" \
            --volume-size "$POSTGRES_VOLUME_SIZE" \
            --initial-cluster-size 1
        log_success "Created PostgreSQL database '${APP_NAME}-db'"
    fi
    
    # Attach database to app
    log_info "Attaching database to app..."
    flyctl postgres attach "${APP_NAME}-db" --app "$APP_NAME" || {
        log_warning "Database might already be attached"
    }
}

# Set up Redis (optional, for caching and sessions)
setup_redis() {
    log_step "Setting up Redis..."
    
    if flyctl redis list | grep -q "${APP_NAME}-redis"; then
        log_success "Redis '${APP_NAME}-redis' already exists"
    else
        log_warning "Creating Redis instance..."
        flyctl redis create \
            --name "${APP_NAME}-redis" \
            --region "$REGION" \
            --plan free
        log_success "Created Redis '${APP_NAME}-redis'"
    fi
}

# Generate secure secrets
generate_secret() {
    local length=${1:-64}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Set required secrets
setup_secrets() {
    log_step "Setting up application secrets..."
    
    # Check existing secrets
    secrets_output=$(flyctl secrets list --app "$APP_NAME" 2>/dev/null || echo "")
    
    # Required secrets with their generators
    declare -A secrets=(
        ["SECRET_KEY_BASE"]="mix phx.gen.secret"
        ["TOKEN_SIGNING_SECRET"]="generate_secret 64"
        ["LIVE_VIEW_SIGNING_SALT"]="mix phx.gen.secret 32"
        ["GUARDIAN_SECRET_KEY"]="generate_secret 64"
    )
    
    for secret_name in "${!secrets[@]}"; do
        if ! echo "$secrets_output" | grep -q "$secret_name"; then
            log_warning "Generating $secret_name..."
            secret_value=$(eval "${secrets[$secret_name]}")
            flyctl secrets set "$secret_name=$secret_value" --app "$APP_NAME"
            log_success "Set $secret_name"
        else
            log_info "$secret_name already exists"
        fi
    done
    
    # Show manual setup instructions
    echo -e "\n${YELLOW}=== Manual Setup Required ===${NC}"
    log_info "Add OAuth secrets manually if needed:"
    echo "  flyctl secrets set OAUTH_GITHUB_CLIENT_ID=your_github_client_id --app $APP_NAME"
    echo "  flyctl secrets set OAUTH_GITHUB_CLIENT_SECRET=your_github_client_secret --app $APP_NAME"
    echo "  flyctl secrets set OAUTH_GOOGLE_CLIENT_ID=your_google_client_id --app $APP_NAME"
    echo "  flyctl secrets set OAUTH_GOOGLE_CLIENT_SECRET=your_google_client_secret --app $APP_NAME"
    
    log_info "Optional email configuration:"
    echo "  flyctl secrets set MAILGUN_API_KEY=your_mailgun_key --app $APP_NAME"
    echo "  flyctl secrets set MAILGUN_DOMAIN=your_domain --app $APP_NAME"
}

# Create volumes for persistent storage
setup_volumes() {
    log_step "Setting up persistent volumes..."
    
    # Volume configurations
    declare -A volumes=(
        ["kyozo_tmp"]="3"
        ["kyozo_uploads"]="10"
        ["kyozo_logs"]="5"
    )
    
    volumes_output=$(flyctl volumes list --app "$APP_NAME" 2>/dev/null || echo "")
    
    for volume_name in "${!volumes[@]}"; do
        if ! echo "$volumes_output" | grep -q "$volume_name"; then
            log_warning "Creating ${volume_name} volume..."
            flyctl volumes create "$volume_name" \
                --region "$REGION" \
                --size "${volumes[$volume_name]}" \
                --app "$APP_NAME"
            log_success "Created $volume_name volume"
        else
            log_info "$volume_name volume already exists"
        fi
    done
}

# Check project dependencies and build requirements
check_project() {
    log_step "Checking project requirements..."
    
    # Check if we're in the right directory
    if [ ! -f "mix.exs" ]; then
        log_error "mix.exs not found. Please run this script from the project root."
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        log_error "Dockerfile not found. Please ensure Dockerfile exists in project root."
        exit 1
    fi
    
    # Check if fly.toml exists
    if [ ! -f "fly.toml" ]; then
        log_error "fly.toml not found. Please ensure fly.toml exists in project root."
        exit 1
    fi
    
    log_success "Project structure validation passed"
}

# Install and update dependencies
setup_dependencies() {
    log_step "Setting up project dependencies..."
    
    log_info "Installing Elixir dependencies..."
    mix deps.get --only prod
    
    if [ -d "assets" ] && [ -f "assets/package.json" ]; then
        log_info "Installing Node.js dependencies..."
        cd assets
        if command -v pnpm &> /dev/null; then
            pnpm install --frozen-lockfile
        elif command -v yarn &> /dev/null; then
            yarn install --frozen-lockfile
        else
            npm ci
        fi
        cd ..
    fi
    
    log_success "Dependencies installed"
}

# Run tests before deployment
run_tests() {
    log_step "Running test suite..."
    
    # Set up test database
    log_info "Setting up test database..."
    MIX_ENV=test mix ash.setup --quiet
    
    # Run tests
    log_info "Executing tests..."
    if MIX_ENV=test mix test --max-failures 3; then
        log_success "All tests passed"
        return 0
    else
        log_error "Tests failed!"
        return 1
    fi
}

# Run linting and code analysis
run_code_analysis() {
    log_step "Running code analysis..."
    
    # Format check
    if command -v mix format &> /dev/null; then
        log_info "Checking code formatting..."
        mix format --check-formatted || {
            log_warning "Code formatting issues found. Run 'mix format' to fix."
        }
    fi
    
    # Compile with warnings as errors
    log_info "Compiling with strict warnings..."
    MIX_ENV=prod mix compile --warnings-as-errors --force || {
        log_error "Compilation warnings found. Please fix them before deploying."
        return 1
    }
    
    log_success "Code analysis passed"
}

# Build and validate Docker image locally
validate_docker_build() {
    log_step "Validating Docker build..."
    
    log_info "Building Docker image locally for validation..."
    if docker build -t "${APP_NAME}-local" .; then
        log_success "Docker build validation passed"
        
        # Clean up local image
        docker rmi "${APP_NAME}-local" &> /dev/null || true
    else
        log_error "Docker build failed. Please fix Dockerfile issues."
        return 1
    fi
}

# Deploy the application
deploy_app() {
    log_step "Deploying application to Fly.io..."
    
    # Show deployment info
    log_info "Deployment configuration:"
    echo "  App: $APP_NAME"
    echo "  Region: $REGION"
    echo "  VM Size: $APP_VM_SIZE"
    echo "  Memory: $APP_MEMORY"
    
    # Deploy with configuration
    deploy_args=(
        "--app" "$APP_NAME"
        "--region" "$REGION"
        "--vm-size" "$APP_VM_SIZE"
        "--vm-memory" "$APP_MEMORY"
    )
    
    if [ "$FORCE_DEPLOY" = true ]; then
        deploy_args+=("--no-cache")
        log_warning "Force deploy enabled - building without cache"
    fi
    
    if flyctl deploy "${deploy_args[@]}"; then
        log_success "Deployment successful!"
        return 0
    else
        log_error "Deployment failed!"
        return 1
    fi
}

# Post-deployment verification
verify_deployment() {
    log_step "Verifying deployment..."
    
    # Wait for app to be ready
    log_info "Waiting for app to be ready..."
    sleep 30
    
    # Check app status
    log_info "Checking app status..."
    if flyctl status --app "$APP_NAME"; then
        log_success "App is running"
    else
        log_warning "App status check failed"
    fi
    
    # Check health endpoint
    app_url="https://${APP_NAME}.fly.dev"
    log_info "Testing health endpoint..."
    if curl -f -s "${app_url}/api/health" > /dev/null; then
        log_success "Health check passed"
    else
        log_warning "Health check failed - app might still be starting"
    fi
    
    # Show app information
    echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
    log_success "Your app is available at: $app_url"
    log_info "Admin dashboard: ${app_url}/dev/dashboard"
    log_info "API documentation: ${app_url}/api/docs"
}

# Show app status and logs
show_status() {
    log_step "Showing app status and recent logs..."
    
    echo -e "\n${BLUE}=== App Status ===${NC}"
    flyctl status --app "$APP_NAME"
    
    echo -e "\n${BLUE}=== Recent Logs ===${NC}"
    flyctl logs --app "$APP_NAME" --lines 50
}

# Rollback to previous version
rollback() {
    log_step "Rolling back to previous version..."
    
    if flyctl releases --app "$APP_NAME" | head -5; then
        echo ""
        read -p "Enter release ID to rollback to (or 'cancel'): " release_id
        
        if [ "$release_id" != "cancel" ] && [ -n "$release_id" ]; then
            flyctl rollback "$release_id" --app "$APP_NAME"
            log_success "Rollback initiated"
        else
            log_info "Rollback cancelled"
        fi
    else
        log_error "Could not retrieve release history"
    fi
}

# Show help
show_help() {
    cat << EOF
Kyozo API Deployment Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  deploy          Deploy the application (default)
  rollback        Rollback to a previous version
  status          Show app status and logs
  setup           Set up infrastructure only
  secrets         Set up secrets only
  validate        Validate project without deploying

Options:
  --skip-tests           Skip running tests before deployment
  --skip-validation      Skip Docker build validation
  --skip-analysis        Skip code analysis
  --force                Force deployment with fresh build
  --environment ENV      Set deployment environment (default: prod)
  --region REGION        Set deployment region (default: sea)
  --help, -h            Show this help message

Examples:
  $0                     # Deploy with all checks
  $0 deploy --skip-tests # Deploy without running tests
  $0 setup              # Set up infrastructure only
  $0 rollback           # Rollback to previous version
  $0 status             # Show current status

Environment Variables:
  APP_NAME              Override app name (default: kyozo-api)
  REGION                Override region (default: sea)
  SKIP_TESTS            Set to 'true' to skip tests
  FORCE_DEPLOY          Set to 'true' for force deploy

EOF
}

# Main deployment flow
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════╗"
    echo "║        Kyozo API Deployment          ║"
    echo "║              to Fly.io               ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Parse command line arguments
    COMMAND="deploy"
    SKIP_TESTS=false
    SKIP_VALIDATION=false
    SKIP_ANALYSIS=false
    FORCE_DEPLOY=false
    ENVIRONMENT="prod"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            deploy|rollback|status|setup|secrets|validate)
                COMMAND=$1
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --skip-analysis)
                SKIP_ANALYSIS=true
                shift
                ;;
            --force)
                FORCE_DEPLOY=true
                shift
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Override with environment variables if set
    SKIP_TESTS=${SKIP_TESTS:-$SKIP_TESTS}
    FORCE_DEPLOY=${FORCE_DEPLOY:-$FORCE_DEPLOY}
    
    # Execute based on command
    case $COMMAND in
        rollback)
            check_flyctl
            check_auth
            rollback
            exit 0
            ;;
        status)
            check_flyctl
            check_auth
            show_status
            exit 0
            ;;
        setup)
            log_info "Setting up infrastructure for $APP_NAME..."
            check_flyctl
            check_auth
            check_or_create_app
            setup_database
            setup_secrets
            setup_volumes
            log_success "Infrastructure setup complete!"
            exit 0
            ;;
        secrets)
            check_flyctl
            check_auth
            setup_secrets
            exit 0
            ;;
        validate)
            check_project
            setup_dependencies
            if [ "$SKIP_ANALYSIS" = false ]; then
                run_code_analysis || exit 1
            fi
            if [ "$SKIP_TESTS" = false ]; then
                run_tests || exit 1
            fi
            if [ "$SKIP_VALIDATION" = false ]; then
                validate_docker_build || exit 1
            fi
            log_success "Validation complete!"
            exit 0
            ;;
        deploy)
            # Continue with deployment
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
    
    # Pre-flight checks
    check_project
    check_flyctl
    check_auth
    check_or_create_app
    
    # Infrastructure setup
    setup_database
    setup_secrets
    setup_volumes
    
    # Project validation
    setup_dependencies
    
    if [ "$SKIP_ANALYSIS" = false ]; then
        run_code_analysis || {
            if [ "$FORCE_DEPLOY" = false ]; then
                exit 1
            else
                log_warning "Code analysis failed but continuing due to --force flag"
            fi
        }
    fi
    
    if [ "$SKIP_VALIDATION" = false ]; then
        validate_docker_build || {
            if [ "$FORCE_DEPLOY" = false ]; then
                exit 1
            else
                log_warning "Docker validation failed but continuing due to --force flag"
            fi
        }
    fi
    
    # Run tests unless skipped
    if [ "$SKIP_TESTS" = false ]; then
        run_tests || {
            if [ "$FORCE_DEPLOY" = false ]; then
                exit 1
            else
                log_warning "Tests failed but continuing due to --force flag"
            fi
        }
    else
        log_warning "Skipping tests as requested"
    fi
    
    # Deploy
    if deploy_app; then
        verify_deployment
        log_success "🎉 Deployment completed successfully!"
        
        # Show next steps
        echo -e "\n${BLUE}=== Next Steps ===${NC}"
        log_info "1. Set up your custom domain:"
        echo "   flyctl certs create your-domain.com --app $APP_NAME"
        log_info "2. Configure OAuth secrets if needed"
        log_info "3. Set up monitoring and alerts"
        log_info "4. Configure CDN for static assets"
        log_info "5. Set up automated backups"
    else
        log_error "💥 Deployment failed!"
        log_info "Check the logs above for details"
        log_info "You can view more logs with: flyctl logs --app $APP_NAME"
        exit 1
    fi
}

# Handle script interruption gracefully
cleanup() {
    log_warning "Deployment interrupted! Cleaning up..."
    exit 130
}

trap cleanup INT TERM

# Change to script directory
cd "$(dirname "$0")/.."

# Run main function
main "$@"