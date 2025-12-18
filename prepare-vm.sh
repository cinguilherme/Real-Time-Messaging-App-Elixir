#!/bin/bash

################################################################################
# AWS VM Preparation Script for Real-Time Messaging API
# 
# This script prepares a fresh Ubuntu 22.04 LTS VM on AWS to run the
# Real-Time Messaging API in production.
#
# Usage:
#   sudo bash prepare-vm.sh
#
# What it does:
#   - Installs Erlang/OTP 26 and Elixir 1.16+
#   - Installs and configures PostgreSQL 14+
#   - Installs and configures Redis
#   - Installs and configures Nginx
#   - Sets up application user and directories
#   - Configures firewall (UFW)
#   - Sets up systemd services
#   - Installs Certbot for SSL
#
# Prerequisites:
#   - Fresh Ubuntu 22.04 LTS instance
#   - Root or sudo access
#   - Internet connectivity
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
APP_USER="messaging"
APP_DIR="/opt/messaging"
LOG_DIR="/var/log/messaging"
STORAGE_DIR="/opt/messaging/storage"
BACKUP_DIR="/opt/messaging/backups"
DB_NAME="messaging"
DB_USER="messaging_user"
ERLANG_VERSION="26"
ELIXIR_VERSION="1.16"
POSTGRES_VERSION="14"

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}[STEP]${NC} $1"
    echo -e "${BLUE}===================================================${NC}\n"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log_error "Cannot determine OS version"
        exit 1
    fi

    if [[ "$OS" != "ubuntu" ]]; then
        log_warn "This script is designed for Ubuntu 22.04 LTS"
        log_warn "Detected OS: $OS $VERSION"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

