# AWS Deployment Checklist

Use this checklist to ensure a complete and successful deployment of the Real-Time Messaging API.

## Pre-Deployment

### AWS Infrastructure

- [ ] EC2 instance launched (Ubuntu 22.04 LTS, t3.medium or larger)
- [ ] Elastic IP allocated and associated
- [ ] Security Group configured:
  - [ ] SSH (22) from your IP
  - [ ] HTTP (80) from anywhere
  - [ ] HTTPS (443) from anywhere
- [ ] DNS A record created (optional): `messaging.yourdomain.com` → Elastic IP
- [ ] SSH key pair downloaded and permissions set (`chmod 400`)

### Local Preparation

- [ ] Application code ready (Git repository URL or local directory)
- [ ] Strong database password prepared (12+ characters)
- [ ] Domain name ready (if using SSL)
- [ ] SSH access tested: `ssh -i key.pem ubuntu@YOUR_IP`

---

## Phase 1: VM Preparation (Automated)

### Run Preparation Script

- [ ] Connected to EC2 instance via SSH
- [ ] Downloaded or copied `prepare-vm.sh` to server
- [ ] Made script executable: `chmod +x prepare-vm.sh`
- [ ] Ran script with sudo: `sudo bash prepare-vm.sh`
- [ ] Provided PostgreSQL password (and confirmed)
- [ ] Provided domain name (or skipped)
- [ ] Script completed successfully (no errors)
- [ ] Read and saved location of deployment guide: `/opt/messaging/DEPLOYMENT_NEXT_STEPS.txt`

### Verify Installations

- [ ] Erlang/OTP installed: `erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell`
- [ ] Elixir installed: `elixir --version`
- [ ] PostgreSQL running: `sudo systemctl status postgresql`
- [ ] Redis running: `sudo systemctl status redis-server`
- [ ] Nginx running: `sudo systemctl status nginx`
- [ ] UFW firewall enabled: `sudo ufw status`
- [ ] Application user created: `id messaging`
- [ ] Directories created: `ls -la /opt/messaging`

---

## Phase 2: Application Deployment

### Deploy Code

**Option A: Git Repository**
- [ ] Switched to messaging user: `sudo su - messaging`
- [ ] Cloned repository: `git clone REPO_URL /opt/messaging/app`
- [ ] Checked out correct branch
- [ ] Verified code is present: `ls -la /opt/messaging/app`

**Option B: Local Copy**
- [ ] Copied code from local machine using `rsync` or `scp`
- [ ] Moved to correct location: `/opt/messaging/app`
- [ ] Set correct ownership: `sudo chown -R messaging:messaging /opt/messaging/app`

### Generate Secrets

- [ ] Generated SECRET_KEY_BASE: `mix phx.gen.secret`
- [ ] Copied the generated secret (saved securely)

### Configure Environment

- [ ] Edited environment file: `sudo nano /opt/messaging/.env`
- [ ] Updated `SECRET_KEY_BASE` with generated value
- [ ] Verified `DATABASE_URL` is correct
- [ ] Verified `PHX_HOST` matches your domain (or localhost)
- [ ] Verified `FEATURES_CONFIG` path is correct
- [ ] Saved and closed file
- [ ] Set correct permissions: `sudo chmod 600 /opt/messaging/.env`
- [ ] Verified SECRET_KEY_BASE is set: `sudo grep SECRET_KEY_BASE /opt/messaging/.env`

### Select Feature Configuration

- [ ] Reviewed available feature configs: `ls config/features*.yaml`
- [ ] Chose appropriate configuration:
  - [ ] `features.standard.yaml` (recommended for production)
  - [ ] `features.yaml` (full featured)
  - [ ] `features.minimal.yaml` (core only)
  - [ ] `features.no-media.yaml` (no media processing)
- [ ] Copied chosen config: `cp config/features.XXX.yaml config/features.yaml`
- [ ] Or updated `FEATURES_CONFIG` in `.env` file

### Build Application

- [ ] Switched to messaging user: `sudo su - messaging`
- [ ] Changed to app directory: `cd /opt/messaging/app`
- [ ] Set production environment: `export MIX_ENV=prod`
- [ ] Installed Hex/Rebar: `mix local.hex --force && mix local.rebar --force`
- [ ] Installed dependencies: `mix deps.get --only prod`
- [ ] Compiled dependencies: `mix deps.compile`
- [ ] Compiled application: `mix compile`
- [ ] No compilation errors

### Database Setup

