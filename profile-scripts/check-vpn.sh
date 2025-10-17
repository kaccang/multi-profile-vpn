#!/bin/bash

# ============================================
# Check VPN Account Details
# ============================================

source /etc/xray-multi/scripts/colors.sh

clear
print_banner

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                 ${BOLD}CHECK VPN ACCOUNT${NC}                         ${CYAN}║${NC}"
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

    printf "${WHITE}%2d)${NC} %-20s ${CYAN}(%s)${NC}\n" $i "$username" "$protocol"

    user_files[$i]="$user_file"
    i=$((i + 1))
done

echo ""
read -p "$(echo -e ${WHITE}Select user number [0 to cancel]: ${NC})" selection

if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
    print_info "Cancelled"
    exit 0
fi

if [[ ! "${user_files[$selection]}" ]]; then
    print_error "Invalid selection"
    exit 1
fi

# Get profile info
PROFILE_NAME=$(cat /etc/hostname)
DOMAIN=$(grep "DOMAIN=" /etc/profile.d/vpn-env.sh | cut -d= -f2)

selected_file="${user_files[$selection]}"
username=$(jq -r '.username' "$selected_file")
protocol=$(jq -r '.protocol' "$selected_file")
created=$(jq -r '.created' "$selected_file")
expired=$(jq -r '.expired' "$selected_file")
expired_epoch=$(jq -r '.expired_epoch' "$selected_file")

now_epoch=$(date +%s)
days_left=$(( (expired_epoch - now_epoch) / 86400 ))

if (( days_left < 0 )); then
    status="${RED}EXPIRED${NC}"
elif (( days_left <= 5 )); then
    status="${YELLOW}$days_left days left${NC}"
else
    status="${GREEN}$days_left days left${NC}"
fi

# Generate connection link based on protocol
case "$protocol" in
    vmess)
        uuid=$(jq -r '.uuid' "$selected_file")
        vmess_path=$(grep "PATH_VMESS=" /etc/xray/paths.env | cut -d= -f2)

        vmess_json=$(cat << JSON | base64 -w 0
{
  "v": "2",
  "ps": "${username}@${PROFILE_NAME}",
  "add": "${DOMAIN}",
  "port": "443",
  "id": "${uuid}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "${vmess_path}",
  "tls": "tls",
  "sni": "${DOMAIN}"
}
JSON
)
        link="vmess://${vmess_json}"
        id_field="UUID"
        id_value="$uuid"
        ;;
    vless)
        uuid=$(jq -r '.uuid' "$selected_file")
        vless_path=$(grep "PATH_VLESS=" /etc/xray/paths.env | cut -d= -f2)
        link="vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&path=${vless_path}&host=${DOMAIN}&sni=${DOMAIN}#${username}@${PROFILE_NAME}"
        id_field="UUID"
        id_value="$uuid"
        ;;
    trojan)
        password=$(jq -r '.password' "$selected_file")
        trojan_path=$(grep "PATH_TROJAN=" /etc/xray/paths.env | cut -d= -f2)
        link="trojan://${password}@${DOMAIN}:443?type=ws&security=tls&path=${trojan_path}&host=${DOMAIN}&sni=${DOMAIN}#${username}@${PROFILE_NAME}"
        id_field="Password"
        id_value="$password"
        ;;
esac

# Display details
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    ${BOLD}ACCOUNT DETAILS${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${CYAN}║${NC} ${WHITE}Username      :${NC} %-45s ${CYAN}║${NC}\n" "$username"
printf "${CYAN}║${NC} ${WHITE}Protocol      :${NC} %-45s ${CYAN}║${NC}\n" "$protocol"
printf "${CYAN}║${NC} ${WHITE}Domain        :${NC} %-45s ${CYAN}║${NC}\n" "$DOMAIN"
printf "${CYAN}║${NC} ${WHITE}Port          :${NC} %-45s ${CYAN}║${NC}\n" "443"
printf "${CYAN}║${NC} ${WHITE}%-13s :${NC} %-45s ${CYAN}║${NC}\n" "$id_field" "$id_value"
printf "${CYAN}║${NC} ${WHITE}Network       :${NC} %-45s ${CYAN}║${NC}\n" "WebSocket (ws)"
printf "${CYAN}║${NC} ${WHITE}TLS           :${NC} %-45s ${CYAN}║${NC}\n" "Yes"
printf "${CYAN}║${NC} ${WHITE}Created       :${NC} %-45s ${CYAN}║${NC}\n" "$created"
printf "${CYAN}║${NC} ${WHITE}Expired       :${NC} %-45s ${CYAN}║${NC}\n" "$expired"
printf "${CYAN}║${NC} ${WHITE}Status        :${NC} " && echo -e "%-45b ${CYAN}║${NC}" "$status"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Connection Link:${NC}"
echo -e "${CYAN}$link${NC}"
echo ""

read -n 1 -s -r -p "Press any key to continue..."
