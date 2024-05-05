#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-dump.sh
#
# This script connects to the backup server over ssh and prunes backups
# from the given directory that are older than the given number of days.
#
# Args:
#   $1 - The directory to prune.
#   $2 - Do not prune files created within this number of days.
#   $3 - The host/IP of the remote server.
#   $4 - The path to the SSH key file to authenticating.
#
# Example:
#   $ ./wom-prune.sh \
#       /path/to/remote/backup/dir \
#       7 \
#       111.112.113.114 \
#       /path/to/ssh/private/key
# ----------------------------------------------------------------------

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
        send_webhook_error "$@";
        error "$@";
    fi
}

NUMBER_REGEX='^[0-9]+$';
if [ -z $1 ]; then
    error "Remote directory to prune is required";
elif [ -z $2 ]; then
    error "Number of days worth of files to keep is required";
elif ! [[ $2 =~ $NUMBER_REGEX ]]; then
    error "Prune keep days must be a number";
fi

BACKUP_DIR=$1;
DAYS=$2;
REMOTE_HOST=$3;
SSH_KEY_PATH=$4;
PRUNE="find $BACKUP_DIR -type f -name \"*.bak\" -mtime +$DAYS -exec rm -rdf {} \;";

# Run the prune command on the remote backup server
ssh root@$REMOTE_HOST -i $SSH_KEY_PATH "bash -s" <<< $PRUNE;
check_last_exit "Failed to prune remote backup directory";
echo "Pruning complete...";
