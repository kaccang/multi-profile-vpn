#!/bin/bash

# VPN Multi-Profile Manager - Container Entrypoint
# This script runs when the container starts

set -e

echo "===================================="
echo "VPN Profile Container Starting..."
echo "===================================="
echo ""

# Get environment variables
PROFILE_NAME=${PROFILE_NAME:-unknown}
DOMAIN=${DOMAIN:-localhost}
SSH_PORT=${SSH_PORT:-22}
ROOT_PASSWORD=${ROOT_PASSWORD:-changeme}

echo "Profile: $PROFILE_NAME"
echo "Domain: $DOMAIN"
echo "SSH Port: $SSH_PORT"
echo ""

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Create Xray config if it doesn't exist
if [ ! -f /etc/xray/config.json ]; then
    echo "Warning: Xray config.json not found at /etc/xray/config.json"
    echo "Creating minimal config..."
    cat > /etc/xray/config.json << 'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
fi

# Test Xray configuration
echo "Testing Xray configuration..."
if xray run -test -config /etc/xray/config.json; then
    echo "✓ Xray configuration is valid"
else
    echo "✗ Xray configuration is invalid!"
    echo "Container will start but Xray may not work properly."
fi

# Initialize vnstat if needed
if [ ! -d /var/lib/vnstat ]; then
    echo "Initializing vnstat..."
    mkdir -p /var/lib/vnstat
    # vnstatd will auto-create database on first run
fi

# Create log directories
mkdir -p /var/log/xray
mkdir -p /var/log/supervisor

# Set permissions
chmod 600 /root/.ssh/* 2>/dev/null || true

echo ""
echo "===================================="
echo "Container initialized successfully!"
echo "===================================="
echo ""
echo "Services starting:"
echo "  - SSH Server (port $SSH_PORT)"
echo "  - Xray VPN Core"
echo "  - vnstat (bandwidth monitor)"
echo ""

# Execute the main command
exec "$@"
