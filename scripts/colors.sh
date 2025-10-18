#!/bin/bash

# ============================================
# Color Functions for VPN Multi-Profile Manager
# ============================================

# Color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export GRAY='\033[0;37m'
export NC='\033[0m' # No Color

# Background colors
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'

# Text styles
export BOLD='\033[1m'
export DIM='\033[2m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export REVERSE='\033[7m'

# Print functions
print_color() {
    local color=$1
    shift
    echo -e "${color}${@}${NC}"
}

print_red() {
    echo -e "${RED}$@${NC}"
}

print_green() {
    echo -e "${GREEN}$@${NC}"
}

print_yellow() {
    echo -e "${YELLOW}$@${NC}"
}

print_blue() {
    echo -e "${BLUE}$@${NC}"
}

print_cyan() {
    echo -e "${CYAN}$@${NC}"
}

print_magenta() {
    echo -e "${MAGENTA}$@${NC}"
}

# Status indicators
print_success() {
    echo -e "${GREEN}✔${NC} $@"
}

print_error() {
    echo -e "${RED}✖${NC} $@"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $@"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $@"
}

print_step() {
    echo -e "${CYAN}►${NC} $@"
}

# Box drawing
print_box() {
    local width=${2:-60}
    local text="$1"
    local padding=$(( (width - ${#text} - 2) / 2 ))

    echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
    printf "${CYAN}║${NC}%*s${GREEN}%s${NC}%*s${CYAN}║${NC}\n" $padding "" "$text" $padding ""
    echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
}

print_line() {
    local width=${1:-60}
    printf "${GRAY}%${width}s${NC}\n" | tr ' ' '─'
}

print_double_line() {
    local width=${1:-60}
    printf "${CYAN}%${width}s${NC}\n" | tr ' ' '═'
}

# Progress bar
print_progress() {
    local percent=$1
    local width=50
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))

    printf "${CYAN}["
    printf "${GREEN}%${filled}s" | tr ' ' '█'
    printf "${GRAY}%${empty}s" | tr ' ' '░'
    printf "${CYAN}]${NC} ${WHITE}%3d%%${NC}\n" $percent
}

# Banner
print_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}         ${GREEN}VPN MULTI-PROFILE MANAGER${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}         ${BLUE}github.com/kaccang/xray-multiprofile${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}