prompt_config() {
    log_step "Configuration Setup"
    
    echo "Please provide the following configuration values:"
    echo
    
    # Database password
    read -sp "PostgreSQL password for $DB_USER: " DB_PASSWORD
    echo
    read -sp "Confirm password: " DB_PASSWORD_CONFIRM
    echo
    
    if [[ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]]; then
        log_error "Passwords do not match"
        exit 1
    fi
    
    if [[ ${#DB_PASSWORD} -lt 12 ]]; then
        log_error "Password must be at least 12 characters"
        exit 1
    fi
    
    # Domain name (optional, can be configured later)
    read -p "Domain name (e.g., messaging.yourdomain.com) [optional]: " DOMAIN_NAME
    
    # Confirmation
    echo
    log_info "Configuration:"
    log_info "  Database User: $DB_USER"
    log_info "  Database Name: $DB_NAME"
    log_info "  Domain Name: ${DOMAIN_NAME:-Not configured}"
    log_info "  Application Directory: $APP_DIR"
    echo
    
    read -p "Continue with these settings? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Setup cancelled"
        exit 1
    fi
}

################################################################################
# Installation Functions
################################################################################

update_system() {
    log_step "Updating System Packages"
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update
    apt-get upgrade -y
    
    log_info "Installing essential build tools..."
    apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        software-properties-common \
        gnupg2 \
        apt-transport-https \
        ca-certificates \
        unzip \
        autoconf \
        m4 \
        libncurses5-dev \
        libssl-dev \
        libssh-dev \
        unixodbc-dev \
        gcc \
        g++ \
        make
    
    log_info "System packages updated successfully"
}

setup_timezone() {
    log_step "Configuring System Timezone"
    
    timedatectl set-timezone UTC
    log_info "Timezone set to UTC"
    timedatectl status
}

setup_firewall() {
    log_step "Configuring Firewall (UFW)"
    
    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        apt-get install -y ufw
    fi
    
    # Configure UFW rules
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable UFW
    echo "y" | ufw enable
    
    log_info "Firewall configured successfully"
    ufw status verbose
}

install_erlang_elixir() {
    log_step "Installing Erlang/OTP and Elixir"
    
    # Add Erlang Solutions repository
    if [[ ! -f /etc/apt/sources.list.d/erlang-solutions.list ]]; then
        log_info "Adding Erlang Solutions repository..."
        wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
        dpkg -i erlang-solutions_2.0_all.deb
        rm erlang-solutions_2.0_all.deb
        apt-get update
    fi
    
    # Install Erlang
    log_info "Installing Erlang/OTP ${ERLANG_VERSION}..."
    apt-get install -y esl-erlang
    
    # Install Elixir
    log_info "Installing Elixir ${ELIXIR_VERSION}..."
    apt-get install -y elixir
    
    # Verify installation
    ERLANG_INSTALLED=$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)
    ELIXIR_INSTALLED=$(elixir --version | grep Elixir | awk '{print $2}')
    
    log_info "Erlang/OTP version: $ERLANG_INSTALLED"
    log_info "Elixir version: $ELIXIR_INSTALLED"
    
    # Install Hex and Rebar as root (will be available for all users)
    log_info "Installing Hex and Rebar..."
    mix local.hex --force
    mix local.rebar --force
}

install_postgresql() {
    log_step "Installing and Configuring PostgreSQL"
    
    # Add PostgreSQL repository
    if [[ ! -f /etc/apt/sources.list.d/pgdg.list ]]; then
        log_info "Adding PostgreSQL repository..."
        sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        apt-get update
    fi
    
    # Install PostgreSQL
    log_info "Installing PostgreSQL ${POSTGRES_VERSION}..."
    apt-get install -y postgresql-${POSTGRES_VERSION} postgresql-contrib-${POSTGRES_VERSION}
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Wait for PostgreSQL to be ready
    sleep 3
    
    log_info "PostgreSQL installed successfully"
    systemctl status postgresql --no-pager
}

configure_postgresql() {
    log_step "Configuring PostgreSQL Database"
    
    # Create database user
    log_info "Creating database user: $DB_USER"
    sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" || true
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    
    # Create database
    log_info "Creating database: $DB_NAME"
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" || true
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    
    # Enable UUID extension
    log_info "Enabling UUID extension..."
    sudo -u postgres psql -d $DB_NAME -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
    
    # Update pg_hba.conf for local connections
    PG_HBA_CONF="/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
    
    if ! grep -q "local.*${DB_NAME}.*${DB_USER}" "$PG_HBA_CONF"; then
        log_info "Updating pg_hba.conf..."
        echo "local   ${DB_NAME}    ${DB_USER}                    scram-sha-256" >> "$PG_HBA_CONF"
        systemctl reload postgresql
    fi
    
    log_info "PostgreSQL configured successfully"
}

install_redis() {
    log_step "Installing and Configuring Redis"
    
    apt-get install -y redis-server
    
    # Configure Redis
    log_info "Configuring Redis..."
    sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
    
    # Start and enable Redis
    systemctl restart redis-server
    systemctl enable redis-server
    
    # Test Redis
    if redis-cli ping | grep -q PONG; then
        log_info "Redis installed and running successfully"
    else
        log_warn "Redis installation completed but ping test failed"
    fi
}

install_nginx() {
    log_step "Installing Nginx"
    
    apt-get install -y nginx
    
    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
    
    log_info "Nginx installed successfully"
    systemctl status nginx --no-pager
}

install_certbot() {
    log_step "Installing Certbot for SSL/TLS"
    
    apt-get install -y certbot python3-certbot-nginx
    
    log_info "Certbot installed successfully"
    log_info "To obtain SSL certificate, run:"
    log_info "  certbot --nginx -d your-domain.com"
}

setup_app_user() {
    log_step "Setting Up Application User and Directories"
    
    # Create application user if it doesn't exist
    if ! id "$APP_USER" &>/dev/null; then
        log_info "Creating user: $APP_USER"
        useradd -m -s /bin/bash "$APP_USER"
    else
        log_info "User $APP_USER already exists"
    fi
    
    # Create application directories
    log_info "Creating application directories..."
    mkdir -p "$APP_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$STORAGE_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Set ownership
    chown -R "$APP_USER":"$APP_USER" "$APP_DIR"
    chown -R "$APP_USER":"$APP_USER" "$LOG_DIR"
    chown -R "$APP_USER":"$APP_USER" "$STORAGE_DIR"
    chown -R "$APP_USER":"$APP_USER" "$BACKUP_DIR"
    
    # Set permissions
    chmod 755 "$APP_DIR"
    chmod 755 "$LOG_DIR"
    chmod 755 "$STORAGE_DIR"
    chmod 700 "$BACKUP_DIR"
    
    log_info "Application directories created successfully"
}

create_env_template() {
    log_step "Creating Environment Configuration Template"
    
    ENV_FILE="${APP_DIR}/.env.template"
    
    # Generate a placeholder secret key base
    SECRET_PLACEHOLDER="GENERATE_WITH_mix_phx_gen_secret"
    
    cat > "$ENV_FILE" << EOF
# Database Configuration
DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}
POOL_SIZE=20

# Phoenix Configuration
SECRET_KEY_BASE=${SECRET_PLACEHOLDER}
PHX_HOST=${DOMAIN_NAME:-localhost}
PORT=4000

# Feature Configuration
FEATURES_CONFIG=${APP_DIR}/app/config/features.yaml

# Storage Configuration
LOCAL_STORAGE_DIR=${STORAGE_DIR}
LOCAL_STORAGE_URL=https://${DOMAIN_NAME:-localhost}/storage

# Optional: S3 Configuration (uncomment and configure if using S3)
# S3_BUCKET=messaging-blobs
# S3_REGION=us-east-1
# AWS_ACCESS_KEY_ID=your_access_key
# AWS_SECRET_ACCESS_KEY=your_secret_key

# Oban Queue Concurrency
OBAN_DELIVER_REALTIME_CONCURRENCY=50
OBAN_SCHEDULED_DELIVERY_CONCURRENCY=5
OBAN_FILES_CONCURRENCY=4
OBAN_HEAVY_IO_CONCURRENCY=2

# Logging
LOG_LEVEL=info
EOF
    
    chmod 600 "$ENV_FILE"
    chown "$APP_USER":"$APP_USER" "$ENV_FILE"
    
    log_info "Environment template created at: $ENV_FILE"
    log_warn "IMPORTANT: You must generate SECRET_KEY_BASE before starting the app"
    log_warn "Run as $APP_USER user: cd ${APP_DIR}/app && mix phx.gen.secret"
}

create_nginx_config() {
    log_step "Creating Nginx Configuration Template"
    
    if [[ -z "$DOMAIN_NAME" ]]; then
        log_warn "No domain name provided, skipping Nginx configuration"
        log_info "You can configure Nginx manually later using SETUP-VM.MD guide"
        return
    fi
    
    NGINX_CONFIG="/etc/nginx/sites-available/messaging"
    
    cat > "$NGINX_CONFIG" << 'EOF'
upstream messaging_backend {
    server 127.0.0.1:4000 fail_timeout=10s max_fails=3;
    keepalive 32;
}

limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ws_limit:10m rate=5r/s;

server {
    listen 80;
    server_name DOMAIN_NAME_PLACEHOLDER;

    location / {
        proxy_pass http://messaging_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /healthz {
        proxy_pass http://messaging_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        access_log off;
    }
}
EOF
    
    # Replace domain placeholder
    sed -i "s/DOMAIN_NAME_PLACEHOLDER/${DOMAIN_NAME}/" "$NGINX_CONFIG"
    
    # Enable the site
    ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/messaging
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    if nginx -t; then
        systemctl reload nginx
        log_info "Nginx configuration created and enabled"
    else
        log_error "Nginx configuration test failed"
    fi
}

create_systemd_services() {
    log_step "Creating Systemd Service Templates"
    
    # API Service
    cat > /etc/systemd/system/messaging-api.service << EOF
[Unit]
Description=Real-Time Messaging API Server
After=network.target postgresql.service redis.service
Requires=postgresql.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}/app
EnvironmentFile=${APP_DIR}/.env
Environment=MIX_ENV=prod
Environment=LANG=en_US.UTF-8

ExecStart=/usr/bin/mix phx.server

Restart=on-failure
RestartSec=5
StandardOutput=append:${LOG_DIR}/api.log
StandardError=append:${LOG_DIR}/api-error.log

LimitNOFILE=65535
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
    
    # Job Processor Service
    cat > /etc/systemd/system/messaging-jobs.service << EOF
[Unit]
Description=Real-Time Messaging Job Processor
After=network.target postgresql.service redis.service
Requires=postgresql.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}/app
EnvironmentFile=${APP_DIR}/.env
Environment=MIX_ENV=prod
Environment=LANG=en_US.UTF-8

