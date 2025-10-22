#!/bin/bash
# Multi-Profile VPN - One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/kaccang/multi-profile-vpn/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Config
INSTALL_DIR="/opt/multi-profile-vpn"
GITHUB_REPO="https://github.com/kaccang/multi-profile-vpn.git"

clear

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       MULTI-PROFILE VPN - AUTO INSTALLER                ║
║                                                          ║
║       Enterprise-Grade VPN Management System            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}[INFO]${NC} Starting automatic installation..."
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Please run as root: sudo bash install.sh"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}[ERROR]${NC} Cannot detect OS"
    exit 1
fi

echo -e "${GREEN}[✓]${NC} Detected: $OS $VER"

# Update system
echo -e "${YELLOW}[1/10]${NC} Updating system packages..."
apt-get update -qq > /dev/null 2>&1
echo -e "${GREEN}[✓]${NC} System updated"

# Install dependencies
echo -e "${YELLOW}[2/10]${NC} Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl wget git unzip jq sqlite3 \
    docker.io docker-compose \
    nginx ufw fail2ban \
    net-tools vnstat supervisor \
    ca-certificates gnupg lsb-release qrencode bc > /dev/null 2>&1

systemctl enable docker > /dev/null 2>&1
systemctl start docker > /dev/null 2>&1
echo -e "${GREEN}[✓]${NC} Dependencies installed"

# Clone repository
echo -e "${YELLOW}[3/10]${NC} Cloning repository..."
rm -rf "$INSTALL_DIR" 2>/dev/null || true
git clone -q "$GITHUB_REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo -e "${GREEN}[✓]${NC} Repository cloned"

# Create directories
echo -e "${YELLOW}[4/10]${NC} Creating directories..."
mkdir -p "$INSTALL_DIR"/{data,backups,logs}
mkdir -p /etc/vpn-profiles
mkdir -p /var/log/vpn
echo -e "${GREEN}[✓]${NC} Directories created"

# Setup database
echo -e "${YELLOW}[5/10]${NC} Initializing database..."
DB_PATH="$INSTALL_DIR/data/app.db"
sqlite3 "$DB_PATH" << 'EOFSQL'
CREATE TABLE IF NOT EXISTS profiles (
    profile_id TEXT PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    domain TEXT,
    ssh_port INTEGER,
    xray_port INTEGER,
    cpu_percent REAL DEFAULT 10,
    ram_mb INTEGER DEFAULT 512,
    quota_tb REAL DEFAULT 1.0,
    bandwidth_quota_gb REAL DEFAULT 1024.0,
    quota_used_gb REAL DEFAULT 0,
    quota_reset_date TEXT,
    expiry_date TEXT,
    status TEXT DEFAULT 'active',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS profile_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id TEXT NOT NULL,
    username TEXT UNIQUE NOT NULL,
    protocol TEXT,
    uuid TEXT UNIQUE NOT NULL,
    expiry_date TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (profile_id) REFERENCES profiles(profile_id)
);

CREATE TABLE IF NOT EXISTS bandwidth_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id TEXT NOT NULL,
    usage_gb REAL DEFAULT 0,
    logged_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (profile_id) REFERENCES profiles(profile_id)
);

CREATE TABLE IF NOT EXISTS health_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_name TEXT,
    check_type TEXT,
    status TEXT,
    details TEXT,
    checked_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS action_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action_type TEXT,
    details TEXT,
    status TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
EOFSQL
echo -e "${GREEN}[✓]${NC} Database initialized"

# Build Docker image
echo -e "${YELLOW}[6/10]${NC} Building Docker base image (this may take 3-5 minutes)..."
cd "$INSTALL_DIR/docker"
docker build -t vpn-profile-base:latest . > /dev/null 2>&1
echo -e "${GREEN}[✓]${NC} Docker image built"

# Configure system
echo -e "${YELLOW}[7/10]${NC} Configuring system..."

# Create system config
cat > /etc/vpn-system.conf << EOFCONFIG
VPN_HOME=$INSTALL_DIR
DB_PATH=$INSTALL_DIR/data/app.db
PROFILE_DIR=/etc/vpn-profiles
BACKUP_DIR=$INSTALL_DIR/backups
LOG_DIR=/var/log/vpn
EOFCONFIG

# Make scripts executable
chmod +x "$INSTALL_DIR"/scripts/* 2>/dev/null || true
chmod +x "$INSTALL_DIR"/profile-scripts/* 2>/dev/null || true

echo -e "${GREEN}[✓]${NC} System configured"

# Setup firewall
echo -e "${YELLOW}[8/10]${NC} Configuring firewall..."
ufw --force enable > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
ufw allow 2200:2333/tcp > /dev/null 2>&1
ufw --force reload > /dev/null 2>&1
echo -e "${GREEN}[✓]${NC} Firewall configured"

# Install menu system
echo -e "${YELLOW}[9/10]${NC} Installing CLI menu system..."

# Copy menu to /usr/local/bin
cp "$INSTALL_DIR/scripts/vpn-menu" /usr/local/bin/vpn-menu 2>/dev/null || true
chmod +x /usr/local/bin/vpn-menu

# Auto-start menu on login (only if not already added)
if ! grep -q "vpn-menu" /root/.bashrc; then
    cat >> /root/.bashrc << 'EOFBASH'

# Auto-start VPN Menu
if [[ -z "$VPN_MENU_LOADED" ]]; then
    export VPN_MENU_LOADED=1
    vpn-menu 2>/dev/null || true
fi
EOFBASH
fi

echo -e "${GREEN}[✓]${NC} Menu system installed"

# Final setup
echo -e "${YELLOW}[10/10]${NC} Finalizing installation..."
sleep 1
echo -e "${GREEN}[✓]${NC} Installation complete"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              INSTALLATION SUCCESSFUL!                    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓${NC} Installation directory: ${CYAN}$INSTALL_DIR${NC}"
echo -e "${GREEN}✓${NC} Database: ${CYAN}$DB_PATH${NC}"
echo -e "${GREEN}✓${NC} Configuration: ${CYAN}/etc/vpn-system.conf${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Menu will auto-start on next login"
echo -e "  2. Or run manually: ${CYAN}vpn-menu${NC}"
echo ""
echo -e "${MAGENTA}Starting menu now...${NC}"
echo ""
sleep 2

# Start menu
exec bash -c "source /root/.bashrc && vpn-menu"
