# Usage Guide - VPN Multi-Profile Manager

Complete guide for using the VPN Multi-Profile Manager to create and manage multiple VPN profiles.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Dashboard Overview](#dashboard-overview)
- [Profile Management](#profile-management)
- [Backup & Restore](#backup--restore)
- [System Settings](#system-settings)
- [Monitoring & Logs](#monitoring--logs)
- [Best Practices](#best-practices)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

---

## Getting Started

### Launch VPSAdmin

```bash
# Run the manager
vpsadmin
```

You'll see the main dashboard with system resources and notifications.

### Navigation

- **Number keys (0-13)**: Select menu options
- **Ctrl+C**: Exit current operation
- **Enter**: Confirm selections
- **Y/N**: Answer yes/no prompts

---

## Dashboard Overview

The dashboard displays real-time system information:

### System Resources Panel

```
┌─────────────────────────────────────────────────────────────────┐
│ SYSTEM RESOURCES                                                │
├─────────────────────────────────────────────────────────────────┤
│ CPU Usage       :  12.5% / 400%      (200% allocated)           │
│ RAM Usage       :  2048MB / 8192MB  (4096MB allocated)        │
│ Bandwidth Global: 56TB                                          │
│ Active Profiles : 5 / 10                                        │
│ Disk Usage      : 45%                                           │
└─────────────────────────────────────────────────────────────────┘
```

**Metrics explained:**

- **CPU Usage**: Current vs max allocatable (100% = 1 core)
- **RAM Usage**: Used vs total system RAM
- **Bandwidth Global**: Total bandwidth across all profiles
- **Active Profiles**: Running profiles vs max allowed
- **Disk Usage**: Percentage of disk space used

### Notifications Panel

Alerts for:
- ⏰ **Expired profiles** (shown in red)
- ⏰ **Expiring soon** (within 5 days, shown in yellow)
- ⚠️ **Bandwidth exceeded** (100%+, shown in red)
- ⚠️ **High bandwidth usage** (90%+, shown in yellow)
- ✅ **All healthy** (no issues)

---

## Profile Management

### 1. List All Profiles

**Menu:** `1) List All Profiles`

Shows all profiles with:
- Profile name
- Domain
- Status (Active/Stopped)
- Expiration (days left or "Expired")

**Example:**

```
┌─────────────────────────────────────────────────────────────────┐
│ PROFILE LIST                                                    │
├─────────────────────────────────────────────────────────────────┤
│ #   Name         Domain               Status   Expired          │
├─────────────────────────────────────────────────────────────────┤
│ 1   customer1    vpn1.example.com     Active   25d left         │
│ 2   customer2    vpn2.example.com     Active   5d left          │
│ 3   reseller1    vpn3.example.com     Stopped  Expired          │
└─────────────────────────────────────────────────────────────────┘
```

**Color codes:**
- 🟢 **Green "Active"**: Profile is running
- 🔴 **Red "Stopped"**: Profile is not running
- 🟢 **Green "Xd left"**: More than 5 days until expiration
- 🟡 **Yellow "Xd left"**: 1-5 days until expiration
- 🔴 **Red "Expired"**: Profile has expired

---

### 2. Create New Profile

**Menu:** `2) Create New Profile`

Step-by-step profile creation:

#### Step 1: Basic Information

```
Name: customer1
```
- Only letters, numbers, hyphens, underscores
- Must be unique
- Used for container naming

```
Domain: vpn1.example.com
```
- Must be a valid domain
- DNS must point to your VPS IP
- Used for SSL certificate

#### Step 2: Resource Allocation

```
CPU (%): 100
```
- 100% = 1 CPU core
- Minimum: 50% (0.5 core)
- Maximum: 800% (8 cores)
- **Recommended**: 100-200% per profile

```
RAM (MB): 512
```
- Minimum: 256MB
- Maximum: 16384MB (16GB)
- **Recommended**: 512-1024MB per profile

#### Step 3: SSH Configuration

```
SSH Port [auto]:
```
- Leave empty for auto-assignment
- Range: 2200-2299 (configurable in `.env`)
- Each profile gets unique SSH port

```
Password [auto]:
```
- Leave empty for auto-generated secure password
- Or provide custom password (min 8 characters)
- Used for SSH access to profile container

#### Step 4: Expiration & Bandwidth

```
Expired (days): 30
```
- Number of days until profile expires
- Profile will be flagged when expired
- You'll receive notifications 5 days before

```
Bandwidth Quota (TB): 5
```
- Monthly bandwidth limit in Terabytes
- Example: 5 = 5000GB = 5TB
- Alerts when 90% and 100% reached

#### Step 5: WebSocket Paths

```
VMess Path [/vmess]:
VLess Path [/vless]:
Trojan Path [/trojan]:
```
- Custom paths for different protocols
- Leave empty for defaults
- Must start with `/`
- Used in Nginx routing

#### Step 6: Restore Link (Optional)

```
Restore Link [empty]:
```
- Optional: URL to restore from backup
- Leave empty for fresh profile
- Used for migration/restoration

#### Step 7: Preview & Confirm

```
╔══════════════════════════════════════════════════════════════╗
║ PROFILE PREVIEW:                                             ║
╠══════════════════════════════════════════════════════════════╣
║ Name            : customer1                                  ║
║ Domain          : vpn1.example.com                           ║
║ CPU             : 100% (1.0 cores)                           ║
║ RAM             : 512MB                                      ║
║ SSH Port        : 2200                                       ║
║ Password        : Ab12Cd34Ef                                 ║
║ Expired         : 2025-11-18 (30 days)                       ║
║ Bandwidth Quota : 5TB/month                                  ║
║ WebSocket Paths:                                             ║
║   VMess         : /vmess                                     ║
║   VLess         : /vless                                     ║
║   Trojan        : /trojan                                    ║
╚══════════════════════════════════════════════════════════════╝

Create this profile? [y/N]:
```

Type `y` and press Enter to create.

#### What Happens Next

The system will:
1. ✅ Create profile directory structure
2. ✅ Save profile metadata
3. ✅ Create Docker container with resource limits
4. ✅ Install and configure Xray
5. ✅ Set up SSH access
6. ✅ Request SSL certificate from Let's Encrypt
7. ✅ Configure Nginx reverse proxy
8. ✅ Start the container
9. ✅ Add to profiles database
10. ✅ Send Telegram notification (if configured)

**Typical creation time:** 2-5 minutes (SSL cert takes longest)

---

### 3. Delete Profile

**Menu:** `3) Delete Profile`

#### Step 1: Select Profile

```
Available profiles:

 1) customer1         vpn1.example.com         [active]
 2) customer2         vpn2.example.com         [active]
 3) reseller1         vpn3.example.com         [stopped]

Select profile number to delete [0 to cancel]:
```

#### Step 2: Confirm Deletion

```
⚠️  WARNING: This will permanently delete profile: customer1
    All data, configurations, and VPN accounts will be removed!

Are you sure you want to delete this profile? [y/N]:
```

Type `y` to confirm.

#### What Gets Deleted

- ❌ Docker container (stopped and removed)
- ❌ Nginx configuration
- ❌ Profile directory and all data
- ❌ SSL certificates
- ❌ Profile entry in database
- ❌ Xray configurations
- ❌ User accounts and settings

**⚠️ Warning:** This action is **irreversible**. Always backup before deleting!

---

### 4. Access Profile (SSH)

**Menu:** `4) Access Profile (SSH)`

#### Step 1: Select Profile

```
Available profiles:

 1) customer1         Port: 2200    Status: running
 2) customer2         Port: 2201    Status: running
 3) reseller1         Port: N/A     Status: stopped

Select profile number to access [0 to cancel]:
```

#### Step 2: View Connection Info

```
╔══════════════════════════════════════════════════════════════╗
║                 SSH CONNECTION INFO                          ║
╠══════════════════════════════════════════════════════════════╣
║ Profile     : customer1                                      ║
║ Host        : localhost                                      ║
║ Port        : 2200                                           ║
║ Username    : root                                           ║
║ Password    : Ab12Cd34Ef                                     ║
╠══════════════════════════════════════════════════════════════╣
║ Command: ssh -p 2200 root@localhost                         ║
╚══════════════════════════════════════════════════════════════╝

Connect now? [Y/n]:
```

#### Step 3: Connect

Type `Y` or press Enter to connect automatically.

**Inside the container:**

```bash
# You're now inside the profile container!
root@customer1:~#

# View Xray status
systemctl status xray

# View user accounts
ls -la /etc/xray/users/

# Check bandwidth
vnstat

# View logs
tail -f /var/log/xray/access.log
```

**To exit:** Type `exit` or press `Ctrl+D`

---

### 5. Extend Profile Expiration

**Menu:** `5) Extend Profile Expiration`

#### Step 1: Select Profile

```
Available profiles:

 1) customer1    Exp: 2025-11-18 (30 days)
 2) customer2    Exp: 2025-10-23 (5 days)
 3) reseller1    Exp: 2025-10-10 (EXPIRED)

Select profile number to extend [0 to cancel]:
```

#### Step 2: Add Days

```
Current expiration: 2025-11-18

Add days to expiration: 30
```

Enter number of days to add (e.g., `30` for one more month).

#### Result

```
✔ Expiration extended successfully

Previous expiration: 2025-11-18
New expiration:      2025-12-18 (+30 days)
```

**Notifications sent to:**
- 📱 Telegram (if configured)
- 📝 History log

---

### 6. Extend Profile Bandwidth

**Menu:** `6) Extend Profile Bandwidth`

#### Step 1: Select Profile

```
Available profiles:

 1) customer1    Quota:  5000 GB  Used:  2340.50 GB
 2) customer2    Quota:  3000 GB  Used:  2850.75 GB
 3) reseller1    Quota: 10000 GB  Used:  9999.99 GB

Select profile number to extend [0 to cancel]:
```

#### Step 2: Add Bandwidth

```
Current quota: 5000 GB

Add bandwidth quota (GB): 2000
```

Enter amount in Gigabytes (e.g., `2000` for +2TB).

#### Result

```
✔ Bandwidth quota extended successfully

Previous quota: 5000 GB
New quota:      7000 GB (+2000 GB)
```

**Note:** Bandwidth usage resets monthly or can be manually reset.

---

## Backup & Restore

### 7. Backup Profile

**Menu:** `7) Backup Profile`

**Current Status:** Backs up ALL profiles (single profile backup coming soon)

What gets backed up:
- ✅ `profiles.json` (profile database)
- ✅ SSL certificates from acme.sh
- ✅ Nginx site configurations
- ✅ Xray configurations per profile
- ✅ User account data
- ✅ WebSocket path settings
- ✅ Bandwidth statistics (vnstat data)
- ✅ SSH keys
- ✅ Profile metadata

**Backup locations:**

- **Local**: `/var/backups/xray-multi/YYYYMMDD-HHMMSS.tar.gz`
- **S3**: Uploaded to configured S3 bucket
- **Rclone**: Synced to configured cloud storage

**Retention:** 30 days (configurable in `.env`)

---

### 8. Restore Profile

**Menu:** `8) Restore Profile`

#### Step 1: List Available Backups

```
Available backups:

 1) 20251018-020000.tar.gz  (45.2MB)  2025-10-18 02:00:00
 2) 20251017-020000.tar.gz  (42.8MB)  2025-10-17 02:00:00
 3) 20251016-020000.tar.gz  (40.1MB)  2025-10-16 02:00:00

Select backup to restore [0 to cancel]:
```

#### Step 2: Choose Restore Method

```
Restore options:

 1) Full restore (all profiles and settings)
 2) Selective restore (choose specific profiles)
 3) Configuration only (profiles.json, SSL certs)

Select restore method [0 to cancel]:
```

#### Step 3: Confirm Restoration

```
⚠️  WARNING: This will overwrite existing data!

Backup: 20251018-020000.tar.gz
Method: Full restore

Continue? [y/N]:
```

**⚠️ Important:**
- Stop all profiles before restoring
- Backup current state first
- DNS records must still point to your IP

---

### 9. Global Backup (All Profiles)

**Menu:** `9) Global Backup (All Profiles)`

Creates a complete system backup.

#### Process

```
Creating backup...
✔ Backed up profiles.json
✔ Backed up SSL certificates from acme.sh
✔ Backed up Nginx site configs
✔ Backed up profile: customer1
✔ Backed up profile: customer2
✔ Backed up profile: reseller1
✔ Backed up 3 profiles

Creating archive: /var/backups/xray-multi/20251018-143022.tar.gz
✔ Backup archive created (48.5MB)

Uploading to S3...
✔ Upload complete

Cleaning up old backups...
✔ Remaining backups: 15

✔ Backup completed successfully!
```

**Schedule automatic backups:**

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /etc/xray-multi/scripts/backup-manager.sh global
```

---

### 10. Global Restore

**Menu:** `10) Global Restore`

Restores complete system state from backup. Same as option 8 but defaults to full restore.

---

## System Settings

**Menu:** `11) System Settings`

### 1. Edit .env Configuration

**Menu:** `1) Edit .env Configuration`

Opens nano editor with all settings:

```bash
# System Settings
MAX_PROFILES=10
BASE_IP=172.20.1
SSH_PORT_START=2200
SSH_PORT_END=2299

# Telegram Notifications
TELEGRAM_BOT_TOKEN="your_token"
TELEGRAM_CHAT_ID="your_chat_id"

# Backup Settings
BACKUP_METHOD="local"  # local, s3, or rclone
BACKUP_RETENTION_DAYS=30

# S3 Backup
S3_ACCESS_KEY=""
S3_SECRET_KEY=""
S3_BUCKET=""
S3_REGION="us-east-1"

# Rclone Backup
RCLONE_REMOTE=""
RCLONE_PATH="VPN-Backups"

# SSL Settings
MAX_CERTS_PER_HOUR=5
ACME_EMAIL="admin@example.com"

# Xray Settings
XRAY_VERSION="v25.10.15"
DEFAULT_VMESS_PATH="/vmess"
DEFAULT_VLESS_PATH="/vless"
DEFAULT_TROJAN_PATH="/trojan"

# Docker Settings
DOCKER_SUBNET="172.20.1.0/24"
DEFAULT_CPU_LIMIT="100"
DEFAULT_RAM_LIMIT="512"
```

**Save:** `Ctrl+X`, then `Y`, then `Enter`

---

### 2. Configure Telegram Alerts

**Menu:** `2) Configure Telegram Alerts`

Interactive setup for Telegram notifications.

#### Process

```
Telegram Bot Token: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
Telegram Chat ID: 123456789

✔ Telegram configuration saved

Send test message? [y/N]: y

✔ Test message sent
```

**Notifications sent for:**
- 🆕 Profile created
- 🗑️ Profile deleted
- 📅 Expiration extended
- 📊 Bandwidth quota extended
- 💾 Backup completed/failed
- ⚠️ Profile expired
- ⚠️ Bandwidth exceeded

---

### 3. Configure S3 Backup

**Menu:** `3) Configure S3 Backup`

Set up AWS S3 for automated backups.

```
AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS Region [ap-southeast-1]: us-east-1
S3 Bucket Name: my-vpn-backups

✔ S3 configuration saved
```

**Test upload:**

```bash
/etc/xray-multi/scripts/backup-manager.sh global
```

---

### 4. Configure rclone Backup

**Menu:** `4) Configure rclone Backup`

Set up cloud storage (Google Drive, Dropbox, OneDrive, etc.)

#### Step 1: Configure Remote

```
Running rclone config...

