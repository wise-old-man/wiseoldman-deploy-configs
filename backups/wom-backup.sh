#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-backup.sh
#
# This script performs the removal of old local backups on the WOM
# server, creates a new backup of the current WOM and WOM bot databases,
# stores them on the backup server, and prunes old backups from the
# backup server.
#
# Args:
#   $1 - The host/IP of the remote server.
#   $2 - The path to the SSH key file to authenticating.
#   $3 - The local backup directory.
#   $4 - The remote backup directory.
#   $5 - How many days worth of backups to keep on the remote server.
#
# Example:
#   $ ./wom-backup.sh \
#       111.112.113.114 \
#       /path/to/ssh/private/key \
#       /path/to/local/backup/dir \
#       /path/to/remote/backup/dir \
#       7
# ----------------------------------------------------------------------

# Errors and exits the script.
#
# Args:
#   $@ - The error message to display before exiting.
function error {
    echo "$@";
    exit 1;
}

# Generates the JSON for a discord embed.
#
# Args:
#   $@ - The error message to send to discord.
function generate_embed_json {
    # Escape quotes and remove newlines
    DESCRIPTION=$(sed -e 's/"/\\"/g' <<< "$@" | tr -d '\n\r');

    cat <<EOF
{
    "username": "WOM Backups",
    "avatar_url": "https://jonxslays.github.io/wom.py/dev/wom-logo.png",
    "content": "<@329256344798494773>",
    "embeds": [{
        "color": 16720916,
        "title": "Database Backup Failed",
        "description": "$DESCRIPTION"
    }]
}
EOF
}

# Sends a message to the WOM discord if the backup fails for any reason.
#
# Args:
#   $@ - The error message to send to discord.
function send_webhook_error {
    # TODO: Add webhook url
    curl -X POST "" \
      -H "Content-Type: application/json" \
      -d "$(generate_embed_json "$@")";
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
    # First argument is missing
    error "ERROR: Remote backup server host/IP is required";
elif [ -z $2 ]; then
    # Second argument is missing
    error "ERROR: Path to SSH private key is required";
elif [ ! -f $2 ]; then
    # Second argument isnt a file
    error "ERROR: Invalid path to SSH private key";
elif [ -z $3 ]; then
    # Third argument is missing
    error "ERROR: Path to local backup dir is required";
elif [ ! -d $3 ]; then
    # Third argument isnt a directory
    error "ERROR: Path to local backup dir is not a directory";
elif [ -z $4 ]; then
    # Fourth argument is missing
    error "ERROR: Path to remote backup dir is required";
elif [ -z $5 ]; then
    # Fifth argument is missing
    error "ERROR: Number of days worth of files to keep is required.";
elif ! [[ $5 =~ $NUMBER_REGEX ]]; then
    # A non-numeric was used for prune keep days
    error "ERROR: Prune keep days must be a number.";
fi

echo "Starting database backups...";
REMOTE_HOST=$1;
SSH_KEY_PATH=$2;
LOCAL_BACKUP_DIR=$3;
REMOTE_BACKUP_DIR=$4;
PRUNE_KEEP_DAYS=$5;

# Dump the WOM bot db into the local directory
WOM_DB=$(./wom-dump.sh "wise-old-man" $LOCAL_BACKUP_DIR);
check_last_exit $WOM_DB;
echo "Dumped WOM db...";

# Dump the discord bot db into the local directory
BOT_DB=$(./wom-dump.sh "discord-bot" $LOCAL_BACKUP_DIR);
check_last_exit $BOT_DB;
echo "Dumped bot db...";

# Upload backups from the local backup dir to remote backup dir
UPLOAD=$(./wom-upload.sh $REMOTE_HOST $SSH_KEY_PATH $LOCAL_BACKUP_DIR $REMOTE_BACKUP_DIR);
check_last_exit $UPLOAD;
echo "Pruned old backups from local server...";
echo "Backups uploaded to remote server...";

# Prune old backups from the remote server
PRUNE=$(./wom-prune.sh $REMOTE_BACKUP_DIR $PRUNE_KEEP_DAYS $REMOTE_HOST $SSH_KEY_PATH);
check_last_exit $PRUNE;
echo "Pruned old backups from remote server...";

# All went well
echo "Success!";
