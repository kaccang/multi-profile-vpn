#!/bin/bash

# ============================================
# Profile VPN Menu
# Sub-menu for managing VPN accounts inside profile
# ============================================

source /etc/xray-multi/scripts/colors.sh

show_menu() {
    clear
    print_banner

    PROFILE_NAME=$(cat /etc/hostname)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}VPN ACCOUNT MANAGEMENT${NC} - Profile: ${GREEN}$PROFILE_NAME${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}1)${NC}  Create VMess Account                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}2)${NC}  Create VLess Account                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}3)${NC}  Create Trojan Account                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}4)${NC}  Delete VPN Account                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}5)${NC}  Renew VPN Account                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}6)${NC}  Check VPN Account                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}7)${NC}  List All Users                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}8)${NC}  Delete Expired Accounts                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}0)${NC}  Exit                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

while true; do
    show_menu
    read -p "$(echo -e ${WHITE}Select option [0-8]: ${NC})" choice

    case $choice in
        1)
            /usr/local/bin/vpn-scripts/add-vmess.sh
            ;;
        2)
            /usr/local/bin/vpn-scripts/add-vless.sh
            ;;
        3)
            /usr/local/bin/vpn-scripts/add-trojan.sh
            ;;
        4)
            /usr/local/bin/vpn-scripts/del-vpn.sh
            ;;
        5)
            /usr/local/bin/vpn-scripts/renew-vpn.sh
            ;;
        6)
            /usr/local/bin/vpn-scripts/check-vpn.sh
            ;;
        7)
            /usr/local/bin/vpn-scripts/list-users.sh
            ;;
        8)
            /usr/local/bin/vpn-scripts/xp.sh
            ;;
        0)
            clear
            print_success "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            sleep 1
            ;;
    esac
done