n) New remote
s) Set configuration password
q) Quit config
n/s/q> n

name> gdrive
Type of storage> drive
# Follow prompts...
```

#### Step 2: Set Backup Path

```
Enter remote name (from rclone config): gdrive
Enter backup path [VPN-Backups]: MyBackups

✔ rclone configuration saved
```

---

### 5. View Current Configuration

**Menu:** `5) View Current Configuration`

Shows current settings (passwords/tokens hidden):

```
MAX_PROFILES=10
BASE_IP=172.20.1
SSH_PORT_START=2200
SSH_PORT_END=2299
BACKUP_METHOD=s3
BACKUP_RETENTION_DAYS=30
MAX_CERTS_PER_HOUR=5
ACME_EMAIL=admin@example.com
XRAY_VERSION=v25.10.15
...
```

---

## Monitoring & Logs

**Menu:** `12) View Logs`

### Log Options

```
┌─────────────────────────────────────────────────────────────────┐
│ LOGS                                                            │
├─────────────────────────────────────────────────────────────────┤
│  1)  VPSAdmin Log                                               │
│  2)  SSL Manager Log                                            │
│  3)  Health Check Log                                           │
│  4)  Backup Log                                                 │
│  0)  Back to Main Menu                                          │
└─────────────────────────────────────────────────────────────────┘
```

### 1. VPSAdmin Log

```bash
tail -f /var/log/xray-multi/vpsadmin.log
```

Shows:
- Menu actions
- Profile operations
- User interactions
- Errors and warnings

### 2. SSL Manager Log

```bash
tail -f /var/log/xray-multi/ssl-manager.log
```

Shows:
- Certificate requests
- Renewals
- Failures
- Rate limit warnings

### 3. Health Check Log

```bash
tail -f /var/log/xray-multi/health-check.log
```

Shows:
- Container status checks
- Resource monitoring
- Alert triggers
- System health

### 4. Backup Log

```bash
tail -f /var/log/xray-multi/backup.log
```

Shows:
- Backup start/end times
- Files backed up
- Upload status
- Cleanup operations

**Exit logs:** Press `Ctrl+C`

---

### 13. Health Check Status

**Menu:** `13) Health Check Status`

Real-time health report:

```
╔══════════════════════════════════════════════════════════════╗
║                 SYSTEM HEALTH CHECK                          ║
╠══════════════════════════════════════════════════════════════╣
║ Docker Service      : ✔ Running                              ║
║ Nginx Service       : ✔ Running                              ║
║ Disk Space          : ✔ 55GB free (45% used)                 ║
║ Memory              : ✔ 4096MB free (50% used)               ║
║ CPU Load            : ✔ Normal (12.5%)                       ║
╠══════════════════════════════════════════════════════════════╣
║ PROFILES                                                     ║
╠══════════════════════════════════════════════════════════════╣
║ customer1           : ✔ Running   ✔ Healthy                  ║
║ customer2           : ✔ Running   ⚠ High bandwidth (92%)    ║
║ reseller1           : ✖ Stopped   ✖ Expired                  ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Best Practices

