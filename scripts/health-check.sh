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

show_status() {
    clear
    print_banner

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}SYSTEM HEALTH CHECK${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"

    # Check Docker service
    if systemctl is-active --quiet docker; then
        printf "${CYAN}║${NC} Docker Service      : ${GREEN}✔ Running${NC}                              ${CYAN}║${NC}\n"
    else
        printf "${CYAN}║${NC} Docker Service      : ${RED}✖ Stopped${NC}                              ${CYAN}║${NC}\n"
    fi

    # Check Nginx service
    if systemctl is-active --quiet nginx; then
        printf "${CYAN}║${NC} Nginx Service       : ${GREEN}✔ Running${NC}                              ${CYAN}║${NC}\n"
    else
        printf "${CYAN}║${NC} Nginx Service       : ${RED}✖ Stopped${NC}                              ${CYAN}║${NC}\n"
    fi

    # Disk space
    local disk_free=$(df -h / | awk 'NR==2 {print $4}')
    local disk_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if (( disk_percent < 80 )); then
        printf "${CYAN}║${NC} Disk Space          : ${GREEN}✔ %s free (%d%% used)${NC}                 ${CYAN}║${NC}\n" "$disk_free" "$disk_percent"
    else
        printf "${CYAN}║${NC} Disk Space          : ${YELLOW}⚠ %s free (%d%% used)${NC}                ${CYAN}║${NC}\n" "$disk_free" "$disk_percent"
    fi

    # Memory
    local mem_free=$(free -m | awk 'NR==2 {print $7}')
    local mem_percent=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
    if (( mem_percent < 80 )); then
        printf "${CYAN}║${NC} Memory              : ${GREEN}✔ %sMB free (%d%% used)${NC}               ${CYAN}║${NC}\n" "$mem_free" "$mem_percent"
    else
        printf "${CYAN}║${NC} Memory              : ${YELLOW}⚠ %sMB free (%d%% used)${NC}              ${CYAN}║${NC}\n" "$mem_free" "$mem_percent"
    fi

    # CPU Load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    printf "${CYAN}║${NC} CPU Load            : ${GREEN}✔ Normal (%s)${NC}                       ${CYAN}║${NC}\n" "$cpu_load"

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}PROFILES${NC}                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"

    # Check profiles
    local profiles=$(jq -r '.profiles[].name' /etc/xray-multi/profiles.json 2>/dev/null)

    if [[ -z "$profiles" ]]; then
        printf "${CYAN}║${NC} ${YELLOW}No profiles configured${NC}                                       ${CYAN}║${NC}\n"
    else
        while IFS= read -r profile; do
            local container="${profile}-vpn"
            local status_text=""
            local health_text=""

            # Check container status
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                status_text="${GREEN}✔ Running${NC}"

                # Check health
                local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
                if [[ "$health" == "healthy" ]] || [[ -z "$health" ]]; then
                    health_text="${GREEN}✔ Healthy${NC}"
                elif [[ "$health" == "unhealthy" ]]; then
                    health_text="${RED}⚠ Unhealthy${NC}"
                else
                    health_text="${YELLOW}⚠ Starting${NC}"
                fi
            else
                status_text="${RED}✖ Stopped${NC}"
                health_text="${RED}✖ N/A${NC}"
            fi

            printf "${CYAN}║${NC} %-20s : %b   %b                  ${CYAN}║${NC}\n" "$profile" "$status_text" "$health_text"
        done <<< "$profiles"
    fi

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

run_monitor() {
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
}

# Main
case "${1:-monitor}" in
    status)
        show_status
        ;;
    monitor)
        run_monitor
        ;;
    *)
        echo "Usage: $0 {status|monitor}"
        exit 1
        ;;
esac
