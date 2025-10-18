#!/bin/bash

# Profile Manager untuk VPN Multi-Profile

set -e

BASE_DIR="/etc/xray-multi"
source "${BASE_DIR}/scripts/colors.sh"
source "${BASE_DIR}/scripts/utils.sh"
load_env

# Create Profile Function
create_profile() {
    clear
    print_banner
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}CREATE NEW PROFILE${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Input Name
    while true; do
        read -p "$(echo -e ${WHITE}Name: ${NC})" profile_name
        profile_name=$(sanitize_input "$profile_name")
        
        if [[ -z "$profile_name" ]]; then
            print_error "Name cannot be empty"
            continue
        fi
        
        if profile_exists "$profile_name"; then
            print_error "Profile already exists"
            continue
        fi
        
        break
    done
    
    # Input Domain
    while true; do
        read -p "$(echo -e ${WHITE}Domain: ${NC})" domain
        
        if ! validate_domain "$domain"; then
            print_error "Invalid domain format"
            continue
        fi
        
        break
    done
    
    # Input CPU
    while true; do
        read -p "$(echo -e "${WHITE}CPU (%): ${NC}")" cpu
        
        if ! validate_number_range "$cpu" 50 800; then
            print_error "CPU must be between 50-800"
            continue
        fi
        
        break
    done
    
    # Input RAM
    while true; do
        read -p "$(echo -e "${WHITE}RAM (MB): ${NC}")" ram
        
        if ! validate_number_range "$ram" 256 16384; then
            print_error "RAM must be between 256-16384 MB"
            continue
        fi
        
        break
    done
    
    # SSH Port
    read -p "$(echo -e "${WHITE}SSH Port [auto]: ${NC}")" ssh_port
    if [[ -z "$ssh_port" ]]; then
        ssh_port=$(find_available_port $SSH_PORT_START $SSH_PORT_END)
        if [[ -z "$ssh_port" ]]; then
            print_error "No available SSH ports"
            return 1
        fi
        echo "Auto-assigned: $ssh_port"
    fi
    
    # Password
    read -p "$(echo -e "${WHITE}Password [auto]: ${NC}")" password
    if [[ -z "$password" ]]; then
        password=$(generate_password 10)
        echo "Auto-generated: $password"
    fi
    
    # Expiration
    read -p "$(echo -e "${WHITE}Expired (days): ${NC}")" expired_days
    expired_date=$(date -d "+${expired_days} days" +%Y-%m-%d)
    
    # Bandwidth
    read -p "$(echo -e "${WHITE}Bandwidth Quota (TB): ${NC}")" bw_quota
    
    # Custom Paths
    read -p "$(echo -e "${WHITE}VMess Path [/vmess]: ${NC}")" path_vmess
    path_vmess=${path_vmess:-/vmess}
    
    read -p "$(echo -e "${WHITE}VLess Path [/vless]: ${NC}")" path_vless
    path_vless=${path_vless:-/vless}
    
    read -p "$(echo -e "${WHITE}Trojan Path [/trojan]: ${NC}")" path_trojan
    path_trojan=${path_trojan:-/trojan}
    
    # Restore Link
    read -p "$(echo -e "${WHITE}Restore Link [empty]: ${NC}")" restore_link
    
    # Preview
    echo ""
    print_double_line 60
    echo -e "${YELLOW}PROFILE PREVIEW:${NC}"
    print_line 60
    echo -e "Name            : ${GREEN}$profile_name${NC}"
    echo -e "Domain          : ${GREEN}$domain${NC}"
    echo -e "CPU             : ${GREEN}${cpu}%${NC} ($(bc <<< "scale=1; $cpu/100") cores)"
    echo -e "RAM             : ${GREEN}${ram}MB${NC}"
    echo -e "SSH Port        : ${GREEN}$ssh_port${NC}"
    echo -e "Password        : ${GREEN}$password${NC}"
    echo -e "Expired         : ${GREEN}$expired_date${NC} ($expired_days days)"
    echo -e "Bandwidth Quota : ${GREEN}${bw_quota}TB/month${NC}"
    echo -e "WebSocket Paths:"
    echo -e "  VMess         : ${CYAN}$path_vmess${NC}"
    echo -e "  VLess         : ${CYAN}$path_vless${NC}"
    echo -e "  Trojan        : ${CYAN}$path_trojan${NC}"
    print_double_line 60
    echo ""
    
    if ! confirm_action "Create this profile?"; then
        print_info "Cancelled"
        return 0
    fi
    
    # Create profile
    print_step "Creating profile..."
    
    mkdir -p "${BASE_DIR}/profiles/${profile_name}"/{xray,ssh,backup}
    
    # Create .profile metadata
    cat > "${BASE_DIR}/profiles/${profile_name}/.profile" << EOF
PROFILE_NAME=$profile_name
DOMAIN=$domain
CPU=$cpu
RAM=$ram
SSH_PORT=$ssh_port
PASSWORD=$password
EXPIRED=$expired_date
BANDWIDTH=$((bw_quota * 1024))
BANDWIDTH_USED=0
STATUS=active
CREATED=$(date +%Y-%m-%d)
IP=$(get_next_ip)
EOF
    
    # Create paths.env
    cat > "${BASE_DIR}/profiles/${profile_name}/xray/paths.env" << EOF
PATH_VMESS=$path_vmess
PATH_VLESS=$path_vless
PATH_TROJAN=$path_trojan
EOF
    
    print_success "Profile created: $profile_name"
    
    # Add to history
    add_to_history "Create Profile" "Created profile: $profile_name (Domain: $domain)"
    
    press_any_key
}

