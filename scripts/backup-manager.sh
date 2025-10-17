#!/bin/bash

# ============================================
# Backup Manager
# Main backup orchestrator for VPN profiles
# Supports S3, Rclone, and local backups
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

BACKUP_DIR="/var/backups/xray-multi"
LOG_FILE="/var/log/xray-multi/backup.log"
RETENTION_DAYS=30  # Keep backups for 30 days

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Create backup directory
create_backup_dir() {
    local backup_date=$(date +%Y%m%d-%H%M%S)
    local backup_path="${BACKUP_DIR}/${backup_date}"

    mkdir -p "$backup_path"
    echo "$backup_path"
}

# Backup profiles.json
backup_profiles_config() {
    local backup_path="$1"

    if [[ -f /etc/xray-multi/profiles.json ]]; then
        cp /etc/xray-multi/profiles.json "${backup_path}/profiles.json"
        log "Backed up profiles.json"
    else
        log "WARNING: profiles.json not found"
    fi
}

# Backup SSL certificates
backup_ssl_certs() {
    local backup_path="$1"
    local ssl_dir="${backup_path}/ssl"

    mkdir -p "$ssl_dir"

    # Backup acme.sh certificates
    if [[ -d /root/.acme.sh ]]; then
        rsync -a /root/.acme.sh/ "${ssl_dir}/acme.sh/" --exclude="*.sh"
        log "Backed up SSL certificates from acme.sh"
    fi

    # Backup Nginx SSL configs
    if [[ -d /etc/nginx/sites-enabled ]]; then
        mkdir -p "${ssl_dir}/nginx"
        cp -r /etc/nginx/sites-enabled/* "${ssl_dir}/nginx/" 2>/dev/null
        log "Backed up Nginx site configs"
    fi
}

# Backup individual profile data
backup_profile_data() {
    local backup_path="$1"
    local profile="$2"
    local container="${profile}-vpn"

    local profile_dir="${backup_path}/profiles/${profile}"
    mkdir -p "$profile_dir"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        log "WARNING: Container $container does not exist, skipping"
        return 1
    fi

    # Backup Xray config
    docker cp "${container}:/etc/xray/config.json" "${profile_dir}/config.json" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log "Backed up Xray config for $profile"
    fi

    # Backup user data
    docker cp "${container}:/etc/xray/users/" "${profile_dir}/users/" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log "Backed up user data for $profile"
    fi

    # Backup paths.env
    docker cp "${container}:/etc/xray/paths.env" "${profile_dir}/paths.env" 2>/dev/null

    # Export bandwidth stats
    docker exec "$container" vnstat --json > "${profile_dir}/vnstat.json" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log "Exported bandwidth stats for $profile"
    fi

    # Backup SSH keys
    docker cp "${container}:/etc/ssh/" "${profile_dir}/ssh/" 2>/dev/null

    # Create profile metadata
    cat > "${profile_dir}/metadata.json" << EOF
{
  "profile": "$profile",
  "backup_date": "$(date -Iseconds)",
  "container": "$container",
  "status": "$(docker inspect --format='{{.State.Status}}' $container 2>/dev/null)"
}
EOF

    log "Backed up profile data for $profile"
    return 0
}

# Create backup archive
create_backup_archive() {
    local backup_path="$1"
    local backup_name=$(basename "$backup_path")
    local archive_path="${BACKUP_DIR}/${backup_name}.tar.gz"

    log "Creating backup archive: $archive_path"

    tar -czf "$archive_path" -C "${BACKUP_DIR}" "$backup_name" 2>&1 | tee -a "$LOG_FILE"

    if [[ $? -eq 0 ]]; then
        # Remove uncompressed backup
        rm -rf "$backup_path"

        # Get archive size
        local size=$(du -h "$archive_path" | cut -f1)
        log "Backup archive created: $archive_path ($size)"

        echo "$archive_path"
        return 0
    else
        log "ERROR: Failed to create backup archive"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days"

    find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>&1 | tee -a "$LOG_FILE"

    local remaining=$(find "$BACKUP_DIR" -type f -name "*.tar.gz" | wc -l)
    log "Remaining backups: $remaining"
}

# Upload backup to remote storage
upload_backup() {
    local archive_path="$1"
    local backup_method="${BACKUP_METHOD:-local}"

    case "$backup_method" in
        s3)
            log "Uploading backup to S3..."
            /etc/xray-multi/scripts/backup-s3.sh "$archive_path"
            ;;
        rclone)
            log "Uploading backup via rclone..."
            /etc/xray-multi/scripts/backup-rclone.sh "$archive_path"
            ;;
        local)
            log "Backup stored locally only"
            ;;
        *)
            log "WARNING: Unknown backup method: $backup_method"
            ;;
    esac
}

# Main backup execution
main() {
    log "========== BACKUP STARTED =========="

    # Load environment variables
    load_env

    # Create backup directory
    backup_path=$(create_backup_dir)
    log "Backup path: $backup_path"

    # Backup global configs
    backup_profiles_config "$backup_path"
    backup_ssl_certs "$backup_path"

    # Backup each profile
    if [[ -f /etc/xray-multi/profiles.json ]]; then
        profiles=$(jq -r '.profiles[].name' /etc/xray-multi/profiles.json 2>/dev/null)

        if [[ -n "$profiles" ]]; then
            profile_count=0

            for profile in $profiles; do
                backup_profile_data "$backup_path" "$profile"
                if [[ $? -eq 0 ]]; then
                    ((profile_count++))
                fi
            done

            log "Backed up $profile_count profiles"
        else
            log "No profiles found to backup"
        fi
    fi

    # Create archive
    archive_path=$(create_backup_archive "$backup_path")

    if [[ $? -eq 0 ]]; then
        # Upload to remote storage
        upload_backup "$archive_path"

        # Clean old backups
        cleanup_old_backups

        # Send notification
        local hostname=$(cat /etc/hostname)
        local size=$(du -h "$archive_path" | cut -f1)
        send_telegram "💾 *Backup Completed*\nVPS: $hostname\nSize: $size\nProfiles: $profile_count\nLocation: $archive_path"

        log "========== BACKUP COMPLETED =========="
        exit 0
    else
        log "========== BACKUP FAILED =========="
        send_telegram "❌ *Backup Failed*\nVPS: $(cat /etc/hostname)\nCheck logs: $LOG_FILE"
        exit 1
    fi
}

# Run main function
main
