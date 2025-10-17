#!/bin/bash

# ============================================
# Auto-Delete Expired VPN Accounts
# Run this script daily via cron
# ============================================

source /etc/xray-multi/scripts/colors.sh

LOG_FILE="/var/log/xray/xp.log"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Check if running in interactive mode
if [[ -t 0 ]]; then
    INTERACTIVE=true
    clear
    print_banner

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${BOLD}DELETE EXPIRED VPN ACCOUNTS${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
else
    INTERACTIVE=false
fi

# Check if users directory exists
if [[ ! -d /etc/xray/users ]]; then
    if [[ "$INTERACTIVE" == "true" ]]; then
        print_error "No users directory found"
    fi
    log "No users directory found"
    exit 1
fi

# Get current timestamp
now_epoch=$(date +%s)

# Find expired users
expired_count=0
deleted_users=""

for user_file in /etc/xray/users/*.json; do
    if [[ ! -f "$user_file" ]]; then
        continue
    fi

    username=$(jq -r '.username' "$user_file")
    protocol=$(jq -r '.protocol' "$user_file")
    expired=$(jq -r '.expired' "$user_file")
    expired_epoch=$(jq -r '.expired_epoch' "$user_file")

    # Check if expired
    if (( expired_epoch < now_epoch )); then
        if [[ "$INTERACTIVE" == "true" ]]; then
            echo -e "${YELLOW}►${NC} Deleting expired user: ${RED}$username${NC} ($protocol) - Expired: $expired"
        fi

        log "Deleting expired user: $username ($protocol) - Expired: $expired"

        # Remove from Xray config
        python3 << EOF
import json

config_file = '/etc/xray/config.json'

with open(config_file, 'r') as f:
    config = json.load(f)

# Find and remove user from inbounds
for inbound in config['inbounds']:
    if 'clients' in inbound.get('settings', {}):
        clients = inbound['settings']['clients']
        inbound['settings']['clients'] = [
            c for c in clients
            if c.get('email') != '${username}@${protocol}'
        ]

# Save config
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
EOF

        # Remove user file
        rm -f "$user_file"

        expired_count=$((expired_count + 1))
        deleted_users="${deleted_users}\n- ${username} (${protocol})"
    fi
done

# Restart Xray if any users were deleted
if (( expired_count > 0 )); then
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}Restarting Xray...${NC}"
    fi

    supervisorctl restart xray > /dev/null 2>&1

    log "Deleted $expired_count expired users, Xray restarted"

    # Send Telegram notification (only if running from cron)
    if [[ "$INTERACTIVE" == "false" ]]; then
        PROFILE_NAME=$(cat /etc/hostname)
        source /etc/xray-multi/scripts/utils.sh
        load_env
        send_telegram "🗑️ *Expired Accounts Deleted*\nProfile: $PROFILE_NAME\nDeleted: $expired_count users$deleted_users"
    fi

    if [[ "$INTERACTIVE" == "true" ]]; then
        echo ""
        print_success "Deleted $expired_count expired accounts"
        echo ""
    fi
else
    if [[ "$INTERACTIVE" == "true" ]]; then
        print_info "No expired accounts found"
        echo ""
    fi

    log "No expired accounts found"
fi

if [[ "$INTERACTIVE" == "true" ]]; then
    read -n 1 -s -r -p "Press any key to continue..."
fi
