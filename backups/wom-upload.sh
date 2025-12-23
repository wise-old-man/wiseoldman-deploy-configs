#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-upload.sh
#
# This script uploads the local backups to the remote backup server.
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

if [ -z $BACKUP_REMOTE_HOST ]; then
    error "Remote backup server host/IP env is required";
elif [ -z $BACKUP_LOCAL_DIR_PATH ]; then
    error "Path to local backup dir env is required";
elif [ ! -d $BACKUP_LOCAL_DIR_PATH ]; then
    error "Path to local backup dir is not a directory";
elif [ -z $BACKUP_REMOTE_DIR_PATH ]; then
    error "Path to remote backup dir env is required";
elif [ -z $BACKUP_LOCAL_SSH_KEY_PATH ]; then
    error "Path to SSH private key env is required";
elif [ ! -f $BACKUP_LOCAL_SSH_KEY_PATH ]; then
    error "Invalid path to SSH private key";
fi

# Upload remaining backups to the remote server
rsync -raze "ssh -i $BACKUP_LOCAL_SSH_KEY_PATH" \
    $BACKUP_LOCAL_DIR_PATH/ \
    root@$BACKUP_REMOTE_HOST:$BACKUP_REMOTE_DIR_PATH;


check_last_exit "Failed upload backups to remote server";
echo "Uploaded to remote backup directory...";
