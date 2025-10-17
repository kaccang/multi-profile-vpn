#!/bin/bash

# ============================================
# VPN Multi-Profile Manager - SSL Certificate Auto-Renewal
# Automatically renew certificates that are expiring soon
# ============================================

set -e

BASE_DIR="/etc/xray-multi"
source "${BASE_DIR}/scripts/colors.sh"
source "${BASE_DIR}/scripts/utils.sh"
load_env

SSL_DIR="${BASE_DIR}/ssl-manager"
ACME_DIR="${SSL_DIR}/acme.sh"
CERT_DIR="${SSL_DIR}/certs"
LOG_FILE="${BASE_DIR}/logs/ssl-manager.log"

# Renew certificates with less than 60 days remaining
RENEW_DAYS=${SSL_RENEW_DAYS:-60}

# ============================================
# Logging
# ============================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# ============================================
# Check Certificate Expiry
# ============================================

check_certificate_expiry() {
    local domain=$1
    local cert_file="${CERT_DIR}/${domain}/cert.pem"

    if [[ ! -f "$cert_file" ]]; then
        log "WARN" "Certificate not found for $domain"
        return 1
    fi

    # Get expiry date
    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local now_epoch=$(date +%s)
    local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

    echo $days_remaining
}

# ============================================
# Renew Certificate
# ============================================

renew_certificate() {
    local domain=$1

    log "INFO" "Renewing certificate for $domain"

    # Renew using acme.sh
    if "${ACME_DIR}/acme.sh" --renew -d "$domain" --force >> "$LOG_FILE" 2>&1; then
        log "INFO" "Certificate renewed successfully for $domain"

        # Reinstall certificate
        "${ACME_DIR}/acme.sh" --install-cert -d "$domain" \
            --key-file "${CERT_DIR}/${domain}/privkey.pem" \
            --fullchain-file "${CERT_DIR}/${domain}/fullchain.pem" \
            --cert-file "${CERT_DIR}/${domain}/cert.pem" \
            --ca-file "${CERT_DIR}/${domain}/chain.pem" \
            >> "$LOG_FILE" 2>&1

        # Set permissions
        chmod 644 "${CERT_DIR}/${domain}"/*.pem

        log "INFO" "Certificate reinstalled for $domain"

        # Reload Nginx
        systemctl reload nginx

        # Send notification
        send_telegram "🔄 *SSL Certificate Renewed*\nDomain: $domain\nStatus: Success"

        return 0
    else
        log "ERROR" "Failed to renew certificate for $domain"
        send_telegram "❌ *SSL Certificate Renewal Failed*\nDomain: $domain\nStatus: Failed"
        return 1
    fi
}

# ============================================
# Check All Certificates
# ============================================

check_all_certificates() {
    log "INFO" "Checking all certificates for renewal"

    if [[ ! -d "$CERT_DIR" ]]; then
        log "WARN" "Certificate directory not found"
        return 0
    fi

    local renewed_count=0
    local failed_count=0

    for cert_domain in "$CERT_DIR"/*; do
        if [[ -d "$cert_domain" ]]; then
            local domain=$(basename "$cert_domain")

            log "INFO" "Checking certificate for $domain"

            local days_remaining=$(check_certificate_expiry "$domain")

            if [[ $? -ne 0 ]]; then
                log "WARN" "Could not check certificate for $domain"
                continue
            fi

            log "INFO" "$domain: $days_remaining days remaining"

            if (( days_remaining <= RENEW_DAYS )); then
                log "INFO" "$domain needs renewal (less than $RENEW_DAYS days remaining)"

                if renew_certificate "$domain"; then
                    renewed_count=$((renewed_count + 1))
                else
                    failed_count=$((failed_count + 1))
                fi
            else
                log "INFO" "$domain does not need renewal yet"
            fi
        fi
    done

    log "INFO" "Certificate renewal check completed: $renewed_count renewed, $failed_count failed"

    if (( renewed_count > 0 )) || (( failed_count > 0 )); then
        send_telegram "📋 *SSL Renewal Summary*\nRenewed: $renewed_count\nFailed: $failed_count"
    fi
}

# ============================================
# Main
# ============================================

case "$1" in
    check)
        check_all_certificates
        ;;
    renew)
        if [[ -z "$2" ]]; then
            echo "Usage: $0 renew <domain>"
            exit 1
        fi
        renew_certificate "$2"
        ;;
    *)
        echo "Usage: $0 {check|renew <domain>}"
        echo ""
        echo "  check       - Check all certificates and renew if needed"
        echo "  renew       - Force renew a specific domain certificate"
        exit 1
        ;;
esac