ExecStart=/usr/bin/mix run --no-halt

Restart=on-failure
RestartSec=5
StandardOutput=append:${LOG_DIR}/jobs.log
StandardError=append:${LOG_DIR}/jobs-error.log

LimitNOFILE=65535
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    log_info "Systemd services created (not yet enabled)"
    log_info "Services will be enabled after application deployment"
}

setup_log_rotation() {
    log_step "Setting Up Log Rotation"
    
    cat > /etc/logrotate.d/messaging << EOF
${LOG_DIR}/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 ${APP_USER} ${APP_USER}
    sharedscripts
    postrotate
        systemctl reload messaging-api > /dev/null 2>&1 || true
        systemctl reload messaging-jobs > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log_info "Log rotation configured"
}

create_backup_script() {
    log_step "Creating Database Backup Script"
    
    cat > /usr/local/bin/backup-messaging-db.sh << EOF
#!/bin/bash

BACKUP_DIR="${BACKUP_DIR}"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/messaging_\${TIMESTAMP}.sql.gz"

# Perform backup
sudo -u postgres pg_dump ${DB_NAME} | gzip > "\${BACKUP_FILE}"

# Keep only last 7 days of backups
find "\${BACKUP_DIR}" -name "messaging_*.sql.gz" -mtime +7 -delete

echo "Backup completed: \${BACKUP_FILE}"
EOF
    
    chmod +x /usr/local/bin/backup-messaging-db.sh
    
    log_info "Backup script created at: /usr/local/bin/backup-messaging-db.sh"
    log_info "Schedule with cron: 0 2 * * * /usr/local/bin/backup-messaging-db.sh"
}

