#!/bin/bash

# ============================================
# Cron Alternative for Docker Containers
# Provides scheduling without systemd/cron
# Runs monitoring tasks on schedule
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

LOG_FILE="/var/log/xray-multi/scheduler.log"
PID_FILE="/var/run/xray-multi-scheduler.pid"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Check if already running
if [[ -f "$PID_FILE" ]]; then
    old_pid=$(cat "$PID_FILE")
    if ps -p "$old_pid" > /dev/null 2>&1; then
        echo "Scheduler already running with PID $old_pid"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# Write PID
echo $$ > "$PID_FILE"

# Cleanup on exit
cleanup() {
    log "Scheduler stopping..."
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

log "Scheduler started with PID $$"

# Initialize counters
health_check_counter=0
bandwidth_check_counter=0
expiration_check_counter=0
ssl_renew_counter=0
cleanup_counter=0

# Intervals in seconds
HEALTH_CHECK_INTERVAL=300      # 5 minutes
BANDWIDTH_CHECK_INTERVAL=3600  # 1 hour
EXPIRATION_CHECK_INTERVAL=86400  # 24 hours
SSL_RENEW_INTERVAL=86400       # 24 hours
CLEANUP_INTERVAL=604800        # 7 days

# Main scheduler loop
while true; do
    current_time=$(date +%s)

    # Health check (every 5 minutes)
    if (( current_time - health_check_counter >= HEALTH_CHECK_INTERVAL )); then
        log "Running health check..."
        /etc/xray-multi/scripts/health-check.sh >> "$LOG_FILE" 2>&1
        health_check_counter=$current_time
    fi

    # Bandwidth monitoring (every hour)
    if (( current_time - bandwidth_check_counter >= BANDWIDTH_CHECK_INTERVAL )); then
        log "Running bandwidth monitor..."
        /etc/xray-multi/scripts/bandwidth-monitor.sh >> "$LOG_FILE" 2>&1
        bandwidth_check_counter=$current_time
    fi

    # Expiration check (daily at 00:05)
    current_hour=$(date +%H)
    current_minute=$(date +%M)
    if [[ "$current_hour" == "00" ]] && [[ "$current_minute" == "05" ]]; then
        if (( current_time - expiration_check_counter >= EXPIRATION_CHECK_INTERVAL )); then
            log "Running expiration check..."
            /etc/xray-multi/scripts/expiration-check.sh >> "$LOG_FILE" 2>&1
            expiration_check_counter=$current_time
        fi
    fi

    # SSL renewal check (daily at 03:00)
    if [[ "$current_hour" == "03" ]] && [[ "$current_minute" == "00" ]]; then
        if (( current_time - ssl_renew_counter >= SSL_RENEW_INTERVAL )); then
            log "Running SSL renewal check..."
            /etc/xray-multi/scripts/ssl-renew.sh >> "$LOG_FILE" 2>&1
            ssl_renew_counter=$current_time
        fi
    fi

    # Log cleanup (weekly on Sunday at 02:00)
    day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
    if [[ "$day_of_week" == "7" ]] && [[ "$current_hour" == "02" ]] && [[ "$current_minute" == "00" ]]; then
        if (( current_time - cleanup_counter >= CLEANUP_INTERVAL )); then
            log "Running log cleanup..."

            # Keep last 30 days of logs
            find /var/log/xray-multi/ -type f -name "*.log" -mtime +30 -delete 2>&1 | tee -a "$LOG_FILE"

            # Rotate large log files (>100MB)
            for logfile in /var/log/xray-multi/*.log; do
                if [[ -f "$logfile" ]]; then
                    size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null)
                    if (( size > 104857600 )); then  # 100MB
                        log "Rotating large log file: $logfile"
                        mv "$logfile" "${logfile}.old"
                        touch "$logfile"
                    fi
                fi
            done

            cleanup_counter=$current_time
        fi
    fi

    # Sleep for 1 minute before next check
    sleep 60
done
