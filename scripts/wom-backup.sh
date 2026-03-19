#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-backup.sh
#
# This script performs the removal of old local backups on the WOM
# server, creates a new backup of the current WOM and WOM bot databases,
# stores them on the backup server, and prunes old backups from the
# backup server.
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
    echo "$@";
    exit 1;
}

# Generates the JSON for a discord embed.
#
# Args:
#   $@ - The error message to send to discord.
function generate_error_embed_json {
    # Escape quotes and remove newlines
    DESCRIPTION=$(sed -e 's/"/\\"/g' <<< "$@" | tr -d '\n\r');

    cat <<EOF
{
    "username": "WOM Backups",
    "content": "<@329256344798494773>",
    "embeds": [{
        "color": 16720916,
        "title": "Database Backup Failed",
        "description": "$DESCRIPTION"
    }]
}
EOF
}


# Generates the JSON for a discord embed.
#
# Args:
#   $1 - The embed title to send to discord.
#   $2 - The embed message to send to discord.
function generate_success_message_json {
    # Escape quotes and remove newlines
    TITLE=$(sed -e 's/"/\\"/g' <<< "$1" | tr -d '\n\r');
    DESCRIPTION=$(sed -e 's/"/\\"/g' <<< "$2" | tr -d '\n\r');

    cat <<EOF
{
    "username": "WOM Backups",
    "content": "",
    "embeds": [{
        "color": 5763719,
        "title": "$TITLE",
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
    curl -X POST "$BACKUP_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "$(generate_error_embed_json "$@")";
}

# Sends a message to the WOM discord if the backup succeeds.
#
# Args:
#   $1 - The embed title to send to discord.
#   $2 - The embed message to send to discord.
function send_webhook_success {
    curl -X POST "$BACKUP_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "$(generate_success_message_json "$1" "$2")";
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

if [ -z $BACKUP_WEBHOOK_URL ]; then
    error "Webhook URL is required";
fi

SECONDS=0

echo "Starting database backups...";

echo "Pruning old local backups...";
find $BACKUP_LOCAL_DIR_PATH -type f -name "*.bak" -mmin +720 -exec rm -f {} \;
check_last_exit "Failed to prune local backups";
echo "Pruned old local backups.";

# Dump the discord bot db into the local directory
echo "Dumping bot db...";
BOT_DB=$(./wom-dump.sh "discord-bot");
check_last_exit $BOT_DB;
echo "Dumped bot db.";

# Dump the WOM bot db into the local directory
echo "Dumping core db...";
CORE_DB=$(./wom-dump.sh "wise-old-man");
check_last_exit $CORE_DB;
echo "Dumped core db.";

# Upload backups from the local backup dir to remote backup dir
echo "Uploading to remote server...";
UPLOAD=$(./wom-upload.sh);
check_last_exit $UPLOAD;
echo "Pruned old backups from local server.";
echo "Backups uploaded to remote server.";

# Prune old backups from the remote server
echo "Pruning old backups on remote server...";
PRUNE=$(./wom-prune.sh);
check_last_exit $PRUNE;
echo "Pruned old backups from remote server.";

elapsed=$SECONDS

duration="$((elapsed / 60)) minutes and $((elapsed % 60)) seconds"

# All went well
echo "Success! Duration: $duration."
send_webhook_success "Database backup succeeded!" "Duration: $duration"
