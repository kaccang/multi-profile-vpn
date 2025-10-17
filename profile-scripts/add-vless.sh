#!/bin/bash

# ============================================
# Add VLess Account
# ============================================

source /etc/xray-multi/scripts/colors.sh

clear
print_banner

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                 ${BOLD}CREATE VLESS ACCOUNT${NC}                      ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get profile info
PROFILE_NAME=$(cat /etc/hostname)
DOMAIN=$(grep "DOMAIN=" /etc/profile.d/vpn-env.sh | cut -d= -f2)

# Input username
read -p "$(echo -e ${WHITE}Username: ${NC})" username

if [[ -z "$username" ]]; then
    print_error "Username cannot be empty"
    exit 1
fi

# Sanitize username
username=$(echo "$username" | sed 's/[^a-zA-Z0-9]//g')

# Check if user exists
if grep -q "\"email\": \"$username@vless\"" /etc/xray/config.json; then
    print_error "User $username already exists"
    exit 1
fi

# Input expiration days
read -p "$(echo -e ${WHITE}Expiration (days): ${NC})" days
if [[ -z "$days" ]]; then
    days=30
fi

exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
exp_epoch=$(date -d "$exp_date" +%s)

# Generate UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

# Get WebSocket path
vless_path=$(grep "PATH_VLESS=" /etc/xray/paths.env | cut -d= -f2)

# Add user to Xray config
python3 << EOF
import json

config_file = '/etc/xray/config.json'

with open(config_file, 'r') as f:
    config = json.load(f)

# Find VLess inbound
for inbound in config['inbounds']:
    if inbound.get('protocol') == 'vless' and inbound.get('port') == 10002:
        if 'clients' not in inbound['settings']:
            inbound['settings']['clients'] = []

        # Add new client
        inbound['settings']['clients'].append({
            'id': '$uuid',
            'email': '${username}@vless',
            'level': 0
        })
        break

# Save config
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print('User added to Xray config')
EOF

# Save user data
mkdir -p /etc/xray/users
cat > /etc/xray/users/${username}-vless.json << EOF
{
  "protocol": "vless",
  "username": "$username",
  "uuid": "$uuid",
  "created": "$(date +%Y-%m-%d)",
  "expired": "$exp_date",
  "expired_epoch": $exp_epoch
}
EOF

# Restart Xray
supervisorctl restart xray > /dev/null 2>&1

# Generate VLess link
vless_link="vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&path=${vless_path}&host=${DOMAIN}&sni=${DOMAIN}#${username}@${PROFILE_NAME}"

# Display result
echo ""
print_success "VLess account created successfully!"
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    ${BOLD}ACCOUNT DETAILS${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${CYAN}║${NC} ${WHITE}Username      :${NC} %-45s ${CYAN}║${NC}\n" "$username"
printf "${CYAN}║${NC} ${WHITE}Protocol      :${NC} %-45s ${CYAN}║${NC}\n" "VLess"
printf "${CYAN}║${NC} ${WHITE}Domain        :${NC} %-45s ${CYAN}║${NC}\n" "$DOMAIN"
printf "${CYAN}║${NC} ${WHITE}Port          :${NC} %-45s ${CYAN}║${NC}\n" "443"
printf "${CYAN}║${NC} ${WHITE}UUID          :${NC} %-45s ${CYAN}║${NC}\n" "$uuid"
printf "${CYAN}║${NC} ${WHITE}Network       :${NC} %-45s ${CYAN}║${NC}\n" "WebSocket (ws)"
printf "${CYAN}║${NC} ${WHITE}Path          :${NC} %-45s ${CYAN}║${NC}\n" "$vless_path"
printf "${CYAN}║${NC} ${WHITE}TLS           :${NC} %-45s ${CYAN}║${NC}\n" "Yes"
printf "${CYAN}║${NC} ${WHITE}Created       :${NC} %-45s ${CYAN}║${NC}\n" "$(date +%Y-%m-%d)"
printf "${CYAN}║${NC} ${WHITE}Expired       :${NC} ${GREEN}%-45s${NC} ${CYAN}║${NC}\n" "$exp_date ($days days)"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}VLess Link:${NC}"
echo -e "${CYAN}$vless_link${NC}"
echo ""
echo -e "${GRAY}Note: Save this link to import in your client${NC}"
echo ""

read -n 1 -s -r -p "Press any key to continue..."
