# Installation Guide - VPN Multi-Profile Manager

Complete installation guide for deploying the VPN Multi-Profile Manager on your VPS.

---

## Table of Contents

- [System Requirements](#system-requirements)
- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Manual Installation](#manual-installation)
- [Post-Installation Setup](#post-installation-setup)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## System Requirements

### Minimum Requirements

- **OS**: Ubuntu 20.04 LTS or Debian 11+ (64-bit)
- **RAM**: 2GB minimum (4GB recommended)
- **CPU**: 2 cores minimum (4 cores recommended)
- **Disk**: 20GB SSD minimum (50GB+ recommended)
- **Network**: Static public IP address
- **Root Access**: Required

### Recommended Specifications

For optimal performance with 10+ profiles:

- **RAM**: 8GB or more
- **CPU**: 4+ cores
- **Disk**: 100GB+ NVMe SSD
- **Bandwidth**: 1Gbps unmetered

---

## Prerequisites

### 1. Domain Names

You'll need domain names for each profile. Options:

- **Buy domains**: From registrars like Namecheap, GoDaddy, etc.
- **Use subdomains**: Point multiple subdomains to your VPS IP
- **Free domains**: Use services like DuckDNS, FreeDNS (not recommended for production)

### 2. DNS Configuration

Point your domains to your VPS IP address:

```
A Record: example.com → YOUR_VPS_IP
A Record: *.example.com → YOUR_VPS_IP
```

Wait for DNS propagation (5-60 minutes).

### 3. VPS Access

Ensure you have:
- SSH access to your VPS
- Root or sudo privileges
- Firewall ports open: 80, 443, 2200-2299

---

## Quick Installation

### Step 1: Clone Repository

```bash
# Login as root
sudo su -

# Clone the repository
git clone https://github.com/kaccang/xray-multiprofile.git
cd xray-multiprofile
```

### Step 2: Run Setup Script

```bash
# Make setup script executable
chmod +x setup.sh

# Run installation
./setup.sh
```

The setup script will:
- ✅ Check OS compatibility
- ✅ Install all dependencies (Docker, Nginx, jq, etc.)
- ✅ Create directory structure
- ✅ Copy files to `/etc/xray-multi`
- ✅ Set correct permissions
- ✅ Build Docker image
- ✅ Configure Nginx
- ✅ Create `vpsadmin` command

### Step 3: Configure Environment

```bash
# Edit configuration file
nano /etc/xray-multi/.env
```

**Minimum required settings:**

```bash
# System Settings
MAX_PROFILES=10
BASE_IP=172.20.1
SSH_PORT_START=2200
SSH_PORT_END=2299

# Telegram Notifications (optional but recommended)
TELEGRAM_BOT_TOKEN="your_bot_token_here"
TELEGRAM_CHAT_ID="your_chat_id_here"

# SSL Settings
ACME_EMAIL="your-email@example.com"

# Backup Settings
BACKUP_METHOD="local"  # or "s3" or "rclone"
```

Save and exit: `Ctrl+X`, then `Y`, then `Enter`

### Step 4: Start Using

```bash
# Run the manager
vpsadmin
```

You should see the main dashboard! 🎉

---

## Manual Installation

If you prefer manual installation or the script fails:

### 1. Install Dependencies

```bash
# Update package list
apt-get update

# Install required packages
apt-get install -y \
    curl \
    wget \
    git \
    jq \
    bc \
    nginx \
    docker.io \
    docker-compose \
    ca-certificates \
    unzip

# Enable and start Docker
systemctl enable docker
systemctl start docker
```

### 2. Create Directory Structure

```bash
# Create installation directory
mkdir -p /etc/xray-multi/{scripts,docker,nginx,profiles,logs,docs}
mkdir -p /var/backups/xray-multi
mkdir -p /var/log/xray-multi
```

### 3. Copy Files

```bash
# Clone repository
git clone https://github.com/kaccang/xray-multiprofile.git /tmp/xray-multiprofile

# Copy files to installation directory
cp -r /tmp/xray-multiprofile/scripts/* /etc/xray-multi/scripts/
cp -r /tmp/xray-multiprofile/docker/* /etc/xray-multi/docker/
cp -r /tmp/xray-multiprofile/nginx/* /etc/xray-multi/nginx/
cp -r /tmp/xray-multiprofile/profile-scripts /etc/xray-multi/
```

### 4. Set Permissions

```bash
# Make scripts executable
chmod +x /etc/xray-multi/scripts/*.sh
chmod +x /etc/xray-multi/scripts/vpsadmin
chmod +x /etc/xray-multi/docker/entrypoint.sh
chmod +x /etc/xray-multi/profile-scripts/*.sh
```

### 5. Create Configuration

```bash
# Copy environment template
cp /tmp/xray-multiprofile/.env.example /etc/xray-multi/.env

# Edit configuration
nano /etc/xray-multi/.env
```

### 6. Initialize Profiles Database

```bash
# Create profiles.json
cat > /etc/xray-multi/profiles.json << 'EOF'
{
  "version": "1.0",
  "created": "",
  "profiles": []
}
EOF

# Set creation timestamp
sed -i "s|\"created\": \"\"|\"created\": \"$(date -Iseconds)\"|" /etc/xray-multi/profiles.json
```

### 7. Build Docker Image

```bash
# Navigate to docker directory
cd /etc/xray-multi/docker

# Build image
docker build -t xray-multiprofile:latest .
```

### 8. Configure Nginx

```bash
# Copy Nginx configuration
cp /etc/xray-multi/nginx/nginx.conf /etc/nginx/nginx.conf
cp /etc/xray-multi/nginx/ssl-params.conf /etc/nginx/snippets/ssl-params.conf

# Create sites directory
mkdir -p /etc/nginx/sites-enabled

# Test configuration
nginx -t

# Reload Nginx
systemctl reload nginx
```

### 9. Create Command Symlink

```bash
# Create vpsadmin command
ln -sf /etc/xray-multi/scripts/vpsadmin /usr/local/bin/vpsadmin

# Verify
which vpsadmin
```

---

## Post-Installation Setup

### 1. Configure Telegram Notifications (Recommended)

Get alerts for profile expirations, bandwidth limits, and backups.

**Step 1: Create Telegram Bot**

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow instructions to create bot
4. Copy the **Bot Token** (looks like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

**Step 2: Get Chat ID**

1. Search for `@userinfobot` on Telegram
2. Start the bot
3. Copy your **Chat ID** (looks like: `123456789`)

**Step 3: Update Configuration**

```bash
nano /etc/xray-multi/.env
```

Add your credentials:

```bash
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="123456789"
```

**Step 4: Test Notification**

```bash
# Run vpsadmin
vpsadmin

# Navigate to: System Settings → Configure Telegram Alerts
# Send test message
```

### 2. Configure Backup Method

Choose your backup storage:

#### Option A: Local Backup (Default)

```bash
BACKUP_METHOD="local"
BACKUP_RETENTION_DAYS=30
```

Backups stored in: `/var/backups/xray-multi/`

#### Option B: AWS S3 Backup

```bash
BACKUP_METHOD="s3"

S3_ACCESS_KEY="your_access_key"
S3_SECRET_KEY="your_secret_key"
S3_BUCKET="your-bucket-name"
S3_REGION="us-east-1"
S3_PREFIX="backups"
```

Or configure via vpsadmin:
```
System Settings → Configure S3 Backup
```

#### Option C: Rclone Backup (Google Drive, Dropbox, etc.)

```bash
BACKUP_METHOD="rclone"

RCLONE_REMOTE="gdrive"
RCLONE_PATH="VPN-Backups"
```

Configure via vpsadmin:
```
System Settings → Configure rclone Backup
```

### 3. Configure Firewall

Allow required ports:

```bash
# Using UFW (Ubuntu/Debian)
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 2200:2299/tcp  # SSH profiles
ufw allow 22/tcp    # Main SSH (if different)
ufw enable

# Using iptables
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 2200:2299 -j ACCEPT
iptables-save > /etc/iptables/rules.v4
```

### 4. Set Up Automatic Backups (Optional)

```bash
# Create cron job for daily backups at 2 AM
crontab -e
```

Add this line:

```cron
0 2 * * * /etc/xray-multi/scripts/backup-manager.sh global >> /var/log/xray-multi/cron-backup.log 2>&1
```

### 5. Set Up Health Monitoring (Optional)

```bash
# Check health every hour
crontab -e
```

Add this line:

```cron
0 * * * * /etc/xray-multi/scripts/health-check.sh monitor >> /var/log/xray-multi/health-check.log 2>&1
```

---

## Verification

### Check Installation

```bash
# 1. Check if vpsadmin command exists
which vpsadmin
# Should output: /usr/local/bin/vpsadmin

# 2. Check Docker installation
docker --version
# Should show Docker version 20.10.x or higher

# 3. Check if Docker image is built
docker images | grep xray-multiprofile
# Should show: xray-multiprofile   latest   ...

# 4. Check Nginx status
systemctl status nginx
# Should show: active (running)

# 5. Check directory structure
ls -la /etc/xray-multi/
# Should show: scripts, docker, nginx, profiles, logs, docs

# 6. Check configuration file
cat /etc/xray-multi/.env
# Should show your configuration
```

### Test the Manager

```bash
# Run vpsadmin
vpsadmin
```

You should see:

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║      VPN MULTI-PROFILE MANAGER                               ║
║      github.com/kaccang/xray-multiprofile                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────┐
│ SYSTEM RESOURCES                                                │
├─────────────────────────────────────────────────────────────────┤
│ CPU Usage       :  ...
```

If you see this dashboard, installation is successful! ✅

---

## Troubleshooting

### Issue 1: "vpsadmin: command not found"

**Solution:**

```bash
# Check if symlink exists
ls -la /usr/local/bin/vpsadmin

# If not, create it
ln -sf /etc/xray-multi/scripts/vpsadmin /usr/local/bin/vpsadmin

# Reload shell
hash -r

# Or add to PATH
echo 'export PATH="/etc/xray-multi/scripts:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue 2: "Docker: command not found"

**Solution:**

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Start Docker
systemctl enable docker
systemctl start docker

# Verify
docker --version
```

### Issue 3: ".env file not found"

**Solution:**

```bash
# Check if .env.example exists
ls -la /etc/xray-multi/.env.example

# Copy template
cp /etc/xray-multi/.env.example /etc/xray-multi/.env

# Edit configuration
nano /etc/xray-multi/.env
```

### Issue 4: Nginx fails to start

**Solution:**

```bash
# Check nginx configuration
nginx -t

# Check if port 80/443 is already in use
netstat -tulpn | grep :80
netstat -tulpn | grep :443

# Stop conflicting service (e.g., Apache)
systemctl stop apache2
systemctl disable apache2

# Start Nginx
systemctl start nginx
```

### Issue 5: Docker image build fails

**Solution:**

```bash
# Check Docker service
systemctl status docker

# Rebuild with verbose output
cd /etc/xray-multi/docker
docker build -t xray-multiprofile:latest . --no-cache

# Check for errors in Dockerfile
cat /etc/xray-multi/docker/Dockerfile
```

### Issue 6: Permission denied errors

**Solution:**

```bash
# Fix ownership
chown -R root:root /etc/xray-multi

# Fix permissions
chmod +x /etc/xray-multi/scripts/*.sh
chmod +x /etc/xray-multi/scripts/vpsadmin
chmod +x /etc/xray-multi/docker/entrypoint.sh
chmod +x /etc/xray-multi/profile-scripts/*.sh

# Fix log directory
chmod 755 /var/log/xray-multi
chmod 755 /var/backups/xray-multi
```

### Issue 7: Cannot connect to Docker daemon

**Solution:**

```bash
# Start Docker service
systemctl start docker

# Enable Docker on boot
systemctl enable docker

# Add user to docker group (optional)
usermod -aG docker $USER

# Reboot if needed
reboot
```

### Issue 8: Ports already in use

**Solution:**

```bash
# Check what's using port 80
lsof -i :80

# Check what's using port 443
lsof -i :443

# Kill the process or change SSH_PORT_START in .env
nano /etc/xray-multi/.env
# Change SSH_PORT_START to a different range (e.g., 3200)
```

---

## Getting Help

If you encounter issues not covered here:

1. **Check Logs:**
   ```bash
   # View installation log
   tail -f /var/log/xray-multi/setup.log

   # View vpsadmin log
   tail -f /var/log/xray-multi/vpsadmin.log
   ```

2. **Review Documentation:**
   - [Usage Guide](USAGE.md)
   - [GitHub Issues](https://github.com/kaccang/xray-multiprofile/issues)

3. **Report Bug:**
   - Open an issue on GitHub with:
     - OS version: `cat /etc/os-release`
     - Docker version: `docker --version`
     - Error messages from logs

---

## Next Steps

✅ Installation complete!

Now you can:

1. **Read the [Usage Guide](USAGE.md)** to learn how to:
   - Create your first VPN profile
   - Manage profiles
   - Configure backups
   - Monitor system health

2. **Create your first profile:**
   ```bash
   vpsadmin
   # Select: 2) Create New Profile
   ```

3. **Set up monitoring and backups** as described in Post-Installation Setup

---

**🚀 Happy managing!**

For questions or support, visit: https://github.com/kaccang/xray-multiprofile