### 1. Resource Allocation

**Recommended per profile:**

| User Count | CPU  | RAM   | Bandwidth |
|------------|------|-------|-----------|
| 1-5 users  | 100% | 512MB | 1-2TB     |
| 5-20 users | 150% | 1GB   | 3-5TB     |
| 20-50 users| 200% | 2GB   | 5-10TB    |
| 50+ users  | 300%+ | 4GB+  | 10TB+     |

**Total allocation formula:**

```
Total CPU needed = (profiles × avg_cpu_per_profile) + 100% buffer
Total RAM needed = (profiles × avg_ram_per_profile) + 2GB buffer
```

**Example for 5 profiles:**
- CPU: (5 × 150%) + 100% = 850% (9 cores needed)
- RAM: (5 × 1GB) + 2GB = 7GB

### 2. Naming Conventions

**Good profile names:**
- ✅ `customer1`, `customer2`
- ✅ `reseller-john`
- ✅ `trial-2025-10`
- ✅ `premium_user_01`

**Bad profile names:**
- ❌ `test` (too generic)
- ❌ `my profile` (spaces not allowed)
- ❌ `user@email.com` (special chars)

### 3. Expiration Management

**Strategy:**
- Set initial expiration: 30-90 days
- Send reminder at 7 days
- Auto-notification at 5 days (built-in)
- Extend before expiration
- Grace period: 3-7 days after expiration