- [ ] Ran migrations: `MIX_ENV=prod mix ecto.migrate`
- [ ] Migrations completed successfully
- [ ] Verified tables created: `psql -U messaging_user -d messaging -h localhost -c "\dt"`
- [ ] Expected tables present: `messages`, `receipts`, `inbox`, `oban_jobs`, `oban_peers`

---

## Phase 3: Service Startup

### Start Services

- [ ] Exited from messaging user (back to ubuntu/sudo user)
- [ ] Enabled services: `sudo systemctl enable messaging-api messaging-jobs`
- [ ] Started API service: `sudo systemctl start messaging-api`
- [ ] Started Jobs service: `sudo systemctl start messaging-jobs`
- [ ] Both services running without errors
- [ ] API service status: `sudo systemctl status messaging-api` (active/running)
- [ ] Jobs service status: `sudo systemctl status messaging-jobs` (active/running)

### Verify Deployment

- [ ] Health check passes: `curl http://localhost:4000/healthz`
- [ ] Response received: `{"status":"ok","timestamp":"..."}`
- [ ] API logs look healthy: `tail -50 /var/log/messaging/api.log`
- [ ] Jobs logs look healthy: `tail -50 /var/log/messaging/jobs.log`
- [ ] No errors in systemd journal: `journalctl -u messaging-api -n 50`

### Test Externally (if domain configured)

- [ ] Health check from external: `curl http://messaging.yourdomain.com/healthz`
- [ ] Nginx proxy working correctly
- [ ] No 502/503 errors

---

## Phase 4: SSL/TLS Configuration (Optional but Recommended)

### Certbot Setup

- [ ] DNS propagation complete (domain resolves to server IP)
- [ ] Ran Certbot: `sudo certbot --nginx -d messaging.yourdomain.com`
- [ ] Provided email address for notifications
- [ ] Agreed to terms of service
- [ ] Chose to redirect HTTP to HTTPS
- [ ] Certificate obtained successfully
- [ ] Nginx configuration updated automatically
- [ ] Tested HTTPS: `curl https://messaging.yourdomain.com/healthz`
- [ ] SSL certificate valid (no warnings in browser)
- [ ] Auto-renewal works: `sudo certbot renew --dry-run`

---

## Phase 5: Post-Deployment Configuration

### Monitoring Setup

- [ ] Opened crontab: `sudo crontab -e`
- [ ] Added daily backup job: `0 2 * * * /usr/local/bin/backup-messaging-db.sh`
- [ ] Added health check job: `*/5 * * * * /usr/local/bin/check-messaging-health.sh >> /var/log/messaging/health-check.log 2>&1`
- [ ] Saved crontab
- [ ] Verified cron jobs: `sudo crontab -l`

### Test Automated Backups

- [ ] Ran manual backup: `sudo /usr/local/bin/backup-messaging-db.sh`
- [ ] Backup created: `ls -lh /opt/messaging/backups/`
- [ ] Backup file has content: `du -h /opt/messaging/backups/messaging_*.sql.gz`

### Test Health Checks

- [ ] Ran health check script: `sudo /usr/local/bin/check-messaging-health.sh`
- [ ] Health check passes (exit code 0)

---

## Phase 6: Application Testing

### API Endpoint Tests

- [ ] Health endpoint works: `curl https://messaging.yourdomain.com/healthz`
- [ ] Create message test:
  ```bash
  curl -X POST https://messaging.yourdomain.com/v1/messages \
    -H 'Content-Type: application/json' \
    -d '{
      "conversation_id": "11111111-1111-1111-1111-111111111111",
      "sender_id": "22222222-2222-2222-2222-222222222222",
      "body": {"text": "Test deployment message"},
      "idempotency_key": "deployment-test-1"
    }'
  ```
- [ ] Response: 201 Created with message_id
- [ ] Message persisted to database:
  ```bash
  psql -U messaging_user -d messaging -h localhost \
    -c "SELECT id, status FROM messages LIMIT 1;"
  ```

### WebSocket Test (if applicable)

- [ ] Installed wscat: `npm install -g wscat`
- [ ] Connected to WebSocket: `wscat -c wss://messaging.yourdomain.com/socket/websocket`
- [ ] Connection established successfully

### Performance Baseline

- [ ] Checked response times (should be < 100ms for health check)
- [ ] Monitored CPU usage: `top` (should be low at idle)
- [ ] Monitored memory usage: `free -h` (comfortable buffer available)
- [ ] Checked database connections: 
  ```bash
  sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity WHERE datname='messaging';"
  ```

---

## Phase 7: Documentation and Handoff

### Save Important Information

