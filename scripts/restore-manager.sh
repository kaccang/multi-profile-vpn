#!/bin/bash

# ============================================
# Restore Manager
# Restore VPN profiles from backup
# Supports local, S3, and rclone backups
# ============================================

source /etc/xray-multi/scripts/colors.sh
source /etc/xray-multi/scripts/utils.sh

BACKUP_DIR="/var/backups/xray-multi"
LOG_FILE="/var/log/xray-multi/restore.log"
TEMP_DIR="/tmp/xray-restore-$$"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Cleanup on exit
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# List available backups
list_backups() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                 ${BOLD}AVAILABLE BACKUPS${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "No backup directory found: $BACKUP_DIR"
        return 1
    fi

    local backups=$(find "$BACKUP_DIR" -type f -name "*.tar.gz" | sort -r)

    if [[ -z "$backups" ]]; then
        print_error "No backups found"
        return 1
    fi

    echo -e "${YELLOW}Local backups:${NC}"
    echo ""

    local i=1
    declare -g -A backup_files

    while IFS= read -r backup_file; do
        local filename=$(basename "$backup_file")
        local size=$(du -h "$backup_file" | cut -f1)
        local date=$(echo "$filename" | sed 's/\.tar\.gz//' | sed 's/\([0-9]\{8\}\)-\([0-9]\{6\}\)/\1 \2/')

        printf "${WHITE}%2d)${NC} %-30s ${CYAN}%8s${NC} %s\\n" $i "$filename" "$size" "$date"

        backup_files[$i]="$backup_file"
        i=$((i + 1))
    done <<< "$backups"

    echo ""
    return 0
}

# Extract backup archive
extract_backup() {
    local archive_path="$1"

    if [[ ! -f "$archive_path" ]]; then
        log "ERROR: Backup file not found: $archive_path"
        return 1
    fi

    mkdir -p "$TEMP_DIR"

    log "Extracting backup: $archive_path"

    tar -xzf "$archive_path" -C "$TEMP_DIR" 2>&1 | tee -a "$LOG_FILE"

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "Backup extracted to: $TEMP_DIR"

        # Find the backup directory (should be only one)
        local backup_data=$(find "$TEMP_DIR" -maxdepth 1 -type d ! -path "$TEMP_DIR" | head -n1)

        if [[ -z "$backup_data" ]]; then
            log "ERROR: No backup data found in archive"
            return 1
        fi

        echo "$backup_data"
        return 0
    else
        log "ERROR: Failed to extract backup"
        return 1
    fi
}

# Restore profiles.json
restore_profiles_config() {
    local backup_data="$1"

    if [[ -f "${backup_data}/profiles.json" ]]; then
        log "Restoring profiles.json"

        # Backup current profiles.json if exists
        if [[ -f /etc/xray-multi/profiles.json ]]; then
            cp /etc/xray-multi/profiles.json /etc/xray-multi/profiles.json.backup-$(date +%Y%m%d-%H%M%S)
            log "Current profiles.json backed up"
        fi

        cp "${backup_data}/profiles.json" /etc/xray-multi/profiles.json
        log "profiles.json restored"
        return 0
    else
        log "WARNING: profiles.json not found in backup"
        return 1
    fi
}

# Restore SSL certificates
restore_ssl_certs() {
    local backup_data="$1"

    if [[ -d "${backup_data}/ssl/acme.sh" ]]; then
        log "Restoring SSL certificates"

        # Backup current certificates if exist
        if [[ -d /root/.acme.sh ]]; then
            mv /root/.acme.sh /root/.acme.sh.backup-$(date +%Y%m%d-%H%M%S)
            log "Current SSL certificates backed up"
        fi

        rsync -a "${backup_data}/ssl/acme.sh/" /root/.acme.sh/
        log "SSL certificates restored"
    fi

    # Restore Nginx configs
    if [[ -d "${backup_data}/ssl/nginx" ]]; then
        log "Restoring Nginx site configs"

        mkdir -p /etc/nginx/sites-enabled
        cp -r "${backup_data}/ssl/nginx/"* /etc/nginx/sites-enabled/ 2>/dev/null

        # Test Nginx config
        if nginx -t 2>&1 | grep -q "successful"; then
            nginx -s reload 2>&1 | tee -a "$LOG_FILE"
            log "Nginx reloaded successfully"
        else
            log "WARNING: Nginx config test failed"
        fi
    fi
}

