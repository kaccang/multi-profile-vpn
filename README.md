# 🚀 VPN Multi-Profile Manager

**One VPS, Multiple Isolated VPN Profiles**

Transform a single VPS into multiple isolated VPN environments, similar to how cPanel manages multiple websites. Each profile runs in its own Docker container with dedicated resources, SSH access, and independent configuration.

## ✨ Features

- 🔒 **Profile Isolation**: Each profile runs in isolated Docker container
- 🎛️ **Resource Control**: Allocate CPU, RAM, and bandwidth per profile
- 🔐 **SSH Access**: Each profile has SSH access with custom port (2200-2333)
- 🌐 **Multi-Protocol**: VMess, VLess, and Trojan support
- 🔄 **Custom Paths**: Configure custom WebSocket paths (not /vmess, /vless, /trojan)
- 🔐 **Centralized SSL**: Automatic SSL with Let's Encrypt (queue-based, anti rate-limit)
- 📊 **Monitoring**: Health checks, bandwidth tracking, expiration alerts
- 💾 **Dual Backup**: S3 + rclone (Google Drive, Uloz.to, etc.)
- 📱 **Telegram Alerts**: Real-time notifications for issues
- 🎨 **CLI Semi-GUI**: Interactive menu for easy management

## 📋 Requirements

- **OS**: Ubuntu 22.04 / Debian 11+ (VPS)
- **RAM**: Minimum 2GB (recommended 4GB+)
- **CPU**: Minimum 2 cores (recommended 4 cores+)
- **Disk**: Minimum 20GB SSD
- **Root Access**: Required
- **Docker**: Will be installed automatically
- **Ports**: 80, 443, 4444, 4455, 2200-2333

## 🚀 Quick Install

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/kaccang/xray-multiprofile/main/setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

After installation, SSH to your VPS on port **4444** or **4455** (not 22):

```bash
ssh root@your-vps-ip -p 4444
```

The VPS Admin menu will appear automatically.

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