**Automation:**
```bash
# Check daily for expiring profiles
crontab -e

# Add:
0 9 * * * /etc/xray-multi/scripts/expiration-check.sh
```

### 4. Bandwidth Monitoring

**Best practices:**
- Set realistic quotas (5-10TB for most users)
- Monitor weekly via dashboard
- Get alerts at 90% (automatic)
- Extend quota before 100%
- Reset monthly or on payment

**Check usage:**
```bash
# SSH into profile
ssh -p 2200 root@localhost

# View bandwidth
vnstat -m  # Monthly stats
vnstat -d  # Daily stats
vnstat -h  # Hourly stats
```

### 5. Backup Schedule

**Recommended:**

```cron
# Daily backup at 2 AM
0 2 * * * /etc/xray-multi/scripts/backup-manager.sh global

# Weekly full backup
0 3 * * 0 /etc/xray-multi/scripts/backup-manager.sh global

# Test restore monthly
0 4 1 * * /etc/xray-multi/scripts/test-restore.sh
```

**3-2-1 Backup Rule:**
- **3** copies of data
- **2** different storage types (local + S3)
- **1** offsite copy (cloud)

### 6. Security

**Hardening checklist:**

```bash
# 1. Use strong SSH passwords
# Generate secure password:
openssl rand -base64 12

# 2. Change default SSH port range
nano /etc/xray-multi/.env
# SSH_PORT_START=3200
# SSH_PORT_END=3299

# 3. Firewall: only allow needed ports
ufw default deny incoming
ufw allow 22/tcp    # Main SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3200:3299/tcp  # Profile SSH
ufw enable

# 4. Enable automatic security updates
apt-get install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# 5. Monitor failed login attempts
tail -f /var/log/auth.log | grep Failed

# 6. Use Fail2Ban
apt-get install fail2ban
systemctl enable fail2ban
```

