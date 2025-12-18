# Deployment Options - Real-Time Messaging API

This document provides an overview of all available deployment methods for the Real-Time Messaging API. Choose the method that best fits your needs and infrastructure requirements.

---

## Quick Comparison

| Method | Complexity | Setup Time | Best For | Flexibility |
|--------|------------|------------|----------|-------------|
| **Docker Compose** | Low | 15-30 min | Quick demos, single VM production | Medium |
| **Bare Metal VM** | High | 1-2 hours | Maximum control, custom infrastructure | High |
| **AWS Quick Start** | Medium | 20-30 min | AWS deployments, automated setup | Medium |

---

## 1. Docker Compose Deployment (Recommended for Quick Start)

**Best for:** 
- Quick demos and testing
- Small to medium production deployments
- Single VM deployments
- Teams familiar with Docker

**Pros:**
- ✅ Fastest setup time (15-30 minutes)
- ✅ Simplified management with docker-compose
- ✅ Easy to replicate across environments
- ✅ Built-in service orchestration
- ✅ All services pre-configured and isolated
- ✅ Simple updates and rollbacks

**Cons:**
- ❌ Limited to single-VM by default
- ❌ All services on one machine (can be a SPOF)
- ❌ Docker overhead (minimal but present)

**Requirements:**
- Linux VM with Docker and Docker Compose
- 4GB RAM minimum (8GB recommended)
- 30GB disk space

**Documentation:**
- 📖 **[DOCKER_DEPLOYMENT.md](./DOCKER_DEPLOYMENT.md)** - Full step-by-step guide
- 🚀 Quick deploy script: `./quick-deploy.sh`

**Quick Start:**
```bash
# Clone repository
git clone https://github.com/YOUR_REPO/real-time-messaging.git
cd real-time-messaging

# Setup environment
cp .env.example .env
nano .env  # Update with your values

# Deploy
./quick-deploy.sh
```

---

## 2. Bare Metal VM Deployment

**Best for:**
- Maximum performance requirements
- Custom infrastructure setups
- Long-term production deployments
- Teams that need full system control

**Pros:**
- ✅ Maximum performance (no container overhead)
- ✅ Full control over system configuration
- ✅ Can optimize every component
- ✅ Traditional deployment model
- ✅ Direct access to all services

**Cons:**
- ❌ Longer setup time (1-2 hours)
- ❌ More complex configuration
- ❌ Manual dependency management
- ❌ Requires deeper system administration knowledge

**Requirements:**
- Ubuntu 22.04 LTS (or compatible Linux)
- 4GB RAM minimum (8GB recommended)
- 20GB disk space
- Erlang/OTP 26+, Elixir 1.16+
- PostgreSQL 14+, Redis, Nginx

**Documentation:**
- 📖 **[SETUP-VM.MD](./SETUP-VM.MD)** - Complete manual setup guide
- 🤖 Automated script: `prepare-vm.sh`

**Quick Start:**
```bash
# Download and run automated setup script
wget https://raw.githubusercontent.com/YOUR_REPO/real-time-messaging/main/prepare-vm.sh
sudo bash prepare-vm.sh

# Then follow prompts for application deployment
```

---

## 3. AWS Quick Start (Automated)

**Best for:**
- AWS deployments
- Teams using AWS infrastructure
- Automated cloud deployments
- Quick production setups on AWS

**Pros:**
- ✅ Automated EC2 instance preparation
- ✅ AWS-optimized configuration
- ✅ Elastic IP and security group templates
- ✅ CloudFormation ready (coming soon)
- ✅ Integrated with AWS services

**Cons:**
- ❌ AWS-specific (not portable)
- ❌ Requires AWS account and setup
- ❌ AWS costs apply

**Requirements:**
- AWS account
- EC2 instance (t3.medium or larger)
- Elastic IP (recommended)
- Domain name (optional, for SSL)

**Documentation:**
- 📖 **[AWS_DEPLOYMENT_QUICKSTART.md](./AWS_DEPLOYMENT_QUICKSTART.md)** - AWS-specific guide
- Uses `prepare-vm.sh` for VM setup

**Quick Start:**
```bash
# 1. Launch EC2 instance (Ubuntu 22.04)
# 2. SSH into instance
ssh -i your-key.pem ubuntu@YOUR_ELASTIC_IP

# 3. Run preparation script
wget https://raw.githubusercontent.com/YOUR_REPO/real-time-messaging/main/prepare-vm.sh
sudo bash prepare-vm.sh

# Follow AWS-specific guide for deployment
```

---

## Feature Support Matrix

All deployment methods support all features, but with different default configurations:

| Feature | Docker Compose | Bare Metal | AWS Quick Start |
|---------|----------------|------------|-----------------|
| Messages | ✅ PostgreSQL | ✅ PostgreSQL | ✅ PostgreSQL |
| Receipts | ✅ PostgreSQL | ✅ PostgreSQL | ✅ PostgreSQL |
| Inbox | ✅ PostgreSQL | ✅ PostgreSQL | ✅ PostgreSQL |
| Scheduled Messages | ✅ Oban | ✅ Oban | ✅ Oban |
| Media Processing | ✅ MinIO | ⚙️ S3/Local | ✅ S3 |
| Real-time PubSub | ✅ Redis | ✅ Redis | ✅ Redis |
| WebSockets | ✅ Phoenix | ✅ Phoenix | ✅ Phoenix |
| Caching | ✅ Memcached | ✅ Memcached | ✅ Memcached |
| SSL/TLS | ⚙️ Manual | ✅ Let's Encrypt | ⚙️ ALB/Certbot |

✅ = Included out of the box  
⚙️ = Manual configuration required

---

## Scaling Considerations

### Docker Compose
- **Vertical Scaling**: Increase VM resources
- **Horizontal Scaling**: Use docker-compose scale or Swarm
- **Multi-Node**: Requires Docker Swarm or Kubernetes migration

### Bare Metal
- **Vertical Scaling**: Increase VM resources
- **Horizontal Scaling**: Deploy multiple VMs with load balancer
- **Multi-Node**: Configure distributed Erlang clustering

### AWS
- **Vertical Scaling**: Change EC2 instance type
- **Horizontal Scaling**: Multiple EC2 + Application Load Balancer
- **Multi-Node**: Auto Scaling Groups + ECS/EKS

---

## Production Readiness Checklist

Before going to production, ensure you have:

- [ ] Strong passwords for all services (generate with `openssl rand -base64 32`)
- [ ] SSL/TLS certificates configured (Let's Encrypt or load balancer)
- [ ] Firewall configured (only necessary ports open)
- [ ] Automated backups configured (daily database backups)
- [ ] Monitoring setup (health checks, logs, metrics)
- [ ] Domain name configured with DNS
- [ ] Feature flags configured for your use case
- [ ] Storage backend configured (S3/MinIO for media)
- [ ] Secrets management (for sensitive configuration)
- [ ] Log rotation configured
- [ ] Disaster recovery plan documented
- [ ] Performance testing completed

See **[DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)** for detailed checklist.

---

## Migration Between Methods

### From Docker to Bare Metal
1. Backup database from Docker: `docker compose exec postgres pg_dump ...`
2. Setup bare metal deployment
3. Restore database: `psql < backup.sql`
4. Copy storage files: `rsync -avz app_storage/ /app/priv/storage/`

### From Bare Metal to Docker
1. Backup database: `pg_dump > backup.sql`
2. Setup Docker deployment
3. Restore database: `cat backup.sql | docker compose exec -T postgres psql`
4. Copy storage files to Docker volume

### Between Cloud Providers
1. Export data (database dump + storage files)
2. Setup new environment
3. Import data
4. Update DNS records
5. Verify and cutover

---

## Cost Comparison (Estimated Monthly)

### Docker Compose on VPS
- **DigitalOcean Droplet** (4GB RAM): ~$24/month
- **Linode** (4GB RAM): ~$24/month
- **AWS EC2 t3.medium**: ~$30-40/month (with reserved instance discounts)
- **Total**: $24-40/month

### Bare Metal on VPS
- Same as Docker (same infrastructure)
- **Total**: $24-40/month

### AWS with Managed Services
- **EC2 t3.medium**: ~$30/month
- **RDS PostgreSQL db.t3.medium**: ~$60/month
- **ElastiCache Redis**: ~$15/month
- **S3**: ~$1-10/month (depending on usage)
- **Application Load Balancer**: ~$20/month
- **Total**: $126-135/month

*Note: Costs vary by region and usage. These are estimates for low-traffic deployments.*

---

## Getting Help

### Documentation
- **General Setup**: [SETUP.md](./SETUP.md)
- **API Testing**: [API_TESTING_GUIDE.md](./API_TESTING_GUIDE.md)
- **Feature Flags**: [docs/FEATURE_FLAGS.md](./docs/FEATURE_FLAGS.md)

### Support
- GitHub Issues: Report bugs and request features
- Discussions: Ask questions and share experiences
- Documentation: Check deployment guides for troubleshooting sections

---

## Recommended Deployment Flow

```
Development → Testing → Staging → Production
     ↓            ↓         ↓          ↓
  Local Dev   Docker    Docker    Bare Metal
              Compose   Compose   or Cloud
```

1. **Development**: Local development with `docker-compose.yaml`
2. **Testing**: Docker Compose for CI/CD testing
3. **Staging**: Docker Compose on dedicated VM
4. **Production**: Choice of Docker Compose, Bare Metal, or Cloud based on scale

---

## Quick Decision Guide

**Choose Docker Compose if:**
- You want to get started quickly
- You're comfortable with containers
- You want easy updates and rollbacks
- You're deploying to a single VM

**Choose Bare Metal if:**
- You need maximum performance
- You prefer traditional deployment
- You have specific system requirements
- You want full control over everything

**Choose AWS Quick Start if:**
- You're already using AWS
- You want cloud-native deployment
- You plan to use AWS managed services
- You want automated infrastructure

---

**Still not sure?** Start with **Docker Compose** - it's the fastest way to get running, and you can always migrate later if needed.
