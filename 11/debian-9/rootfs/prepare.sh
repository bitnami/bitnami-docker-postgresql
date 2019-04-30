#!/bin/bash

# shellcheck disable=SC1091

# Load libraries
. /libfs.sh
. /libpostgresql.sh

# Load MySQL environment variables
eval "$(postgresql_env)"

for dir in "$POSTGRESQL_INITSCRIPTS_DIR" "$POSTGRESQL_TMPDIR" "$POSTGRESQL_LOGDIR" "$POSTGRESQL_CONFDIR" "${POSTGRESQL_CONFDIR}/conf.d" "$POSTGRESQL_VOLUMEDIR"; do
    ensure_dir_exists "$dir"
done
chmod -R g+rwX "$POSTGRESQL_INITSCRIPTS_DIR" "$POSTGRESQL_TMPDIR" "$POSTGRESQL_LOGDIR" "$POSTGRESQL_CONFDIR" "${POSTGRESQL_CONFDIR}/conf.d" "$POSTGRESQL_VOLUMEDIR"

# Redirect all logging to stdout
ln -sf /dev/stdout "$POSTGRESQL_LOGDIR/postgresql.log"
