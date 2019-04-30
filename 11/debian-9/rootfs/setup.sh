#!/bin/bash
#
# Bitnami PostgreSQL setup

# shellcheck disable=SC1090
# shellcheck disable=SC1091

# Load Generic Libraries
. /libfile.sh
. /liblog.sh
. /libservice.sh
. /libvalidations.sh

# Functions

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose
# shellcheck disable=SC1091

# Load libraries
. /libfs.sh
. /libos.sh
. /libpostgresql.sh

# Load MariaDB environment variables
eval "$(postgresql_env)"

# Ensure MariaDB environment variables settings are valid
postgresql_validate
# Ensure MariaDB is stopped when this script ends.
trap "postgresql_stop" EXIT
# Ensure 'daemon' user exists when running as 'root'
am_i_root && ensure_user_exists "$POSTGRESQL_DAEMON_USER" "$POSTGRESQL_DAEMON_GROUP"
# Ensure MariaDB is initialized
postgresql_initialize
# Allow running custom initialization scripts
postgresql_custom_init_scripts

# Allow remote connections once the initialization is finished
if ! postgresql_is_file_external "postgresql.conf"; then
    info "Enabling remote connections"
    postgresql_enable_remote_connections
fi

