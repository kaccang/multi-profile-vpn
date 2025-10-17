#!/bin/bash

# ============================================
# Delete VPN Account
# ============================================

source /etc/xray-multi/scripts/colors.sh

clear
print_banner

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                 ${BOLD}DELETE VPN ACCOUNT${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# List all users
if [[ ! -d /etc/xray/users ]] || [[ -z "$(ls -A /etc/xray/users 2>/dev/null)" ]]; then
    print_error "No users found"
    exit 1
fi

echo -e "${YELLOW}Available users:${NC}"
echo ""

i=1
declare -a user_files
for user_file in /etc/xray/users/*.json; do
    username=$(jq -r '.username' "$user_file")
    protocol=$(jq -r '.protocol' "$user_file")
    expired=$(jq -r '.expired' "$user_file")

    printf "${WHITE}%2d)${NC} %-20s ${CYAN}%-10s${NC} Exp: %s\n" $i "$username" "($protocol)" "$expired"

    user_files[$i]="$user_file"
    i=$((i + 1))
done

echo ""
read -p "$(echo -e ${WHITE}Select user number to delete [0 to cancel]: ${NC})" selection

if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
    print_info "Cancelled"
    exit 0
fi

if [[ ! "${user_files[$selection]}" ]]; then
    print_error "Invalid selection"
    exit 1
fi

selected_file="${user_files[$selection]}"
username=$(jq -r '.username' "$selected_file")
protocol=$(jq -r '.protocol' "$selected_file")

# Confirm deletion
echo ""
read -p "$(echo -e ${RED}Are you sure you want to delete user \"$username\" ($protocol)? [y/N]: ${NC})" -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cancelled"
    exit 0
fi

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

print('User removed from Xray config')
EOF

# Remove user file
rm -f "$selected_file"

# Restart Xray
supervisorctl restart xray > /dev/null 2>&1

echo ""
print_success "User $username ($protocol) deleted successfully"
echo ""

read -n 1 -s -r -p "Press any key to continue..."
