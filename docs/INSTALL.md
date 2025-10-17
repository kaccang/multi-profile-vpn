# 📦 Installation Guide

**VPN Multi-Profile Manager**

Transform your VPS into multiple isolated VPN profiles with dedicated resources.

---

## 📋 Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 22.04 / Debian 11 | Ubuntu 22.04 LTS |
| RAM | 2GB | 4GB+ |
| CPU | 2 cores | 4 cores+ |
| Disk | 20GB SSD | 50GB+ SSD |
| Network | 100 Mbps | 1 Gbps |

### Required Access
- Root access to VPS
- Clean installation (recommended)
- Domain with DNS access
- Port 80 & 443 available

### Optional
- Telegram Bot (for notifications)
- AWS S3 account (for backup)
- rclone remote (Google Drive, uloz.to, etc.)

---

## 🚀 Quick Installation

### Step 1: Download Installer

```bash
curl -fsSL https://raw.githubusercontent.com/kaccang/xray-multiprofile/main/setup.sh -o setup.sh
```

### Step 2: Make Executable

```bash
chmod +x setup.sh
```

### Step 3: Run Installer

```bash
sudo ./setup.sh
```

The installer will:
1. ✅ Check OS compatibility
2. ✅ Install Docker & Docker Compose
3. ✅ Install dependencies (curl, wget, jq, etc.)
4. ✅ Install latest rclone (with uloz.to support)
5. ✅ Configure SSH ports (4444, 4455)
6. ✅ Setup firewall (UFW)
7. ✅ Create directory structure
8. ✅ Download scripts from GitHub
9. ✅ Install acme.sh for SSL
10. ✅ Setup Nginx reverse proxy
11. ✅ Create systemd services
12. ✅ Generate documentation

### Step 4: Configure Environment

After installation, edit `.env` file:

```bash
nano /etc/xray-multi/.env
```

**Required Settings**:
```env
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

**Optional Settings**:
```env
# AWS S3 Backup
AWS_ACCESS_KEY_ID="your-key"
AWS_SECRET_ACCESS_KEY="your-secret"
AWS_BUCKET_NAME="your-bucket"

# rclone Backup
RCLONE_REMOTE="gdrive"
RCLONE_BACKUP_PATH="VPN-Backups"
```

### Step 5: Reconnect SSH

The installer changes SSH ports for security:

```bash
# From another terminal
ssh root@your-vps-ip -p 4444
```

Or:

```bash
ssh root@your-vps-ip -p 4455
```

**Note**: Original port 22 will be disabled after first successful connection to new ports.

---

## 🎮 Post-Installation

### Launch VPSAdmin Menu

After SSH reconnection, VPSAdmin menu appears automatically.

Or manually run:

```bash
vpsadmin
```

### Create First Profile

1. From main menu, select: `2) Create New Profile`
2. Enter profile details:
   - Name: client1
   - Domain: vpn1.yourdomain.com
   - CPU: 150 (1.5 cores)
   - RAM: 2048 (2GB)
   - SSH Port: [auto] or custom
   - Password: [auto] or custom
   - Expired: 30 (days)
   - Bandwidth: 2 (TB/month)
   - Paths: [default] or custom
3. Confirm creation
4. Wait for SSL certificate (1-2 minutes)

### DNS Configuration

Before creating profile, point your domain to VPS:

```bash
# A record
vpn1.yourdomain.com → your-vps-ip
```

**Verify DNS**:
```bash
dig +short vpn1.yourdomain.com
# Should return your VPS IP
```

---

## 🔧 Configuration Guide

### SSH Access to Profile

After profile creation, access it via:

```bash
ssh root@your-vps-ip -p 2201
```

Or from main VPS:

```bash
vpsadmin
# Select: 4) Access Profile (SSH)
# Choose profile
```

### Create VPN Account

Inside profile:

```bash
# VMess
1) Create VMess Account

# VLess
2) Create VLess Account

# Trojan
3) Create Trojan Account
```

### Telegram Notifications

Get bot token from [@BotFather](https://t.me/BotFather):

1. Create bot: `/newbot`
2. Get token: `123456:ABC-DEF...`
3. Get chat ID: `/start` to [@userinfobot](https://t.me/userinfobot)
4. Update `.env` file

Test:
```bash
vpsadmin
# Select: 12) System Settings
# Select: 2) Configure Telegram Alerts
# Send test message
```

### S3 Backup Setup

1. Create S3 bucket
2. Create IAM user with S3 access
3. Generate access keys
4. Update `.env` file

Test:
```bash
vpsadmin
# Select: 10) Global Backup
```

### rclone Backup Setup

```bash
vpsadmin
# Select: 12) System Settings
# Select: 4) Configure rclone Backup
# Follow rclone config wizard
```

Supported remotes:
- Google Drive
- Uloz.to
- Proton Drive
- Dropbox
- OneDrive
- 40+ more

---

## 🔒 Security Recommendations

### 1. Change Default Settings

```bash
# Update .env
nano /etc/xray-multi/.env

# Change ports range if needed
SSH_PORT_START=2200
SSH_PORT_END=2333
```

### 2. Enable Fail2Ban

```bash
# Already installed, configure if needed
nano /etc/fail2ban/jail.local
systemctl restart fail2ban
```

### 3. Firewall Rules

```bash
# View current rules
ufw status verbose

# Add custom rules if needed
ufw allow from TRUSTED_IP to any port 4444
```

### 4. SSL Certificate

Certificates auto-renew every 60 days. Monitor:

```bash
vpsadmin
# Select: 13) View Logs
# Select: 2) SSL Manager Log
```

### 5. Regular Backups

Enable auto-backup:

```bash
# Edit crontab
crontab -e

# Add daily backup (already configured)
0 2 * * * /etc/xray-multi/scripts/backup-manager.sh global
```

---

## 🐛 Troubleshooting

### Installation Failed

```bash
# Check logs
tail -f /var/log/install.log

# Retry installation
rm -rf /etc/xray-multi
./setup.sh
```

### Cannot Connect SSH

```bash
# Check SSH service
systemctl status sshd

# Check ports
ss -tuln | grep -E '4444|4455'

# Check firewall
ufw status
```

### Docker Issues

```bash
# Check Docker status
systemctl status docker

# View containers
docker ps -a

# Restart Docker
systemctl restart docker
```

### SSL Certificate Failed

```bash
# Check domain DNS
dig +short yourdomain.com

# Check acme.sh logs
cat ~/.acme.sh/acme.sh.log

# Manual certificate request
/etc/xray-multi/scripts/ssl-manager.sh request yourdomain.com
```

### Profile Not Starting

```bash
# Check Docker logs
docker logs profile-yourname

# Check Xray config
docker exec profile-yourname xray run -test -config /etc/xray/config.json

# Restart profile
docker restart profile-yourname
```

---

## 📖 Next Steps

1. [Read Progress](progress.md) - Current feature status
2. [View History](history.md) - Change log
3. [Check README](../README.md) - Project overview

---

## 🆘 Support

- **Issues**: GitHub Issues (private repo)
- **Telegram**: [@your-admin](https://t.me/your-admin)
- **Email**: admin@yourdomain.com

---

## 📝 Notes

- First installation takes 5-10 minutes
- DNS propagation may take up to 24 hours
- SSL certificate issuance: 1-2 minutes per domain
- Recommended: Test on sandbox VPS first

---

**Installation guide version**: 1.0
**Last updated**: 2025-01-17
**Compatible with**: Ubuntu 22.04+, Debian 11+
