#!/bin/bash
set -o pipefail

# Ruta del archivo de configuración.
# Puedes ajustar la ruta si lo deseas, por ejemplo: /etc/files-backup.conf
CONFIG_FILE="$(dirname "$0")/files-backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Asignar valores por defecto en caso de que no se hayan definido en el archivo de configuración.
# Se espera que FILES_TO_BACKUP sea una lista separada por comas, por ejemplo:
# FILES_TO_BACKUP="/etc,/var/www,/home/usuario"
: ${FILES_TO_BACKUP:="/path/to/your/files"}
: ${DEFAULT_CLOUD_BUCKET:="gs://bucket-backups-servers/files"}
: ${CLOUD_BUCKET:="$DEFAULT_CLOUD_BUCKET"}
: ${LOCAL_PATH:="/var/backups/files"}
: ${REMOTE_HOST:=""}
: ${RETENTION_DAYS:=7}
: ${ENCRYPTION_KEY:=""}
: ${MODE:="gcp"}

LOG_FILE="/var/log/backups-files.log"
BACKUP_DATE=$(date +%Y%m%d-%H%M)
ERROR_COUNT=0

# Process command line options
while getopts "m:l:b:k:T:h:" opt; do
    case $opt in
        m) MODE=$OPTARG ;;
        l) LOCAL_PATH=$OPTARG ;;
        b) CLOUD_BUCKET=$OPTARG ;;
        k) ENCRYPTION_KEY=$OPTARG ;;
        T) RETENTION_DAYS=$OPTARG ;;
        h) REMOTE_HOST=$OPTARG ;;
        *)
cat << 'EOF'
Usage: $0 [options]

Options:
  -m  Mode of backup. Valid options:
         gcp   -> Backup to a Google Cloud Storage bucket.
         local -> Backup to a local directory.
         s3    -> Backup to an AWS S3 bucket.
         
  -l  Backup path:
         For 'local', this is the destination folder on the system.
         For remote transfers (with -h), this is the folder on the remote host.
         
  -b  Cloud bucket path (for gcp and s3 modes). Example:
         gs://my-bucket/path or s3://my-bucket/path
         
  -k  Encryption key to protect the backup using GPG symmetric encryption (AES256).
  
  -T  Retention days: number of days to keep backup files.
  
  -h  Remote host for transferring backups (format: user@host).

Examples:
  $0 -m local -l /backups/files -T 7
  $0 -m gcp -b gs://my-bucket/path -k mysecret
  $0 -m local -l /backups/files -h user@remotehost

EOF
exit 1
;;
    esac
done
shift $((OPTIND - 1))

# Function for logging with timestamp
log_check_message() {
    local timestamp
    timestamp=$(date '+%a %b %e %T %Y')
    local log_message="[${timestamp}] $1"
    echo "$log_message" >> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[${timestamp}] [error] Error occurred during logging: $1" >> "$LOG_FILE"
        exit 1
    fi
}

