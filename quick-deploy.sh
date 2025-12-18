#!/bin/bash
# Quick deployment script for Docker-based deployment
# This script helps automate the deployment process

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

# Check if .env exists
if [ ! -f .env ]; then
    print_error ".env file not found!"
    echo "Creating .env from .env.example..."
    
    if [ ! -f .env.example ]; then
        print_error ".env.example not found either!"
        exit 1
    fi
    
    cp .env.example .env
    echo ""
    echo "Generated .env file. Please update it with your actual values:"
    echo "  1. Set strong passwords for DB_PASSWORD, REDIS_PASSWORD, MINIO_ROOT_PASSWORD"
    echo "  2. Generate SECRET_KEY_BASE with: openssl rand -base64 64"
    echo "  3. Set your DOMAIN if using SSL"
    echo ""
    echo "After updating .env, run this script again."
    exit 1
fi

# Source .env file
source .env

# Check required environment variables
REQUIRED_VARS=("DB_PASSWORD" "SECRET_KEY_BASE")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    print_error "Missing required environment variables: ${MISSING_VARS[*]}"
    echo "Please update your .env file and try again."
    exit 1
fi

# Check if SECRET_KEY_BASE is still the default
if [[ "$SECRET_KEY_BASE" == *"your_secret_key_base_here"* ]]; then
    print_warning "SECRET_KEY_BASE appears to be using the default value."
    echo "Generate a secure key with: openssl rand -base64 64"
    read -p "Continue anyway? (not recommended for production) [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Main menu
echo ""
echo "=========================================="
echo "  Real-Time Messaging API - Docker Deploy"
echo "=========================================="
echo ""
echo "What would you like to do?"
echo "  1) Build and start services (first time deployment)"
echo "  2) Start existing services"
echo "  3) Stop services"
echo "  4) Restart services"
echo "  5) View logs"
echo "  6) Update and redeploy"
echo "  7) Backup database"
echo "  8) Run database migrations"
echo "  9) Check service status"
echo "  10) Validate deployment configuration"
echo "  11) Clean up (remove containers and volumes)"
echo "  0) Exit"
echo ""
read -p "Enter your choice [0-11]: " choice

