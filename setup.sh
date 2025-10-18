#!/bin/bash

# ============================================
# VPN Multi-Profile Manager - Setup Script
# ============================================

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/etc/xray-multi"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "${CYAN}►${NC} $@"
}

print_success() {
    echo -e "${GREEN}✔${NC} $@"
}

print_error() {
    echo -e "${RED}✖${NC} $@"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $@"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}      ${GREEN}VPN MULTI-PROFILE MANAGER - SETUP${NC}                   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}      ${YELLOW}github.com/kaccang/xray-multiprofile${NC}            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check OS
print_step "Checking OS compatibility..."
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]]; then
        print_warning "This script is designed for Ubuntu/Debian"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    print_success "OS: $PRETTY_NAME"
else
    print_error "Unable to detect OS"
    exit 1
fi

# Update package list
print_step "Updating package list..."
apt-get update -qq

# Install dependencies
print_step "Installing dependencies..."
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
    unzip \
    > /dev/null 2>&1

print_success "Dependencies installed"

# Start Docker
print_step "Starting Docker service..."
systemctl enable docker > /dev/null 2>&1
systemctl start docker
print_success "Docker is running"

# Create directory structure
print_step "Creating directory structure..."
mkdir -p "${INSTALL_DIR}"/{scripts,docker,nginx,profiles,logs,docs}
mkdir -p /var/backups/xray-multi
mkdir -p /var/log/xray-multi
print_success "Directories created"

# Copy files
print_step "Copying files..."
cp -r "${REPO_DIR}/scripts"/* "${INSTALL_DIR}/scripts/"
cp -r "${REPO_DIR}/docker"/* "${INSTALL_DIR}/docker/"
cp -r "${REPO_DIR}/nginx"/* "${INSTALL_DIR}/nginx/"
cp -r "${REPO_DIR}/profile-scripts" "${INSTALL_DIR}/"
print_success "Files copied"

# Set permissions
print_step "Setting permissions..."
chmod +x "${INSTALL_DIR}/scripts"/*.sh
chmod +x "${INSTALL_DIR}/scripts/vpsadmin"
chmod +x "${INSTALL_DIR}/docker/entrypoint.sh"
chmod +x "${INSTALL_DIR}/profile-scripts"/*.sh
print_success "Permissions set"

# Create .env if not exists
if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
    print_step "Creating .env configuration..."
    if [[ -f "${REPO_DIR}/.env.example" ]]; then
        cp "${REPO_DIR}/.env.example" "${INSTALL_DIR}/.env"
        print_success ".env created from template"
        print_warning "Please edit ${INSTALL_DIR}/.env with your settings"
    else
        print_error ".env.example not found"
    fi
fi

# Initialize profiles.json
if [[ ! -f "${INSTALL_DIR}/profiles.json" ]]; then
    print_step "Initializing profiles.json..."
    cat > "${INSTALL_DIR}/profiles.json" << 'JSONEOF'
{
  "version": "1.0",
  "created": "",
  "profiles": []
}
JSONEOF
    sed -i "s|\"created\": \"\"|\"created\": \"$(date -Iseconds)\"|" "${INSTALL_DIR}/profiles.json"
    print_success "profiles.json initialized"
fi

# Create symlink for vpsadmin
print_step "Creating vpsadmin command..."
ln -sf "${INSTALL_DIR}/scripts/vpsadmin" /usr/local/bin/vpsadmin
print_success "Command 'vpsadmin' is now available"

# Build Docker image
print_step "Building Docker image..."
cd "${INSTALL_DIR}/docker"
docker build -t xray-multiprofile:latest . > /dev/null 2>&1
print_success "Docker image built"

# Setup Nginx
print_step "Configuring Nginx..."
cp "${INSTALL_DIR}/nginx/nginx.conf" /etc/nginx/nginx.conf
cp "${INSTALL_DIR}/nginx/ssl-params.conf" /etc/nginx/snippets/ssl-params.conf
mkdir -p /etc/nginx/sites-enabled
nginx -t > /dev/null 2>&1 && systemctl reload nginx
print_success "Nginx configured"

# Create initial documentation
print_step "Creating documentation..."
cat > "${INSTALL_DIR}/docs/history.md" << 'HISTEOF'
# VPN Multi-Profile Manager - History Log

This file tracks all major actions performed through the system.

---
HISTEOF
print_success "Documentation initialized"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}      ${GREEN}✓ INSTALLATION COMPLETED SUCCESSFULLY!${NC}               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Edit configuration: ${CYAN}nano ${INSTALL_DIR}/.env${NC}"
echo -e "  2. Run the manager: ${CYAN}vpsadmin${NC}"
echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo -e "  • Installation Guide: ${CYAN}https://github.com/kaccang/xray-multiprofile#installation${NC}"
echo -e "  • Usage Guide: ${CYAN}https://github.com/kaccang/xray-multiprofile#usage${NC}"
echo ""
echo -e "${GREEN}Happy managing! 🚀${NC}"
echo ""
