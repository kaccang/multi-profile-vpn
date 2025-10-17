#!/bin/bash

# ============================================
# Profile Expiration Checker
# Checks profile expiration dates daily
# Sends warnings and auto-disables expired profiles
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

LOG_FILE="/var/log/xray-multi/expiration.log"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

check_profile_expiration() {
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

    # Get expiration date and status
    local expired_date=$(echo "$profile_data" | jq -r '.expired')
    local status=$(echo "$profile_data" | jq -r '.status')

    if [[ "$expired_date" == "null" ]] || [[ -z "$expired_date" ]]; then
        log "Profile $profile has no expiration date (lifetime)"
        return 0
    fi

    # Calculate days until expiration
    local now_epoch=$(date +%s)
    local expired_epoch=$(date -d "$expired_date" +%s)
    local days_left=$(( (expired_epoch - now_epoch) / 86400 ))

    log "Profile $profile: $days_left days until expiration ($expired_date)"

    # Check if expired
    if (( days_left < 0 )); then
        if [[ "$status" == "active" ]]; then
            log "ALERT: Profile $profile has EXPIRED (expired on $expired_date)"

            # Disable profile
            log "Disabling profile $profile due to expiration"
            docker stop "$container" 2>&1 | tee -a "$LOG_FILE"

            # Update status in profiles.json
            local updated_profiles=$(jq "(.profiles[] | select(.name == \"$profile\") | .status) = \"expired\"" /etc/xray-multi/profiles.json)
            echo "$updated_profiles" > /etc/xray-multi/profiles.json

            # Disable Nginx config
            local nginx_config="/etc/nginx/sites-enabled/${profile}.conf"
            if [[ -f "$nginx_config" ]]; then
                rm -f "$nginx_config"
                nginx -s reload 2>&1 | tee -a "$LOG_FILE"
                log "Removed Nginx config for expired profile $profile"
            fi

            # Send Telegram notification
            load_env
            local hostname=$(cat /etc/hostname)
            send_telegram "❌ *Profile Expired*\nVPS: $hostname\nProfile: $profile\nExpired: $expired_date\nStatus: Disabled"
        else
            log "Profile $profile already expired and disabled, skipping"
        fi
    elif (( days_left <= 3 )); then
        log "WARNING: Profile $profile expires in $days_left days!"

        # Send warning notification
        load_env
        local hostname=$(cat /etc/hostname)
        send_telegram "⚠️ *Expiration Warning*\nVPS: $hostname\nProfile: $profile\nExpires in: $days_left days\nExpiration: $expired_date\nPlease renew soon!"
    elif (( days_left <= 7 )); then
        log "INFO: Profile $profile expires in $days_left days"

        # Send reminder notification
        load_env
        local hostname=$(cat /etc/hostname)
        send_telegram "📅 *Expiration Reminder*\nVPS: $hostname\nProfile: $profile\nExpires in: $days_left days\nExpiration: $expired_date"
    fi

    return 0
}

# Main execution
log "Expiration checker started"

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
expired_count=0
expiring_soon=0

for profile in $profiles; do
    check_profile_expiration "$profile"
    exit_code=$?

    if (( exit_code == 2 )); then
        ((expired_count++))
    elif (( exit_code == 1 )); then
        ((expiring_soon++))
    fi
done

# Summary
if (( expired_count > 0 )) || (( expiring_soon > 0 )); then
    log "Summary: $expired_count expired, $expiring_soon expiring soon"
else
    log "All profiles are valid"
fi

log "Expiration checker completed"
