# 🚀 VPN Multi-Profile Manager

**One VPS, Multiple Isolated VPN Profiles**

Transform a single VPS into multiple isolated VPN environments, similar to how cPanel manages multiple websites. Each profile runs in its own Docker container with dedicated resources, SSH access, and independent configuration.

## ✨ Features

### 🚀 Installation & Interface
- ⚡ **One-Line Installer**: curl | bash - fully automatic installation
- 🎨 **CLI Semi-GUI**: Beautiful colored interface with real-time system info
- 📊 **System Dashboard**: Live CPU, RAM, Storage, and Profile count display
- 🔄 **Auto-Start Menu**: Menu appears automatically on SSH login
- 🎯 **Easy Navigation**: Numbered menu options (1-9, 0) - no commands to remember

### 🔒 Profile Management
- 🏠 **Profile Isolation**: Each profile runs in isolated Docker container
- 🎛️ **Resource Control**: Allocate CPU, RAM, and bandwidth per profile
- 🔐 **SSH Access**: Each profile has SSH access with custom port (2200-2333)
- 📋 **Detailed Lists**: Shows name, IP:port, bandwidth usage (TB), days remaining
- 🔓 **Passwordless Login**: SSH to profiles without password from menu
- 🎨 **Color-Coded Status**: Green/Yellow/Red based on days remaining

### 🌐 VPN Features
- 🌐 **Multi-Protocol**: VMess, VLess, and Trojan support
- 🔄 **Custom Paths**: Configure custom WebSocket paths
- 🔐 **Centralized SSL**: Automatic SSL with Let's Encrypt (queue-based, anti rate-limit)
- 📱 **QR Code Generation**: Easy mobile client setup
- 🎨 **Container Menu**: CLI Semi-GUI inside containers (no manual commands!)

### 📊 Monitoring & Management
- 📊 **Monitoring**: Health checks, bandwidth tracking, expiration alerts
- 💾 **Dual Backup**: S3 + rclone (Google Drive, Uloz.to, etc.)
- 📱 **Telegram Alerts**: Real-time notifications for issues
- 🔒 **Security Hardening**: Built-in security fixes and audits

## 📋 Requirements

- **OS**: Ubuntu 22.04 / Debian 11+ (VPS)
- **RAM**: Minimum 2GB (recommended 4GB+)
- **CPU**: Minimum 2 cores (recommended 4 cores+)
- **Disk**: Minimum 20GB SSD
- **Root Access**: Required
- **Docker**: Will be installed automatically
- **Ports**: 80, 443, 4444, 4455, 2200-2333

## 🚀 Quick Install

**NEW: One-Line Automatic Installer!**

```bash
curl -fsSL https://raw.githubusercontent.com/kaccang/multi-profile-vpn/main/install.sh | bash
```

**That's it!** Just wait 5-10 minutes for automatic installation:
- Auto-installs Docker, Nginx, UFW, Fail2ban, SQLite, vnstat
- Auto-builds Docker base image
- Auto-initializes database
- Auto-configures firewall
- Auto-installs CLI Semi-GUI menu
- Menu auto-starts on login

The beautiful CLI Semi-GUI menu will appear automatically after installation!

## 📖 Documentation

- [Installation Guide](docs/INSTALL.md)
- [Features & Progress](docs/progress.md)
- [Change History](docs/history.md)
- [Project Status](PROJECT_STATUS.md)

## 🎮 Usage Example

### Create New Profile

```
1. SSH to main VPS (port 4444/4455)
2. Select: "2) Create New Profile"
3. Fill in details:
   - Name: asep1
   - Domain: sg1.domain.com
   - CPU: 150 (1.5 cores)
   - RAM: 2048 (2GB)
   - SSH Port: 2201 (auto-assigned)
   - Expired: 30 days
   - Bandwidth: 2TB/month
```

### Access Profile

```bash
# Method 1: From main VPS menu
Select: "4) Access Profile (SSH)"
Choose profile: asep1

# Method 2: Direct SSH
ssh root@your-vps-ip -p 2201
```

### Create VPN Account (inside profile)

```
1. SSH to profile
2. Select: "1) Create VMess Account"
3. Enter username and expiration
4. Get VMess link
```

## 🏗️ Architecture