# List Profiles Function
list_profiles() {
    if [[ ! -f "${BASE_DIR}/profiles.json" ]]; then
        return 1
    fi

    jq -r '.profiles[].name' "${BASE_DIR}/profiles.json" 2>/dev/null
}

# Get Profile Info
get_profile_info() {
    local profile="$1"

    if [[ ! -f "${BASE_DIR}/profiles.json" ]]; then
        return 1
    fi

    jq -r ".profiles[] | select(.name == \"$profile\")" "${BASE_DIR}/profiles.json" 2>/dev/null
}

# Delete Profile Function
delete_profile() {
    clear
    print_banner

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}DELETE PROFILE${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # List profiles
    profiles=$(list_profiles)

    if [[ -z "$profiles" ]]; then
        print_error "No profiles found"
        press_any_key
        return 1
    fi

    echo -e "${YELLOW}Available profiles:${NC}"
    echo ""

    local i=1
    declare -A profile_map

    while IFS= read -r profile; do
        local info=$(get_profile_info "$profile")
        local domain=$(echo "$info" | jq -r '.domain')
        local status=$(echo "$info" | jq -r '.status')

        printf "${WHITE}%2d)${NC} %-20s ${CYAN}%-30s${NC} [%s]\n" $i "$profile" "$domain" "$status"
        profile_map[$i]="$profile"
        i=$((i + 1))
    done <<< "$profiles"

    echo ""
    read -p "$(echo -e ${WHITE}Select profile number to delete [0 to cancel]: ${NC})" selection

    if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
        print_info "Cancelled"
        return 0
    fi

    local selected_profile="${profile_map[$selection]}"

    if [[ -z "$selected_profile" ]]; then
        print_error "Invalid selection"
        press_any_key
        return 1
    fi

    # Confirm deletion
    echo ""
    echo -e "${RED}⚠️  WARNING: This will permanently delete profile: $selected_profile${NC}"
    echo -e "${RED}    All data, configurations, and VPN accounts will be removed!${NC}"
    echo ""

    if ! confirm_action "Are you sure you want to delete this profile?"; then
        print_info "Cancelled"
        return 0
    fi

    print_step "Stopping and removing Docker container..."

    local container="${selected_profile}-vpn"

    # Stop and remove container
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        docker stop "$container" 2>&1 | tee -a /var/log/xray-multi/profile-manager.log
        docker rm "$container" 2>&1 | tee -a /var/log/xray-multi/profile-manager.log
        print_success "Container removed"
    fi

    print_step "Removing Nginx configuration..."

    # Remove Nginx config
    if [[ -f "/etc/nginx/sites-enabled/${selected_profile}.conf" ]]; then
        rm -f "/etc/nginx/sites-enabled/${selected_profile}.conf"
        nginx -s reload 2>&1 | tee -a /var/log/xray-multi/profile-manager.log
        print_success "Nginx config removed"
    fi

    print_step "Removing profile data..."

    # Remove profile directory
    if [[ -d "${BASE_DIR}/profiles/${selected_profile}" ]]; then
        rm -rf "${BASE_DIR}/profiles/${selected_profile}"
        print_success "Profile data removed"
    fi

    print_step "Updating profiles.json..."

    # Remove from profiles.json
    if [[ -f "${BASE_DIR}/profiles.json" ]]; then
        local updated=$(jq "del(.profiles[] | select(.name == \"$selected_profile\"))" "${BASE_DIR}/profiles.json")
        echo "$updated" > "${BASE_DIR}/profiles.json"
        print_success "Profile registry updated"
    fi

    # Add to history
    add_to_history "Delete Profile" "Deleted profile: $selected_profile"

    # Send notification
    send_telegram "🗑️ *Profile Deleted*\nVPS: $(cat /etc/hostname)\nProfile: $selected_profile"

    echo ""
    print_success "Profile $selected_profile deleted successfully"
    press_any_key
}