case $choice in
    1)
        # Run validation first
        if [ -f "$SCRIPT_DIR/scripts/validate-deployment.sh" ]; then
            print_info "Running pre-deployment validation..."
            bash "$SCRIPT_DIR/scripts/validate-deployment.sh"
            if [ $? -ne 0 ]; then
                echo ""
                read -p "Validation found issues. Continue anyway? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
            echo ""
        fi
        
        print_step "Building and starting services..."
        docker compose -f docker-compose.prod.yaml build
        docker compose -f docker-compose.prod.yaml up -d
        
        echo ""
        print_step "Waiting for services to start..."
        sleep 10
        
        print_step "Checking service health..."
        docker compose -f docker-compose.prod.yaml ps
        
        echo ""
        print_step "Creating MinIO bucket..."
        docker compose -f docker-compose.prod.yaml exec s3_minio sh -c "
            mc alias set myminio http://localhost:9000 \$MINIO_ROOT_USER \$MINIO_ROOT_PASSWORD 2>/dev/null
            mc mb myminio/messaging-blobs 2>/dev/null || true
            mc anonymous set download myminio/messaging-blobs 2>/dev/null
            echo 'MinIO bucket created successfully'
        " || print_warning "Could not create MinIO bucket automatically. You may need to do this manually."
        
        echo ""
        print_step "Testing API health endpoint..."
        sleep 5
        if curl -s http://localhost:4000/api/health | grep -q "ok"; then
            echo -e "${GREEN}✓${NC} API is healthy!"
        else
            print_warning "API health check failed. Check logs with: docker compose -f docker-compose.prod.yaml logs app"
        fi
        
        echo ""
        echo "Deployment complete!"
        echo "API is available at: http://localhost:4000"
        if [ ! -z "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
            echo "Or at: http://$DOMAIN:4000"
        fi
        ;;
        
    2)
        print_step "Starting services..."
        docker compose -f docker-compose.prod.yaml up -d
        docker compose -f docker-compose.prod.yaml ps
        ;;
        
    3)
        print_step "Stopping services..."
        docker compose -f docker-compose.prod.yaml stop
        echo "Services stopped."
        ;;
        
    4)
        print_step "Restarting services..."
        docker compose -f docker-compose.prod.yaml restart
        docker compose -f docker-compose.prod.yaml ps
        ;;
        
    5)
        echo "Which service logs would you like to view?"
        echo "  1) All services"
        echo "  2) Application only"
        echo "  3) PostgreSQL"
        echo "  4) Redis"
        echo "  5) MinIO"
        read -p "Enter your choice [1-5]: " log_choice
        
        case $log_choice in
            1) docker compose -f docker-compose.prod.yaml logs -f ;;
            2) docker compose -f docker-compose.prod.yaml logs -f app ;;
            3) docker compose -f docker-compose.prod.yaml logs -f postgres ;;
            4) docker compose -f docker-compose.prod.yaml logs -f redis ;;
            5) docker compose -f docker-compose.prod.yaml logs -f s3_minio ;;
            *) echo "Invalid choice" ;;
        esac
        ;;
        
    6)
        print_step "Pulling latest changes..."
        git pull origin main || print_warning "Git pull failed. Continuing with local code."
        
        print_step "Rebuilding application..."
        docker compose -f docker-compose.prod.yaml build app
        
        print_step "Restarting application..."
        docker compose -f docker-compose.prod.yaml up -d app
        
        print_step "Checking logs..."
        docker compose -f docker-compose.prod.yaml logs --tail=50 app
        
        echo ""
        echo "Update complete!"
        ;;
        
    7)
        BACKUP_DIR="./backups"
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"
        
        print_step "Creating database backup..."
        docker compose -f docker-compose.prod.yaml exec -T postgres \
            pg_dump -U messaging_user messaging_prod > "$BACKUP_FILE"
        
        print_step "Compressing backup..."
        gzip "$BACKUP_FILE"
        
        echo ""
        echo -e "${GREEN}✓${NC} Backup created: $BACKUP_FILE.gz"
        echo "Backup size: $(du -h $BACKUP_FILE.gz | cut -f1)"
        ;;
        
    8)
        print_step "Running database migrations..."
        docker compose -f docker-compose.prod.yaml exec app \
            bin/messaging_api eval "Messaging.Release.migrate()"
        echo "Migrations complete!"
        ;;
        
    9)
        print_step "Service Status:"
        docker compose -f docker-compose.prod.yaml ps
        
        echo ""
        print_step "Resource Usage:"
        docker stats --no-stream
        
        echo ""
        print_step "API Health Check:"
        if curl -s http://localhost:4000/api/health | grep -q "ok"; then
            echo -e "${GREEN}✓${NC} API is healthy"
        else
            echo -e "${RED}✗${NC} API is not responding"
        fi
        ;;
        
    10)
        print_step "Running deployment validation..."
        if [ -f "$SCRIPT_DIR/scripts/validate-deployment.sh" ]; then
            bash "$SCRIPT_DIR/scripts/validate-deployment.sh"
        else
            print_error "Validation script not found at: $SCRIPT_DIR/scripts/validate-deployment.sh"
        fi
        ;;
        
    11)
        print_warning "This will remove all containers and volumes (including data)!"
        read -p "Are you sure? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_step "Stopping services..."
            docker compose -f docker-compose.prod.yaml down
            
            read -p "Also remove volumes (database data, storage, etc.)? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_step "Removing volumes..."
                docker compose -f docker-compose.prod.yaml down -v
                echo "All data removed."
            fi
            echo "Cleanup complete."
        fi
        ;;
        
    0)
        echo "Exiting..."
        exit 0
        ;;
        
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac
