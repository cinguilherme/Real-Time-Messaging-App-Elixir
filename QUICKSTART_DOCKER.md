# Quick Start - Docker Deployment

Get the Real-Time Messaging API running with Docker in under 15 minutes!

## Prerequisites

- Linux VM (Ubuntu 22.04 recommended)
- 4GB RAM minimum
- 30GB disk space
- Docker and Docker Compose installed

---

## Step 1: Install Docker (if not already installed)

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

---

## Step 2: Clone Repository

```bash
# Clone the repository
git clone https://github.com/YOUR_REPO/real-time-messaging.git
cd real-time-messaging

# Or download and extract if not using git
```

---

## Step 3: Configure Environment

```bash
# Create environment file from example
cp .env.example .env

# Generate a secure secret key
SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n')

# Generate secure passwords
DB_PASS=$(openssl rand -base64 32 | tr -d '\n')
REDIS_PASS=$(openssl rand -base64 32 | tr -d '\n')
MINIO_PASS=$(openssl rand -base64 32 | tr -d '\n')

# Update .env file with generated values
sed -i "s|your_secret_key_base_here.*|$SECRET_KEY|" .env
sed -i "s|changeme123|$DB_PASS|" .env
sed -i "s|redispass123|$REDIS_PASS|" .env
sed -i "s|minioadmin|$MINIO_PASS|g" .env

# Optional: Set your domain (if you have one)
sed -i "s|localhost|yourdomain.com|" .env

echo "✓ Environment configured!"
```

**Important:** Save these passwords somewhere safe!

---

## Step 4: Deploy!

### Option A: Using Quick Deploy Script (Recommended)

```bash
# Make script executable
chmod +x quick-deploy.sh

# Run deployment
./quick-deploy.sh

# Select option 1: "Build and start services"
```

### Option B: Manual Deployment

```bash
# Build images
docker compose -f docker-compose.prod.yaml build

# Start services
docker compose -f docker-compose.prod.yaml up -d

# Wait a moment, then check status
docker compose -f docker-compose.prod.yaml ps
```

---

## Step 5: Verify Deployment

```bash
# Check if API is healthy
curl http://localhost:4000/api/health

# Expected response: {"status":"ok"}

# View logs
docker compose -f docker-compose.prod.yaml logs -f app
```

---

## Step 6: Test the API

```bash
# Send a test message
curl -X POST http://localhost:4000/v1/messages \
  -H 'content-type: application/json' \
  -d '{
    "conversation_id": "11111111-1111-1111-1111-111111111111",
    "sender_id": "22222222-2222-2222-2222-222222222222",
    "body": {"text": "Hello from Docker!"},
    "idempotency_key": "test-1"
  }'

# You should get a response like:
# {"message_id":"...","status":"queued"}
```

---

## Success! 🎉

Your Real-Time Messaging API is now running!

### Access Points

- **API**: http://YOUR_SERVER_IP:4000
- **Health Check**: http://YOUR_SERVER_IP:4000/api/health
- **MinIO Console**: http://YOUR_SERVER_IP:9001 (for managing media storage)

### Next Steps

1. **Setup SSL/TLS** (for production)
   - See [SSL Setup Section](DOCKER_DEPLOYMENT.md#ssltls-setup-optional) in full guide

2. **Configure Firewall**
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 4000/tcp
   sudo ufw enable
   ```

3. **Setup Automated Backups**
   ```bash
   # Database backup
   ./quick-deploy.sh
   # Select option 7: "Backup database"
   ```

4. **Monitor Logs**
   ```bash
   # View application logs
   docker compose -f docker-compose.prod.yaml logs -f app
   
   # View all services
   docker compose -f docker-compose.prod.yaml logs -f
   ```

---

## Common Commands

```bash
# View service status
docker compose -f docker-compose.prod.yaml ps

# View logs
docker compose -f docker-compose.prod.yaml logs -f app

# Restart services
docker compose -f docker-compose.prod.yaml restart

# Stop services
docker compose -f docker-compose.prod.yaml stop

# Start services
docker compose -f docker-compose.prod.yaml start

# Update and redeploy
git pull
docker compose -f docker-compose.prod.yaml build
docker compose -f docker-compose.prod.yaml up -d

# Backup database
docker compose -f docker-compose.prod.yaml exec -T postgres \
  pg_dump -U messaging_user messaging_prod > backup.sql
```

---

## Troubleshooting

### API won't start
```bash
# Check logs for errors
docker compose -f docker-compose.prod.yaml logs app

# Verify environment variables
docker compose -f docker-compose.prod.yaml config

# Check if database is ready
docker compose -f docker-compose.prod.yaml exec postgres \
  pg_isready -U messaging_user
```

### Port already in use
```bash
# Check what's using the port
sudo lsof -i :4000

# Either stop the service or change the port in docker-compose.prod.yaml
```

### Out of disk space
```bash
# Check disk usage
df -h

# Clean up Docker
docker system prune -a
```

### Can't connect from external network
```bash
# Check firewall
sudo ufw status

# Allow port 4000
sudo ufw allow 4000/tcp
```

---

## Full Documentation

For detailed information, see:

- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Complete deployment guide
- **[DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md)** - Compare all deployment methods
- **[API_TESTING_GUIDE.md](API_TESTING_GUIDE.md)** - API usage examples
- **[docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md)** - Feature configuration

---

## Need Help?

- Check the [Troubleshooting section](DOCKER_DEPLOYMENT.md#troubleshooting) in the full guide
- Review [Common Issues](DOCKER_DEPLOYMENT.md#troubleshooting)
- Open an issue on GitHub

---

**That's it!** You now have a production-ready Real-Time Messaging API running with Docker. 🚀