# Function to backup a directory or file
backup_item() {
    local item="$1"
    local base_item
    base_item=$(basename "$item")
    local ext=".tar.gz"
    if [ -n "$ENCRYPTION_KEY" ]; then
        ext=".tar.gz.gpg"
    fi
    local file_name="${base_item}-${BACKUP_DATE}${ext}"
    
    log_check_message "[info] Starting backup of ${item}"
    
    if [ "$MODE" == "local" ]; then
        if [ -n "$REMOTE_HOST" ]; then
            # Remote backup via SSH
            local tmp_backup="/tmp/${file_name}"
            if [ -n "$ENCRYPTION_KEY" ]; then
                tar czf - "$item" 2>/dev/null | \
                gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" -o "$tmp_backup"
            else
                tar czf "$tmp_backup" "$item" 2>/dev/null
            fi
            if [ $? -ne 0 ]; then
                log_check_message "[error] Error creating temporary backup for ${item}"
                ERROR_COUNT=$((ERROR_COUNT+1))
                rm -f "$tmp_backup"
                return 1
            fi
            log_check_message "[info] Transferring backup of ${item} to remote host ${REMOTE_HOST}:${LOCAL_PATH}"
            scp "$tmp_backup" "${REMOTE_HOST}:${LOCAL_PATH}/${file_name}"
            if [ $? -ne 0 ]; then
                log_check_message "[error] Remote transfer failed for backup of ${item}"
                ERROR_COUNT=$((ERROR_COUNT+1))
            else
                log_check_message "[info] Backup of ${item} transferred successfully to remote host"
            fi
            rm -f "$tmp_backup"
        else
            # Local backup on filesystem
            mkdir -p "$LOCAL_PATH"
            local backup_file="${LOCAL_PATH}/${file_name}"
            if [ -n "$ENCRYPTION_KEY" ]; then
                tar czf - "$item" 2>/dev/null | \
                gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" -o "$backup_file"
            else
                tar czf "$backup_file" "$item" 2>/dev/null
            fi
            if [ $? -ne 0 ]; then
                log_check_message "[error] Error during local backup of ${item}"
                ERROR_COUNT=$((ERROR_COUNT+1))
            else
                log_check_message "[info] Local backup of ${item} completed: ${backup_file}"
            fi
        fi
    elif [ "$MODE" == "s3" ]; then
        # Backup to AWS S3 using AWS CLI
        local remote_file="${base_item}/${file_name}"
        if [ -n "$ENCRYPTION_KEY" ]; then
            tar czf - "$item" 2>/dev/null | \
            gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" | \
            aws s3 cp - "${CLOUD_BUCKET}/${remote_file}"
        else
            tar czf - "$item" 2>/dev/null | aws s3 cp - "${CLOUD_BUCKET}/${remote_file}"
        fi
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error with S3 backup for ${item}"
            ERROR_COUNT=$((ERROR_COUNT+1))
        else
            log_check_message "[info] S3 backup of ${item} completed: ${remote_file}"
        fi
    elif [ "$MODE" == "gcp" ]; then
        # Backup to GCP using gsutil
        local remote_file="${base_item}/${file_name}"
        if [ -n "$ENCRYPTION_KEY" ]; then
            tar czf - "$item" 2>/dev/null | \
            gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" | \
            gsutil cp - "${CLOUD_BUCKET}/${remote_file}"
        else
            tar czf - "$item" 2>/dev/null | gsutil cp - "${CLOUD_BUCKET}/${remote_file}"
        fi
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error with GCP backup for ${item}"
            ERROR_COUNT=$((ERROR_COUNT+1))
        else
            log_check_message "[info] GCP backup of ${item} completed: ${remote_file}"
        fi
    else
        echo "Unknown mode: $MODE. Valid options: gcp, local, s3"
        exit 1
    fi
}

# Function to apply retention policy on local backups (or remote backups via SSH)
apply_retention_policy() {
    log_check_message "[info] Applying retention policy: deleting backups older than ${RETENTION_DAYS} days."
    if [ "$MODE" == "local" ]; then
        if [ -n "$REMOTE_HOST" ]; then
            ssh "$REMOTE_HOST" "find \"$LOCAL_PATH\" -type f -mtime +${RETENTION_DAYS} -delete"
            if [ $? -eq 0 ]; then
                log_check_message "[info] Retention policy applied on remote destination."
            else
                log_check_message "[error] Retention policy failed on remote host."
            fi
        else
            find "$LOCAL_PATH" -type f -mtime +${RETENTION_DAYS} -delete
            if [ $? -eq 0 ]; then
                log_check_message "[info] Retention policy applied on local destination."
            else
                log_check_message "[error] Retention policy failed locally."
            fi
        fi
    else
        log_check_message "[info] Retention policy does not apply for mode ${MODE}."
    fi
}

# Main function to coordinate the backup process
main() {
    # Convert comma separated list into an array
    IFS=',' read -ra items <<< "$FILES_TO_BACKUP"
    for item in "${items[@]}"; do
        # Remove extra spaces if any
        item=$(echo "$item" | xargs)
        if [ -n "$item" ]; then
            if [ -e "$item" ]; then
                backup_item "$item"
            else
                log_check_message "[error] Backup target '$item' does not exist"
                ERROR_COUNT=$((ERROR_COUNT+1))
            fi
        fi
    done

    apply_retention_policy

    if [ $ERROR_COUNT -gt 0 ]; then
        log_check_message "[error] Process finished with ${ERROR_COUNT} errors"
        exit 1
    else
        log_check_message "[info] All backups completed successfully"
        exit 0
    fi
}

main
