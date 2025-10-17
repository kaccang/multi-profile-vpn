#!/bin/bash

# ============================================
# VPN Multi-Profile Manager - Installer
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Base directory
BASE_DIR="/etc/xray-multi"
REPO_URL="https://github.com/kaccang/xray-multiprofile"
RAW_URL="https://raw.githubusercontent.com/kaccang/xray-multiprofile/main"

# ============================================
# Helper Functions
# ============================================

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}VPN Multi-Profile Manager - Installer${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}github.com/kaccang/xray-multiprofile${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}►${NC} $1"
}

print_success() {
    echo -e "${GREEN}✔${NC} $1"
}

print_error() {
    echo -e "${RED}✖${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check OS compatibility
check_os() {
    print_step "Checking OS compatibility..."

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID

        if [[ "$OS" == "ubuntu" ]]; then
            if [[ "${VER%%.*}" -lt 20 ]]; then
                print_error "Ubuntu 20.04 or higher is required"
                exit 1
            fi
            print_success "OS: Ubuntu $VER"
        elif [[ "$OS" == "debian" ]]; then
            if [[ "${VER%%.*}" -lt 11 ]]; then
                print_error "Debian 11 or higher is required"
                exit 1
            fi
            print_success "OS: Debian $VER"
        else
            print_error "Only Ubuntu 20.04+ and Debian 11+ are supported"
            exit 1
        fi
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

# Check if already installed
check_existing() {
    if [[ -d "$BASE_DIR" ]]; then
        print_info "Existing installation detected at $BASE_DIR"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
        print_step "Backing up existing installation..."
        mv "$BASE_DIR" "${BASE_DIR}.backup.$(date +%s)"
        print_success "Backup created"
    fi
}

# Install Docker
install_docker() {
    print_step "Installing Docker..."

    if command -v docker &> /dev/null; then
        print_success "Docker already installed: $(docker --version)"
        return
    fi

    # Install Docker
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    # Install Docker Compose
    DOCKER_COMPOSE_VERSION="2.24.0"
    curl -SL "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Start Docker
    systemctl enable docker
    systemctl start docker

    print_success "Docker installed: $(docker --version)"
    print_success "Docker Compose installed: $(docker-compose --version)"
}

# Install dependencies
install_dependencies() {
    print_step "Installing dependencies..."

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        wget \
        git \
        jq \
        bc \
        net-tools \
        dnsutils \
        ca-certificates \
        gnupg \
        lsb-release \
        unzip \
        zip \
        p7zip-full \
        htop \
        nano \
        vim \
        openssh-server \
        ufw \
        fail2ban \
        > /dev/null 2>&1

    print_success "Dependencies installed"
}

# Install latest rclone (with uloz.to support)
install_rclone() {
    print_step "Installing latest rclone..."

    # Remove old rclone if exists
    apt-get remove -y rclone > /dev/null 2>&1 || true

    # Install latest from official script
    curl https://rclone.org/install.sh | bash > /dev/null 2>&1

    RCLONE_VER=$(rclone version | head -1 | awk '{print $2}')
    print_success "rclone installed: v${RCLONE_VER}"
}

# Configure SSH ports
configure_ssh() {
    print_step "Configuring SSH ports (4444, 4455)..."

    # Backup original sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    # Remove existing Port lines
    sed -i '/^Port /d' /etc/ssh/sshd_config

    # Add new ports
    sed -i '1i Port 4444' /etc/ssh/sshd_config
    sed -i '2i Port 4455' /etc/ssh/sshd_config

    # Ensure PermitRootLogin is yes
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

    # Restart SSH
    systemctl restart sshd

    print_success "SSH configured on ports 4444 and 4455"
    print_info "Original port 22 is still active (will be disabled after you reconnect)"
}

# Configure firewall
configure_firewall() {
    print_step "Configuring firewall..."

    # Reset UFW
    ufw --force reset > /dev/null 2>&1

    # Default policies
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1

    # Allow SSH ports
    ufw allow 4444/tcp comment 'SSH Primary' > /dev/null 2>&1
    ufw allow 4455/tcp comment 'SSH Secondary' > /dev/null 2>&1

    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP' > /dev/null 2>&1
    ufw allow 443/tcp comment 'HTTPS' > /dev/null 2>&1

    # Allow ACME challenge port
    ufw allow 8080/tcp comment 'ACME Challenge' > /dev/null 2>&1

    # Allow profile SSH ports (2200-2333)
    ufw allow 2200:2333/tcp comment 'Profile SSH' > /dev/null 2>&1

    # Enable UFW
    ufw --force enable > /dev/null 2>&1

    print_success "Firewall configured"
}

# Create directory structure
create_directories() {
    print_step "Creating directory structure..."

    mkdir -p "$BASE_DIR"/{profiles,ssl-manager/{acme.sh,certs,queue},nginx/{sites,logs},backups/{s3,rclone,history},monitoring,scripts,logs,docs,tmp}

    # Create Docker network config
    mkdir -p "$BASE_DIR/docker"

    print_success "Directory structure created"
}

# Download scripts from GitHub
download_scripts() {
    print_step "Downloading scripts from GitHub..."

    cd "$BASE_DIR"

    # Download all scripts
    SCRIPTS=(
        "scripts/vpsadmin"
        "scripts/profile-manager.sh"
        "scripts/ssl-manager.sh"
        "scripts/backup-manager.sh"
        "scripts/health-check.sh"
        "scripts/cron-alternative.sh"
        "scripts/utils.sh"
        "scripts/colors.sh"
    )

    for script in "${SCRIPTS[@]}"; do
        wget -q "${RAW_URL}/${script}" -O "${BASE_DIR}/${script}"
        chmod +x "${BASE_DIR}/${script}"
    done

    # Download Docker files
    wget -q "${RAW_URL}/docker/Dockerfile" -O "${BASE_DIR}/docker/Dockerfile"
    wget -q "${RAW_URL}/docker/docker-compose.base.yml" -O "${BASE_DIR}/docker/docker-compose.yml"
    wget -q "${RAW_URL}/docker/entrypoint.sh" -O "${BASE_DIR}/docker/entrypoint.sh"
    chmod +x "${BASE_DIR}/docker/entrypoint.sh"

    # Download Nginx configs
    wget -q "${RAW_URL}/nginx/nginx.conf" -O "${BASE_DIR}/nginx/nginx.conf"
    wget -q "${RAW_URL}/nginx/ssl-params.conf" -O "${BASE_DIR}/nginx/ssl-params.conf"

    # Download profile scripts
    mkdir -p "${BASE_DIR}/profile-scripts"
    PROFILE_SCRIPTS=(
        "add-vmess.sh"
        "add-vless.sh"
        "add-trojan.sh"
        "del-vpn.sh"
        "renew-vpn.sh"
        "check-vpn.sh"
        "list-users.sh"
        "profile-menu.sh"
    )

    for script in "${PROFILE_SCRIPTS[@]}"; do
        wget -q "${RAW_URL}/profile-scripts/${script}" -O "${BASE_DIR}/profile-scripts/${script}"
        chmod +x "${BASE_DIR}/profile-scripts/${script}"
    done

    print_success "Scripts downloaded"
}

# Create .env file
create_env_file() {
    print_step "Creating .env configuration file..."

    # Download .env.example
    wget -q "${RAW_URL}/.env.example" -O "${BASE_DIR}/.env"

    # Generate random values for security
    RANDOM_SECRET=$(openssl rand -base64 32)

    print_info "Please configure your .env file:"
    print_info "  nano ${BASE_DIR}/.env"
    print_info ""
    print_info "Required: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID"
    print_info "Optional: AWS S3 credentials, rclone remote"

    print_success ".env file created"
}

# Install acme.sh
install_acme() {
    print_step "Installing acme.sh for SSL certificates..."

    cd "${BASE_DIR}/ssl-manager"

    # Download and install acme.sh
    curl https://get.acme.sh | sh -s email=admin@localhost > /dev/null 2>&1

    # Copy to our directory
    cp -r ~/.acme.sh/* "${BASE_DIR}/ssl-manager/acme.sh/"

    # Set default CA to Let's Encrypt
    "${BASE_DIR}/ssl-manager/acme.sh/acme.sh" --set-default-ca --server letsencrypt > /dev/null 2>&1

    print_success "acme.sh installed"
}

# Setup vpsadmin command
setup_vpsadmin() {
    print_step "Setting up vpsadmin command..."

    # Create symlink
    ln -sf "${BASE_DIR}/scripts/vpsadmin" /usr/local/bin/vpsadmin

    # Add to bashrc for auto-start on login
    if ! grep -q "vpsadmin" /root/.bashrc; then
        echo "" >> /root/.bashrc
        echo "# VPN Multi-Profile Manager" >> /root/.bashrc
        echo "if [ -f /usr/local/bin/vpsadmin ]; then" >> /root/.bashrc
        echo "    /usr/local/bin/vpsadmin" >> /root/.bashrc
        echo "fi" >> /root/.bashrc
    fi

    print_success "vpsadmin command installed"
}

# Initialize Nginx
setup_nginx() {
    print_step "Setting up Nginx reverse proxy..."

    # Stop any existing Nginx
    systemctl stop nginx > /dev/null 2>&1 || true

    # Install Nginx if not exists
    if ! command -v nginx &> /dev/null; then
        apt-get install -y nginx > /dev/null 2>&1
    fi

    # Backup original config
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup 2>/dev/null || true

    # Symlink our config
    ln -sf "${BASE_DIR}/nginx/nginx.conf" /etc/nginx/nginx.conf
    ln -sf "${BASE_DIR}/nginx/sites" /etc/nginx/sites-enabled-vpn

    # Test configuration
    nginx -t > /dev/null 2>&1 || print_error "Nginx configuration test failed (will be fixed when profiles are created)"

    # Enable and start
    systemctl enable nginx > /dev/null 2>&1
    systemctl start nginx > /dev/null 2>&1 || true

    print_success "Nginx configured"
}

# Start background services
start_services() {
    print_step "Starting background services..."

    # SSL Manager service
    cat > /etc/systemd/system/vpn-ssl-manager.service << 'EOF'
[Unit]
Description=VPN Multi-Profile SSL Manager
After=network.target

[Service]
Type=simple
ExecStart=/etc/xray-multi/scripts/ssl-manager.sh daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Health Check service
    cat > /etc/systemd/system/vpn-health-check.service << 'EOF'
[Unit]
Description=VPN Multi-Profile Health Check
After=network.target

[Service]
Type=simple
ExecStart=/etc/xray-multi/scripts/health-check.sh daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload

    # Enable services
    systemctl enable vpn-ssl-manager.service > /dev/null 2>&1
    systemctl enable vpn-health-check.service > /dev/null 2>&1

    # Start services
    systemctl start vpn-ssl-manager.service
    systemctl start vpn-health-check.service

    print_success "Background services started"
}

# Create documentation
create_docs() {
    print_step "Creating documentation files..."

    # Download docs from GitHub
    wget -q "${RAW_URL}/docs/INSTALL.md" -O "${BASE_DIR}/docs/INSTALL.md" 2>/dev/null || true
    wget -q "${RAW_URL}/docs/progress.md" -O "${BASE_DIR}/docs/progress.md" 2>/dev/null || true

    # Create empty history.md
    cat > "${BASE_DIR}/docs/history.md" << 'EOF'
# Change History

## Initial Installation - $(date +%Y-%m-%d)

### Action: System Setup
**User**: Initial install
**Changes**:
- Installed VPN Multi-Profile Manager
- Configured SSH ports: 4444, 4455
- Installed Docker and dependencies
- Configured Nginx reverse proxy
- Installed SSL manager
- Setup monitoring and health checks

**Status**: ✅ Success
EOF

    # Create report template
    cat > "${BASE_DIR}/docs/report.md" << 'EOF'
# Testing Report

## Test Date: [TO BE FILLED]

## Environment
- VPS Provider:
- OS:
- RAM:
- CPU:
- Disk:

## Tests Performed
- [ ] Installation
- [ ] Profile creation
- [ ] SSH access to profile
- [ ] VMess account creation
- [ ] VLess account creation
- [ ] Trojan account creation
- [ ] VPN connection test
- [ ] SSL certificate
- [ ] Bandwidth monitoring
- [ ] Expiration check
- [ ] Backup/Restore
- [ ] Telegram notifications

## Issues Found
[TO BE FILLED DURING TESTING]

## Status
[TO BE FILLED]
EOF

    print_success "Documentation created"
}

# Final message
show_completion() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}Installation Completed Successfully!${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT NEXT STEPS:${NC}"
    echo ""
    echo -e "1. Configure your .env file:"
    echo -e "   ${CYAN}nano ${BASE_DIR}/.env${NC}"
    echo ""
    echo -e "2. Reconnect to SSH using new ports:"
    echo -e "   ${CYAN}ssh root@$(hostname -I | awk '{print $1}') -p 4444${NC}"
    echo -e "   ${CYAN}ssh root@$(hostname -I | awk '{print $1}') -p 4455${NC}"
    echo ""
    echo -e "3. After reconnecting, port 22 will be disabled automatically"
    echo ""
    echo -e "4. VPSAdmin menu will appear automatically on login"
    echo -e "   Or run: ${CYAN}vpsadmin${NC}"
    echo ""
    echo -e "${YELLOW}Documentation:${NC}"
    echo -e "  ${BASE_DIR}/docs/INSTALL.md"
    echo -e "  ${BASE_DIR}/docs/progress.md"
    echo ""
    echo -e "${GREEN}Ready to create your first profile!${NC}"
    echo ""
}

# ============================================
# Main Installation
# ============================================

main() {
    clear
    print_header

    check_root
    check_os
    check_existing

    echo ""
    read -p "Continue with installation? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    echo ""
    print_step "Starting installation..."
    echo ""

    install_docker
    install_dependencies
    install_rclone
    configure_ssh
    configure_firewall
    create_directories
    download_scripts
    create_env_file
    install_acme
    setup_nginx
    setup_vpsadmin
    start_services
    create_docs

    show_completion
}

# Run main
main "$@"
