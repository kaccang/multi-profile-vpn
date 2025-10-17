#!/bin/bash

# ============================================
# Bandwidth Usage Monitor
# Tracks bandwidth usage and enforces quotas
# Run hourly via cron-alternative.sh
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

LOG_FILE="/var/log/xray-multi/bandwidth.log"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    local gb=$((bytes / 1024 / 1024 / 1024))
    local mb=$((bytes / 1024 / 1024))

    if (( gb > 0 )); then
        echo "${gb} GB"
    else
        echo "${mb} MB"
    fi
}

check_bandwidth_quota() {
    local profile="$1"
    local container="${profile}-vpn"

    # Check if profile exists in profiles.json
    if [[ ! -f /etc/xray-multi/profiles.json ]]; then
        log "ERROR: profiles.json not found"
        return 1
    fi

    # Get profile data
    local profile_data=$(jq -r ".profiles[] | select(.name == \"$profile\")" /etc/xray-multi/profiles.json)

    if [[ -z "$profile_data" ]]; then
        log "WARNING: Profile $profile not found in profiles.json"
        return 1
    fi

    # Get bandwidth quota (in GB)
    local quota_gb=$(echo "$profile_data" | jq -r '.bandwidth_quota')
    local status=$(echo "$profile_data" | jq -r '.status')

    if [[ "$quota_gb" == "null" ]] || [[ "$quota_gb" == "0" ]]; then
        log "Profile $profile has unlimited bandwidth"
        return 0
    fi

    # Convert quota to bytes
    local quota_bytes=$((quota_gb * 1024 * 1024 * 1024))

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log "WARNING: Container $container is not running, skipping bandwidth check"
        return 1
    fi

    # Get bandwidth usage from vnstat inside container
    # Use monthly stats, reset on first day of month
    local usage_output=$(docker exec "$container" vnstat --json 2>/dev/null)

    if [[ -z "$usage_output" ]]; then
        log "WARNING: Could not get vnstat data from $container"
        return 1
    fi

    # Parse total RX + TX for current month
    local rx_bytes=$(echo "$usage_output" | jq -r '.interfaces[0].traffic.month[-1].rx // 0')
    local tx_bytes=$(echo "$usage_output" | jq -r '.interfaces[0].traffic.month[-1].tx // 0')
    local total_bytes=$((rx_bytes + tx_bytes))

    # Calculate usage percentage
    local usage_percent=$((total_bytes * 100 / quota_bytes))

    local quota_human=$(bytes_to_human "$quota_bytes")
    local usage_human=$(bytes_to_human "$total_bytes")

    log "Profile $profile: $usage_human / $quota_human ($usage_percent%)"

    # Check if quota exceeded
    if (( total_bytes >= quota_bytes )); then
        if [[ "$status" == "active" ]]; then
            log "ALERT: Profile $profile exceeded bandwidth quota ($usage_human / $quota_human)"

            # Disable profile
            log "Disabling profile $profile due to bandwidth quota exceeded"
            docker stop "$container" 2>&1 | tee -a "$LOG_FILE"

            # Update status in profiles.json
            local updated_profiles=$(jq "(.profiles[] | select(.name == \"$profile\") | .status) = \"suspended_bandwidth\"" /etc/xray-multi/profiles.json)
            echo "$updated_profiles" > /etc/xray-multi/profiles.json

            # Send Telegram notification
            load_env
            local hostname=$(cat /etc/hostname)
            send_telegram "🚫 *Bandwidth Quota Exceeded*\nVPS: $hostname\nProfile: $profile\nUsage: $usage_human / $quota_human\nStatus: Suspended"
        else
            log "Profile $profile already suspended/disabled, skipping"
        fi
    elif (( usage_percent >= 90 )); then
        log "WARNING: Profile $profile at $usage_percent% bandwidth quota"

        # Send warning notification
        load_env
        local hostname=$(cat /etc/hostname)
        send_telegram "⚠️ *Bandwidth Warning*\nVPS: $hostname\nProfile: $profile\nUsage: $usage_human / $quota_human ($usage_percent%)\nQuota almost exceeded!"
    elif (( usage_percent >= 75 )); then
        log "INFO: Profile $profile at $usage_percent% bandwidth quota"
    fi

    # Update bandwidth usage in profiles.json
    local updated_profiles=$(jq "(.profiles[] | select(.name == \"$profile\") | .bandwidth_used) = $total_bytes" /etc/xray-multi/profiles.json)
    echo "$updated_profiles" > /etc/xray-multi/profiles.json

    return 0
}

# Main execution
log "Bandwidth monitor started"

# Check if profiles.json exists
if [[ ! -f /etc/xray-multi/profiles.json ]]; then
    log "ERROR: profiles.json not found"
    exit 1
fi

# Get all profiles
profiles=$(jq -r '.profiles[].name' /etc/xray-multi/profiles.json 2>/dev/null)

if [[ -z "$profiles" ]]; then
    log "No profiles found"
    exit 0
fi

# Check each profile
for profile in $profiles; do
    check_bandwidth_quota "$profile"
done

log "Bandwidth monitor completed"
