#!/bin/bash

# ============================================
# Profile Health Check Daemon
# Monitors profile status every 5 minutes
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

LOG_FILE="/var/log/xray-multi/health-check.log"
CHECK_INTERVAL=300  # 5 minutes

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

check_profile_health() {
    local profile="$1"
    local container="${profile}-vpn"
    local issues=0
    local issue_details=""

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log "ERROR: Container $container is not running"
        issue_details="${issue_details}\n❌ Container not running"
        ((issues++))

        # Try to start container
        log "Attempting to start container $container"
        docker start "$container" 2>&1 | tee -a "$LOG_FILE"

        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            log "SUCCESS: Container $container started successfully"
            issue_details="${issue_details}\n✅ Container auto-restarted"
        else
            log "FAILED: Could not start container $container"
            issue_details="${issue_details}\n❌ Auto-restart failed"
        fi
    fi

    # Check if container is healthy (only if running)
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)

        if [[ "$health_status" == "unhealthy" ]]; then
            log "WARNING: Container $container is unhealthy"
            issue_details="${issue_details}\n⚠️ Container unhealthy"
            ((issues++))
        fi
    fi

    # Check Xray process inside container
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        if ! docker exec "$container" pgrep -f xray > /dev/null 2>&1; then
            log "ERROR: Xray not running in container $container"
            issue_details="${issue_details}\n❌ Xray process dead"
            ((issues++))

            # Try to restart Xray via supervisor
            log "Attempting to restart Xray in $container"
            docker exec "$container" supervisorctl restart xray 2>&1 | tee -a "$LOG_FILE"
        fi
    fi

    # Check SSH access
    local ssh_port=$(docker port "$container" 22 2>/dev/null | cut -d: -f2)
    if [[ -n "$ssh_port" ]]; then
        if ! nc -z -w 5 localhost "$ssh_port" 2>/dev/null; then
            log "WARNING: SSH port $ssh_port not accessible for $container"
            issue_details="${issue_details}\n⚠️ SSH not accessible"
            ((issues++))
        fi
    fi

    # Check Nginx configuration for this profile
    local nginx_config="/etc/nginx/sites-enabled/${profile}.conf"
    if [[ -f "$nginx_config" ]]; then
        if ! nginx -t -c /etc/nginx/nginx.conf 2>&1 | grep -q "successful"; then
            log "ERROR: Nginx configuration test failed for $profile"
            issue_details="${issue_details}\n❌ Nginx config invalid"
            ((issues++))
        fi
    fi

    # Send notification if issues detected
    if (( issues > 0 )); then
        load_env
        local hostname=$(cat /etc/hostname)
        send_telegram "⚠️ *Health Check Alert*\nVPS: $hostname\nProfile: $profile\nIssues: $issues$issue_details"
    else
        log "OK: Profile $profile is healthy"
    fi

    return $issues
}

# Main execution (run once, called by cron-alternative.sh)
log "Health check started"

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
total_issues=0

for profile in $profiles; do
    check_profile_health "$profile"
    total_issues=$((total_issues + $?))
done

# Summary
if (( total_issues == 0 )); then
    log "All profiles healthy"
else
    log "Total issues detected: $total_issues"
fi

log "Health check completed"
