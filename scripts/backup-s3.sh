#!/bin/bash

# ============================================
# S3 Backup Uploader
# Upload backups to S3-compatible storage
# Supports: AWS S3, DigitalOcean Spaces, MinIO, etc.
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

LOG_FILE="/var/log/xray-multi/backup-s3.log"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log "ERROR: AWS CLI not installed"
        echo "Installing AWS CLI..."

        # Install AWS CLI v2
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        unzip -q /tmp/awscliv2.zip -d /tmp/
        /tmp/aws/install --update
        rm -rf /tmp/awscliv2.zip /tmp/aws

        if command -v aws &> /dev/null; then
            log "AWS CLI installed successfully"
        else
            log "ERROR: Failed to install AWS CLI"
            return 1
        fi
    fi

    return 0
}

# Configure AWS credentials
configure_aws() {
    # Load from environment
    load_env

    if [[ -z "$S3_ACCESS_KEY" ]] || [[ -z "$S3_SECRET_KEY" ]]; then
        log "ERROR: S3_ACCESS_KEY or S3_SECRET_KEY not set in environment"
        return 1
    fi

    # Configure AWS CLI
    aws configure set aws_access_key_id "$S3_ACCESS_KEY"
    aws configure set aws_secret_access_key "$S3_SECRET_KEY"
    aws configure set default.region "${S3_REGION:-us-east-1}"

    # Set endpoint if using S3-compatible storage (DigitalOcean Spaces, MinIO, etc.)
    if [[ -n "$S3_ENDPOINT" ]]; then
        log "Using custom S3 endpoint: $S3_ENDPOINT"
    fi

    log "AWS credentials configured"
    return 0
}

# Upload file to S3
upload_to_s3() {
    local file_path="$1"
    local bucket="${S3_BUCKET}"
    local prefix="${S3_PREFIX:-backups}"

    if [[ ! -f "$file_path" ]]; then
        log "ERROR: File not found: $file_path"
        return 1
    fi

    if [[ -z "$bucket" ]]; then
        log "ERROR: S3_BUCKET not set in environment"
        return 1
    fi

    local filename=$(basename "$file_path")
    local s3_key="${prefix}/${filename}"

    log "Uploading $filename to s3://${bucket}/${s3_key}"

    # Build AWS CLI command
    local aws_cmd="aws s3 cp \"$file_path\" \"s3://${bucket}/${s3_key}\""

    # Add endpoint if specified
    if [[ -n "$S3_ENDPOINT" ]]; then
        aws_cmd="${aws_cmd} --endpoint-url \"$S3_ENDPOINT\""
    fi

    # Add server-side encryption if enabled
    if [[ "$S3_ENCRYPTION" == "true" ]]; then
        aws_cmd="${aws_cmd} --server-side-encryption AES256"
    fi

    # Add storage class if specified
    if [[ -n "$S3_STORAGE_CLASS" ]]; then
        aws_cmd="${aws_cmd} --storage-class \"$S3_STORAGE_CLASS\""
    fi

    # Execute upload
    eval $aws_cmd 2>&1 | tee -a "$LOG_FILE"

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "Upload successful: s3://${bucket}/${s3_key}"

        # Get file size
        local size=$(du -h "$file_path" | cut -f1)
        send_telegram "☁️ *S3 Backup Upload*\nBucket: $bucket\nFile: $filename\nSize: $size\nStatus: Success"

        return 0
    else
        log "ERROR: Upload failed"
        send_telegram "❌ *S3 Upload Failed*\nBucket: $bucket\nFile: $filename\nCheck logs: $LOG_FILE"
        return 1
    fi
}

# List backups in S3
list_s3_backups() {
    local bucket="${S3_BUCKET}"
    local prefix="${S3_PREFIX:-backups}"

    log "Listing backups in s3://${bucket}/${prefix}"

    local aws_cmd="aws s3 ls \"s3://${bucket}/${prefix}/\" --human-readable"

    if [[ -n "$S3_ENDPOINT" ]]; then
        aws_cmd="${aws_cmd} --endpoint-url \"$S3_ENDPOINT\""
    fi

    eval $aws_cmd 2>&1 | tee -a "$LOG_FILE"
}

# Delete old backups from S3
cleanup_s3_backups() {
    local bucket="${S3_BUCKET}"
    local prefix="${S3_PREFIX:-backups}"
    local retention_days="${S3_RETENTION_DAYS:-30}"

    log "Cleaning up S3 backups older than $retention_days days"

    # Get list of old backups
    local cutoff_date=$(date -d "$retention_days days ago" +%s)

    local aws_cmd="aws s3 ls \"s3://${bucket}/${prefix}/\" --recursive"

    if [[ -n "$S3_ENDPOINT" ]]; then
        aws_cmd="${aws_cmd} --endpoint-url \"$S3_ENDPOINT\""
    fi

    eval $aws_cmd | while read -r line; do
        # Parse date and filename from AWS CLI output
        # Format: 2024-01-15 12:34:56    1234567 backups/20240115-123456.tar.gz
        local file_date=$(echo "$line" | awk '{print $1" "$2}')
        local file_path=$(echo "$line" | awk '{print $4}')

        local file_epoch=$(date -d "$file_date" +%s 2>/dev/null)

        if [[ -n "$file_epoch" ]] && (( file_epoch < cutoff_date )); then
            log "Deleting old backup: $file_path"

            local delete_cmd="aws s3 rm \"s3://${bucket}/${file_path}\""

            if [[ -n "$S3_ENDPOINT" ]]; then
                delete_cmd="${delete_cmd} --endpoint-url \"$S3_ENDPOINT\""
            fi

            eval $delete_cmd 2>&1 | tee -a "$LOG_FILE"
        fi
    done

    log "S3 cleanup completed"
}

# Main execution
main() {
    local file_path="$1"

    if [[ -z "$file_path" ]]; then
        echo "Usage: $0 <backup_file>"
        echo "Environment variables required:"
        echo "  S3_ACCESS_KEY    - S3 access key"
        echo "  S3_SECRET_KEY    - S3 secret key"
        echo "  S3_BUCKET        - S3 bucket name"
        echo "  S3_REGION        - S3 region (default: us-east-1)"
        echo "  S3_ENDPOINT      - Custom S3 endpoint (optional)"
        echo "  S3_PREFIX        - S3 key prefix (default: backups)"
        echo "  S3_ENCRYPTION    - Enable encryption (true/false)"
        echo "  S3_STORAGE_CLASS - Storage class (STANDARD, GLACIER, etc.)"
        exit 1
    fi

    log "========== S3 UPLOAD STARTED =========="

    # Check and install AWS CLI
    check_aws_cli || exit 1

    # Configure AWS credentials
    configure_aws || exit 1

    # Upload backup
    upload_to_s3 "$file_path" || exit 1

    # Cleanup old backups
    if [[ "${S3_AUTO_CLEANUP}" == "true" ]]; then
        cleanup_s3_backups
    fi

    log "========== S3 UPLOAD COMPLETED =========="
}

# Run main function
main "$@"
