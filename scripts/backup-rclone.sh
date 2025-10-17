#!/bin/bash

# ============================================
# Rclone Backup Uploader
# Upload backups using rclone (multi-cloud support)
# Supports: Google Drive, Dropbox, OneDrive, B2, etc.
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

LOG_FILE="/var/log/xray-multi/backup-rclone.log"
RCLONE_CONFIG="/root/.config/rclone/rclone.conf"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Check if rclone is installed
check_rclone() {
    if ! command -v rclone &> /dev/null; then
        log "ERROR: rclone not installed"
        echo "Installing rclone..."

        # Install rclone
        curl https://rclone.org/install.sh | bash 2>&1 | tee -a "$LOG_FILE"

        if command -v rclone &> /dev/null; then
            log "rclone installed successfully: $(rclone version | head -n1)"
        else
            log "ERROR: Failed to install rclone"
            return 1
        fi
    fi

    return 0
}

# Check rclone configuration
check_rclone_config() {
    local remote="${RCLONE_REMOTE}"

    if [[ -z "$remote" ]]; then
        log "ERROR: RCLONE_REMOTE not set in environment"
        echo "Please configure rclone remote first:"
        echo "  rclone config"
        return 1
    fi

    # Check if remote exists
    if ! rclone listremotes | grep -q "^${remote}:$"; then
        log "ERROR: Rclone remote '$remote' not found"
        echo "Available remotes:"
        rclone listremotes
        echo ""
        echo "Configure remote with: rclone config"
        return 1
    fi

    log "Using rclone remote: $remote"
    return 0
}

# Upload file via rclone
upload_to_rclone() {
    local file_path="$1"
    local remote="${RCLONE_REMOTE}"
    local dest_path="${RCLONE_PATH:-backups}"

    if [[ ! -f "$file_path" ]]; then
        log "ERROR: File not found: $file_path"
        return 1
    fi

    local filename=$(basename "$file_path")
    local dest="${remote}:${dest_path}/${filename}"

    log "Uploading $filename to $dest"

    # Build rclone command with options
    local rclone_opts=""

    # Progress display
    if [[ -t 1 ]]; then
        rclone_opts="$rclone_opts --progress"
    fi

    # Bandwidth limit (if set)
    if [[ -n "$RCLONE_BANDWIDTH_LIMIT" ]]; then
        rclone_opts="$rclone_opts --bwlimit $RCLONE_BANDWIDTH_LIMIT"
    fi

    # Transfers (parallel uploads)
    if [[ -n "$RCLONE_TRANSFERS" ]]; then
        rclone_opts="$rclone_opts --transfers $RCLONE_TRANSFERS"
    else
        rclone_opts="$rclone_opts --transfers 4"
    fi

    # Verbose logging
    rclone_opts="$rclone_opts --log-file $LOG_FILE --log-level INFO"

    # Execute upload
    rclone copy "$file_path" "${remote}:${dest_path}" $rclone_opts

    if [[ $? -eq 0 ]]; then
        log "Upload successful: $dest"

        # Verify upload
        local remote_size=$(rclone size "${remote}:${dest_path}/${filename}" --json 2>/dev/null | jq -r '.bytes')
        local local_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)

        if [[ "$remote_size" == "$local_size" ]]; then
            log "Upload verified: size matches ($local_size bytes)"
        else
            log "WARNING: Size mismatch - local: $local_size, remote: $remote_size"
        fi

        # Get file size in human readable format
        local size=$(du -h "$file_path" | cut -f1)
        send_telegram "☁️ *Rclone Backup Upload*\\nRemote: $remote\\nPath: $dest_path\\nFile: $filename\\nSize: $size\\nStatus: Success"

        return 0
    else
        log "ERROR: Upload failed"
        send_telegram "❌ *Rclone Upload Failed*\\nRemote: $remote\\nFile: $filename\\nCheck logs: $LOG_FILE"
        return 1
    fi
}

# List backups in remote
list_rclone_backups() {
    local remote="${RCLONE_REMOTE}"
    local dest_path="${RCLONE_PATH:-backups}"

    log "Listing backups in ${remote}:${dest_path}"

    rclone ls "${remote}:${dest_path}" --human-readable 2>&1 | tee -a "$LOG_FILE"
}

# Delete old backups from remote
cleanup_rclone_backups() {
    local remote="${RCLONE_REMOTE}"
    local dest_path="${RCLONE_PATH:-backups}"
    local retention_days="${RCLONE_RETENTION_DAYS:-30}"

    log "Cleaning up backups older than $retention_days days from ${remote}:${dest_path}"

    # Use rclone delete with --min-age flag
    rclone delete "${remote}:${dest_path}" --min-age "${retention_days}d" --log-file "$LOG_FILE" --log-level INFO

    if [[ $? -eq 0 ]]; then
        log "Cleanup completed successfully"
    else
        log "WARNING: Cleanup encountered errors"
    fi
}

# Download backup from remote (for restore)
download_from_rclone() {
    local filename="$1"
    local dest_dir="${2:-/var/backups/xray-multi}"
    local remote="${RCLONE_REMOTE}"
    local remote_path="${RCLONE_PATH:-backups}"

    if [[ -z "$filename" ]]; then
        log "ERROR: No filename specified"
        return 1
    fi

    mkdir -p "$dest_dir"

    log "Downloading $filename from ${remote}:${remote_path}"

    rclone copy "${remote}:${remote_path}/${filename}" "$dest_dir" --progress --log-file "$LOG_FILE" --log-level INFO

    if [[ $? -eq 0 ]]; then
        log "Download successful: ${dest_dir}/${filename}"
        echo "${dest_dir}/${filename}"
        return 0
    else
        log "ERROR: Download failed"
        return 1
    fi
}

# Test rclone connection
test_rclone() {
    local remote="${RCLONE_REMOTE}"

    log "Testing connection to $remote"

    rclone lsd "${remote}:" --max-depth 1 2>&1 | tee -a "$LOG_FILE"

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "Connection test successful"
        return 0
    else
        log "ERROR: Connection test failed"
        return 1
    fi
}

# Main execution
main() {
    local file_path="$1"

    if [[ -z "$file_path" ]]; then
        echo "Usage: $0 <backup_file>"
        echo ""
        echo "Environment variables required:"
        echo "  RCLONE_REMOTE           - Rclone remote name (configured via 'rclone config')"
        echo "  RCLONE_PATH             - Remote path (default: backups)"
        echo "  RCLONE_BANDWIDTH_LIMIT  - Bandwidth limit (e.g., 10M, 1G)"
        echo "  RCLONE_TRANSFERS        - Number of parallel transfers (default: 4)"
        echo "  RCLONE_RETENTION_DAYS   - Retention period (default: 30)"
        echo ""
        echo "Configure rclone remote with: rclone config"
        exit 1
    fi

    log "========== RCLONE UPLOAD STARTED =========="

    # Load environment
    load_env

    # Check and install rclone
    check_rclone || exit 1

    # Check rclone configuration
    check_rclone_config || exit 1

    # Test connection
    test_rclone || exit 1

    # Upload backup
    upload_to_rclone "$file_path" || exit 1

    # Cleanup old backups
    if [[ "${RCLONE_AUTO_CLEANUP}" == "true" ]]; then
        cleanup_rclone_backups
    fi

    log "========== RCLONE UPLOAD COMPLETED =========="
}

# Run main function
main "$@"
