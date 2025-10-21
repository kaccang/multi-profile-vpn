# 🚀 ONE-LINE INSTALLER - Multi-Profile VPN

## Installation (Full Otomatis!)

```bash
curl -fsSL https://raw.githubusercontent.com/kaccang/multi-profile-vpn/main/install.sh | bash
```

**DONE!** User cukup tunggu 5-10 menit, semua terinstall otomatis!

---

## ✨ What Happens Automatically

Installer akan melakukan **10 steps** secara otomatis:

### [1/10] Update System
- Update package repository
- Upgrade existing packages

### [2/10] Install Dependencies
- **Docker** & Docker Compose
- **Nginx** (reverse proxy)
- **UFW** (firewall)
- **Fail2ban** (intrusion prevention)
- **SQLite3** (database)
- **vnstat** (bandwidth monitoring)
- **jq** (JSON processor)
- **qrencode** (QR code generator)
- **bc** (calculator for bandwidth)

### [3/10] Clone Repository
- Download dari GitHub ke `/opt/multi-profile-vpn`
- Set correct permissions

### [4/10] Create Directories
- `/opt/multi-profile-vpn/data` (database)
- `/opt/multi-profile-vpn/backups` (backup files)
- `/opt/multi-profile-vpn/logs` (log files)
- `/etc/vpn-profiles` (profile configs)
- `/var/log/vpn` (VPN logs)

### [5/10] Initialize Database
- Create `profiles` table
- Create `profile_accounts` table
- Create `bandwidth_logs` table
- Create `health_checks` table
- Create `action_history` table

### [6/10] Build Docker Image
- Build `vpn-profile-base:latest`
- Ubuntu 24.04 base
- Xray v25.10.15
- SSH server configured
- Takes 3-5 minutes

### [7/10] Configure System
- Create `/etc/vpn-system.conf`
- Set environment variables
- Make all scripts executable
- Configure paths

### [8/10] Setup Firewall
- Enable UFW
- Allow SSH (port 22)
- Allow HTTP (port 80)
- Allow HTTPS (port 443)
- Allow VPN ports (2200-2333)
- Apply rules

### [9/10] Install Menu System
- Copy `vpn-menu` to `/usr/local/bin`
- Make executable
- Add to `.bashrc` for auto-start
- Configure auto-load on login

### [10/10] Finalize
- Verify installation
- Start menu automatically

**TIDAK ADA** step manual! User hanya tunggu!

---

## 🎨 CLI Semi-GUI Menu

### Main Menu (Auto-start saat login)

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
║
║  1) Create Profile       # Create new VPN profile
║  2) Delete Profile       # Remove existing profile
║  3) List Profiles        # View all profiles
║  4) Extend Days          # Add more days
║  5) Extend Bandwidth     # Add more bandwidth (TB)
║  6) Login Profile        # SSH to profile (no password)
║
║  7) Security Hardening   # Apply security fixes
║  8) Monitoring           # View dashboard
║  9) Backup Management    # Backup/Restore
║
║  0) Exit
║
╚══════════════════════════════════════════════════════════╝

Select option [0-9]: 
```

**Features:**
- ✅ Real-time system info (CPU, RAM, Storage, Profiles)
- ✅ Beautiful colored interface
- ✅ Easy numbered selection
- ✅ Auto-start on SSH login
- ✅ No commands to remember!

### Profile List (Option 3)

Shows detailed info untuk setiap profile:

```
╔══════════════════ PROFILE LIST ══════════════════════════╗

┌────────────────────────────────────────────────────────────┐
NAME            ACCESS              BANDWIDTH           EXPIRES
├────────────────────────────────────────────────────────────┤
premium         123.45.67.89:2200   0.3TB/2.0TB        13 days
standard        123.45.67.89:2201   0.15TB/1.0TB       5 days
trial           123.45.67.89:2202   0.5TB/0.5TB        EXPIRED
└────────────────────────────────────────────────────────────┘
```

**Shows exactly:**
- ✅ Profile name
- ✅ IP:Port untuk SSH access
- ✅ Bandwidth usage (used/quota in TB)
- ✅ Days remaining

**Color coding:**
- 🟢 Green: >7 days remaining
- 🟡 Yellow: 3-7 days remaining
- 🔴 Red: <3 days or expired

### Container Menu (Inside Profile)

Saat login ke profile via option 6, container menu otomatis muncul:

```
╔══════════════════════════════════════════════════════════╗
║           VPN ACCOUNT MANAGEMENT                         ║
╚══════════════════════════════════════════════════════════╝

╔══════════════════ PROFILE INFO ══════════════════════════╗
║  Profile : premium
║  Accounts: 5
║  Xray    : RUNNING
║  SSH     : RUNNING
╚══════════════════════════════════════════════════════════╝