### 7. Performance Optimization

**For high-traffic servers:**

```bash
# 1. Increase system limits
nano /etc/sysctl.conf

# Add:
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 8192

# Apply:
sysctl -p

# 2. Enable BBR congestion control
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 3. Optimize Docker
nano /etc/docker/daemon.json

{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}

systemctl restart docker
```

---

## Advanced Usage

### Manual Profile Operations

**Start/stop containers:**

```bash
# List all containers
docker ps -a | grep vpn

# Stop profile
docker stop customer1-vpn

# Start profile
docker start customer1-vpn

# Restart profile
docker restart customer1-vpn

# View logs
docker logs -f customer1-vpn
```

### Direct Database Access

**Edit profiles.json:**

```bash
# Backup first!
cp /etc/xray-multi/profiles.json /etc/xray-multi/profiles.json.bak

# Edit
nano /etc/xray-multi/profiles.json

# Validate JSON
jq . /etc/xray-multi/profiles.json
```

### Custom Scripts

**Location:** `/etc/xray-multi/profile-scripts/`

Create custom automation:

```bash
#!/bin/bash
# /etc/xray-multi/profile-scripts/custom-action.sh

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

# Your custom logic here
print_success "Custom script executed!"
```

### API Integration (Coming Soon)

**REST API endpoints:**

