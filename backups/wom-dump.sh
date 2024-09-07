#!/usr/bin/env bash

# ----------------------------------------------------------------------
# wom-dump.sh
#
# This script dumps the specified database.
#
# Args:
#   $1 - The name of the database that should be dumped.
#
# Example:
#   $ ./wom-dump.sh wise-old-man_LOCAL
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

# Gets an environment variables value from docker.
#
# Args:
#   $1 - The environment variable to get without the $ prefix.
function get_docker_env {
    value=$(docker exec db env | grep "^$1=" | cut -d'=' -f2-)

    if [ -z "$value" ]; then
        error "Failed to get $1 from docker environment"
    else
        echo $value
    fi
}

# Dumps the specified database inside docker to the local filesystem.
#
# Args:
#   $1 - The postgres username to connect with.
#   $2 - The database to dump.
#   $3 - The path to file to dump to. (will be overwritten if it exists)
function dump_db {
    docker exec -it db pg_dump -Z1 -U $1 $2 > $3;

    if [ $? -ne 0 ]; then
        ERROR=$(sed -e 's/"/\"/g' $3);
        error "Failed to dump. $ERROR";
    fi
}

if [ -z $1 ]; then
    error "Database name is required";
elif [ -z $BACKUP_LOCAL_DIR_PATH ]; then
    error "Backup directory env is required";
fi


DATABASE_NAME=$1;
POSTGRES_USER=$(get_docker_env "POSTGRES_USER");

BACKUP_FILE="$DATABASE_NAME-$(date +'%Y-%m-%dT%H:%M:%S').bak";
BACKUP_PATH="$BACKUP_LOCAL_DIR_PATH/$BACKUP_FILE";

mkdir -p $BACKUP_LOCAL_DIR_PATH;
check_last_exit "Failed to create backup directory - $BACKUP_LOCAL_DIR_PATH";

dump_db $POSTGRES_USER $DATABASE_NAME $BACKUP_PATH;
echo "Backup file: $BACKUP_PATH";
