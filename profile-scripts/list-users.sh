#!/bin/bash

# ============================================
# List All VPN Users
# ============================================

source /etc/xray-multi/scripts/colors.sh

clear
print_banner

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                 ${BOLD}ACTIVE VPN USERS${NC}                          ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if users exist
if [[ ! -d /etc/xray/users ]] || [[ -z "$(ls -A /etc/xray/users 2>/dev/null)" ]]; then
    print_error "No users found"
    exit 1
fi

# Count users by protocol
vmess_count=$(ls /etc/xray/users/*-vmess.json 2>/dev/null | wc -l)
vless_count=$(ls /etc/xray/users/*-vless.json 2>/dev/null | wc -l)
trojan_count=$(ls /etc/xray/users/*-trojan.json 2>/dev/null | wc -l)
total_count=$((vmess_count + vless_count + trojan_count))

echo -e "${WHITE}Total Users:${NC} ${GREEN}$total_count${NC}"
echo -e "${WHITE}VMess:${NC} $vmess_count | ${WHITE}VLess:${NC} $vless_count | ${WHITE}Trojan:${NC} $trojan_count"
echo ""

# Table header
printf "${CYAN}%-3s %-18s %-10s %-12s %-12s %-15s${NC}\n" "#" "Username" "Protocol" "Created" "Expired" "Status"
echo "─────────────────────────────────────────────────────────────────────"

# List all users
i=1
for user_file in /etc/xray/users/*.json; do
    username=$(jq -r '.username' "$user_file")
    protocol=$(jq -r '.protocol' "$user_file")
    created=$(jq -r '.created' "$user_file")
    expired=$(jq -r '.expired' "$user_file")
    expired_epoch=$(jq -r '.expired_epoch' "$user_file")

    now_epoch=$(date +%s)
    days_left=$(( (expired_epoch - now_epoch) / 86400 ))

    if (( days_left < 0 )); then
        status="${RED}EXPIRED${NC}"
    elif (( days_left <= 5 )); then
        status="${YELLOW}${days_left}d left${NC}"
    else
        status="${GREEN}${days_left}d left${NC}"
    fi

    printf "%-3d %-18s %-10s %-12s %-12s " $i "$username" "$protocol" "$created" "$expired"
    echo -e "$status"

    i=$((i + 1))
done

echo ""
read -n 1 -s -r -p "Press any key to continue..."
