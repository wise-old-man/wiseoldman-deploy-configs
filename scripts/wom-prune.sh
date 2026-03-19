#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-prune.sh
#
# This script connects to the backup server over ssh
# and prunes backups that are older than the retention period.
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

NUMBER_REGEX='^[0-9]+$';
if [ -z $BACKUP_REMOTE_HOST ]; then
    error "Remote backup server host/IP env is required";
elif [ -z $BACKUP_REMOTE_DIR_PATH ]; then
    error "Remote directory to prune is required";
elif [ -z $BACKUP_RETENTION_PERIOD_DAYS ]; then
    error "Retention period is required";
elif ! [[ $BACKUP_RETENTION_PERIOD_DAYS =~ $NUMBER_REGEX ]]; then
    error "Retention period must be a number";
elif [ -z $BACKUP_LOCAL_SSH_KEY_PATH ]; then
    error "Path to SSH private key env is required";
elif [ ! -f $BACKUP_LOCAL_SSH_KEY_PATH ]; then
    error "Invalid path to SSH private key";
fi

PRUNE="find $BACKUP_REMOTE_DIR_PATH -type f -name \"*.bak\" -mtime +$BACKUP_RETENTION_PERIOD_DAYS -exec rm -rdf {} \;";

# Run the prune command on the remote backup server
ssh root@$BACKUP_REMOTE_HOST -i $BACKUP_LOCAL_SSH_KEY_PATH "bash -s" <<< $PRUNE;


check_last_exit "Failed to prune remote backup directory";
echo "Pruning complete...";
