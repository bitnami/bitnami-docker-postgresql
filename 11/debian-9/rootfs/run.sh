#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose
# shellcheck disable=SC1091

# Load libraries
. /libpostgresql.sh
. /libos.sh

# Load PostgreSQL environment variables
eval "$(postgresql_env)"
readonly flags=("-D" "$POSTGRESQL_DATADIR" "--config-file=$POSTGRESQL_CONFFILE" "--external_pid_file=$POSTGRESQL_PIDFILE" "--hba_file=$POSTGRESQL_PGHBAFILE")

info "** Starting PostgreSQL **"
if am_i_root; then
    exec gosu "$POSTGRESQL_DAEMON_USER" "${POSTGRESQL_BINDIR}/postgres" "${flags[@]}"
else
    exec "${POSTGRESQL_BINDIR}/postgres" "${flags[@]}"
fi
