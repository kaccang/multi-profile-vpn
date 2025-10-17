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
        read -p "$(echo -e ${WHITE}"CPU (%): "${NC})" cpu
        
        if ! validate_number_range "$cpu" 50 800; then
            print_error "CPU must be between 50-800"
            continue
        fi
        
        break
    done
    
    # Input RAM
    while true; do
        read -p "$(echo -e ${WHITE}"RAM (MB): "${NC})" ram
        
        if ! validate_number_range "$ram" 256 16384; then
            print_error "RAM must be between 256-16384 MB"
            continue
        fi
        
        break
    done
    
    # SSH Port
    read -p "$(echo -e ${WHITE}"SSH Port [auto]: "${NC})" ssh_port
    if [[ -z "$ssh_port" ]]; then
        ssh_port=$(find_available_port $SSH_PORT_START $SSH_PORT_END)
        if [[ -z "$ssh_port" ]]; then
            print_error "No available SSH ports"
            return 1
        fi
        echo "Auto-assigned: $ssh_port"
    fi
    
    # Password
    read -p "$(echo -e ${WHITE}"Password [auto]: "${NC})" password
    if [[ -z "$password" ]]; then
        password=$(generate_password 10)
        echo "Auto-generated: $password"
    fi
    
    # Expiration
    read -p "$(echo -e ${WHITE}"Expired (days): "${NC})" expired_days
    expired_date=$(date -d "+${expired_days} days" +%Y-%m-%d)
    
    # Bandwidth
    read -p "$(echo -e ${WHITE}"Bandwidth Quota (TB): "${NC})" bw_quota
    
    # Custom Paths
    read -p "$(echo -e ${WHITE}"VMess Path [/vmess]: "${NC})" path_vmess
    path_vmess=${path_vmess:-/vmess}
    
    read -p "$(echo -e ${WHITE}"VLess Path [/vless]: "${NC})" path_vless
    path_vless=${path_vless:-/vless}
    
    read -p "$(echo -e ${WHITE}"Trojan Path [/trojan]: "${NC})" path_trojan
    path_trojan=${path_trojan:-/trojan}
    
    # Restore Link
    read -p "$(echo -e ${WHITE}"Restore Link [empty]: "${NC})" restore_link
    
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

# Main
case "$1" in
    create) create_profile ;;
    delete) echo "Delete function - TBD" ;;
    access) echo "Access function - TBD" ;;
    *) echo "Usage: $0 {create|delete|access|manage|extend-expiration|extend-bandwidth}" ;;
esac
