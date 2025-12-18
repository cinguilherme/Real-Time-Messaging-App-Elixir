# Deployment Documentation

This directory contains comprehensive documentation for deploying the Real-Time Messaging API to production environments.

## Documentation Files

### 1. **SETUP-VM.MD** - Detailed Manual Setup Guide
Comprehensive step-by-step guide for manually setting up the application on a bare cloud VM instance.

**Use this when**:
- You want to understand every step of the setup process
- You need to troubleshoot issues
- You're setting up on a non-standard environment
- You need reference documentation

**Contents**:
- Prerequisites and system requirements
- Complete installation instructions for all dependencies
- Database setup and configuration
- Nginx reverse proxy configuration
- SSL/TLS setup with Let's Encrypt
- Systemd service configuration
- Monitoring and maintenance procedures
- Comprehensive troubleshooting guide

---

### 2. **prepare-vm.sh** - Automated Setup Script
Automated bash script that prepares a fresh Ubuntu 22.04 VM for running the messaging API.

**Use this when**:
- You're deploying to a fresh VM
- You want to automate the infrastructure setup
- You're setting up AWS EC2, DigitalOcean, or similar cloud VMs

**What it does**:
- Installs all system dependencies (Erlang, Elixir, PostgreSQL, Redis, Nginx)
- Configures database and creates users
- Sets up application user and directories
- Creates systemd service files
- Configures firewall and security
- Sets up log rotation and backup scripts
- Creates environment configuration templates

**Usage**:
```bash
sudo bash prepare-vm.sh
```

**Time**: ~5-10 minutes

---

### 3. **AWS_DEPLOYMENT_QUICKSTART.md** - AWS Quick Start Guide
Streamlined guide specifically for AWS EC2 deployments with step-by-step instructions.

**Use this when**:
- You're deploying to AWS EC2
- You want a quick, prescriptive deployment guide
- You're new to AWS deployments

**Contents**:
- AWS-specific prerequisites (EC2, Security Groups, Elastic IP)
- Two-phase deployment process
- Phase 1: Automated VM preparation
- Phase 2: Application deployment
- Post-deployment configuration
- Testing procedures
- Scaling considerations
- Cost optimization tips

**Time**: ~15-20 minutes for complete deployment

---

### 4. **DEPLOYMENT_CHECKLIST.md** - Interactive Deployment Checklist
Comprehensive checklist to ensure nothing is missed during deployment.

**Use this when**:
- You're performing a production deployment
- You need to verify all steps were completed
- You're documenting a deployment for compliance
- You're training new team members

**Contents**:
- Pre-deployment verification
- VM preparation checklist
- Application deployment checklist
- SSL/TLS setup verification
- Post-deployment configuration
- Production readiness checks
- Sign-off section
- Quick reference commands

---

## Deployment Paths

### Path A: Automated AWS Deployment (Recommended for Most Users)

**Best for**: Quick deployments, AWS EC2, standard configurations

1. Read: **AWS_DEPLOYMENT_QUICKSTART.md**
2. Use: **prepare-vm.sh**
3. Follow: **DEPLOYMENT_CHECKLIST.md**

**Time**: 15-20 minutes

---

### Path B: Manual Deployment (Learning/Troubleshooting)

**Best for**: Non-standard environments, learning, troubleshooting

1. Read: **SETUP-VM.MD** (complete guide)
2. Follow: **DEPLOYMENT_CHECKLIST.md**

**Time**: 30-45 minutes

---

### Path C: Automated + Deep Dive

**Best for**: Production deployments, want to understand everything

1. Read: **SETUP-VM.MD** (understand the process)
2. Read: **AWS_DEPLOYMENT_QUICKSTART.md** (AWS specifics)
3. Use: **prepare-vm.sh** (automate setup)
4. Follow: **DEPLOYMENT_CHECKLIST.md** (verify everything)

**Time**: 1 hour (including reading)

---

## Quick Start

### For AWS EC2 (Ubuntu 22.04)