```bash
# Get all profiles
curl http://localhost:8080/api/profiles

# Get specific profile
curl http://localhost:8080/api/profiles/customer1

# Create profile
curl -X POST http://localhost:8080/api/profiles \
  -H "Content-Type: application/json" \
  -d '{"name":"customer1","domain":"vpn1.example.com",...}'
```

---

## Troubleshooting

### Profile Creation Fails

**Issue:** SSL certificate request fails

**Solutions:**

```bash
# 1. Check DNS
dig vpn1.example.com
# Should return your VPS IP

# 2. Check Let's Encrypt rate limits
# Max 5 certs per hour, 50 per week per domain

# 3. Manual certificate request
acme.sh --issue -d vpn1.example.com --standalone

# 4. Use staging for testing
# Edit .env: ACME_SERVER="staging"
```

### Profile Not Starting

**Issue:** Container fails to start

**Solutions:**

```bash
# Check container logs
docker logs customer1-vpn

# Check resource limits
docker inspect customer1-vpn | grep -A 10 Resources

# Increase limits
docker update --cpus=2 --memory=1g customer1-vpn

# Restart
docker restart customer1-vpn
```

### High Bandwidth Usage

**Issue:** Profile using too much bandwidth

**Solutions:**

```bash
# SSH into profile
ssh -p 2200 root@localhost

# Check top connections
netstat -tunap | sort -k3

# Check user usage
vnstat -l  # Live view

# Limit per-user bandwidth (edit Xray config)
nano /etc/xray/config.json
# Add traffic policies
```

### Dashboard Not Updating

**Issue:** Resource metrics stuck

**Solutions:**

```bash
# Restart vpsadmin
# Press Ctrl+C and run again
vpsadmin

# Check system commands
which bc
which jq
which vnstat

# Install missing tools
apt-get install bc jq vnstat -y
```

### Cannot Access SSH

**Issue:** SSH connection refused

**Solutions:**

```bash
# 1. Check if container is running
docker ps | grep customer1-vpn

# 2. Check port mapping
docker port customer1-vpn

# 3. Check firewall
ufw status
ufw allow 2200/tcp

# 4. Check SSH service inside container
docker exec customer1-vpn systemctl status ssh

# 5. Restart SSH inside container
docker exec customer1-vpn systemctl restart ssh
```

---

## Getting Help

**Need support?**

1. **Check Logs:**
   ```bash
   vpsadmin → View Logs
   ```

2. **GitHub Issues:**
   - Search existing: https://github.com/kaccang/xray-multiprofile/issues
   - Open new issue with:
     - VPS specs
     - OS version
     - Error messages
     - Steps to reproduce

3. **Documentation:**
   - [Installation Guide](INSTALLATION.md)
   - [README](README.md)

---

**🚀 Happy managing!**

Master these workflows and you'll efficiently manage hundreds of VPN profiles with ease.

For questions or support, visit: https://github.com/kaccang/xray-multiprofile
