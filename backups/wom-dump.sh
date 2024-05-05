#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-dump.sh
#
# This script dumps the specified database.
#
# Args:
#   $1 - The name of the database that should be dumped.
#   $2 - The directory where the backup should be stored. This directory
#        will be created if it does not exist.
#
# Example:
#   $ ./wom-dump.sh wise-old-man_LOCAL /path/to/backup/dir
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

# Gets an environment variables value from docker.
#
# Args:
#   $1 - The environment variable to get without the $ prefix.
function get_docker_env {
    docker exec db env | grep -oP "$1=\K.*";
    check_last_exit "Failed to get $1 from docker environment";
}

# Dumps the specified database inside docker to the local filesystem.
#
# Args:
#   $1 - The postgres username to connect with.
#   $2 - The database to dump.
#   $3 - The path to file to dump to. (will be overwritten if it exists)
function dump_db {
    docker exec -it db pg_dump -Fc -U $1 $2 > $3;

    if [ $? -ne 0 ]; then
        ERROR=$(sed -e 's/"/\"/g' $3);
        error "Failed to dump. $ERROR";
    fi
}

if [ -z $1 ]; then
    error "Database name is required";
elif [ -z $2 ]; then
    error "Backup directory is required";
fi

BACKUP_DIR=$2;
DATABASE_NAME=$1;
POSTGRES_USER=$(get_docker_env "POSTGRES_USER");
BACKUP_FILE="$DATABASE_NAME-$(date +'%Y-%m-%dT%H:%M:%S').bak";
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE";

mkdir -p $BACKUP_DIR;
check_last_exit "Failed to create backup directory - $BACKUP_DIR";

dump_db $POSTGRES_USER $DATABASE_NAME $BACKUP_PATH;
echo "Backup file: $BACKUP_PATH";
