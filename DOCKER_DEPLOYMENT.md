# Docker Deployment Guide - Real-Time Messaging API

This guide walks you through deploying the Real-Time Messaging API using Docker Compose on a single VM. This is a production-ready setup that's simpler than the bare-metal installation.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [VM Setup](#vm-setup)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Building and Deployment](#building-and-deployment)
7. [SSL/TLS Setup (Optional)](#ssltls-setup-optional)
8. [Monitoring and Maintenance](#monitoring-and-maintenance)
9. [Scaling Options](#scaling-options)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This deployment method uses Docker Compose to orchestrate all services in containers:

- **Messaging API** - Elixir/Phoenix application
- **PostgreSQL** - Primary database for messages, receipts, and inbox
- **Redis** - PubSub and caching
- **MinIO** - S3-compatible object storage for media files
- **Memcached** - Application-level caching (optional)
- **Nginx** - Reverse proxy with SSL support (optional)

**Advantages:**
- ✅ Simplified deployment and updates
- ✅ Isolated services in containers
- ✅ Easy to scale and replicate
- ✅ Consistent environment across deployments
- ✅ Quick rollback capabilities

---

## Prerequisites

### VM Requirements

**Minimum Specifications:**
- **CPU**: 2 vCPUs
- **RAM**: 4GB (8GB recommended for production)
- **Storage**: 30GB SSD (adjust based on expected message volume)
- **OS**: Ubuntu 22.04 LTS, Debian 11+, or any Linux with Docker support

**Network:**
- Public IP address
- Open ports: 80 (HTTP), 443 (HTTPS), 4000 (API - optional for direct access)

### Domain Setup (Optional but Recommended)

For SSL/TLS support:
- Domain name pointing to your VM's IP
- DNS A record: `messaging.yourdomain.com` → `YOUR_VM_IP`

---

## VM Setup

### Step 1: Initial Server Setup

```bash
# Connect to your VM
ssh root@YOUR_VM_IP

# Update system packages
apt update && apt upgrade -y

# Install basic utilities
apt install -y curl wget git unzip
```

### Step 2: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Verify installation
docker --version
```

### Step 3: Install Docker Compose

```bash
# Install Docker Compose (v2)
apt install -y docker-compose-plugin

# OR for older systems, install standalone Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker compose version
```

### Step 4: Configure Firewall

```bash
# Install and configure UFW
apt install -y ufw

# Allow SSH (important!)
ufw allow OpenSSH

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Optional: Allow direct API access
ufw allow 4000/tcp

# Enable firewall
ufw enable

# Verify status
ufw status
```

### Step 5: Create Application Directory

```bash
# Create directory for the application
mkdir -p /opt/messaging-api
cd /opt/messaging-api

# Create docker user (optional, for better security)
useradd -r -s /bin/false messaging
```

---

## Installation

### Option 1: Clone from Git Repository

```bash
cd /opt/messaging-api

# Clone your repository
git clone https://github.com/YOUR_USERNAME/real-time-messaging.git .

# Or if using a specific branch
git clone -b main https://github.com/YOUR_USERNAME/real-time-messaging.git .
```

### Option 2: Copy Files Manually

```bash
# From your local machine, copy files to the VM
scp -r /path/to/real-time-messaging/* root@YOUR_VM_IP:/opt/messaging-api/

# Or use rsync for better performance
rsync -avz --exclude='_build' --exclude='deps' \
  /path/to/real-time-messaging/ root@YOUR_VM_IP:/opt/messaging-api/
```

---

## Configuration

### Step 1: Create Environment File

Create a `.env` file to store sensitive configuration:

```bash
cd /opt/messaging-api
cat > .env << 'EOF'
# Database Configuration
DB_PASSWORD=your_secure_postgres_password_here

# Application Secrets
SECRET_KEY_BASE=your_secret_key_base_here

# Domain Configuration
DOMAIN=messaging.yourdomain.com

# Storage Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_minio_password_here

# Redis Configuration
REDIS_PASSWORD=your_redis_password_here

# Optional: Database pool size
POOL_SIZE=20

# Optional: Custom features config path
# FEATURES_CONFIG_PATH=./config/features.production.yaml
EOF

# Secure the .env file
chmod 600 .env
```

### Step 2: Generate Secrets

Generate secure secrets for your deployment:

```bash
# Generate SECRET_KEY_BASE
# You'll need Elixir installed for this, or use an online generator
# Alternative: Use OpenSSL
SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n')
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"

# Update .env file
sed -i "s/your_secret_key_base_here/$SECRET_KEY_BASE/" .env

# Generate secure passwords
DB_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
MINIO_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

echo "DB_PASSWORD=$DB_PASSWORD"
echo "REDIS_PASSWORD=$REDIS_PASSWORD"
echo "MINIO_ROOT_PASSWORD=$MINIO_PASSWORD"

# Update .env file with generated passwords
sed -i "s/your_secure_postgres_password_here/$DB_PASSWORD/" .env
sed -i "s/your_redis_password_here/$REDIS_PASSWORD/" .env
sed -i "s/your_minio_password_here/$MINIO_PASSWORD/" .env
```

**Important:** Save these credentials securely! You'll need them if you ever need to access the database or storage directly.

### Step 3: Configure Features (Optional)

Customize the feature configuration based on your needs:

```bash
# Copy the default config to create a production variant
cp config/features.yaml config/features.production.yaml

# Edit the production config
nano config/features.production.yaml
```

Available feature configurations:
- `config/features.yaml` - Full features (default)
- `config/features.minimal.yaml` - Minimal features (no media, no scheduled delivery)
- `config/features.no-media.yaml` - All features except media processing

Update `.env` to use custom config:
```bash
echo "FEATURES_CONFIG_PATH=./config/features.production.yaml" >> .env
```

### Step 4: Review Docker Compose Configuration

Review the production compose file:

```bash
cat docker-compose.prod.yaml
```

Key services:
- `app` - Main application (port 4000)
- `postgres` - Database (port 5432)
- `redis` - Cache/PubSub (port 6379)
- `s3_minio` - Object storage (ports 9000, 9001)
- `memcached` - Optional cache (port 11211)
- `nginx` - Optional reverse proxy (ports 80, 443)

---

## Building and Deployment

### Step 1: Build the Application Image

```bash
cd /opt/messaging-api

# Build the Docker image (this may take 5-10 minutes)
docker compose -f docker-compose.prod.yaml build

# View built images
docker images | grep messaging
```

### Step 2: Start Services

```bash
# Start all services in detached mode
docker compose -f docker-compose.prod.yaml up -d

# View running containers
docker compose -f docker-compose.prod.yaml ps

# Check logs
docker compose -f docker-compose.prod.yaml logs -f app
```

### Step 3: Initialize Database

The database migrations should run automatically on first startup. Verify:

```bash
# Check application logs for migration messages
docker compose -f docker-compose.prod.yaml logs app | grep -i migration

# If migrations didn't run, run them manually
docker compose -f docker-compose.prod.yaml exec app bin/messaging_api eval "Messaging.Release.migrate()"
```

### Step 4: Create MinIO Bucket

Create the S3 bucket for blob storage:

```bash
# Access MinIO container
docker compose -f docker-compose.prod.yaml exec s3_minio sh

# Inside container, create bucket
mc alias set myminio http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
mc mb myminio/messaging-blobs
mc anonymous set download myminio/messaging-blobs
exit
```

Or access the MinIO Console at `http://YOUR_VM_IP:9001` and create the bucket via the web interface.

### Step 5: Verify Deployment

Test the API health endpoint:

```bash
# Check health endpoint
curl http://localhost:4000/api/health

# Expected response:
# {"status":"ok"}

# Check from external network (if firewall allows)
curl http://YOUR_VM_IP:4000/api/health
```

---

## SSL/TLS Setup (Optional)

For production deployments, SSL/TLS is highly recommended.

### Option 1: Use Nginx with Let's Encrypt

#### Step 1: Create Nginx Configuration

```bash
# Create nginx directory
mkdir -p /opt/messaging-api/nginx/conf.d

# Create nginx configuration
cat > /opt/messaging-api/nginx/conf.d/messaging.conf << 'EOF'
upstream messaging_api {
    server app:4000;
}

server {
    listen 80;
    server_name messaging.yourdomain.com;

    # Redirect to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name messaging.yourdomain.com;

    # SSL certificates (will be generated by certbot)
    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # API endpoints
    location / {
        proxy_pass http://messaging_api;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /api/health {
        proxy_pass http://messaging_api;
        access_log off;
    }
}
EOF

# Update with your domain
sed -i 's/messaging.yourdomain.com/YOUR_DOMAIN/g' /opt/messaging-api/nginx/conf.d/messaging.conf
```

#### Step 2: Create Main Nginx Configuration

```bash
cat > /opt/messaging-api/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;

    include /etc/nginx/conf.d/*.conf;
}
EOF
```

#### Step 3: Generate SSL Certificates with Certbot

```bash
# Install Certbot
apt install -y certbot

# Generate certificate (replace with your domain and email)
certbot certonly --standalone \
  -d messaging.yourdomain.com \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive

# Copy certificates to nginx volume directory
mkdir -p /opt/messaging-api/nginx/certs
cp /etc/letsencrypt/live/messaging.yourdomain.com/fullchain.pem /opt/messaging-api/nginx/certs/
cp /etc/letsencrypt/live/messaging.yourdomain.com/privkey.pem /opt/messaging-api/nginx/certs/

# Set proper permissions
chmod 644 /opt/messaging-api/nginx/certs/fullchain.pem
chmod 600 /opt/messaging-api/nginx/certs/privkey.pem
```

#### Step 4: Start Nginx

```bash
# Start nginx with the with-nginx profile
docker compose -f docker-compose.prod.yaml --profile with-nginx up -d

# Verify nginx is running
docker compose -f docker-compose.prod.yaml ps nginx

# Test SSL
curl https://messaging.yourdomain.com/api/health
```

#### Step 5: Setup Certificate Auto-Renewal

```bash
# Create renewal script
cat > /opt/messaging-api/renew-certs.sh << 'EOF'
#!/bin/bash
certbot renew --quiet
cp /etc/letsencrypt/live/messaging.yourdomain.com/fullchain.pem /opt/messaging-api/nginx/certs/
cp /etc/letsencrypt/live/messaging.yourdomain.com/privkey.pem /opt/messaging-api/nginx/certs/
docker compose -f /opt/messaging-api/docker-compose.prod.yaml restart nginx
EOF

chmod +x /opt/messaging-api/renew-certs.sh

# Add to crontab (runs daily at 2 AM)
echo "0 2 * * * /opt/messaging-api/renew-certs.sh" | crontab -
```

### Option 2: Use Cloudflare or AWS Application Load Balancer

If using a cloud provider, SSL termination can be handled at the load balancer level:

1. Configure your load balancer to handle SSL
2. Forward traffic to port 4000 on your VM
3. Keep `docker-compose.prod.yaml` as-is (without nginx)

---

## Monitoring and Maintenance

### Viewing Logs

```bash
# View all logs
docker compose -f docker-compose.prod.yaml logs -f

# View specific service logs
docker compose -f docker-compose.prod.yaml logs -f app
docker compose -f docker-compose.prod.yaml logs -f postgres
docker compose -f docker-compose.prod.yaml logs -f redis

# View logs with timestamps
docker compose -f docker-compose.prod.yaml logs -f --timestamps app

# View last 100 lines
docker compose -f docker-compose.prod.yaml logs --tail=100 app
```

### Checking Service Status

```bash
# View running containers
docker compose -f docker-compose.prod.yaml ps

# Check resource usage
docker stats

# Check disk usage
docker system df
```

### Database Backup

```bash
# Create backup directory
mkdir -p /opt/messaging-api/backups

# Backup database
docker compose -f docker-compose.prod.yaml exec -T postgres \
  pg_dump -U messaging_user messaging_prod \
  > /opt/messaging-api/backups/backup_$(date +%Y%m%d_%H%M%S).sql

# Compress backup
gzip /opt/messaging-api/backups/backup_$(date +%Y%m%d_%H%M%S).sql

# Automated backup script
cat > /opt/messaging-api/backup-db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/messaging-api/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.sql"

# Create backup
docker compose -f /opt/messaging-api/docker-compose.prod.yaml exec -T postgres \
  pg_dump -U messaging_user messaging_prod > "$BACKUP_FILE"

# Compress
gzip "$BACKUP_FILE"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE.gz"
EOF

chmod +x /opt/messaging-api/backup-db.sh

# Schedule daily backups at 3 AM
echo "0 3 * * * /opt/messaging-api/backup-db.sh" | crontab -
```

### Restore Database

```bash
# Stop the application
docker compose -f docker-compose.prod.yaml stop app

# Restore from backup
gunzip -c /opt/messaging-api/backups/backup_20241217_030000.sql.gz | \
  docker compose -f docker-compose.prod.yaml exec -T postgres \
  psql -U messaging_user messaging_prod

# Restart application
docker compose -f docker-compose.prod.yaml start app
```

### Updating the Application

```bash
cd /opt/messaging-api

# Pull latest code
git pull origin main

# Rebuild and restart
docker compose -f docker-compose.prod.yaml build
docker compose -f docker-compose.prod.yaml up -d

# View logs to ensure successful startup
docker compose -f docker-compose.prod.yaml logs -f app
```

### Log Rotation

Logs are automatically rotated by Docker's json-file driver (configured in docker-compose.prod.yaml):
- Max size: 10MB per file
- Max files: 3 (keeps last 30MB of logs)

To change log settings, edit `docker-compose.prod.yaml` under each service's `logging` section.

---

## Scaling Options

### Vertical Scaling (Same VM)

Increase resources allocated to containers:

```bash
# Edit docker-compose.prod.yaml
nano docker-compose.prod.yaml

# Add resource limits to the app service:
```

```yaml
app:
  # ... existing config ...
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
```

```bash
# Restart with new limits
docker compose -f docker-compose.prod.yaml up -d
```

### Horizontal Scaling (Multiple Containers)

Run multiple app containers behind a load balancer:

```bash
# Scale app service to 3 replicas
docker compose -f docker-compose.prod.yaml up -d --scale app=3

# Configure nginx for load balancing (edit nginx/conf.d/messaging.conf)
```

```nginx
upstream messaging_api {
    server app:4000;
    # Note: Docker Compose will handle DNS round-robin
}
```

### Database Scaling

For high-traffic deployments:

1. **Read Replicas**: Setup PostgreSQL read replicas
2. **Connection Pooling**: Use PgBouncer
3. **Separate Database VM**: Move PostgreSQL to dedicated VM

---

## Troubleshooting

### Application Won't Start

```bash
# Check logs for errors
docker compose -f docker-compose.prod.yaml logs app

# Common issues:
# 1. Missing environment variables
docker compose -f docker-compose.prod.yaml config

# 2. Database connection issues
docker compose -f docker-compose.prod.yaml exec postgres pg_isready -U messaging_user

# 3. Permission issues
docker compose -f docker-compose.prod.yaml exec app ls -la /app

# Restart services
docker compose -f docker-compose.prod.yaml restart
```

### Database Connection Errors

```bash
# Check if PostgreSQL is running
docker compose -f docker-compose.prod.yaml ps postgres

# Check database logs
docker compose -f docker-compose.prod.yaml logs postgres

# Test connection
docker compose -f docker-compose.prod.yaml exec postgres \
  psql -U messaging_user -d messaging_prod -c "SELECT 1;"

# Verify DATABASE_URL in .env matches postgres service
cat .env | grep DATABASE_URL
```

### Out of Disk Space

```bash
# Check Docker disk usage
docker system df

# Clean up unused images and containers
docker system prune -a

# Clean up volumes (CAUTION: This deletes data!)
docker volume prune

# Check specific volume sizes
docker system df -v

# Remove old images
docker images | grep messaging | awk '{print $3}' | xargs docker rmi
```

### High Memory Usage

```bash
# Check container memory usage
docker stats

# Reduce pool size in .env
echo "POOL_SIZE=10" >> .env

# Restart application
docker compose -f docker-compose.prod.yaml restart app

# Add memory limits (see Scaling Options section)
```

### SSL Certificate Issues

```bash
# Check certificate expiry
openssl x509 -in /opt/messaging-api/nginx/certs/fullchain.pem -noout -dates

# Manually renew certificate
certbot renew --force-renewal

# Copy renewed certs
cp /etc/letsencrypt/live/messaging.yourdomain.com/fullchain.pem /opt/messaging-api/nginx/certs/
cp /etc/letsencrypt/live/messaging.yourdomain.com/privkey.pem /opt/messaging-api/nginx/certs/

# Restart nginx
docker compose -f docker-compose.prod.yaml restart nginx
```

### Container Keeps Restarting

```bash
# Check restart count and status
docker compose -f docker-compose.prod.yaml ps

# View full logs
docker compose -f docker-compose.prod.yaml logs --tail=200 app

# Check health check status
docker inspect messaging_api | grep -A 10 Health

# Stop all services and start one by one
docker compose -f docker-compose.prod.yaml down
docker compose -f docker-compose.prod.yaml up postgres redis s3_minio -d
# Wait a moment, then:
docker compose -f docker-compose.prod.yaml up app -d
```

### WebSocket Connection Issues

```bash
# Check if nginx is properly configured for WebSocket
cat nginx/conf.d/messaging.conf | grep -A 2 Upgrade

# Test WebSocket connection (requires wscat)
# Install: npm install -g wscat
wscat -c ws://messaging.yourdomain.com/socket/websocket

# Check firewall rules
ufw status
```

---

## Performance Tuning

### PostgreSQL Optimization

```bash
# Create custom postgres config
cat > /opt/messaging-api/postgres.conf << 'EOF'
# Memory Configuration
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
work_mem = 16MB

# Connection Configuration
max_connections = 100

# WAL Configuration
wal_buffers = 16MB
checkpoint_completion_target = 0.9

# Query Planner
random_page_cost = 1.1
EOF

# Update docker-compose.prod.yaml to mount this config
```

```yaml
postgres:
  # ... existing config ...
  volumes:
    - postgres_data:/var/lib/postgresql/data
    - ./postgres.conf:/etc/postgresql/postgresql.conf:ro
  command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

```bash
# Restart postgres
docker compose -f docker-compose.prod.yaml restart postgres
```

### Redis Optimization

```bash
# Edit docker-compose.prod.yaml to add Redis tuning
```

```yaml
redis:
  # ... existing config ...
  command: >
    redis-server
    --appendonly yes
    --requirepass ${REDIS_PASSWORD:-redispass123}
    --maxmemory 256mb
    --maxmemory-policy allkeys-lru
```

```bash
# Restart redis
docker compose -f docker-compose.prod.yaml restart redis
```

---

## Security Best Practices

1. **Use Strong Passwords**: Always generate strong, random passwords for all services
2. **Keep .env Secure**: Set proper permissions (`chmod 600 .env`)
3. **Regular Updates**: Keep Docker, images, and base OS updated
4. **Network Isolation**: Use Docker networks to isolate services
5. **SSL/TLS**: Always use HTTPS in production
6. **Firewall**: Only expose necessary ports
7. **Monitoring**: Setup monitoring for suspicious activity
8. **Backups**: Regular automated backups stored off-site
9. **Secrets Management**: Consider using Docker Secrets or external secret management
10. **Container Scanning**: Scan images for vulnerabilities

---

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Phoenix Framework Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [PostgreSQL Tuning Guide](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Security](https://redis.io/topics/security)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

---

## Support and Maintenance

For production deployments, consider:

1. **Monitoring Tools**: Setup Prometheus + Grafana, or use cloud monitoring
2. **Log Aggregation**: Use ELK stack or cloud logging services
3. **Alerting**: Configure alerts for service failures, high resource usage, etc.
4. **Regular Maintenance Windows**: Schedule for updates and maintenance
5. **Disaster Recovery Plan**: Document and test recovery procedures

---

**Deployment Complete! 🚀**

Your Real-Time Messaging API is now running in production with Docker Compose.

Access your API at: `http://YOUR_VM_IP:4000` or `https://messaging.yourdomain.com`