create_health_check_script() {
    log_step "Creating Health Check Script"
    
    cat > /usr/local/bin/check-messaging-health.sh << 'EOF'
#!/bin/bash

HEALTH_URL="http://localhost:4000/healthz"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

if [ "$RESPONSE" -eq 200 ]; then
    echo "✓ Messaging API is healthy"
    exit 0
else
    echo "✗ Messaging API is unhealthy (HTTP $RESPONSE)"
    exit 1
fi
EOF
    
    chmod +x /usr/local/bin/check-messaging-health.sh
    
    log_info "Health check script created at: /usr/local/bin/check-messaging-health.sh"
}

create_deployment_guide() {
    log_step "Creating Deployment Guide"
    
    GUIDE_FILE="${APP_DIR}/DEPLOYMENT_NEXT_STEPS.txt"
    
    cat > "$GUIDE_FILE" << EOF
================================================================================
REAL-TIME MESSAGING API - DEPLOYMENT NEXT STEPS
================================================================================

The VM has been prepared successfully! Follow these steps to deploy the application:

1. DEPLOY APPLICATION CODE
   ------------------------
   Option A: Clone from Git repository
   $ su - ${APP_USER}
   $ cd ${APP_DIR}
   $ git clone YOUR_REPOSITORY_URL app
   $ cd app

   Option B: Copy from local machine
   $ scp -r /path/to/app ${APP_USER}@$(hostname -I | awk '{print $1}'):${APP_DIR}/

2. GENERATE SECRET KEY BASE
   -------------------------
   $ su - ${APP_USER}
   $ cd ${APP_DIR}/app
   $ mix phx.gen.secret
   
   Copy the output and update ${APP_DIR}/.env:
   Replace: SECRET_KEY_BASE=GENERATE_WITH_mix_phx_gen_secret
   With:    SECRET_KEY_BASE=<generated_secret>

3. INSTALL DEPENDENCIES AND BUILD
   -------------------------------
   $ su - ${APP_USER}
   $ cd ${APP_DIR}/app
   $ export MIX_ENV=prod
   $ mix deps.get --only prod
   $ mix deps.compile
   $ mix compile

4. RUN DATABASE MIGRATIONS
   ------------------------
   $ su - ${APP_USER}
   $ cd ${APP_DIR}/app
   $ MIX_ENV=prod mix ecto.migrate

5. CONFIGURE FEATURE FLAGS
   ------------------------
   Choose appropriate feature configuration:
   $ cp config/features.standard.yaml config/features.yaml
   
   Available options:
   - features.yaml (full featured)
   - features.minimal.yaml (core messaging only)
   - features.standard.yaml (balanced production)
   - features.no-media.yaml (no media processing)

6. START SERVICES
   --------------
   $ sudo systemctl enable messaging-api messaging-jobs
   $ sudo systemctl start messaging-api messaging-jobs
   $ sudo systemctl status messaging-api messaging-jobs

7. VERIFY DEPLOYMENT
   -----------------
   $ curl http://localhost:4000/healthz
   
   Expected response: {"status":"ok","timestamp":"..."}

8. CONFIGURE SSL/TLS (if domain is set)
   ------------------------------------
   $ sudo certbot --nginx -d ${DOMAIN_NAME:-your-domain.com}
   
   Follow the prompts to obtain SSL certificate.

9. SETUP MONITORING (Optional)
   ---------------------------
   # Schedule database backups (daily at 2 AM)
   $ sudo crontab -e
   Add: 0 2 * * * /usr/local/bin/backup-messaging-db.sh
   
   # Schedule health checks (every 5 minutes)
   Add: */5 * * * * /usr/local/bin/check-messaging-health.sh >> ${LOG_DIR}/health-check.log 2>&1

================================================================================
CONFIGURATION FILES
================================================================================

Environment file:     ${APP_DIR}/.env
Application directory: ${APP_DIR}/app
Log directory:        ${LOG_DIR}
Storage directory:    ${STORAGE_DIR}
Backup directory:     ${BACKUP_DIR}

Database:             ${DB_NAME}
Database user:        ${DB_USER}
Database connection:  postgres://${DB_USER}:****@localhost:5432/${DB_NAME}

================================================================================
USEFUL COMMANDS
================================================================================

# View logs
$ tail -f ${LOG_DIR}/api.log
$ tail -f ${LOG_DIR}/jobs.log
$ journalctl -u messaging-api -f

# Restart services
$ sudo systemctl restart messaging-api
$ sudo systemctl restart messaging-jobs

# Check service status
$ sudo systemctl status messaging-api
$ sudo systemctl status messaging-jobs

# Test database connection
$ psql -U ${DB_USER} -d ${DB_NAME} -h localhost

# Run health check
$ /usr/local/bin/check-messaging-health.sh

# Create database backup
$ /usr/local/bin/backup-messaging-db.sh

================================================================================
TROUBLESHOOTING
================================================================================

If services fail to start:
1. Check logs: journalctl -u messaging-api -n 50
2. Verify .env file has correct SECRET_KEY_BASE
3. Ensure database migrations ran successfully
4. Check database connectivity: psql -U ${DB_USER} -d ${DB_NAME} -h localhost

For more detailed troubleshooting, see: ${APP_DIR}/app/SETUP-VM.MD

================================================================================
DOCUMENTATION
================================================================================

Full setup guide:     ${APP_DIR}/app/SETUP-VM.MD
Development setup:    ${APP_DIR}/app/SETUP.md
Feature flags:        ${APP_DIR}/app/docs/FEATURE_FLAGS.md
API testing:          ${APP_DIR}/app/API_TESTING_GUIDE.md

================================================================================
EOF
    
    chown "$APP_USER":"$APP_USER" "$GUIDE_FILE"
    chmod 644 "$GUIDE_FILE"
    
    log_info "Deployment guide created at: $GUIDE_FILE"
}