```
VPS Host (Ubuntu/Debian)
├── Docker Network (172.20.1.0/24)
├── Nginx Reverse Proxy (Port 80/443 shared)
├── SSL Manager (Centralized ACME)
└── Profiles (Docker Containers)
    ├── Profile 1 (172.20.1.2, SSH: 2201)
    ├── Profile 2 (172.20.1.3, SSH: 2202)
    └── Profile N ...
```

## 🔧 Technology Stack

- **Containerization**: Docker + Docker Compose
- **VPN Core**: Xray-core v25.10.15
- **Reverse Proxy**: Nginx with SNI routing
- **SSL**: acme.sh with Let's Encrypt
- **Monitoring**: vnstat + custom scripts
- **Backup**: AWS S3 + rclone
- **Notifications**: Telegram Bot API

## 📊 Resource Allocation Example

| Profile | CPU | RAM | SSH Port | Bandwidth | Status |
|---------|-----|-----|----------|-----------|--------|
| asep1 | 150% | 2GB | 2201 | 2TB/mo | Active |
| client2 | 200% | 4GB | 2202 | 5TB/mo | Active |
| test3 | 50% | 512MB | 2203 | 500GB/mo | Expired |

## ⚙️ Configuration

Edit `.env` file for global settings:

```bash
cd /etc/xray-multi
nano .env
```

## 🔒 Security Features

- SSH port changed from 22 to 4444/4455
- Per-profile SSH isolation
- SSL/TLS encryption (Let's Encrypt)
- Resource limits (prevent resource exhaustion)
- Automatic service stop on expiration/quota exceeded
- Backup encryption (optional)

## 📈 Monitoring

- Health checks every 5 minutes
- Bandwidth monitoring (hourly)
- Expiration checks (daily)
- Telegram notifications for:
  - Profile down/up
  - Bandwidth 90% used
  - Bandwidth quota exceeded
  - Profile expiring (5 days warning)
  - Profile expired

## 💾 Backup & Restore

**Per-Profile Backup:**
```
1. Access profile
2. Select: "9) Backup This Profile"
3. Backup saved to: S3 + rclone remote
```

**Global Backup (All Profiles):**
```
1. Main VPS menu
2. Select: "10) Global Backup"
3. All profiles backed up
```

**Restore Profile:**
```
1. Create new profile
2. Provide restore link during creation
3. Configuration auto-restored
```

## 🤝 Contributing

This is a private project. If you have access and want to contribute:

1. Clone the repository
2. Create feature branch
3. Make changes
4. Submit pull request

## 📝 License

Private/Proprietary - All rights reserved

## 🆘 Support

Contact admin: [@your-telegram](https://t.me/your-username)

## 🎯 Roadmap

See [progress.md](docs/progress.md) for current features and upcoming improvements.

---

**Made with ❤️ for efficient VPS resource utilization**

## 🎨 CLI Semi-GUI Interface

The new CLI Semi-GUI provides a beautiful, user-friendly interface:

### Main Menu
```
╔══════════════════════════════════════════════════════════╗
║           MULTI-PROFILE VPN MANAGEMENT                   ║
╚══════════════════════════════════════════════════════════╝

╔══════════════════ SYSTEM INFO ═══════════════════════════╗
║  CPU      : 17.3% / 400% (4 cores)
║  RAM      : 1266/4096 MB
║  Storage  : 20GB/100GB
║  Profiles : 3 active
╚══════════════════════════════════════════════════════════╝

╔══════════════════ MAIN MENU ═════════════════════════════╗
║  1) Create Profile       # Create new VPN profile
║  2) Delete Profile       # Remove existing profile
║  3) List Profiles        # View all profiles
║  4) Extend Days          # Add more days
║  5) Extend Bandwidth     # Add more bandwidth (TB)
║  6) Login Profile        # SSH to profile (no password)
║  7) Security Hardening   # Apply security fixes
║  8) Monitoring           # View dashboard
║  9) Backup Management    # Backup/Restore
║  0) Exit
╚══════════════════════════════════════════════════════════╝
```

### Profile List
Shows detailed information for each profile:
- Profile name
- IP:Port for SSH access
- Bandwidth usage (e.g., 0.3TB/2.0TB)
- Days remaining (e.g., 13 days)
- Color-coded status (green/yellow/red)

### Container Menu
Inside each profile container, manage VPN accounts via CLI Semi-GUI:
- Add accounts (VMess/VLess/Trojan)
- List all accounts with connection links
- Delete/Renew accounts
- Generate QR codes for mobile
- View logs, restart services

**NO MORE** manual commands like `./add-vmess` - everything via beautiful menu!

