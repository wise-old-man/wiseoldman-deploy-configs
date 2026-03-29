#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-upload.sh
#
# This script uploads the local backups to Cloudflare R2.
# ----------------------------------------------------------------------

if [ -f ../.env ]; then
  source ../.env
else
  echo ".env file not found!"
  exit 1
fi


# Errors and exits the script.
#
# Args:
#   $@ - The error message to display before exiting.
function error {
    echo "ERROR: $@";
    exit 1;
}

# Checks the last exit code was 0, and exits the program if not.
#
# Args:
#   $@ - The error message to display if the last exit was not 0.
function check_last_exit {
    if [ $? -ne 0 ]; then
        error "$@";
    fi
}

if [ -z $BACKUP_R2_ACCOUNT_ID ]; then
    error "R2 account ID env is required";
elif [ -z $BACKUP_R2_ACCESS_KEY_ID ]; then
    error "R2 access key ID env is required";
elif [ -z $BACKUP_R2_SECRET_ACCESS_KEY ]; then
    error "R2 secret access key env is required";
elif [ -z $BACKUP_R2_BUCKET_NAME ]; then
    error "R2 bucket name env is required";
elif [ -z $BACKUP_LOCAL_DIR_PATH ]; then
    error "Path to local backup dir env is required";
elif [ ! -d $BACKUP_LOCAL_DIR_PATH ]; then
    error "Path to local backup dir is not a directory";
fi

RCLONE_CONFIG_R2_TYPE=s3 \
RCLONE_CONFIG_R2_PROVIDER=Cloudflare \
RCLONE_CONFIG_R2_ACCESS_KEY_ID=$BACKUP_R2_ACCESS_KEY_ID \
RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=$BACKUP_R2_SECRET_ACCESS_KEY \
RCLONE_CONFIG_R2_ENDPOINT=https://${BACKUP_R2_ACCOUNT_ID}.r2.cloudflarestorage.com \
RCLONE_CONFIG_R2_CHUNK_SIZE=25M \
rclone copy $BACKUP_LOCAL_DIR_PATH R2:$BACKUP_R2_BUCKET_NAME

check_last_exit "Failed to upload backups to R2";
echo "Uploaded to R2 bucket $BACKUP_R2_BUCKET_NAME...";