print_summary() {
    log_step "Installation Summary"
    
    echo
    echo "=================================================="
    echo "  VM PREPARATION COMPLETED SUCCESSFULLY! 🎉"
    echo "=================================================="
    echo
    echo "Installed components:"
    echo "  ✓ Erlang/OTP ${ERLANG_VERSION}"
    echo "  ✓ Elixir ${ELIXIR_VERSION}+"
    echo "  ✓ PostgreSQL ${POSTGRES_VERSION}"
    echo "  ✓ Redis"
    echo "  ✓ Nginx"
    echo "  ✓ Certbot (for SSL)"
    echo "  ✓ UFW Firewall (configured)"
    echo
    echo "Configured:"
    echo "  ✓ Application user: ${APP_USER}"
    echo "  ✓ Application directory: ${APP_DIR}"
    echo "  ✓ Database: ${DB_NAME}"
    echo "  ✓ Database user: ${DB_USER}"
    if [[ -n "$DOMAIN_NAME" ]]; then
        echo "  ✓ Domain: ${DOMAIN_NAME}"
    fi
    echo
    echo "Created:"
    echo "  ✓ Systemd services (messaging-api, messaging-jobs)"
    echo "  ✓ Nginx configuration template"
    echo "  ✓ Environment configuration template"
    echo "  ✓ Backup scripts"
    echo "  ✓ Health check scripts"
    echo "  ✓ Log rotation configuration"
    echo
    echo "=================================================="
    echo "NEXT STEPS:"
    echo "=================================================="
    echo
    echo "1. Read the deployment guide:"
    echo "   cat ${APP_DIR}/DEPLOYMENT_NEXT_STEPS.txt"
    echo
    echo "2. Deploy your application code to:"
    echo "   ${APP_DIR}/app"
    echo
    echo "3. Generate SECRET_KEY_BASE:"
    echo "   su - ${APP_USER}"
    echo "   cd ${APP_DIR}/app"
    echo "   mix phx.gen.secret"
    echo
    echo "4. Update environment file:"
    echo "   nano ${APP_DIR}/.env"
    echo
    echo "5. Run database migrations:"
    echo "   MIX_ENV=prod mix ecto.migrate"
    echo
    echo "6. Start the services:"
    echo "   systemctl start messaging-api messaging-jobs"
    echo
    if [[ -n "$DOMAIN_NAME" ]]; then
        echo "7. Configure SSL certificate:"
        echo "   certbot --nginx -d ${DOMAIN_NAME}"
        echo
    fi
    echo "For detailed instructions, see:"
    echo "  ${APP_DIR}/DEPLOYMENT_NEXT_STEPS.txt"
    echo "  ${APP_DIR}/app/SETUP-VM.MD (after deploying code)"
    echo
    echo "=================================================="
    echo
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting AWS VM preparation for Real-Time Messaging API"
    echo
    
    # Pre-flight checks
    check_root
    check_os
    
    # Get configuration
    prompt_config
    
    # System setup
    update_system
    setup_timezone
    setup_firewall
    
    # Install software
    install_erlang_elixir
    install_postgresql
    configure_postgresql
    install_redis
    install_nginx
    install_certbot
    
    # Application setup
    setup_app_user
    create_env_template
    create_systemd_services
    create_nginx_config
    setup_log_rotation
    
    # Utilities
    create_backup_script
    create_health_check_script
    create_deployment_guide
    
    # Summary
    print_summary
    
    log_info "VM preparation completed successfully!"
}

# Run main function
main

exit 0
