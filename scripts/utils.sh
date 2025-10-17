#!/bin/bash

# ============================================
# Utility Functions for VPN Multi-Profile Manager
# ============================================

BASE_DIR="/etc/xray-multi"

# Load .env file
load_env() {
    if [[ -f "${BASE_DIR}/.env" ]]; then
        set -a
        source "${BASE_DIR}/.env"
        set +a
    else
        echo "Error: .env file not found"
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Validate domain
validate_domain() {
    local domain=$1

    if [[ -z "$domain" ]]; then
        return 1
    fi

    # Basic domain regex
    if [[ ! $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi

    return 0
}

# Validate IP address
validate_ip() {
    local ip=$1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi

    return 1
}

# Check domain DNS
check_domain_dns() {
    local domain=$1
    local server_ip=$(curl -s -4 ifconfig.me)

    local domain_ip=$(dig +short $domain | head -1)

    if [[ "$domain_ip" == "$server_ip" ]]; then
        return 0
    else
        return 1
    fi
}

# Generate random password
generate_password() {
    local length=${1:-10}
    local use_special=${2:-false}

    if [[ "$use_special" == "true" ]]; then
        # With special characters
        tr -dc 'A-Za-z0-9!@#$%^&*()_+=' < /dev/urandom | head -c $length
    else
        # Alphanumeric only
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c $length
    fi
}

# Check port availability
check_port() {
    local port=$1

    if ss -tuln | grep -q ":$port "; then
        return 1  # Port in use
    else
        return 0  # Port available
    fi
}

# Find available port in range
find_available_port() {
    local start=$1
    local end=$2

    for port in $(seq $start $end); do
        if check_port $port; then
            echo $port
            return 0
        fi
    done

    return 1
}

# Get profile count
get_profile_count() {
    if [[ -d "${BASE_DIR}/profiles" ]]; then
        ls -1 "${BASE_DIR}/profiles" 2>/dev/null | wc -l
    else
        echo 0
    fi
}

# Check if profile exists
profile_exists() {
    local profile_name=$1

    if [[ -d "${BASE_DIR}/profiles/${profile_name}" ]]; then
        return 0
    else
        return 1
    fi
}

# Get profile metadata
get_profile_meta() {
    local profile_name=$1
    local key=$2

    if [[ -f "${BASE_DIR}/profiles/${profile_name}/.profile" ]]; then
        grep "^${key}=" "${BASE_DIR}/profiles/${profile_name}/.profile" | cut -d= -f2-
    fi
}

# Set profile metadata
set_profile_meta() {
    local profile_name=$1
    local key=$2
    local value=$3

    local profile_file="${BASE_DIR}/profiles/${profile_name}/.profile"

    if grep -q "^${key}=" "$profile_file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$profile_file"
    else
        echo "${key}=${value}" >> "$profile_file"
    fi
}

# Calculate days until expiration
days_until_expiration() {
    local expire_date=$1
    local now=$(date +%s)
    local expire=$(date -d "$expire_date" +%s)
    local diff=$(( (expire - now) / 86400 ))

    echo $diff
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1

    if (( bytes < 1024 )); then
        echo "${bytes}B"
    elif (( bytes < 1048576 )); then
        echo "$((bytes / 1024))KB"
    elif (( bytes < 1073741824 )); then
        echo "$((bytes / 1048576))MB"
    elif (( bytes < 1099511627776 )); then
        printf "%.2fGB" $(bc <<< "scale=2; $bytes / 1073741824")
    else
        printf "%.2fTB" $(bc <<< "scale=2; $bytes / 1099511627776")
    fi
}

# Send Telegram message
send_telegram() {
    local message=$1

    if [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=Markdown" > /dev/null 2>&1
    fi
}

# Log message
log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "${BASE_DIR}/logs/vpsadmin.log"
}

# Get system resources
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
}

get_mem_usage() {
    free -m | awk 'NR==2{printf "%.0f", $3}'
}

get_mem_total() {
    free -m | awk 'NR==2{printf "%.0f", $2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Docker operations
docker_profile_start() {
    local profile_name=$1
    docker-compose -f "${BASE_DIR}/docker/docker-compose.yml" start "profile-${profile_name}"
}

docker_profile_stop() {
    local profile_name=$1
    docker-compose -f "${BASE_DIR}/docker/docker-compose.yml" stop "profile-${profile_name}"
}

docker_profile_restart() {
    local profile_name=$1
    docker-compose -f "${BASE_DIR}/docker/docker-compose.yml" restart "profile-${profile_name}"
}

docker_profile_exec() {
    local profile_name=$1
    shift
    local command="$@"
    docker exec -it "profile-${profile_name}" $command
}

# Sanitize input
sanitize_input() {
    local input=$1
    # Remove dangerous characters
    echo "$input" | sed 's/[^a-zA-Z0-9._-]//g'
}

# Confirm action
confirm_action() {
    local message=${1:-"Are you sure?"}

    read -p "$(echo -e ${YELLOW}${message}${NC} [y/N]: )" -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Press any key to continue
press_any_key() {
    read -n 1 -s -r -p "$(echo -e ${GRAY}Press any key to continue...${NC})"
    echo
}

# Validate number in range
validate_number_range() {
    local number=$1
    local min=$2
    local max=$3

    if [[ ! $number =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if (( number < min || number > max )); then
        return 1
    fi

    return 0
}

# Get next available IP
get_next_ip() {
    local base_ip=$BASE_IP
    local start=2
    local max=254

    for i in $(seq $start $max); do
        local ip="${base_ip}.${i}"

        # Check if IP is used in docker-compose.yml
        if ! grep -q "ipv4_address: ${ip}" "${BASE_DIR}/docker/docker-compose.yml" 2>/dev/null; then
            echo $ip
            return 0
        fi
    done

    return 1
}

# Add to history
add_to_history() {
    local action=$1
    local description=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat >> "${BASE_DIR}/docs/history.md" << EOF

## ${timestamp}

**Action**: ${action}
**Description**: ${description}
**Status**: ✅ Completed

---
EOF
}

# Update progress
update_progress() {
    local feature=$1
    local status=$2

    # This will be called when implementing features
    log_message "INFO" "Progress: ${feature} - ${status}"
}
