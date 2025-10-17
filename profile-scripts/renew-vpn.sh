#!/bin/bash

# ============================================
# Renew VPN Account
# ============================================

source /etc/xray-multi/scripts/colors.sh

clear
print_banner

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                 ${BOLD}RENEW VPN ACCOUNT${NC}                         ${CYAN}║${NC}"
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
    expired_epoch=$(jq -r '.expired_epoch' "$user_file")

    now_epoch=$(date +%s)
    days_left=$(( (expired_epoch - now_epoch) / 86400 ))

    if (( days_left < 0 )); then
        status="${RED}EXPIRED${NC}"
    elif (( days_left <= 5 )); then
        status="${YELLOW}$days_left days${NC}"
    else
        status="${GREEN}$days_left days${NC}"
    fi

    printf "${WHITE}%2d)${NC} %-20s ${CYAN}%-10s${NC} Exp: %s (%b)\n" $i "$username" "($protocol)" "$expired" "$status"

    user_files[$i]="$user_file"
    i=$((i + 1))
done

echo ""
read -p "$(echo -e ${WHITE}Select user number to renew [0 to cancel]: ${NC})" selection

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
current_expired=$(jq -r '.expired' "$selected_file")

# Input new expiration
echo ""
read -p "$(echo -e ${WHITE}Add days to expiration: ${NC})" add_days

if [[ -z "$add_days" ]] || [[ ! "$add_days" =~ ^[0-9]+$ ]]; then
    print_error "Invalid number of days"
    exit 1
fi

# Calculate new expiration (from current expiration, not now)
new_exp_date=$(date -d "$current_expired + $add_days days" +"%Y-%m-%d")
new_exp_epoch=$(date -d "$new_exp_date" +%s)

# Update user file
jq ".expired = \"$new_exp_date\" | .expired_epoch = $new_exp_epoch" "$selected_file" > "${selected_file}.tmp" && mv "${selected_file}.tmp" "$selected_file"

echo ""
print_success "User $username ($protocol) renewed successfully"
echo ""
echo -e "${WHITE}Previous expiration:${NC} $current_expired"
echo -e "${WHITE}New expiration:${NC}      ${GREEN}$new_exp_date${NC} (+$add_days days)"
echo ""

read -n 1 -s -r -p "Press any key to continue..."