```bash
# 1. Launch EC2 instance (t3.medium, Ubuntu 22.04)
# 2. SSH into instance
ssh -i your-key.pem ubuntu@YOUR_IP

# 3. Download and run preparation script
wget https://raw.githubusercontent.com/YOUR_REPO/real-time-messaging/main/prepare-vm.sh
sudo bash prepare-vm.sh

# 4. Follow the prompts and wait for completion (~10 minutes)

# 5. Deploy your application code
sudo su - messaging
cd /opt/messaging
git clone YOUR_REPO app
cd app

# 6. Generate secrets and configure
mix phx.gen.secret  # Copy output
exit
sudo nano /opt/messaging/.env  # Update SECRET_KEY_BASE

# 7. Build and deploy
sudo su - messaging
cd /opt/messaging/app
export MIX_ENV=prod
mix deps.get --only prod
mix compile
mix ecto.migrate
exit

# 8. Start services
sudo systemctl start messaging-api messaging-jobs
sudo systemctl status messaging-api messaging-jobs

# 9. Verify
curl http://localhost:4000/healthz

# 10. Configure SSL (if you have a domain)
sudo certbot --nginx -d messaging.yourdomain.com
```

---

## File Structure

```
real-time-messaging/
├── SETUP-VM.MD                    # Detailed manual setup guide
├── prepare-vm.sh                  # Automated VM preparation script
├── AWS_DEPLOYMENT_QUICKSTART.md   # AWS-specific quick start
├── DEPLOYMENT_CHECKLIST.md        # Interactive deployment checklist
├── DEPLOYMENT_README.md           # This file
├── SETUP.md                       # Development setup (local)
├── readme.md                      # Project overview
└── docs/
    └── FEATURE_FLAGS.md           # Feature configuration guide
```

---

## Support Matrix

### Operating Systems

| OS | Version | Status | Script Support |
|----|---------|--------|----------------|
| Ubuntu | 22.04 LTS | ✅ Recommended | Full |
| Ubuntu | 20.04 LTS | ✅ Supported | Full |
| Debian | 11+ | ✅ Supported | Partial |
| CentOS/Rocky | 8+ | ⚠️ Untested | Manual only |
| Amazon Linux | 2023 | ⚠️ Untested | Manual only |

### Cloud Providers

| Provider | Status | Notes |
|----------|--------|-------|
| AWS EC2 | ✅ Fully Tested | See AWS_DEPLOYMENT_QUICKSTART.md |
| DigitalOcean | ✅ Compatible | Use prepare-vm.sh |
| Google Cloud | ✅ Compatible | Use prepare-vm.sh |
| Azure | ✅ Compatible | Use prepare-vm.sh |
| Linode | ✅ Compatible | Use prepare-vm.sh |
| Vultr | ✅ Compatible | Use prepare-vm.sh |

---

## Prerequisites Summary

### Minimum Requirements

- **VM**: 2 vCPUs, 4GB RAM, 20GB SSD
- **OS**: Ubuntu 22.04 LTS (or compatible)
- **Network**: Public IP, ports 80/443/22 accessible
- **Dependencies**: Installed by `prepare-vm.sh` or manual setup

### Recommended for Production

- **VM**: 4 vCPUs, 8GB RAM, 50GB SSD
- **Database**: Separate RDS/managed PostgreSQL instance
- **Load Balancer**: ALB/Load balancer for high availability
- **Monitoring**: CloudWatch, DataDog, or similar
- **Backups**: Automated daily backups with off-site storage

---

## Deployment Workflows

### Initial Deployment

1. ✅ Provision infrastructure (EC2, networking, DNS)
2. ✅ Run `prepare-vm.sh` to setup system
3. ✅ Deploy application code
4. ✅ Configure environment variables
5. ✅ Run database migrations
6. ✅ Start services
7. ✅ Configure SSL/TLS
8. ✅ Verify deployment
9. ✅ Setup monitoring and backups

### Updates and Patches

```bash
# 1. SSH to server
ssh -i key.pem ubuntu@YOUR_IP

# 2. Switch to app user
sudo su - messaging
cd /opt/messaging/app

# 3. Pull latest code
git pull origin main

# 4. Update dependencies
export MIX_ENV=prod
mix deps.get --only prod
mix compile

# 5. Run migrations
mix ecto.migrate

# 6. Restart services
exit
sudo systemctl restart messaging-api messaging-jobs

# 7. Verify
curl http://localhost:4000/healthz
```

### Rollback Procedure

```bash
# 1. Revert code
cd /opt/messaging/app
git log --oneline -5
git reset --hard PREVIOUS_COMMIT_HASH

# 2. Rollback database (if needed)
MIX_ENV=prod mix ecto.rollback

# 3. Restart services
sudo systemctl restart messaging-api messaging-jobs
```

---

## Security Considerations

### Implemented by `prepare-vm.sh`

