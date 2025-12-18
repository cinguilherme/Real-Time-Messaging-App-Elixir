# AWS Deployment Quick Start Guide

This guide provides a streamlined approach to deploying the Real-Time Messaging API on AWS using the automated preparation script.

## Overview

The deployment process consists of two main phases:

1. **VM Preparation** (automated via `prepare-vm.sh`)
2. **Application Deployment** (semi-automated, requires your code)

Total time: ~15-20 minutes for a fresh deployment.

---

## Prerequisites

### AWS Setup

1. **Launch EC2 Instance**
   - **AMI**: Ubuntu 22.04 LTS (ami-ubuntu-22.04)
   - **Instance Type**: t3.medium or larger (2 vCPUs, 4GB RAM minimum)
   - **Storage**: 20GB gp3 SSD (adjust based on expected message volume)
   - **Security Group**: 
     - SSH (port 22) from your IP
     - HTTP (port 80) from anywhere (0.0.0.0/0)
     - HTTPS (port 443) from anywhere (0.0.0.0/0)

2. **Allocate Elastic IP** (recommended for production)
   - Associate Elastic IP with your instance
   - Prevents IP changes on instance restart

3. **Configure DNS** (optional but recommended for SSL)
   - Create A record: `messaging.yourdomain.com` → `YOUR_ELASTIC_IP`
   - Wait for DNS propagation (~5-10 minutes)

### Local Setup

1. SSH key pair for EC2 access
2. Application code ready (Git repository or local directory)
3. Database password (12+ characters, store securely)

---

## Phase 1: Automated VM Preparation

### Step 1: Connect to Your EC2 Instance

```bash
# Download your SSH key (if not already local)
chmod 400 ~/Downloads/your-key.pem

# Connect to instance
ssh -i ~/Downloads/your-key.pem ubuntu@YOUR_ELASTIC_IP
```

### Step 2: Download and Run Preparation Script

```bash
# Update system first
sudo apt update

# Download the preparation script
wget https://raw.githubusercontent.com/YOUR_REPO/real-time-messaging/main/prepare-vm.sh

# Or copy from your local machine:
scp -i ~/Downloads/your-key.pem prepare-vm.sh ubuntu@YOUR_ELASTIC_IP:~/

# Make it executable
chmod +x prepare-vm.sh

# Run the script (requires sudo)
sudo bash prepare-vm.sh
```

### Step 3: Follow Script Prompts

The script will ask for:

1. **PostgreSQL Password**: Choose a strong password (12+ chars)
   - Store this securely (you'll need it later)
   - Example: Use a password manager or AWS Secrets Manager

2. **Domain Name** (optional): e.g., `messaging.yourdomain.com`
   - Skip if you don't have a domain yet (you can add it later)
   - Press Enter to skip

3. **Confirmation**: Review settings and confirm

### What the Script Does

The script automatically:

- ✅ Updates system packages
- ✅ Installs Erlang/OTP 26 and Elixir 1.16+
- ✅ Installs and configures PostgreSQL 14+
- ✅ Creates database user and database
- ✅ Installs and configures Redis
- ✅ Installs Nginx reverse proxy
- ✅ Installs Certbot for SSL/TLS
- ✅ Configures UFW firewall
- ✅ Creates application user (`messaging`)
- ✅ Sets up directory structure
- ✅ Creates systemd services
- ✅ Sets up log rotation
- ✅ Creates backup and health check scripts

**Estimated time**: 5-10 minutes

---

## Phase 2: Application Deployment

After the preparation script completes, follow these steps:

### Step 4: Deploy Application Code

**Option A: Deploy from Git Repository (Recommended)**

```bash
# Switch to application user
sudo su - messaging

# Clone your repository
cd /opt/messaging
git clone https://github.com/YOUR_USERNAME/real-time-messaging.git app
cd app

# Checkout production branch (if different from main)
git checkout production
```

**Option B: Deploy from Local Machine**

```bash
# From your local machine, copy the code:
cd /path/to/your/local/real-time-messaging
rsync -avz --exclude 'node_modules' --exclude '_build' --exclude 'deps' \
  -e "ssh -i ~/Downloads/your-key.pem" \
  . ubuntu@YOUR_ELASTIC_IP:/tmp/app/

# On the server, move to app directory:
sudo mv /tmp/app /opt/messaging/app
sudo chown -R messaging:messaging /opt/messaging/app
```

### Step 5: Generate Secret Key Base

```bash
# As messaging user
sudo su - messaging
cd /opt/messaging/app

# Generate secret key
mix phx.gen.secret

# Copy the output (will look like: Jk3f9sKd...)
```

### Step 6: Configure Environment

```bash
# Edit environment file
sudo nano /opt/messaging/.env

# Update the SECRET_KEY_BASE line:
# Replace: SECRET_KEY_BASE=GENERATE_WITH_mix_phx_gen_secret
# With:    SECRET_KEY_BASE=<paste_the_generated_secret_here>

# Save and exit (Ctrl+X, then Y, then Enter)

# Verify the file is correct
sudo cat /opt/messaging/.env | grep SECRET_KEY_BASE
```

### Step 7: Choose Feature Configuration

```bash
# As messaging user
sudo su - messaging
cd /opt/messaging/app

# List available feature configurations
ls -la config/features*.yaml

# Choose one based on your needs:
# - features.standard.yaml (recommended for production)
# - features.yaml (full featured)
# - features.minimal.yaml (core messaging only)
# - features.no-media.yaml (no media processing)

# Copy your choice
cp config/features.standard.yaml config/features.yaml

# Or update .env to point to a different file:
# FEATURES_CONFIG=/opt/messaging/app/config/features.standard.yaml
```

### Step 8: Install Dependencies and Build

```bash
# As messaging user
sudo su - messaging
cd /opt/messaging/app

# Set production environment
export MIX_ENV=prod

# Install dependencies
mix deps.get --only prod

# Compile dependencies
mix deps.compile

# Compile application
mix compile
```

**Estimated time**: 3-5 minutes

### Step 9: Run Database Migrations

```bash
# As messaging user
cd /opt/messaging/app
export MIX_ENV=prod

# Run migrations
mix ecto.migrate
```

### Step 10: Start Services

```bash
# Exit from messaging user (back to ubuntu/root)
exit

# Enable services to start on boot
sudo systemctl enable messaging-api messaging-jobs

# Start services
sudo systemctl start messaging-api messaging-jobs

# Check status
sudo systemctl status messaging-api
sudo systemctl status messaging-jobs
```

### Step 11: Verify Deployment

```bash
# Test health endpoint
curl http://localhost:4000/healthz

# Expected response:
# {"status":"ok","timestamp":"2024-12-17T..."}

# Check logs
tail -f /var/log/messaging/api.log
tail -f /var/log/messaging/jobs.log

# Test from external (if domain configured)
curl http://messaging.yourdomain.com/healthz
```

### Step 12: Configure SSL/TLS (Optional but Recommended)

If you configured a domain name:

```bash
# Run Certbot
sudo certbot --nginx -d messaging.yourdomain.com

# Follow the prompts:
# 1. Enter email address for renewal notifications
# 2. Agree to terms of service
# 3. Choose to redirect HTTP to HTTPS (recommended)

# Test SSL
curl https://messaging.yourdomain.com/healthz

# Verify auto-renewal
sudo certbot renew --dry-run
```

---

## Post-Deployment Configuration

### Setup Automated Backups

```bash
# Edit root crontab
sudo crontab -e

# Add daily backup at 2 AM UTC:
0 2 * * * /usr/local/bin/backup-messaging-db.sh

# Add health checks every 5 minutes:
*/5 * * * * /usr/local/bin/check-messaging-health.sh >> /var/log/messaging/health-check.log 2>&1
```

### Setup CloudWatch Monitoring (Optional)

```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

# Configure CloudWatch (follow AWS documentation)
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

### Configure AWS Backup (Optional)

Use AWS Backup service to:
- Create daily EBS snapshots
- Retain backups for 30 days
- Cross-region replication for disaster recovery

---

## Testing Your Deployment

### Test API Endpoints

```bash
# Health check
curl https://messaging.yourdomain.com/healthz

# Create a test message
curl -X POST https://messaging.yourdomain.com/v1/messages \
  -H 'Content-Type: application/json' \
  -d '{
    "conversation_id": "11111111-1111-1111-1111-111111111111",
    "sender_id": "22222222-2222-2222-2222-222222222222",
    "body": {"text": "Test message from AWS deployment"},
    "idempotency_key": "test-aws-1"
  }'

# Expected: 201 Created with {"message_id": "...", "status": "queued"}
```

### Test WebSocket Connection

```bash
# Install wscat for WebSocket testing
npm install -g wscat

# Connect to WebSocket
wscat -c wss://messaging.yourdomain.com/socket/websocket
```

---

## Monitoring and Maintenance

### Key Commands

```bash
# View real-time logs
sudo journalctl -u messaging-api -f
sudo journalctl -u messaging-jobs -f

# Restart services
sudo systemctl restart messaging-api
sudo systemctl restart messaging-jobs

# Check service status
sudo systemctl status messaging-api messaging-jobs

# Run manual backup
sudo /usr/local/bin/backup-messaging-db.sh

# Check health
sudo /usr/local/bin/check-messaging-health.sh

# View Nginx logs
sudo tail -f /var/log/nginx/messaging-access.log
sudo tail -f /var/log/nginx/messaging-error.log
```

### Database Administration

```bash
# Connect to database
sudo -u postgres psql -d messaging

# Or as messaging user:
psql -U messaging_user -d messaging -h localhost

# Check database size
sudo -u postgres psql -d messaging -c "SELECT pg_size_pretty(pg_database_size('messaging'));"

# Check active connections
sudo -u postgres psql -d messaging -c "SELECT count(*) FROM pg_stat_activity;"