# Restore individual profile
restore_profile() {
    local backup_data="$1"
    local profile="$2"
    local container="${profile}-vpn"

    local profile_dir="${backup_data}/profiles/${profile}"

    if [[ ! -d "$profile_dir" ]]; then
        log "WARNING: Profile data not found for: $profile"
        return 1
    fi

    log "Restoring profile: $profile"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        log "WARNING: Container $container does not exist, skipping restore"
        echo -e "${YELLOW}Container $container not found. Please create profile first.${NC}"
        return 1
    fi

    # Stop container before restore
    log "Stopping container: $container"
    docker stop "$container" 2>&1 | tee -a "$LOG_FILE"

    # Restore Xray config
    if [[ -f "${profile_dir}/config.json" ]]; then
        docker cp "${profile_dir}/config.json" "${container}:/etc/xray/config.json"
        log "Restored Xray config for $profile"
    fi

    # Restore user data
    if [[ -d "${profile_dir}/users" ]]; then
        docker exec "$container" mkdir -p /etc/xray/users 2>/dev/null
        docker cp "${profile_dir}/users/." "${container}:/etc/xray/users/"
        log "Restored user data for $profile"
    fi

    # Restore paths.env
    if [[ -f "${profile_dir}/paths.env" ]]; then
        docker cp "${profile_dir}/paths.env" "${container}:/etc/xray/paths.env"
        log "Restored paths.env for $profile"
    fi

    # Restore SSH keys
    if [[ -d "${profile_dir}/ssh" ]]; then
        docker cp "${profile_dir}/ssh/." "${container}:/etc/ssh/"
        docker exec "$container" chmod 600 /etc/ssh/ssh_host_* 2>/dev/null
        log "Restored SSH keys for $profile"
    fi

    # Start container
    log "Starting container: $container"
    docker start "$container" 2>&1 | tee -a "$LOG_FILE"

    # Wait for container to be healthy
    sleep 5

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log "Profile $profile restored successfully"
        return 0
    else
        log "ERROR: Container $container failed to start"
        return 1
    fi
}

# Interactive restore
interactive_restore() {
    clear
    print_banner

    # List backups
    list_backups

    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    # Select backup
    echo ""
    read -p "$(echo -e ${WHITE}Select backup number to restore [0 to cancel]: ${NC})" selection

    if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
        print_info "Cancelled"
        exit 0
    fi

    local archive_path="${backup_files[$selection]}"

    if [[ ! -f "$archive_path" ]]; then
        print_error "Invalid selection"
        exit 1
    fi

    # Confirm restore
    echo ""
    echo -e "${RED}⚠️  WARNING: This will overwrite current configuration!${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}Are you sure you want to restore? [y/N]: ${NC})" confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi

    # Extract backup
    echo ""
    echo -e "${YELLOW}Extracting backup...${NC}"
    backup_data=$(extract_backup "$archive_path")

    if [[ $? -ne 0 ]]; then
        print_error "Failed to extract backup"
        exit 1
    fi

    # Restore global configs
    echo -e "${YELLOW}Restoring global configuration...${NC}"
    restore_profiles_config "$backup_data"
    restore_ssl_certs "$backup_data"

    # Get list of profiles to restore
    if [[ -d "${backup_data}/profiles" ]]; then
        profiles=$(ls -1 "${backup_data}/profiles")

        echo ""
        echo -e "${YELLOW}Found profiles:${NC}"
        echo "$profiles"
        echo ""

        read -p "$(echo -e ${WHITE}Restore all profiles? [Y/n]: ${NC})" restore_all

        if [[ ! "$restore_all" =~ ^[Nn]$ ]]; then
            # Restore all profiles
            for profile in $profiles; do
                echo ""
                echo -e "${YELLOW}Restoring profile: $profile${NC}"
                restore_profile "$backup_data" "$profile"
            done
        else
            # Selective restore
            for profile in $profiles; do
                echo ""
                read -p "$(echo -e ${WHITE}Restore profile $profile? [y/N]: ${NC})" restore_this

                if [[ "$restore_this" =~ ^[Yy]$ ]]; then
                    restore_profile "$backup_data" "$profile"
                else
                    echo -e "${YELLOW}Skipped: $profile${NC}"
                fi
            done
        fi
    fi

    echo ""
    print_success "Restore completed!"

    # Send notification
    load_env
    local hostname=$(cat /etc/hostname)
    send_telegram "♻️ *Restore Completed*\\nVPS: $hostname\\nBackup: $(basename $archive_path)\\nProfiles restored"

    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
}

# Download from remote storage
download_remote_backup() {
    local backup_method="${BACKUP_METHOD:-local}"

    case "$backup_method" in
        s3)
            echo -e "${YELLOW}Downloading from S3...${NC}"
            echo "Not implemented yet. Please download manually and restore from local."
            ;;
        rclone)
            echo -e "${YELLOW}Available backups in rclone:${NC}"
            /etc/xray-multi/scripts/backup-rclone.sh list
            echo ""
            read -p "Enter filename to download: " filename

            if [[ -n "$filename" ]]; then
                /etc/xray-multi/scripts/backup-rclone.sh download "$filename" "$BACKUP_DIR"
            fi
            ;;
        *)
            print_error "Unknown backup method: $backup_method"
            return 1
            ;;
    esac
}

# Main execution
main() {
    log "========== RESTORE STARTED =========="

    # Load environment
    load_env

    # Run interactive restore
    interactive_restore

    log "========== RESTORE COMPLETED =========="
}

# Run main function
main