- ✅ UFW firewall configured (SSH, HTTP, HTTPS only)
- ✅ Non-root application user
- ✅ Restricted file permissions (600 for .env)
- ✅ PostgreSQL local-only connections
- ✅ Redis local-only connections

### Additional Recommendations

- 🔒 Use SSH key-only authentication (disable password auth)
- 🔒 Enable fail2ban for brute-force protection
- 🔒 Configure automatic security updates
- 🔒 Use AWS Security Groups restrictively
- 🔒 Enable AWS GuardDuty for threat detection
- 🔒 Implement rate limiting (already in Nginx config)
- 🔒 Use AWS Secrets Manager for sensitive data
- 🔒 Enable CloudTrail for audit logging

---

## Monitoring and Observability

### Built-in Health Checks

```bash
# Application health
curl http://localhost:4000/healthz

# Service status
systemctl status messaging-api messaging-jobs

# Database connectivity
psql -U messaging_user -d messaging -h localhost -c "SELECT 1;"

# Redis connectivity
redis-cli ping
```

### Log Locations

```bash
# Application logs
/var/log/messaging/api.log
/var/log/messaging/api-error.log
/var/log/messaging/jobs.log
/var/log/messaging/jobs-error.log

# Systemd journals
journalctl -u messaging-api -f
journalctl -u messaging-jobs -f

# Nginx logs
/var/log/nginx/messaging-access.log
/var/log/nginx/messaging-error.log

# PostgreSQL logs
/var/log/postgresql/postgresql-14-main.log
```

### Key Metrics to Monitor

- Response time (p50, p95, p99)
- Request rate (requests/second)
- Error rate (4xx, 5xx responses)
- Database connection pool usage
- Oban queue depth and processing time
- CPU and memory usage
- Disk space usage
- Database query performance

---

## Troubleshooting Resources

### Common Issues

| Issue | Documentation | Section |
|-------|--------------|---------|
| Service won't start | SETUP-VM.MD | Troubleshooting > Application Won't Start |
| Database connection fails | SETUP-VM.MD | Troubleshooting > Database Connection Issues |
| High memory usage | SETUP-VM.MD | Troubleshooting > High Memory Usage |
| SSL certificate issues | SETUP-VM.MD | Troubleshooting > SSL Certificate Issues |
| Performance problems | SETUP-VM.MD | Troubleshooting > Performance Issues |

### Getting Help

1. Check the **SETUP-VM.MD** troubleshooting section
2. Review application logs in `/var/log/messaging/`
3. Check systemd journals: `journalctl -u messaging-api`
4. Review **DEPLOYMENT_CHECKLIST.md** to ensure all steps completed
5. Consult the project's main documentation

---

## Cost Estimation

### AWS Monthly Costs (US-East-1)

**Single Instance Setup**:
- EC2 t3.medium (on-demand): ~$30
- EBS 20GB gp3: ~$2
- Elastic IP: Free (when attached)
- Data transfer: ~$0.09/GB
- **Estimated Total**: $32-50/month

**Production Setup** (HA with managed services):
- ALB: ~$16
- EC2 t3.medium (2x): ~$60
- RDS db.t3.medium: ~$60
- ElastiCache t3.small: ~$25
- Data transfer: variable
- **Estimated Total**: $161-250/month

💡 **Save 30-72%** with Reserved Instances or Savings Plans

---

## Next Steps After Deployment

1. ✅ Setup CloudWatch monitoring and alarms
2. ✅ Configure automated backups to S3
3. ✅ Implement log aggregation (CloudWatch Logs)
4. ✅ Setup CI/CD pipeline for automated deployments
5. ✅ Create disaster recovery runbook
6. ✅ Load test the application
7. ✅ Setup staging environment
8. ✅ Document operational procedures
9. ✅ Train team on operations and troubleshooting
10. ✅ Schedule regular maintenance windows

---

## Additional Resources

- **Application Documentation**: `readme.md` - Project overview and architecture
- **Development Setup**: `SETUP.md` - Local development environment setup
- **Feature Flags**: `docs/FEATURE_FLAGS.md` - Feature configuration guide
- **API Testing**: `API_TESTING_GUIDE.md` - API endpoint documentation and examples

---

## Feedback and Contributions

Found an issue or have a suggestion for these deployment docs?

- Open an issue in the repository
- Submit a pull request with improvements
- Contact the team at [support@yourdomain.com]

---

*Last Updated: December 2024*  
*Documentation Version: 1.0*