# Vacuum database
sudo -u postgres psql -d messaging -c "VACUUM ANALYZE;"
```

---

## Scaling Considerations

### Vertical Scaling (Single Instance)

1. **Upgrade instance type**:
   - Stop instance
   - Change instance type (e.g., t3.medium → t3.large)
   - Start instance
   - Verify services started correctly

2. **Increase storage**:
   - Modify EBS volume size in AWS console
   - Resize filesystem: `sudo resize2fs /dev/xvda1`

### Horizontal Scaling (Multiple Instances)

For production workloads, consider:

1. **Application Load Balancer (ALB)**
   - Distribute traffic across multiple API instances
   - Health checks using `/healthz` endpoint
   - WebSocket support with sticky sessions

2. **Separate API and Job Processor**
   - Run API servers on multiple instances
   - Run job processors on dedicated instances
   - All connected to same RDS database

3. **Amazon RDS for PostgreSQL**
   - Managed database service
   - Automated backups and point-in-time recovery
   - Read replicas for scaling reads
   - Multi-AZ for high availability

4. **Amazon ElastiCache for Redis**
   - Managed Redis service
   - Automatic failover
   - Cluster mode for scaling

---

## Troubleshooting

### Services Won't Start

```bash
# Check detailed logs
sudo journalctl -u messaging-api -n 100 --no-pager
sudo journalctl -u messaging-jobs -n 100 --no-pager

# Common issues:
# 1. Missing SECRET_KEY_BASE in .env
# 2. Database connection failure
# 3. Port 4000 already in use
# 4. Permissions issues

# Verify environment
sudo cat /opt/messaging/.env | grep SECRET_KEY_BASE
sudo -u messaging psql -U messaging_user -d messaging -h localhost -c '\conninfo'
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check connection
sudo -u postgres psql -d messaging -c "SELECT version();"

# Verify user permissions
sudo -u postgres psql -d messaging -c "\du"

# Check pg_hba.conf
sudo cat /etc/postgresql/14/main/pg_hba.conf | grep messaging
```

### High Memory Usage

```bash
# Check memory usage
free -h
htop

# Reduce pool size in .env:
sudo nano /opt/messaging/.env
# Change: POOL_SIZE=10

# Reduce Oban concurrency:
# OBAN_DELIVER_REALTIME_CONCURRENCY=20

# Restart services
sudo systemctl restart messaging-api messaging-jobs
```

### Performance Issues

```bash
# Check system resources
top
iostat -x 5
vmstat 5

# Check database performance
sudo -u postgres psql -d messaging -c "
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;
"

# Check Nginx access log for slow requests
sudo tail -f /var/log/nginx/messaging-access.log
```

---

## Cost Optimization

### AWS Cost Breakdown (Estimated)

**Basic Setup (Single Instance)**:
- EC2 t3.medium (2 vCPU, 4GB): ~$30/month
- EBS 20GB gp3: ~$2/month
- Elastic IP: Free (when attached)
- Data transfer: ~$9/GB out
- **Total**: ~$32-50/month (excluding data transfer)

**Production Setup (Scalable)**:
- ALB: ~$16/month + $0.008/LCU-hour
- RDS db.t3.medium: ~$60/month
- ElastiCache t3.small: ~$25/month
- Multiple EC2 instances: ~$60-120/month
- **Total**: ~$161-221/month + traffic costs

### Cost Saving Tips

1. **Use Reserved Instances**: Save up to 72% vs on-demand
2. **Use Spot Instances**: For job processors (non-critical)
3. **Right-size instances**: Monitor usage and downsize if needed
4. **Enable EBS optimization**: Use gp3 instead of gp2
5. **Implement auto-scaling**: Scale down during off-peak hours

---

## Security Best Practices

- ✅ Use strong passwords (12+ characters)
- ✅ Enable UFW firewall
- ✅ Configure SSL/TLS with valid certificates
- ✅ Keep system packages updated (`sudo apt update && sudo apt upgrade`)
- ✅ Use IAM roles instead of access keys where possible
- ✅ Enable CloudTrail for audit logging
- ✅ Implement regular backups (automated)
- ✅ Use VPC security groups restrictively
- ✅ Enable AWS GuardDuty for threat detection
- ✅ Implement monitoring and alerting

---

## Additional Resources

- **Detailed Setup Guide**: `SETUP-VM.MD` (in repository)
- **Development Setup**: `SETUP.md`
- **Feature Configuration**: `docs/FEATURE_FLAGS.md`
- **API Documentation**: `API_TESTING_GUIDE.md`
- **Next Steps**: `/opt/messaging/DEPLOYMENT_NEXT_STEPS.txt` (on server)

---

## Support

For issues or questions:
- Check troubleshooting section above
- Review logs in `/var/log/messaging/`
- Check systemd journals: `journalctl -u messaging-api`
- Consult `SETUP-VM.MD` for detailed documentation

---

*Last Updated: December 2024*
