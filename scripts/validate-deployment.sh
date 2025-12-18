#!/bin/bash
# Pre-deployment validation script
# Checks for common issues before deploying

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check Docker installation
print_header "Checking Docker Installation"

if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker is installed: $DOCKER_VERSION"
else
    print_error "Docker is not installed"
fi

if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
    if command -v docker compose &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version)
    else
        COMPOSE_VERSION=$(docker-compose --version)
    fi
    print_success "Docker Compose is installed: $COMPOSE_VERSION"
else
    print_error "Docker Compose is not installed"
fi

# Check if Docker daemon is running
if docker info &> /dev/null; then
    print_success "Docker daemon is running"
else
    print_error "Docker daemon is not running"
fi

# Check required files
print_header "Checking Required Files"

REQUIRED_FILES=(
    "docker-compose.prod.yaml"
    "Dockerfile"
    "config/features.yaml"
    "mix.exs"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
    fi
done

# Check .env file
if [ -f ".env" ]; then
    print_success "Found: .env"
    
    # Check for required variables
    print_header "Validating Environment Variables"
    
    source .env 2>/dev/null || true
    
    # Required variables
    if [ -z "$SECRET_KEY_BASE" ]; then
        print_error "SECRET_KEY_BASE is not set in .env"
    elif [[ "$SECRET_KEY_BASE" == *"your_secret_key_base_here"* ]]; then
        print_error "SECRET_KEY_BASE is still using default value"
    else
        print_success "SECRET_KEY_BASE is set"
    fi
    
    if [ -z "$DB_PASSWORD" ]; then
        print_error "DB_PASSWORD is not set in .env"
    elif [ "$DB_PASSWORD" == "changeme123" ]; then
        print_warning "DB_PASSWORD is using default value (not recommended for production)"
    else
        print_success "DB_PASSWORD is set"
    fi
    
    # Optional but recommended
    if [ -z "$DOMAIN" ]; then
        print_warning "DOMAIN is not set (using localhost)"
    else
        print_success "DOMAIN is set to: $DOMAIN"
    fi
    
    if [ -z "$MINIO_ROOT_PASSWORD" ]; then
        print_warning "MINIO_ROOT_PASSWORD not set, using default"
    elif [ "$MINIO_ROOT_PASSWORD" == "minioadmin" ]; then
        print_warning "MINIO_ROOT_PASSWORD is using default value"
    else
        print_success "MINIO_ROOT_PASSWORD is set"
    fi
    
    if [ -z "$REDIS_PASSWORD" ]; then
        print_warning "REDIS_PASSWORD not set, using default"
    elif [ "$REDIS_PASSWORD" == "redispass123" ]; then
        print_warning "REDIS_PASSWORD is using default value"
    else
        print_success "REDIS_PASSWORD is set"
    fi
    
else
    print_error ".env file not found"
    print_info "Create .env from .env.example: cp .env.example .env"
fi

# Check features configuration
print_header "Checking Features Configuration"

if [ -f "config/features.yaml" ]; then
    print_success "Default features.yaml found"
    
    # Check for basic YAML structure
    if grep -q "^features:" config/features.yaml && \
       grep -q "^storage:" config/features.yaml && \
       grep -q "^jobs:" config/features.yaml; then
        print_success "features.yaml has valid structure"
    else
        print_warning "features.yaml may have invalid structure"
    fi
else
    print_error "config/features.yaml not found"
fi

# Check available disk space
print_header "Checking System Resources"

AVAILABLE_DISK=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_DISK" -ge 20 ]; then
    print_success "Available disk space: ${AVAILABLE_DISK}GB"
else
    print_warning "Low disk space: ${AVAILABLE_DISK}GB (recommended: 30GB+)"
fi

# Check available memory
if command -v free &> /dev/null; then
    AVAILABLE_MEMORY=$(free -g | awk '/^Mem:/ {print $2}')
    if [ "$AVAILABLE_MEMORY" -ge 4 ]; then
        print_success "Available memory: ${AVAILABLE_MEMORY}GB"
    else
        print_warning "Low memory: ${AVAILABLE_MEMORY}GB (recommended: 4GB+)"
    fi
fi

# Check if ports are available
print_header "Checking Port Availability"

PORTS=(4000 5432 6379 9000 9001 11211)
PORT_NAMES=("Application" "PostgreSQL" "Redis" "MinIO S3" "MinIO Console" "Memcached")

for i in "${!PORTS[@]}"; do
    PORT="${PORTS[$i]}"
    NAME="${PORT_NAMES[$i]}"
    
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Port $PORT ($NAME) is already in use"
        else
            print_success "Port $PORT ($NAME) is available"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$PORT "; then
            print_warning "Port $PORT ($NAME) is already in use"
        else
            print_success "Port $PORT ($NAME) is available"
        fi
    else
        print_info "Cannot check port $PORT (lsof/netstat not available)"
    fi
done

# Check network connectivity (if deploying with domain)
if [ ! -z "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
    print_header "Checking Domain Configuration"
    
    if command -v dig &> /dev/null; then
        DNS_IP=$(dig +short $DOMAIN | head -1)
        if [ ! -z "$DNS_IP" ]; then
            print_success "Domain $DOMAIN resolves to: $DNS_IP"
            
            # Check if it matches current IP
            if command -v curl &> /dev/null; then
                CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
                if [ "$DNS_IP" == "$CURRENT_IP" ]; then
                    print_success "Domain points to this server"
                else
                    print_warning "Domain IP ($DNS_IP) doesn't match server IP ($CURRENT_IP)"
                fi
            fi
        else
            print_warning "Domain $DOMAIN doesn't resolve to an IP"
        fi
    else
        print_info "Cannot check domain (dig not available)"
    fi
fi

# Check Elixir/Mix for local development
print_header "Checking Elixir Installation (optional)"

if command -v elixir &> /dev/null; then
    ELIXIR_VERSION=$(elixir --version | grep Elixir | awk '{print $2}')
    print_success "Elixir is installed: $ELIXIR_VERSION"
else
    print_info "Elixir is not installed (not required for Docker deployment)"
fi

# Summary
print_header "Validation Summary"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready to deploy.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review your .env configuration"
    echo "  2. Run: docker compose -f docker-compose.prod.yaml build"
    echo "  3. Run: docker compose -f docker-compose.prod.yaml up -d"
    echo "  4. Or use: ./quick-deploy.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warning(s).${NC}"
    echo "You can proceed, but consider addressing the warnings above."
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo "Please fix the errors above before deploying."
    exit 1
fi
