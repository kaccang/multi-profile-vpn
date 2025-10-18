#!/bin/bash

# ============================================
# VPN Multi-Profile Manager - SSL Manager
# Queue-based certificate issuance with rate limit protection
# ============================================

set -e

BASE_DIR="/etc/xray-multi"
source "${BASE_DIR}/scripts/colors.sh"
source "${BASE_DIR}/scripts/utils.sh"
load_env

SSL_DIR="${BASE_DIR}/ssl-manager"
ACME_DIR="${SSL_DIR}/acme.sh"
CERT_DIR="${SSL_DIR}/certs"
QUEUE_FILE="${SSL_DIR}/queue.json"
LOG_FILE="${BASE_DIR}/logs/ssl-manager.log"

# Rate limit: 5 certificates per hour per IP (Let's Encrypt limit)
MAX_CERTS_PER_HOUR=5
HOUR_IN_SECONDS=3600

# ============================================
# Logging Function
# ============================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    echo -e "${CYAN}[${level}]${NC} ${message}"
}

# ============================================
# Queue Management
# ============================================

init_queue() {
    if [[ ! -f "$QUEUE_FILE" ]]; then
        echo '{"queue": [], "processing": [], "completed": []}' > "$QUEUE_FILE"
        log "INFO" "Queue file initialized"
    fi
}

add_to_queue() {
    local domain=$1
    local profile=$2

    init_queue

    # Check if domain already in queue or processing
    if jq -e ".queue[] | select(.domain == \"$domain\")" "$QUEUE_FILE" > /dev/null 2>&1; then
        log "WARN" "Domain $domain already in queue"
        return 1
    fi

    if jq -e ".processing[] | select(.domain == \"$domain\")" "$QUEUE_FILE" > /dev/null 2>&1; then
        log "WARN" "Domain $domain is being processed"
        return 1
    fi

    # Add to queue
    local timestamp=$(date +%s)
    local entry=$(jq -n \
        --arg domain "$domain" \
        --arg profile "$profile" \
        --arg timestamp "$timestamp" \
        '{domain: $domain, profile: $profile, timestamp: $timestamp, attempts: 0}')

    jq ".queue += [$entry]" "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

    log "INFO" "Added domain $domain to queue"
    return 0
}

get_next_from_queue() {
    init_queue

    local next=$(jq -r '.queue[0] // empty' "$QUEUE_FILE")

    if [[ -n "$next" ]]; then
        echo "$next"
        return 0
    else
        return 1
    fi
}

move_to_processing() {
    local domain=$1

    init_queue

    # Move from queue to processing
    local entry=$(jq ".queue[] | select(.domain == \"$domain\")" "$QUEUE_FILE")

    jq "del(.queue[] | select(.domain == \"$domain\")) | .processing += [$entry]" "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

    log "INFO" "Moved $domain to processing"
}

move_to_completed() {
    local domain=$1
    local status=$2

    init_queue

    # Move from processing to completed
    local entry=$(jq ".processing[] | select(.domain == \"$domain\")" "$QUEUE_FILE")
    local completed_time=$(date +%s)

    entry=$(echo "$entry" | jq --arg status "$status" --arg time "$completed_time" '. + {status: $status, completed: $time}')

    jq "del(.processing[] | select(.domain == \"$domain\")) | .completed += [$entry]" "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

    log "INFO" "Moved $domain to completed with status: $status"
}

check_rate_limit() {
    init_queue

    local now=$(date +%s)
    local hour_ago=$((now - HOUR_IN_SECONDS))

    # Count certificates issued in the last hour
    local count=$(jq "[.completed[] | select(.completed > $hour_ago and .status == \"success\")] | length" "$QUEUE_FILE")

    if (( count >= MAX_CERTS_PER_HOUR )); then
        log "WARN" "Rate limit reached: $count certificates issued in the last hour"
        return 1
    fi

    return 0
}

# ============================================
# Certificate Operations
# ============================================