# Access Profile via SSH Function
access_profile() {
    clear
    print_banner

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}ACCESS PROFILE (SSH)${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # List profiles
    profiles=$(list_profiles)

    if [[ -z "$profiles" ]]; then
        print_error "No profiles found"
        press_any_key
        return 1
    fi

    echo -e "${YELLOW}Available profiles:${NC}"
    echo ""

    local i=1
    declare -A profile_map

    while IFS= read -r profile; do
        local info=$(get_profile_info "$profile")
        local domain=$(echo "$info" | jq -r '.domain')
        local status=$(echo "$info" | jq -r '.status')

        # Get SSH port from Docker
        local container="${profile}-vpn"
        local ssh_port=""

        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            ssh_port=$(docker port "$container" 22 2>/dev/null | cut -d: -f2)
            status="${GREEN}running${NC}"
        else
            status="${RED}stopped${NC}"
        fi

        printf "${WHITE}%2d)${NC} %-20s ${CYAN}Port: %-6s${NC} Status: %b\n" $i "$profile" "${ssh_port:-N/A}" "$status"
        profile_map[$i]="$profile"
        i=$((i + 1))
    done <<< "$profiles"

    echo ""
    read -p "$(echo -e ${WHITE}Select profile number to access [0 to cancel]: ${NC})" selection

    if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
        print_info "Cancelled"
        return 0
    fi

    local selected_profile="${profile_map[$selection]}"

    if [[ -z "$selected_profile" ]]; then
        print_error "Invalid selection"
        press_any_key
        return 1
    fi

    local container="${selected_profile}-vpn"

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        print_error "Container is not running"
        press_any_key
        return 1
    fi

    # Get SSH info
    local info=$(get_profile_info "$selected_profile")
    local ssh_port=$(docker port "$container" 22 2>/dev/null | cut -d: -f2)
    local password=$(echo "$info" | jq -r '.password')

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}SSH CONNECTION INFO${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${WHITE}Profile     :${NC} %-45s ${CYAN}║${NC}\n" "$selected_profile"
    printf "${CYAN}║${NC} ${WHITE}Host        :${NC} %-45s ${CYAN}║${NC}\n" "localhost"
    printf "${CYAN}║${NC} ${WHITE}Port        :${NC} %-45s ${CYAN}║${NC}\n" "$ssh_port"
    printf "${CYAN}║${NC} ${WHITE}Username    :${NC} %-45s ${CYAN}║${NC}\n" "root"
    printf "${CYAN}║${NC} ${WHITE}Password    :${NC} %-45s ${CYAN}║${NC}\n" "$password"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${YELLOW}Command:${NC} %-50s ${CYAN}║${NC}\n" "ssh -p $ssh_port root@localhost"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}Connect now? [Y/n]: ${NC})" connect

    if [[ ! "$connect" =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${YELLOW}Connecting to $selected_profile...${NC}"
        echo -e "${YELLOW}Password: $password${NC}"
        echo ""

        # Connect via SSH
        ssh -p "$ssh_port" root@localhost

        echo ""
        print_info "SSH session ended"
    fi

    press_any_key
}

# Extend Expiration Function
extend_expiration() {
    clear
    print_banner

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}EXTEND EXPIRATION${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # List profiles
    profiles=$(list_profiles)

    if [[ -z "$profiles" ]]; then
        print_error "No profiles found"
        press_any_key
        return 1
    fi

    echo -e "${YELLOW}Available profiles:${NC}"
    echo ""

    local i=1
    declare -A profile_map

    while IFS= read -r profile; do
        local info=$(get_profile_info "$profile")
        local expired=$(echo "$info" | jq -r '.expired')
        local expired_epoch=$(echo "$info" | jq -r '.expired_epoch')

        local now_epoch=$(date +%s)
        local days_left=$(( (expired_epoch - now_epoch) / 86400 ))

        if (( days_left < 0 )); then
            local status="${RED}EXPIRED${NC}"
        elif (( days_left <= 7 )); then
            local status="${YELLOW}$days_left days${NC}"
        else
            local status="${GREEN}$days_left days${NC}"
        fi

        printf "${WHITE}%2d)${NC} %-20s Exp: %-12s (%b)\n" $i "$profile" "$expired" "$status"
        profile_map[$i]="$profile"
        i=$((i + 1))
    done <<< "$profiles"

    echo ""
    read -p "$(echo -e ${WHITE}Select profile number to extend [0 to cancel]: ${NC})" selection

    if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
        print_info "Cancelled"
        return 0
    fi

    local selected_profile="${profile_map[$selection]}"

    if [[ -z "$selected_profile" ]]; then
        print_error "Invalid selection"
        press_any_key
        return 1
    fi

    local info=$(get_profile_info "$selected_profile")
    local current_expired=$(echo "$info" | jq -r '.expired')

    echo ""
    echo -e "${WHITE}Current expiration:${NC} $current_expired"
    echo ""

    read -p "$(echo -e ${WHITE}Add days to expiration: ${NC})" add_days

    if [[ -z "$add_days" ]] || [[ ! "$add_days" =~ ^[0-9]+$ ]]; then
        print_error "Invalid number of days"
        press_any_key
        return 1
    fi

    # Calculate new expiration
    local new_exp_date=$(date -d "$current_expired + $add_days days" +"%Y-%m-%d")
    local new_exp_epoch=$(date -d "$new_exp_date" +%s)

    # Update profiles.json
    local updated=$(jq "(.profiles[] | select(.name == \"$selected_profile\") | .expired) = \"$new_exp_date\" | (.profiles[] | select(.name == \"$selected_profile\") | .expired_epoch) = $new_exp_epoch" "${BASE_DIR}/profiles.json")
    echo "$updated" > "${BASE_DIR}/profiles.json"

    # Add to history
    add_to_history "Extend Expiration" "Extended $selected_profile: $current_expired → $new_exp_date (+$add_days days)"

    # Send notification
    send_telegram "📅 *Expiration Extended*\nVPS: $(cat /etc/hostname)\nProfile: $selected_profile\nOld: $current_expired\nNew: $new_exp_date (+$add_days days)"

    echo ""
    print_success "Expiration extended successfully"
    echo ""
    echo -e "${WHITE}Previous expiration:${NC} $current_expired"
    echo -e "${WHITE}New expiration:${NC}      ${GREEN}$new_exp_date${NC} (+$add_days days)"
    echo ""

    press_any_key
}

# Extend Bandwidth Function
extend_bandwidth() {
    clear
    print_banner

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}EXTEND BANDWIDTH QUOTA${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # List profiles
    profiles=$(list_profiles)

    if [[ -z "$profiles" ]]; then
        print_error "No profiles found"
        press_any_key
        return 1
    fi

    echo -e "${YELLOW}Available profiles:${NC}"
    echo ""

    local i=1
    declare -A profile_map

    while IFS= read -r profile; do
        local info=$(get_profile_info "$profile")
        local quota_gb=$(echo "$info" | jq -r '.bandwidth_quota')
        local used_gb=$(echo "$info" | jq -r '.bandwidth_used // 0 / 1024 / 1024 / 1024')

        printf "${WHITE}%2d)${NC} %-20s Quota: ${GREEN}%5d GB${NC} Used: ${CYAN}%5.2f GB${NC}\n" $i "$profile" "$quota_gb" "$used_gb"
        profile_map[$i]="$profile"
        i=$((i + 1))
    done <<< "$profiles"

    echo ""
    read -p "$(echo -e ${WHITE}Select profile number to extend [0 to cancel]: ${NC})" selection

    if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
        print_info "Cancelled"
        return 0
    fi

    local selected_profile="${profile_map[$selection]}"

    if [[ -z "$selected_profile" ]]; then
        print_error "Invalid selection"
        press_any_key
        return 1
    fi

    local info=$(get_profile_info "$selected_profile")
    local current_quota=$(echo "$info" | jq -r '.bandwidth_quota')

    echo ""
    echo -e "${WHITE}Current quota:${NC} ${current_quota} GB"
    echo ""

    read -p "$(echo -e "${WHITE}Add bandwidth quota (GB): ${NC}")" add_gb

    if [[ -z "$add_gb" ]] || [[ ! "$add_gb" =~ ^[0-9]+$ ]]; then
        print_error "Invalid number"
        press_any_key
        return 1
    fi

    # Calculate new quota
    local new_quota=$((current_quota + add_gb))

    # Update profiles.json
    local updated=$(jq "(.profiles[] | select(.name == \"$selected_profile\") | .bandwidth_quota) = $new_quota" "${BASE_DIR}/profiles.json")
    echo "$updated" > "${BASE_DIR}/profiles.json"

    # Add to history
    add_to_history "Extend Bandwidth" "Extended $selected_profile: ${current_quota}GB → ${new_quota}GB (+${add_gb}GB)"

    # Send notification
    send_telegram "📊 *Bandwidth Quota Extended*\nVPS: $(cat /etc/hostname)\nProfile: $selected_profile\nOld: ${current_quota} GB\nNew: ${new_quota} GB (+${add_gb} GB)"

    echo ""
    print_success "Bandwidth quota extended successfully"
    echo ""
    echo -e "${WHITE}Previous quota:${NC} ${current_quota} GB"
    echo -e "${WHITE}New quota:${NC}      ${GREEN}${new_quota} GB${NC} (+${add_gb} GB)"
    echo ""

    press_any_key
}

# Main
case "$1" in
    create) create_profile ;;
    delete) delete_profile ;;
    access) access_profile ;;
    extend-expiration) extend_expiration ;;
    extend-bandwidth) extend_bandwidth ;;
    *) echo "Usage: $0 {create|delete|access|extend-expiration|extend-bandwidth}" ;;
esac