╔══════════════════ MENU ══════════════════════════════════╗
║
║  1) Add Account          # Create new VPN account
║  2) List Accounts        # View all accounts
║  3) Delete Account       # Remove account
║  4) Renew Account        # Extend expiry date
║  5) Show QR Code         # Display QR for scan
║
║  6) Restart Xray         # Restart VPN service
║  7) View Logs            # Check Xray logs
║
║  0) Exit / Logout
║
╚══════════════════════════════════════════════════════════╝

Select option [0-7]: 
```

**NO MORE `./add-vmess`!** Semua via menu CLI Semi-GUI!

---

## 📱 Usage Examples

### 1. Create Profile

Main menu → **1) Create Profile**

```
╔══════════════════ CREATE PROFILE ════════════════════════╗

Profile name: premium
SSH Port [2200]: 2200
Xray Port [443]: 443
Domain (optional): vpn.example.com
CPU Limit (%) [10]: 20
RAM Limit (MB) [512]: 1024
Bandwidth Quota (TB) [1.0]: 2.0
Expiry Days [30]: 30

Creating profile...
✓ Container created
✓ Xray configured
✓ SSH configured
✓ Database updated

Profile 'premium' created successfully!
SSH: 123.45.67.89:2200
```

### 2. List Profiles

Main menu → **3) List Profiles**

Menampilkan semua profile dengan detail lengkap.

### 3. Login to Profile (Passwordless!)

Main menu → **6) Login Profile**

```
╔══════════════════ LOGIN PROFILE ═════════════════════════╗

Available profiles:
  • premium (port: 2200)
  • standard (port: 2201)
  • trial (port: 2202)

Enter profile name: premium
Connecting to premium...
[Automatically SSH to container - NO PASSWORD!]
[Container menu appears automatically]
```

### 4. Add VPN Account

Inside container → **1) Add Account**

```
╔══════════════════ ADD ACCOUNT ═══════════════════════════╗

Username: john

Select Protocol:
  1) VMess
  2) VLess
  3) Trojan

Choice [1-3]: 1
Expiry days [30]: 30

Creating account...
✓ Account created
✓ UUID: 12345678-1234-1234-1234-123456789abc
✓ Configuration updated
✓ Xray restarted

Link: vmess://eyJ2IjoiMiIsInBzIjoiam9obiI...

Press Enter to continue...
```

### 5. Show QR Code

Inside container → **5) Show QR Code**

```
╔══════════════════ QR CODE ═══════════════════════════════╗

Username: john

QR Code for: john

█████████████████████████████████
█████████████████████████████████
████ ▄▄▄▄▄ █▀█ █▄██▀▄ ▄▄▄▄▄ ████
████ █   █ █▀▀▀█ ▀█▀█ █   █ ████
...
█████████████████████████████████

Link: vmess://eyJ2IjoiMiIsInBzIjoiam9obiI...

Scan with v2rayNG/V2RayN/Clash
```

---

## 🔧 Manual Commands (Optional)

Meskipun semua via menu, commands juga tersedia:

```bash
# Manual start menu
vpn-menu

# Or from installation directory
/opt/multi-profile-vpn/scripts/vpn-menu

# Inside container
/root/container-menu
```

---

## 📁 Directory Structure

Setelah instalasi:

```
/opt/multi-profile-vpn/          # Installation directory
├── data/
│   └── app.db                    # SQLite database
├── backups/                      # Auto backups
├── logs/                         # System logs
├── scripts/                      # Management scripts
│   ├── vpn-menu                  # Main CLI Semi-GUI menu
│   ├── profile-create
│   ├── profile-delete
│   ├── profile-extend-expiry
│   ├── profile-extend-bandwidth
│   └── ... (35+ scripts)
├── profile-scripts/              # Container scripts
│   ├── container-menu            # Container CLI Semi-GUI
│   ├── add-vmess.sh
│   ├── add-vless.sh
│   ├── add-trojan.sh
│   ├── list-users.sh
│   └── del-vpn.sh
├── docker/                       # Docker configurations
│   └── Dockerfile
└── install.sh                    # This installer

/etc/vpn-system.conf              # System configuration
/etc/vpn-profiles/                # Profile configs
/var/log/vpn/                     # VPN logs
/usr/local/bin/vpn-menu           # Menu shortcut
/root/.bashrc                     # Auto-start added
```

---

## 🔐 Security Features

Automatically configured:

- ✅ **UFW Firewall** - Only necessary ports open
- ✅ **Fail2ban** - Protection against brute force
- ✅ **SSH Hardening** - Secure SSH configuration
- ✅ **Container Isolation** - Each profile isolated
- ✅ **Resource Limits** - CPU/RAM limits per profile
- ✅ **Bandwidth Monitoring** - Track usage per profile
- ✅ **Auto-backup** - Daily database backups

---

## 📊 System Requirements

**Minimum:**
- Ubuntu 22.04 or 24.04
- 2GB RAM
- 20GB disk space
- 1 CPU core
- Root access

**Recommended:**
- Ubuntu 24.04 LTS
- 4GB+ RAM
- 50GB+ SSD
- 2+ CPU cores
- Clean/fresh VPS

**Supported OS:**
- ✅ Ubuntu 22.04 LTS
- ✅ Ubuntu 24.04 LTS
- ⚠️ Debian 11/12 (should work, not tested)

---

## 🐛 Troubleshooting

### Menu tidak muncul saat login

```bash
# Check if added to .bashrc
grep vpn-menu ~/.bashrc