- [ ] Document server IP: ___________________
- [ ] Document Elastic IP: ___________________
- [ ] Document domain name: ___________________
- [ ] Document database password: ___________________ (store in password manager)
- [ ] Document SECRET_KEY_BASE: ___________________ (store securely)
- [ ] Document SSH key location: ___________________
- [ ] Save AWS instance ID: ___________________
- [ ] Save AWS region: ___________________

### Create Runbook

- [ ] Documented restart procedure
- [ ] Documented backup/restore procedure
- [ ] Documented update/deployment procedure
- [ ] Documented rollback procedure
- [ ] Documented monitoring and alerting setup
- [ ] Documented contact information for support

### Team Knowledge Transfer

- [ ] Shared server access credentials with team (securely)
- [ ] Shared documentation links
- [ ] Demonstrated restart procedures
- [ ] Demonstrated log access and troubleshooting
- [ ] Demonstrated health check and monitoring

---

## Phase 8: Production Readiness

### Security Hardening

- [ ] Changed default passwords
- [ ] Configured fail2ban (optional): `sudo apt install fail2ban`
- [ ] Disabled password authentication in SSH (key-only)
- [ ] Configured automatic security updates:
  ```bash
  sudo apt install unattended-upgrades
  sudo dpkg-reconfigure -plow unattended-upgrades
  ```
- [ ] Reviewed and hardened security group rules
- [ ] Enabled AWS CloudTrail (optional)
- [ ] Configured AWS GuardDuty (optional)

### Monitoring and Alerting

- [ ] Setup CloudWatch monitoring (optional)
- [ ] Configured CloudWatch alarms:
  - [ ] High CPU usage (> 80% for 5 minutes)
  - [ ] High memory usage (> 85%)
  - [ ] Disk space low (< 20% free)
  - [ ] Health check failures
- [ ] Setup email/SMS notifications for alarms
- [ ] Tested alerting (trigger a test alarm)

### Backup and Disaster Recovery

- [ ] Verified automated backups are running
- [ ] Tested database restore procedure
- [ ] Documented RTO (Recovery Time Objective): _____ minutes
- [ ] Documented RPO (Recovery Point Objective): _____ hours
- [ ] Created AMI snapshot of configured instance
- [ ] Configured AWS Backup (optional)
- [ ] Documented disaster recovery runbook

### Performance and Scaling

- [ ] Established performance baselines
- [ ] Configured application performance monitoring (optional)
- [ ] Planned scaling thresholds (when to scale up/out)
- [ ] Tested application under load (optional)
- [ ] Documented scaling procedures

---

## Verification Summary

### Final Checks

- [ ] All services running: `sudo systemctl status messaging-api messaging-jobs nginx postgresql redis-server`
- [ ] No errors in logs: `sudo journalctl -p err -n 50`
- [ ] Health checks passing consistently
- [ ] SSL certificate valid and auto-renewal configured
- [ ] Firewall properly configured: `sudo ufw status`
- [ ] Backups scheduled and working
- [ ] Monitoring and alerting configured
- [ ] Documentation complete and shared
- [ ] Team trained on operations

### Sign-Off

- [ ] Deployment tested and verified
- [ ] Production readiness checklist completed
- [ ] Runbooks created and reviewed
- [ ] Team trained and comfortable with operations
- [ ] Incident response procedures documented

**Deployed by**: ___________________  
**Date**: ___________________  
**Deployment verified by**: ___________________  
**Production approved by**: ___________________

---

## Quick Reference Commands

```bash
# Check service status
sudo systemctl status messaging-api messaging-jobs

# View logs
sudo journalctl -u messaging-api -f
tail -f /var/log/messaging/api.log

# Restart services
sudo systemctl restart messaging-api messaging-jobs

# Test health
curl http://localhost:4000/healthz

# Check database
psql -U messaging_user -d messaging -h localhost

# Manual backup
sudo /usr/local/bin/backup-messaging-db.sh

# Check disk space
df -h

# Check memory usage
free -h

# Monitor processes
htop
```

---

## Troubleshooting Quick Reference

| Issue | Command | Action |
|-------|---------|--------|
| Service won't start | `journalctl -u messaging-api -n 50` | Check logs for errors |
| Database connection fails | `sudo systemctl status postgresql` | Verify PostgreSQL is running |
| High memory usage | `free -h && top` | Reduce pool size in .env |
| Port 4000 in use | `netstat -tlnp \| grep 4000` | Kill conflicting process |
| SSL certificate expired | `sudo certbot renew` | Renew certificate |
| Disk space full | `df -h && du -sh /var/*` | Clean old logs/backups |

---

*Keep this checklist for future deployments and updates*
