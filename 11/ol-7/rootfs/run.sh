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
readonly flags=("-D" "$POSTGRESQL_DATA_DIR" "--config-file=$POSTGRESQL_CONF_FILE" "--external_pid_file=$POSTGRESQL_PID_FILE" "--hba_file=$POSTGRESQL_PGHBA_FILE")
readonly cmd=$(command -v postgres)

info "** Starting PostgreSQL **"
if am_i_root; then
    exec gosu "$POSTGRESQL_DAEMON_USER" "${cmd}" "${flags[@]}"
else
    exec "${cmd}" "${flags[@]}"
fi
<<<<<<< HEAD
=======

# allow running custom initialization scripts
if [[ -n $(find /docker-entrypoint-initdb.d/ -type f -regex ".*\.\(sh\|sql\|sql.gz\)") ]] && [[ ! -f /bitnami/postgresql/.user_scripts_initialized ]]; then
    info "Loading user files from /docker-entrypoint-initdb.d";
    if [[ -n $POSTGRESQL_PASSWORD ]]; then
        export PGPASSWORD=$POSTGRESQL_PASSWORD
    fi
    if [[ $POSTGRESQL_USERNAME == "postgres" ]]; then
        psql=( psql -U postgres)
    else
        psql=( psql -U "$POSTGRESQL_USERNAME" -d "$POSTGRESQL_DATABASE" )
    fi
    postgresqlStart &
    info "Initialization: Waiting for PostgreSQL to be available"
    retries=30
    until "${psql[@]}" -h 127.0.0.1 -c "select 1" > /dev/null 2>&1 || [ $retries -eq 0 ]; do
        info "Waiting for PostgreSQL server: $((retries--)) remaining attempts..."
        sleep 2
    done
    if [[ $retries == 0 ]]; then
        echo "Error: PostgreSQL is not available after 60 seconds"
        exit 1
    fi
    tmp_file=/tmp/filelist
    find /docker-entrypoint-initdb.d/ -type f -regex ".*\.\(sh\|sql\|sql.gz\)" | sort > $tmp_file
    while read -r f; do
        case "$f" in
            *.sh)
                if [ -x "$f" ]; then
                    echo "Executing $f"; "$f"
                else
                    echo "Sourcing $f"; . "$f"
                fi
                ;;
            *.sql)    echo "Executing $f"; "${psql[@]}" -f "$f"; echo ;;
            *.sql.gz) echo "Executing $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
            *)        echo "Ignoring $f" ;;
        esac
    done < $tmp_file
    rm $tmp_file
    touch /bitnami/postgresql/.user_scripts_initialized
    postgresqlStop
fi

postgresqlStart
>>>>>>> master