# Manual add
echo 'vpn-menu 2>/dev/null || true' >> ~/.bashrc

# Or run manually
vpn-menu
```

### Command not found: vpn-menu

```bash
# Check installation
ls -la /usr/local/bin/vpn-menu

# If not found, copy manually
cp /opt/multi-profile-vpn/scripts/vpn-menu /usr/local/bin/
chmod +x /usr/local/bin/vpn-menu
```

### Docker not starting

```bash
# Enable and start Docker
systemctl enable docker
systemctl start docker
systemctl status docker
```

### Database not found

```bash
# Check database
ls -la /opt/multi-profile-vpn/data/app.db

# Reinitialize if needed
sqlite3 /opt/multi-profile-vpn/data/app.db < /opt/multi-profile-vpn/database-schema.sql
```

### Cannot connect to profile

```bash
# Check container status
docker ps -a

# Check SSH port
netstat -tlnp | grep :2200

# Test SSH
ssh -p 2200 root@localhost
```

---

## 🔄 Update System

```bash
cd /opt/multi-profile-vpn
git pull
chmod +x scripts/*
chmod +x profile-scripts/*
```

---

## 🗑️ Uninstall

```bash
# Stop all containers
docker stop $(docker ps -a -q --filter ancestor=vpn-profile-base)
docker rm $(docker ps -a -q --filter ancestor=vpn-profile-base)

# Remove Docker image
docker rmi vpn-profile-base:latest

# Remove installation
rm -rf /opt/multi-profile-vpn
rm -rf /etc/vpn-profiles
rm -f /etc/vpn-system.conf
rm -f /usr/local/bin/vpn-menu

# Remove from .bashrc
sed -i '/vpn-menu/d' ~/.bashrc

# Optional: Remove packages
apt-get remove --purge docker.io nginx ufw fail2ban sqlite3 vnstat
```

---

## 📈 Performance Tips

1. **Use SSD** - Better I/O performance
2. **Enable BBR** - Better network throughput
3. **Monitor resources** - Use option 8 (Monitoring)
4. **Regular backups** - Use option 9 (Backup Management)
5. **Update regularly** - Keep system updated

---

## 🎯 Production Deployment

**Recommended for:**
- ✅ Personal use (1-10 users)
- ✅ Small business (10-50 users)
- ✅ Medium deployment (50-100 users)
- ✅ Medium-large (100-200 users with monitoring)

**Capacity per VPS:**
- 2GB RAM: ~5-10 profiles
- 4GB RAM: ~10-20 profiles
- 8GB RAM: ~20-40 profiles
- 16GB RAM: ~40-80 profiles

---

## 💡 Tips & Tricks

### Auto-start specific profile on login

Edit container's `.bashrc`:
```bash
docker exec -it <container> bash
echo 'container-menu' >> ~/.bashrc
```

### Backup before changes

```bash
vpn-menu → 9) Backup Management → 1) Backup Now
```

### Monitor bandwidth in real-time

```bash
vnstat -l  # Live traffic
vnstat -d  # Daily stats
```

### Check system health

```bash
vpn-menu → 8) Monitoring
```

---

## 📞 Support

- **Repository:** https://github.com/kaccang/multi-profile-vpn
- **Issues:** https://github.com/kaccang/multi-profile-vpn/issues
- **Documentation:** See `/opt/multi-profile-vpn/docs/`

---

## 🎉 Summary

**What you get:**
- ✅ **ONE command** installation
- ✅ **ZERO** manual configuration
- ✅ **Beautiful** CLI Semi-GUI interface
- ✅ **Auto-start** menu on login
- ✅ **Detailed** profile information
- ✅ **Passwordless** SSH between containers
- ✅ **Professional** user experience
- ✅ **Production-ready** out of the box

**Installation time:** 5-10 minutes  
**User interaction:** ZERO  
**Commands to remember:** ZERO  

**Just run:**
```bash
curl -fsSL https://raw.githubusercontent.com/kaccang/multi-profile-vpn/main/install.sh | bash
```

**And wait!** ☕️

---

**ONE COMMAND, FULL SYSTEM!** 🚀
