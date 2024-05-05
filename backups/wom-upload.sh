#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-upload.sh
#
# This script uploads the local backups to the remote backup server.
#
# Args:
#   $1 - The host/IP of the remote server.
#   $2 - The path to the SSH key file to authenticating.
#   $3 - The local backup directory.
#   $4 - The remote backup directory.
#
# Example:
#   $ ./wom-upload.sh \
#       111.112.113.114 \
#       /path/to/ssh/private/key \
#       /path/to/local/backup/dir \
#       /path/to/remote/backup/dir
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
        error "$@";
    fi
}

if [ -z $1 ]; then
    # First argument is missing
    error "Remote backup server host/IP is required";
elif [ -z $2 ]; then
    # Second argument is missing
    error "Path to SSH private key is required";
elif [ ! -f $2 ]; then
    # Second argument isnt a file
    error "Invalid path to SSH private key";
elif [ -z $3 ]; then
    # Third argument is missing
    error "Path to local backup dir is required";
elif [ ! -d $3 ]; then
    # Third argument isnt a directory
    error "Path to local backup dir is not a directory";
elif [ -z $4 ]; then
    # Fourth argument is missing
    error "Path to remote backup dir is required";
fi

REMOTE_HOST=$1;
SSH_KEY_PATH=$2;
LOCAL_BACKUP_DIR=$3;
REMOTE_BACKUP_DIR=$4;

# Prune yesterdays local backups
# find $LOCAL_BACKUP_DIR -type f -name "*.bak" -mtime +1 -exec rm -rdf {} \;
# NOTE: For now always delete all the local backups to conserve disk space
# When were ready to keep copies for a day revert to the above ^
find $LOCAL_BACKUP_DIR -type f -name "*.bak" -exec rm -rdf {} \;
check_last_exit "Failed to prune the local backup directory";

# Upload remaining backups to the remote server
rsync -raze "ssh -i $SSH_KEY_PATH" \
    $LOCAL_BACKUP_DIR/ \
    root@$REMOTE_HOST:$REMOTE_BACKUP_DIR;

check_last_exit "Failed upload backups to remote server";
echo "Uploaded to remote backup directory...";