request_certificate() {
    local domain=$1
    local profile=$2

    log "INFO" "Requesting certificate for $domain (profile: $profile)"

    # Create cert directory
    mkdir -p "${CERT_DIR}/${domain}"

    # Request certificate using acme.sh
    if "${ACME_DIR}/acme.sh" --issue \
        -d "$domain" \
        --webroot "/var/www/html" \
        --keylength 2048 \
        --server letsencrypt >> "$LOG_FILE" 2>&1; then

        log "INFO" "Certificate issued successfully for $domain"

        # Install certificate
        "${ACME_DIR}/acme.sh" --install-cert -d "$domain" \
            --key-file "${CERT_DIR}/${domain}/privkey.pem" \
            --fullchain-file "${CERT_DIR}/${domain}/fullchain.pem" \
            --cert-file "${CERT_DIR}/${domain}/cert.pem" \
            --ca-file "${CERT_DIR}/${domain}/chain.pem" \
            >> "$LOG_FILE" 2>&1

        # Set permissions
        chmod 644 "${CERT_DIR}/${domain}"/*.pem

        log "INFO" "Certificate installed for $domain"

        # Create Nginx site config
        create_nginx_config "$domain" "$profile"

        # Reload Nginx
        systemctl reload nginx

        # Send Telegram notification
        send_telegram "✅ *SSL Certificate Issued*\nDomain: $domain\nProfile: $profile\nStatus: Success"

        return 0
    else
        log "ERROR" "Failed to issue certificate for $domain"
        send_telegram "❌ *SSL Certificate Failed*\nDomain: $domain\nProfile: $profile\nStatus: Failed"
        return 1
    fi
}

create_nginx_config() {
    local domain=$1
    local profile=$2

    log "INFO" "Creating Nginx configuration for $domain"

    # Get profile metadata
    local container_ip=$(get_profile_meta "$profile" "IP")
    local vmess_path=$(grep "PATH_VMESS=" "${BASE_DIR}/profiles/${profile}/xray/paths.env" | cut -d= -f2)
    local vless_path=$(grep "PATH_VLESS=" "${BASE_DIR}/profiles/${profile}/xray/paths.env" | cut -d= -f2)
    local trojan_path=$(grep "PATH_TROJAN=" "${BASE_DIR}/profiles/${profile}/xray/paths.env" | cut -d= -f2)

    # Generate config from template
    cat > "${BASE_DIR}/nginx/sites/${domain}.conf" << 'EOFNGINX'
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;

    # SSL Configuration
    ssl_certificate CERT_DIR_PLACEHOLDER/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key CERT_DIR_PLACEHOLDER/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_trusted_certificate CERT_DIR_PLACEHOLDER/DOMAIN_PLACEHOLDER/chain.pem;

    include BASE_DIR_PLACEHOLDER/nginx/ssl-params.conf;

    # Access & Error Logs
    access_log /var/log/nginx/DOMAIN_PLACEHOLDER-access.log main;
    error_log /var/log/nginx/DOMAIN_PLACEHOLDER-error.log warn;

    # Default location
    location / {
        return 403 "Forbidden";
    }

    # VMess WebSocket
    location VMESS_PATH_PLACEHOLDER {
        if (\$http_upgrade != "websocket") {
            return 404;
        }

        proxy_pass http://CONTAINER_IP_PLACEHOLDER:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_buffering off;
        proxy_redirect off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;

        limit_req zone=ws burst=20 nodelay;
    }

    # VLess WebSocket
    location VLESS_PATH_PLACEHOLDER {
        if (\$http_upgrade != "websocket") {
            return 404;
        }

        proxy_pass http://CONTAINER_IP_PLACEHOLDER:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_buffering off;
        proxy_redirect off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;

        limit_req zone=ws burst=20 nodelay;
    }

    # Trojan WebSocket
    location TROJAN_PATH_PLACEHOLDER {
        if (\$http_upgrade != "websocket") {
            return 404;
        }

        proxy_pass http://CONTAINER_IP_PLACEHOLDER:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_buffering off;
        proxy_redirect off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;

        limit_req zone=ws burst=20 nodelay;
    }
}
EOFNGINX

    # Replace placeholders
    sed -i "s|DOMAIN_PLACEHOLDER|$domain|g" "${BASE_DIR}/nginx/sites/${domain}.conf"
    sed -i "s|CERT_DIR_PLACEHOLDER|$CERT_DIR|g" "${BASE_DIR}/nginx/sites/${domain}.conf"
    sed -i "s|BASE_DIR_PLACEHOLDER|$BASE_DIR|g" "${BASE_DIR}/nginx/sites/${domain}.conf"
    sed -i "s|CONTAINER_IP_PLACEHOLDER|$container_ip|g" "${BASE_DIR}/nginx/sites/${domain}.conf"
    sed -i "s|VMESS_PATH_PLACEHOLDER|$vmess_path|g" "${BASE_DIR}/nginx/sites/${domain}.conf"
    sed -i "s|VLESS_PATH_PLACEHOLDER|$vless_path|g" "${BASE_DIR}/nginx/sites/${domain}.conf"
    sed -i "s|TROJAN_PATH_PLACEHOLDER|$trojan_path|g" "${BASE_DIR}/nginx/sites/${domain}.conf"

    log "INFO" "Nginx configuration created for $domain"
}

# ============================================
# Daemon Mode
# ============================================

daemon_loop() {
    log "INFO" "SSL Manager daemon started"

    while true; do
        # Check if we can process
        if ! check_rate_limit; then
            log "INFO" "Rate limit reached, waiting 10 minutes..."
            sleep 600
            continue
        fi

        # Get next domain from queue
        if next=$(get_next_from_queue); then
            domain=$(echo "$next" | jq -r '.domain')
            profile=$(echo "$next" | jq -r '.profile')

            log "INFO" "Processing: $domain"

            move_to_processing "$domain"

            if request_certificate "$domain" "$profile"; then
                move_to_completed "$domain" "success"
            else
                move_to_completed "$domain" "failed"
            fi
        else
            # No items in queue, sleep for 30 seconds
            sleep 30
        fi
    done
}

# ============================================
# Main
# ============================================

case "$1" in
    daemon)
        daemon_loop
        ;;
    request)
        if [[ -z "$2" ]] || [[ -z "$3" ]]; then
            echo "Usage: $0 request <domain> <profile>"
            exit 1
        fi
        add_to_queue "$2" "$3"
        ;;
    status)
        init_queue
        echo "SSL Manager Queue Status:"
        echo ""
        echo "Queue:"
        jq -r '.queue[] | "  - \(.domain) (\(.profile))"' "$QUEUE_FILE" || echo "  (empty)"
        echo ""
        echo "Processing:"
        jq -r '.processing[] | "  - \(.domain) (\(.profile))"' "$QUEUE_FILE" || echo "  (empty)"
        echo ""
        echo "Completed (last 10):"
        jq -r '.completed[-10:] [] | "  - \(.domain): \(.status)"' "$QUEUE_FILE" || echo "  (empty)"
        ;;
    *)
        echo "Usage: $0 {daemon|request|status}"
        exit 1
        ;;
esac
