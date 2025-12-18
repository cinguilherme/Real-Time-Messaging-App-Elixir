# Cloud VM Setup Guide - Real-Time Messaging API

This guide walks you through setting up the Real-Time Messaging API on a bare cloud VM instance from scratch. This is a production-ready setup without Docker.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Server Setup](#initial-server-setup)
3. [Install System Dependencies](#install-system-dependencies)
4. [Install Erlang/OTP and Elixir](#install-erlangotp-and-elixir)
5. [Install and Configure PostgreSQL](#install-and-configure-postgresql)
6. [Install Redis (Optional)](#install-redis-optional)
7. [Setup Application User](#setup-application-user)
8. [Deploy Application Code](#deploy-application-code)
9. [Configure Environment](#configure-environment)
10. [Build Release](#build-release)
11. [Configure Systemd Services](#configure-systemd-services)
12. [Setup Nginx Reverse Proxy](#setup-nginx-reverse-proxy)
13. [SSL/TLS with Let's Encrypt](#ssltls-with-lets-encrypt)
14. [Monitoring and Logs](#monitoring-and-logs)
15. [Maintenance Tasks](#maintenance-tasks)
16. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Cloud Provider Requirements

- **VM Specifications (Minimum)**:
  - CPU: 2 vCPUs
  - RAM: 4GB (8GB recommended for production)
  - Storage: 20GB SSD (adjust based on expected message volume)
  - Network: Public IP address, ports 80, 443, and 4000 accessible

- **Operating System**: 
  - Ubuntu 22.04 LTS (recommended)
  - Debian 11+
  - CentOS 8+ / Rocky Linux 8+
  
This guide uses Ubuntu 22.04 LTS commands. Adjust package manager commands for other distributions.

### Domain Setup

- A domain name pointing to your VM's IP address (required for SSL/TLS)
- DNS A record: `messaging.yourdomain.com` → `YOUR_VM_IP`

---

## Initial Server Setup

### 1. Connect to Your VM

```bash
ssh root@YOUR_VM_IP
# or if using key-based auth:
ssh -i /path/to/key.pem ubuntu@YOUR_VM_IP
```

### 2. Update System Packages

```bash
# Update package lists and upgrade existing packages
apt update && apt upgrade -y

# Install basic utilities
apt install -y curl wget git build-essential software-properties-common \
  gnupg2 apt-transport-https ca-certificates unzip
```

### 3. Configure Firewall (UFW)

```bash
# Enable UFW firewall
ufw allow OpenSSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable
```

### 4. Set System Timezone (Recommended: UTC)

```bash
timedatectl set-timezone UTC
timedatectl status
```

---

## Install System Dependencies

### Required Build Tools

```bash
apt install -y \
  autoconf \
  m4 \
  libncurses5-dev \
  libssl-dev \
  libssh-dev \
  unixodbc-dev \
  gcc \
  g++ \
  make \
  libwxgtk3.0-gtk3-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev \
  libpng-dev \
  libssh-dev \
  xsltproc \
  fop \
  libxml2-utils
```

---

## Install Erlang/OTP and Elixir

### Method 1: Using Official Erlang Solutions Repository (Recommended)

```bash
# Add Erlang Solutions repository
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
dpkg -i erlang-solutions_2.0_all.deb
apt update

# Install Erlang/OTP 26
apt install -y esl-erlang

# Verify Erlang installation
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
```

### Install Elixir

```bash
# Install Elixir (version 1.16+)
apt install -y elixir

# Verify installation
elixir --version
# Should show Elixir 1.16.x or higher and Erlang/OTP 26
```

### Method 2: Using asdf Version Manager (Alternative)

```bash
# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc

# Install Erlang plugin
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf install erlang 26.2.1
asdf global erlang 26.2.1

# Install Elixir plugin
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install elixir 1.16.0-otp-26
asdf global elixir 1.16.0-otp-26

# Verify
elixir --version
```

### Install Hex and Rebar

```bash
mix local.hex --force
mix local.rebar --force
```

---

## Install and Configure PostgreSQL

### Install PostgreSQL 14+

```bash
# Add PostgreSQL repository
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt update

# Install PostgreSQL 14
apt install -y postgresql-14 postgresql-contrib-14

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql
systemctl status postgresql
```

### Configure PostgreSQL

```bash
# Switch to postgres user
sudo -u postgres psql

# Inside psql prompt, run:
CREATE USER messaging_user WITH PASSWORD 'YOUR_SECURE_PASSWORD_HERE';
CREATE DATABASE messaging OWNER messaging_user;
GRANT ALL PRIVILEGES ON DATABASE messaging TO messaging_user;

# Enable UUID extension (required for the application)
\c messaging
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

# Exit psql
\q
```

### Configure PostgreSQL for Remote Connections (if needed)

```bash
# Edit postgresql.conf
nano /etc/postgresql/14/main/postgresql.conf

# Change listen_addresses (find and modify):
listen_addresses = 'localhost'  # Keep localhost for security

# Edit pg_hba.conf for local connection
nano /etc/postgresql/14/main/pg_hba.conf

# Add this line:
local   messaging    messaging_user                    scram-sha-256

# Restart PostgreSQL
systemctl restart postgresql
```

### Test Database Connection

```bash
# Test connection
psql -U messaging_user -d messaging -h localhost
# Enter password when prompted
# If successful, you'll see the psql prompt
\q
```

---

## Install Redis (Optional)

Redis is optional but recommended for PubSub and caching features.

```bash
# Install Redis
apt install -y redis-server

# Configure Redis
nano /etc/redis/redis.conf

# Set supervised directive to systemd:
supervised systemd

# Set bind address (keep localhost for security):
bind 127.0.0.1 ::1

# Start and enable Redis
systemctl restart redis-server
systemctl enable redis-server

# Test Redis
redis-cli ping
# Should return: PONG
```

---

## Setup Application User

Create a dedicated user for running the application (security best practice).

```bash
# Create messaging user
useradd -m -s /bin/bash messaging

# Create application directories
mkdir -p /opt/messaging
mkdir -p /var/log/messaging
mkdir -p /opt/messaging/storage

# Set ownership
chown -R messaging:messaging /opt/messaging
chown -R messaging:messaging /var/log/messaging
```

---

## Deploy Application Code

### Option A: Deploy from Git Repository

```bash
# Switch to messaging user
su - messaging

# Clone repository
cd /opt/messaging
git clone https://github.com/YOUR_USERNAME/real-time-messaging.git app
cd app

# Checkout production branch
git checkout main  # or your production branch
```

### Option B: Deploy from Local Build (SCP/RSYNC)

```bash
# From your local machine, build a release:
MIX_ENV=prod mix release

# Copy to server (from local machine):
scp -r _build/prod/rel/messaging ubuntu@YOUR_VM_IP:/tmp/

# On the server:
su - messaging
mv /tmp/messaging /opt/messaging/app
cd /opt/messaging/app
```

---

## Configure Environment

### Create Environment File

```bash
# As messaging user
su - messaging
cd /opt/messaging/app

# Create .env file
cat > /opt/messaging/.env << 'EOF'
# Database Configuration
DATABASE_URL=postgres://messaging_user:YOUR_SECURE_PASSWORD_HERE@localhost:5432/messaging
POOL_SIZE=20

# Phoenix Configuration
SECRET_KEY_BASE=GENERATE_WITH_MIX_PHX_GEN_SECRET
PHX_HOST=messaging.yourdomain.com
PORT=4000

# Feature Configuration
FEATURES_CONFIG=/opt/messaging/app/config/features.yaml

# Storage Configuration (if using blob storage)
LOCAL_STORAGE_DIR=/opt/messaging/storage
LOCAL_STORAGE_URL=https://messaging.yourdomain.com/storage

# Optional: S3 Configuration
# S3_BUCKET=messaging-blobs
# S3_REGION=us-east-1
# AWS_ACCESS_KEY_ID=your_access_key
# AWS_SECRET_ACCESS_KEY=your_secret_key

# Oban Queue Concurrency (optional overrides)
OBAN_DELIVER_REALTIME_CONCURRENCY=50
OBAN_SCHEDULED_DELIVERY_CONCURRENCY=5
OBAN_FILES_CONCURRENCY=4
OBAN_HEAVY_IO_CONCURRENCY=2

# Logging
LOG_LEVEL=info
EOF

# Generate SECRET_KEY_BASE
cd /opt/messaging/app
mix phx.gen.secret
# Copy the output and replace GENERATE_WITH_MIX_PHX_GEN_SECRET in .env

# Secure the environment file
chmod 600 /opt/messaging/.env
```

### Select Feature Configuration

```bash
# Choose appropriate feature configuration
# Options:
# - features.yaml (full featured - default)
# - features.minimal.yaml (core messaging only)
# - features.standard.yaml (balanced production)
# - features.no-media.yaml (no media processing)

# Copy chosen configuration
cp /opt/messaging/app/config/features.standard.yaml /opt/messaging/app/config/features.yaml

# Or specify different config in .env:
# FEATURES_CONFIG=/opt/messaging/app/config/features.standard.yaml
```

---

## Build Release

### Install Dependencies and Build

```bash
# As messaging user
su - messaging
cd /opt/messaging/app

# Set production environment
export MIX_ENV=prod

# Install dependencies
mix deps.get --only prod

# Compile dependencies
mix deps.compile

# Compile application
mix compile

# Create database and run migrations
mix ecto.create
mix ecto.migrate

# Build release (optional, for more optimized deployment)
# This creates a standalone release that doesn't require Mix
mix release

# If using release, it will be in:
# _build/prod/rel/messaging/bin/messaging
```

---

## Configure Systemd Services

We'll create two systemd services: one for the API and one for the Job Processor.

### Option A: Running Both Apps in Single Service (Simpler)

```bash
# As root
sudo cat > /etc/systemd/system/messaging.service << 'EOF'
[Unit]
Description=Real-Time Messaging API
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=messaging
Group=messaging
WorkingDirectory=/opt/messaging/app
EnvironmentFile=/opt/messaging/.env
Environment=MIX_ENV=prod
Environment=LANG=en_US.UTF-8

# Start both API and Job Processor in single BEAM VM
ExecStart=/usr/bin/elixir --erl "-detached" -S mix phx.server

# Restart configuration
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/messaging/messaging.log
StandardError=append:/var/log/messaging/messaging-error.log

# Resource limits
LimitNOFILE=65535
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
```

### Option B: Separate Services for API and Job Processor (Recommended for Production)

#### API Service

```bash
# As root
sudo cat > /etc/systemd/system/messaging-api.service << 'EOF'
[Unit]
Description=Real-Time Messaging API Server
After=network.target postgresql.service redis.service
Requires=postgresql.service

[Service]
Type=simple
User=messaging
Group=messaging
WorkingDirectory=/opt/messaging/app/apps/messaging_api
EnvironmentFile=/opt/messaging/.env
Environment=MIX_ENV=prod
Environment=LANG=en_US.UTF-8

# Start only the API
ExecStart=/usr/bin/mix phx.server

# Restart configuration
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/messaging/api.log
StandardError=append:/var/log/messaging/api-error.log

# Resource limits
LimitNOFILE=65535
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
```

#### Job Processor Service

```bash
# As root
sudo cat > /etc/systemd/system/messaging-jobs.service << 'EOF'
[Unit]
Description=Real-Time Messaging Job Processor
After=network.target postgresql.service redis.service
Requires=postgresql.service

[Service]
Type=simple
User=messaging
Group=messaging
WorkingDirectory=/opt/messaging/app/apps/job_processor
EnvironmentFile=/opt/messaging/.env
Environment=MIX_ENV=prod
Environment=LANG=en_US.UTF-8

# Start only the Job Processor
ExecStart=/usr/bin/mix run --no-halt

# Restart configuration
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/messaging/jobs.log
StandardError=append:/var/log/messaging/jobs-error.log

# Resource limits
LimitNOFILE=65535
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
```

### Enable and Start Services

```bash
# Reload systemd
systemctl daemon-reload

# Option A: Single service
systemctl enable messaging
systemctl start messaging
systemctl status messaging

# Option B: Separate services
systemctl enable messaging-api messaging-jobs
systemctl start messaging-api
systemctl start messaging-jobs
systemctl status messaging-api
systemctl status messaging-jobs
```

### Verify Application is Running

```bash
# Check if application is listening on port 4000
netstat -tlnp | grep 4000

# Test health endpoint
curl http://localhost:4000/healthz
# Expected: {"status":"ok","timestamp":"..."}
```

---

## Setup Nginx Reverse Proxy

Install and configure Nginx as a reverse proxy for SSL termination and load balancing.

### Install Nginx

```bash
apt install -y nginx
systemctl start nginx
systemctl enable nginx
```

### Configure Nginx for Messaging API

```bash
# Create Nginx configuration
cat > /etc/nginx/sites-available/messaging << 'EOF'
upstream messaging_backend {
    server 127.0.0.1:4000 fail_timeout=10s max_fails=3;
    keepalive 32;
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ws_limit:10m rate=5r/s;

server {
    listen 80;
    server_name messaging.yourdomain.com;

    # Redirect to HTTPS (will be configured after Let's Encrypt)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name messaging.yourdomain.com;

    # SSL certificates (will be configured by certbot)
    # ssl_certificate /etc/letsencrypt/live/messaging.yourdomain.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/messaging.yourdomain.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Logging
    access_log /var/log/nginx/messaging-access.log;
    error_log /var/log/nginx/messaging-error.log;

    # Max body size (for file uploads if needed)
    client_max_body_size 10M;

    # API endpoints
    location /v1/ {
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://messaging_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket endpoints
    location /socket/ {
        limit_req zone=ws_limit burst=10 nodelay;
        
        proxy_pass http://messaging_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket timeout (keep connection alive)
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # Health check endpoint (no rate limiting)
    location /healthz {
        proxy_pass http://messaging_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        access_log off;
    }

    # Static files / blob storage (if using local storage)
    location /storage/ {
        alias /opt/messaging/storage/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable the site
ln -s /etc/nginx/sites-available/messaging /etc/nginx/sites-enabled/

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Reload Nginx
systemctl reload nginx
```

---

## SSL/TLS with Let's Encrypt

### Install Certbot

```bash
apt install -y certbot python3-certbot-nginx
```

### Obtain SSL Certificate

```bash
# Make sure your domain points to this server's IP
# Then run certbot:
certbot --nginx -d messaging.yourdomain.com

# Follow the prompts:
# - Enter email address
# - Agree to terms
# - Choose to redirect HTTP to HTTPS (option 2)

# Certbot will automatically:
# - Obtain certificate
# - Update Nginx configuration
# - Set up auto-renewal
```

### Test Auto-Renewal

```bash
# Dry run to test renewal
certbot renew --dry-run

# Certificate auto-renewal is handled by systemd timer
systemctl list-timers | grep certbot
```

### Verify SSL Setup

```bash
# Test HTTPS endpoint
curl https://messaging.yourdomain.com/healthz

# Check SSL certificate
openssl s_client -connect messaging.yourdomain.com:443 -servername messaging.yourdomain.com
```

---

## Monitoring and Logs

### Log Management

#### View Application Logs

```bash
# For single service setup:
tail -f /var/log/messaging/messaging.log
tail -f /var/log/messaging/messaging-error.log

# For separate services:
tail -f /var/log/messaging/api.log
tail -f /var/log/messaging/jobs.log

# View systemd logs
journalctl -u messaging-api -f
journalctl -u messaging-jobs -f
```

#### Setup Log Rotation

```bash
cat > /etc/logrotate.d/messaging << 'EOF'
/var/log/messaging/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 messaging messaging
    sharedscripts
    postrotate
        systemctl reload messaging-api > /dev/null 2>&1 || true
        systemctl reload messaging-jobs > /dev/null 2>&1 || true
    endscript
}
EOF
```

### System Monitoring

#### Install Basic Monitoring Tools

```bash
apt install -y htop iotop nethogs
```

#### Monitor Application Resources

```bash
# CPU and memory usage
htop

# PostgreSQL connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity WHERE datname='messaging';"

# Database size
sudo -u postgres psql -d messaging -c "SELECT pg_size_pretty(pg_database_size('messaging'));"

# Oban job queue status (from Elixir console)
# Connect to running application:
su - messaging
cd /opt/messaging/app
iex --name observer@127.0.0.1 --cookie messaging_cookie --remsh messaging@127.0.0.1
```

### Application Health Checks

```bash
# Create a health check script
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

# Run health check
/usr/local/bin/check-messaging-health.sh
```

### Setup Monitoring Cron Job

```bash
# Add to crontab to check health every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-messaging-health.sh >> /var/log/messaging/health-check.log 2>&1") | crontab -
```

---

## Maintenance Tasks

### Database Maintenance

#### Backup Database

```bash
# Create backup directory
mkdir -p /opt/messaging/backups

# Create backup script
cat > /usr/local/bin/backup-messaging-db.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/messaging/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/messaging_$TIMESTAMP.sql.gz"

# Perform backup
sudo -u postgres pg_dump messaging | gzip > "$BACKUP_FILE"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "messaging_*.sql.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE"
EOF

chmod +x /usr/local/bin/backup-messaging-db.sh

# Schedule daily backup at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-messaging-db.sh") | crontab -
```

#### Restore from Backup

```bash
# List backups
ls -lh /opt/messaging/backups/

# Restore from backup (WARNING: This will overwrite current data)
sudo -u postgres psql -d messaging < /opt/messaging/backups/messaging_YYYYMMDD_HHMMSS.sql
# or if compressed:
gunzip -c /opt/messaging/backups/messaging_YYYYMMDD_HHMMSS.sql.gz | sudo -u postgres psql -d messaging
```

#### Database Vacuum and Analyze

```bash
# Schedule weekly vacuum (Sunday 3 AM)
cat > /usr/local/bin/vacuum-messaging-db.sh << 'EOF'
#!/bin/bash
sudo -u postgres psql -d messaging -c "VACUUM ANALYZE;"
echo "Database vacuum completed at $(date)"
EOF

chmod +x /usr/local/bin/vacuum-messaging-db.sh

(crontab -l 2>/dev/null; echo "0 3 * * 0 /usr/local/bin/vacuum-messaging-db.sh >> /var/log/messaging/vacuum.log 2>&1") | crontab -
```

### Application Updates

#### Deploy New Version

```bash
# As messaging user
su - messaging
cd /opt/messaging/app

# Pull latest code
git fetch origin
git pull origin main

# Install new dependencies
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix deps.compile

# Run new migrations
MIX_ENV=prod mix ecto.migrate

# Compile application
MIX_ENV=prod mix compile

# Restart services
sudo systemctl restart messaging-api
sudo systemctl restart messaging-jobs

# Or for single service:
sudo systemctl restart messaging

# Verify deployment
curl http://localhost:4000/healthz
```

#### Rollback

```bash
# Rollback code
cd /opt/messaging/app
git log --oneline -5  # Find previous commit
git reset --hard PREVIOUS_COMMIT_HASH

# Rollback database (if needed)
MIX_ENV=prod mix ecto.rollback

# Rebuild and restart
MIX_ENV=prod mix compile
sudo systemctl restart messaging-api messaging-jobs
```

---

## Troubleshooting

### Application Won't Start

```bash
# Check systemd status
systemctl status messaging-api
systemctl status messaging-jobs

# Check logs
journalctl -u messaging-api -n 100 --no-pager
journalctl -u messaging-jobs -n 100 --no-pager

# Check application logs
tail -100 /var/log/messaging/api-error.log
tail -100 /var/log/messaging/jobs-error.log

# Common issues:
# 1. Database connection - verify DATABASE_URL in .env
# 2. Port already in use - check: netstat -tlnp | grep 4000
# 3. Permission issues - verify ownership: ls -la /opt/messaging/
```

### Database Connection Issues

```bash
# Test PostgreSQL is running
systemctl status postgresql

# Test database connection
sudo -u postgres psql -d messaging

# Check PostgreSQL logs
tail -100 /var/log/postgresql/postgresql-14-main.log

# Verify credentials
psql -U messaging_user -d messaging -h localhost

# Check connection limits
sudo -u postgres psql -c "SHOW max_connections;"
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

### High Memory Usage

```bash
# Check memory usage
free -h

# Check process memory
ps aux --sort=-%mem | head -10

# Reduce database pool size in .env
# POOL_SIZE=10

# Reduce Oban queue concurrency
# OBAN_DELIVER_REALTIME_CONCURRENCY=20

# Restart application
systemctl restart messaging-api messaging-jobs
```

### High CPU Usage

```bash
# Check CPU usage
top

# Check Oban queue status
# Connect to IEx console and run:
# Oban.check_queue()

# Reduce queue concurrency in .env
# Restart application
```

### Disk Space Issues

```bash
# Check disk usage
df -h

# Check large files
du -sh /opt/messaging/* | sort -h

# Clean old logs
find /var/log/messaging/ -name "*.log" -mtime +30 -delete

# Clean old backups
find /opt/messaging/backups/ -name "*.sql.gz" -mtime +30 -delete

# Vacuum database
sudo -u postgres psql -d messaging -c "VACUUM FULL;"
```

### Nginx Issues

```bash
# Test Nginx configuration
nginx -t

# Check Nginx logs
tail -100 /var/log/nginx/messaging-error.log

# Restart Nginx
systemctl restart nginx

# Check if Nginx is running
systemctl status nginx
```

### SSL Certificate Issues

```bash
# Check certificate expiry
certbot certificates

# Renew certificate manually
certbot renew

# Check certificate files
ls -la /etc/letsencrypt/live/messaging.yourdomain.com/

# Test SSL connection
openssl s_client -connect messaging.yourdomain.com:443
```

### Performance Issues

```bash
# Enable query logging in PostgreSQL
sudo -u postgres psql -c "ALTER SYSTEM SET log_statement = 'all';"
sudo -u postgres psql -c "SELECT pg_reload_conf();"

# Check slow queries
sudo -u postgres psql -d messaging -c "
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;
"

# Check indexes
sudo -u postgres psql -d messaging -c "
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public';
"

# Analyze query performance
sudo -u postgres psql -d messaging -c "EXPLAIN ANALYZE SELECT * FROM messages LIMIT 10;"
```

---

## Security Checklist

- [ ] Firewall configured (only necessary ports open)
- [ ] PostgreSQL accepting only local connections
- [ ] Strong database password set
- [ ] SECRET_KEY_BASE generated and secured
- [ ] SSL/TLS enabled with valid certificate
- [ ] Application running as non-root user
- [ ] Environment file permissions restricted (600)
- [ ] Nginx rate limiting configured
- [ ] Security headers configured in Nginx
- [ ] Regular backups scheduled
- [ ] Log rotation configured
- [ ] System updates scheduled
- [ ] Monitoring and alerting set up

---

## Performance Tuning

### PostgreSQL Tuning

```bash
# Edit PostgreSQL config
sudo nano /etc/postgresql/14/main/postgresql.conf

# Recommended settings for 4GB RAM:
shared_buffers = 1GB                 # 25% of RAM
effective_cache_size = 3GB           # 75% of RAM
maintenance_work_mem = 256MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1              # For SSD
effective_io_concurrency = 200      # For SSD
work_mem = 5MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Application Tuning

Edit `/opt/messaging/.env`:

```bash
# Increase pool size for high traffic
POOL_SIZE=30

# Adjust Oban queue concurrency
OBAN_DELIVER_REALTIME_CONCURRENCY=100
OBAN_SCHEDULED_DELIVERY_CONCURRENCY=10
OBAN_FILES_CONCURRENCY=8
OBAN_HEAVY_IO_CONCURRENCY=4
```

---

## Additional Resources

- **Application Documentation**: See `readme.md` and `SETUP.md` in the repository
- **Feature Flags**: See `docs/FEATURE_FLAGS.md` for configuration options
- **API Testing**: See `API_TESTING_GUIDE.md` for endpoint examples
- **Elixir Releases**: https://hexdocs.pm/mix/Mix.Tasks.Release.html
- **Oban Documentation**: https://hexdocs.pm/oban/Oban.html
- **Phoenix Deployment**: https://hexdocs.pm/phoenix/deployment.html

---

## Support and Maintenance Contacts

- System Administrator: [your-email@domain.com]
- Application Repository: [github.com/your-org/real-time-messaging]
- Issue Tracker: [github.com/your-org/real-time-messaging/issues]

---

*Last Updated: December 2024*
*Document Version: 1.0*
