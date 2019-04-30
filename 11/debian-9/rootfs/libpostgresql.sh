#!/bin/bash
#
# Bitnami PostgreSQL library

# shellcheck disable=SC1090
# shellcheck disable=SC1091

# Load Generic Libraries
. /libfile.sh
. /liblog.sh
. /libservice.sh
. /libvalidations.sh

########################
# Configure libnss_wrapper so PostgreSQL commands work with a random user.
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_enable_nss_wrapper() {
  if ! getent passwd "$(id -u)" &> /dev/null && [ -e "$NSS_WRAPPER_LIB" ]; then
    export LD_PRELOAD="$NSS_WRAPPER_LIB"
    # shellcheck disable=SC2155
    export NSS_WRAPPER_PASSWD="$(mktemp)"
    # shellcheck disable=SC2155
    export NSS_WRAPPER_GROUP="$(mktemp)"
    echo "postgres:x:$(id -u):$(id -g):PostgreSQL:$POSTGRESQL_DATADIR:/bin/false" > "$NSS_WRAPPER_PASSWD"
    echo "postgres:x:$(id -g):" > "$NSS_WRAPPER_GROUP"
  fi
}

########################
# Load global variables used on PostgreSQL configuration.
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   Series of exports to be used as 'eval' arguments
#########################
postgresql_env() {
    declare_env_alias() {
      if env | grep -q "$2"; then
          cat << EOF 
export $1="${!2}"
EOF
      fi
    }
  # Alias created for official postgre image compatibility
  declare_env_alias POSTGRESQL_PASSWORD POSTGRES_PASSWORD
  declare_env_alias POSTGRESQL_DATABASE POSTGRES_DB
  declare_env_alias POSTGRESQL_USERNAME POSTGRES_USER
  declare_env_alias POSTGRESQL_DATA_DIR PGDATA
  declare_env_alias POSTGRESQL_INITDB_WALDIR POSTGRES_INITDB_WALDIR
  declare_env_alias POSTGRESQL_INITDB_ARGS POSTGRES_INITDB_ARGS

  # Alias created for maintain consistency using prefix
  declare_env_alias POSTGRESQL_CLUSTER_APP_NAME POSTGRES_CLUSTER_APP_NAME
  declare_env_alias POSTGRESQL_MASTER_HOST POSTGRES_MASTER_HOST
  declare_env_alias POSTGRESQL_MASTER_PORT_NUMBER POSTGRES_MASTER_PORT_NUMBER
  declare_env_alias POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS POSTGRES_NUM_SYNCHRONOUS_REPLICAS
  declare_env_alias POSTGRESQL_PORT_NUMBER POSTGRES_PORT_NUMBER
  declare_env_alias POSTGRESQL_REPLICATION_MODE POSTGRES_REPLICATION_MODE
  declare_env_alias POSTGRESQL_REPLICATION_PASSWORD POSTGRES_REPLICATION_PASSWORD
  declare_env_alias POSTGRESQL_REPLICATION_USER POSTGRES_REPLICATION_USER
  declare_env_alias POSTGRESQL_SYNCHRONOUS_COMMIT_MODE POSTGRES_SYNCHRONOUS_COMMIT_MODE
  declare_env_alias POSTGRESQL_PASSWORD_FILE POSTGRES_PASSWORD_FILE
  declare_env_alias POSTGRESQL_REPLICATION_PASSWORD_FILE POSTGRES_REPLICATION_PASSWORD_FILE
  declare_env_alias POSTGRESQL_INIT_MAX_TIMEOUT POSTGRES_INIT_MAX_TIMEOUT


    cat <<"EOF"
export POSTGRESQL_VOLUMEDIR="/bitnami/postgresql"
export POSTGRESQL_DATADIR="$POSTGRESQL_VOLUMEDIR/data"
export POSTGRESQL_BASEDIR="/opt/bitnami/postgresql"
export POSTGRESQL_CONFDIR="$POSTGRESQL_BASEDIR/conf"
export POSTGRESQL_MOUNTED_CONFDIR="/bitnami/postgresql/conf"
export POSTGRESQL_CONFFILE="$POSTGRESQL_CONFDIR/postgresql.conf"
export POSTGRESQL_PGHBAFILE="$POSTGRESQL_CONFDIR/pg_hba.conf"
export POSTGRESQL_RECOVERYFILE="$POSTGRESQL_DATADIR/recovery.conf"
export POSTGRESQL_LOGDIR="$POSTGRESQL_BASEDIR/logs"
export POSTGRESQL_LOGFILE="$POSTGRESQL_LOGDIR/postgresql.log"
export POSTGRESQL_TMPDIR="$POSTGRESQL_BASEDIR/tmp"
export POSTGRESQL_PIDFILE="$POSTGRESQL_TMPDIR/postgresql.pid"
export POSTGRESQL_BINDIR="$POSTGRESQL_BASEDIR/bin"
export PATH="$POSTGRESQL_BINDIR:$PATH"
export POSTGRESQL_DAEMON_USER="postgresql"
export POSTGRESQL_DAEMON_GROUP="postgresql"
export POSTGRESQL_INIT_MAX_TIMEOUT=${POSTGRESQL_INIT_MAX_TIMEOUT:-60}
EOF
    if [[ -n "${POSTGRESQL_PASSWORD_FILE:-}" ]] && [[ -f "$POSTGRESQL_PASSWORD_FILE" ]]; then
        cat <<"EOF"
export POSTGRESQL_PASSWORD="$(< "${POSTGRESQL_PASSWORD_FILE}")"
EOF
    fi
    if [[ -n "${POSTGRESQL_REPLICATION_PASSWORD_FILE:-}" ]] && [[ -f "$POSTGRESQL_REPLICATION_PASSWORD_FILE" ]]; then
        cat <<"EOF"
export POSTGRESQL_REPLICATION_PASSWORD="$(< "${POSTGRESQL_REPLICATION_PASSWORD_FILE}")"
EOF
    fi
}

########################
# Validate settings in POSTGRESQL_* environment variables
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_validate() {
    info "Validating settings in POSTGRESQL_* env vars.."

    # Auxiliary functions
    empty_password_enabled_warn() {
        warn "You set the environment variable ALLOW_EMPTY_PASSWORD=${ALLOW_EMPTY_PASSWORD}. For safety reasons, do not use this flag in a production environment."
    }
    empty_password_error() {
        error "The $1 environment variable is empty or not set. Set the environment variable ALLOW_EMPTY_PASSWORD=yes to allow the container to be started with blank passwords. This is recommended only for development."
        exit 1
    }

    if [[ -n "$POSTGRESQL_REPLICATION_MODE" ]]; then
        if [[ "$POSTGRESQL_REPLICATION_MODE" = "master" ]]; then
            if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
                empty_password_enabled_warn
            else
                if [[ -z "$POSTGRESQL_PASSWORD" ]]; then
                    empty_password_error "POSTGRESQL_PASSWORD"
                fi
                if (( ${#POSTGRESQL_PASSWORD} > 32 )); then
                    error "The password cannot be longer than 32 characters. Set the environment variable POSTGRESQL_PASSWORD with a shorter value"
                    exit 1
                fi
                if [[ -n "$POSTGRESQL_USERNAME" ]] && [[ -z "$POSTGRESQL_PASSWORD" ]]; then
                    empty_password_error "POSTGRESQL_PASSWORD"
                fi
                if [[ -n "$POSTGRESQL_USERNAME" ]] && [[ -n "$POSTGRESQL_PASSWORD" ]] && [[ -z "$POSTGRESQL_DATABASE" ]]; then
                    error "In order to use a custom PostgreSQL user you need to set the environment variable POSTGRESQL_DATABASE as well"
                fi
            fi
            if (( POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS < 0 )); then
                error "The number of synchronous replicas cannot be less than 0. Set the environment variable POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS"
            fi
        elif [[ "$POSTGRESQL_REPLICATION_MODE" = "slave" ]]; then
            if [[ -z "$POSTGRESQL_MASTER_HOST" ]]; then
                error "Slave replication mode chosen without setting the environment variable POSTGRESQL_MASTER_HOST. Use it to indicate where the Master node is running"
                exit 1
            fi
            if [[ -z "$POSTGRESQL_REPLICATION_USER" ]]; then
                error "Slave replication mode chosen without setting the environment variable POSTGRESQL_REPLICATION_USER. Make sure that the master also has this parameter set"
                exit 1
            fi
        else
            error "Invalid replication mode. Available options are 'master/slave'"
            exit 1
        fi
        # Common replication checks
        if [[ -n "$POSTGRESQL_REPLICATION_USER" ]] && [[ -z "$POSTGRESQL_REPLICATION_PASSWORD" ]]; then
            empty_password_error "POSTGRESQL_REPLICATION_PASSWORD"
        fi
    else
        if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
            empty_password_enabled_warn
        else
            if [[ -z "$POSTGRESQL_PASSWORD" ]]; then
                empty_password_error "POSTGRESQL_PASSWORD"
            fi
            if [[ -n "$POSTGRESQL_USERNAME" ]] && [[ -z "$POSTGRESQL_PASSWORD" ]]; then
                empty_password_error "POSTGRESQL_PASSWORD"
            fi
        fi
    fi
}

########################
# Create basic postgresql.conf file using the example provided in the share/ folder
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_create_config() {
    debug "postgresql.conf file not detected. Generating it..."
    cp "$POSTGRESQL_BASEDIR/share/postgresql.conf.sample" "$POSTGRESQL_CONFFILE"
    sed -i 's/#include_dir/include_dir/g' "$POSTGRESQL_CONFFILE"
}

########################
# Create basic pg_hba.conf file
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_create_pghba() {
    debug "pg_hba.conf file not detected. Generating it..."
    cat << EOF > "$POSTGRESQL_PGHBAFILE"
host     all             all             0.0.0.0/0               trust
host     all             all             ::1/128                 trust
EOF
}

########################
# Change pg_hba.conf so it allows local UNIX socket-based connections
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_allow_local_connection() {
    cat << EOF >> "$POSTGRESQL_PGHBAFILE"
local    all             all                                     trust
EOF
}

########################
# Change pg_hba.conf so only password-based authentication is allowed
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_restrict_pghba() {
    if [[ -n "$POSTGRESQL_PASSWORD" ]];then
        sed -i 's/trust/md5/g' "$POSTGRESQL_PGHBAFILE"
    fi
}

########################
# Change pg_hba.conf so it allows access from replication users
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_add_replication_to_pghba() {
    local replication_auth="trust"
    if [[ -n "$POSTGRESQL_REPLICATION_PASSWORD" ]];then
        replication_auth="md5"
    fi
    cat << EOF >> "$POSTGRESQL_PGHBAFILE"
host      replication     all             0.0.0.0/0               ${replication_auth}
EOF
}

########################
# Change a PostgreSQL configuration file by setting a property
# Globals:
#   POSTGRESQL_*
# Arguments:
#   $1 - property
#   $2 - value
#   $3 - Path to configuration file (default: $POSTGRESQL_CONFFILE)
# Returns:
#   None
#########################
postgresql_set_property() {
    local -r property=$1
    local -r value=$2
    local -r conf_file=${3:-"$POSTGRESQL_CONFFILE"}
    sed -i "s?^#*\s*${property}\s*=.*?${property} = '${value}'?g" "$conf_file"
}

########################
# Create a user for master-slave replication
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_create_replication_user() {
    local -r escaped_password="${POSTGRESQL_REPLICATION_PASSWORD//\'/\'\'}" 
    info "Creating replication user $POSTGRESQL_REPLICATION_USER"
    echo "CREATE ROLE $POSTGRESQL_REPLICATION_USER REPLICATION LOGIN ENCRYPTED PASSWORD '$escaped_password'" | postgresql_execute 
}

########################
# Change postgresql.conf by setting replication parameters
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_configure_replication_parameters() {
    info "Configuring replication parameters"
    postgresql_set_property "wal_level" "hot_standby"
    postgresql_set_property "max_wal_size" "400MB"
    postgresql_set_property "max_wal_senders" "16"
    postgresql_set_property "wal_keep_segments" "12"
    postgresql_set_property "hot_standby" "on"
    if (( POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS > 0 ));then
        postgresql_set_property "synchronous_commit" "$POSTGRESQL_SYNCHRONOUS_COMMIT_MODE"
        postgresql_set_property "synchronous_standby_names" "$POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS ($POSTGRESQL_CLUSTER_APP_NAME)"
    fi
}

########################
# Alter password of the postgres user
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_alter_postgres_user() {
    local -r escaped_password="${POSTGRESQL_PASSWORD//\'/\'\'}" 
    info "Changing password of ${POSTGRESQL_USERNAME}"
    echo "ALTER ROLE postgres WITH PASSWORD '$escaped_password';" | postgresql_execute
}

########################
# Create an admin user with all privileges in POSTGRESQL_DATABASE
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_create_admin_user() {
    local -r escaped_password="${POSTGRESQL_PASSWORD//\'/\'\'}" 
    info "Creating user ${POSTGRESQL_USERNAME}"
    echo "CREATE ROLE ${POSTGRESQL_USERNAME} WITH LOGIN CREATEDB PASSWORD '${escaped_password}';" | postgresql_execute
    info "Grating access to ${POSTGRESQL_USERNAME} to the database ${POSTGRESQL_DATABASE}"
    echo GRANT ALL PRIVILEGES ON DATABASE "${POSTGRESQL_DATABASE}" TO "${POSTGRESQL_USERNAME}"\; | postgresql_execute "" "postgres" "$POSTGRESQL_PASSWORD"
}

########################
# Create a database with name $POSTGRESQL_DATABASE
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_create_custom_database() {
    echo "CREATE DATABASE $POSTGRESQL_DATABASE" | postgresql_execute "" "postgres" "" "localhost"
}

########################
# Change postgresql.conf to listen in 0.0.0.0
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_enable_remote_connections() {
    postgresql_set_property "listen_addresses" "*"
}

########################
# Check if a given configuration file was mounted externally
# Globals:
#   POSTGRESQL_*
# Arguments:
#   $1 - Filename
# Returns:
#   1 if the file was mounted externally, 0 otherwise
#########################
postgresql_is_file_external() {
    local -r filename=$1
    if [[ -d "$POSTGRESQL_MOUNTED_CONFDIR" ]] && [[ -f "$POSTGRESQL_MOUNTED_CONFDIR"/"$filename" ]]; then
        return 0
    else
        return 1
    fi
}

########################
# Ensure PostgreSQL is initialized
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_initialize() {
    info "Initializing PostgreSQL database..."

    # User injected custom configuration
    if [[ -d "$POSTGRESQL_MOUNTED_CONFDIR" ]] && compgen -G "$POSTGRESQL_MOUNTED_CONFDIR"/* > /dev/null;then
        debug "Copying files from $POSTGRESQL_MOUNTED_CONFDIR to $POSTGRESQL_CONFDIR"
        cp -fr "$POSTGRESQL_MOUNTED_CONFDIR"/* "$POSTGRESQL_CONFDIR"
    fi
    local create_conf_file=yes
    local create_pghba_file=yes

    if postgresql_is_file_external "postgresql.conf"; then
        debug "Custom configuration $POSTGRESQL_CONFFILE detected"
        create_conf_file=no
    fi

    if postgresql_is_file_external "pg_hba.conf"; then
        debug "Custom configuration $POSTGRESQL_PGHBAFILE detected"
        create_pghba_file=no
    fi

    debug "Ensuring expected directories/files exist..."
    for dir in "$POSTGRESQL_TMPDIR" "$POSTGRESQL_LOGDIR"; do
        ensure_dir_exists "$dir"
        am_i_root && chown "$DB_DAEMON_USER:$DB_DAEMON_GROUP" "$dir"
    done
    is_boolean_yes "$create_conf_file" && postgresql_create_config
    is_boolean_yes "$create_pghba_file" && postgresql_create_pghba && postgresql_allow_local_connection

    if [[ -e "$POSTGRESQL_DATADIR" ]]; then
        info "Deploying PostgreSQL with persisted data..."
        local -r postmaster_path="$POSTGRESQL_DATADIR"/postmaster.pid
        if [[ -f "$postmaster_path" ]];then
            info "Cleaning stale postmaster.pid file"
            rm "$postmaster_path"
        fi
        is_boolean_yes "$create_pghba_file" && postgresql_restrict_pghba
        is_boolean_yes "$create_conf_file" && postgresql_configure_replication_parameters
        [[ "$POSTGRESQL_REPLICATION_MODE" = "master" ]] && [[ -n "$POSTGRESQL_REPLICATION_USER" ]] && is_boolean_yes "$create_pghba_file" && postgresql_add_replication_to_pghba
    else
        ensure_dir_exists "$POSTGRESQL_DATADIR"
        am_i_root && chown "$DB_DAEMON_USER:$DB_DAEMON_GROUP" "$POSTGRESQL_DATADIR"
        if [[ "$POSTGRESQL_REPLICATION_MODE" = "master" ]];then
            postgresql_master_init_db
            postgresql_start_bg
            [[ -n "${POSTGRESQL_DATABASE}" ]] && postgresql_create_custom_database
            if [[ "$POSTGRESQL_USERNAME" = "postgres" ]];then
                postgresql_alter_postgres_user
            else
                postgresql_create_admin_user
            fi
            is_boolean_yes "$create_pghba_file" && postgresql_restrict_pghba
            [[ -n "$POSTGRESQL_REPLICATION_USER" ]] && postgresql_create_replication_user
            is_boolean_yes "$create_conf_file" && postgresql_configure_replication_parameters
            [[ -n "$POSTGRESQL_REPLICATION_USER" ]] && is_boolean_yes "$create_pghba_file" && postgresql_add_replication_to_pghba
        else 
            postgresql_slave_init_db
            is_boolean_yes "$create_pghba_file" && postgresql_restrict_pghba
            is_boolean_yes "$create_conf_file" && postgresql_configure_replication_parameters
            postgresql_configure_recovery
        fi
    fi

    # Delete conf files generated on first run
    rm -f "$POSTGRESQL_DATADIR"/postgresql.conf "$POSTGRESQL_DATADIR"/pg_hba.conf
}

########################
# Run custom initialization scripts
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_custom_init_scripts() {
    info "Loading custom scripts..."   
    if [[ -n $(find /docker-entrypoint-initdb.d/ -type f -regex ".*\.\(sh\|sql\|sql.gz\)") ]] && [[ ! -f "$POSTGRESQL_VOLUMEDIR/.user_scripts_initialized" ]] ; then
        info "Loading user's custom files from /docker-entrypoint-initdb.d ...";
        postgresql_start_bg
        find /docker-entrypoint-initdb.d/ -type f -regex ".*\.\(sh\|sql\|sql.gz\)" | sort | while read -r f; do
            case "$f" in
                *.sh)
                    if [[ -x "$f" ]]; then
                        debug "Executing $f"; "$f"
                    else
                        debug "Sourcing $f"; . "$f"
                    fi
                    ;;
                *.sql)    debug "Executing $f"; postgresql_execute "$POSTGRESQL_DATABASE" "$POSTGRESQL_USERNAME" "$POSTGRESQL_PASSWORD" < "$f";;
                *.sql.gz) debug "Executing $f"; gunzip -c "$f" | postgresql_execute "$POSTGRESQL_DATABASE" "$POSTGRESQL_USERNAME" "$POSTGRESQL_PASSWORD";;
                *)        debug "Ignoring $f" ;;
            esac
        done
        touch "$POSTGRESQL_VOLUMEDIR"/.user_scripts_initialized
    fi
}

########################
# Stop PostgreSQL
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_stop() {
    info "Stopping PostgreSQL..."
    stop_service_using_pid "$POSTGRESQL_PIDFILE"
}

########################
# Execute an arbitrary query/queries against the running PostgreSQL service
# Stdin:
#   Query/queries to execute
# Globals:
#   BITNAMI_DEBUG
#   POSTGRESQL_*
# Arguments:
#   $1 - Database where to run the queries
#   $2 - User to run queries
#   $3 - Password
#   $4 - Host
# Returns:
#   None
postgresql_execute() {
    local -r db="${1:-}"
    local -r user="${2:-postgres}"
    local -r pass="${3:-}"
    local -r host="${4:-localhost}"
    local args=( "-h" "$host" "-U" "$user" )
    local cmd=("$POSTGRESQL_BINDIR/psql")
    [[ -n "$db" ]] && args+=( "-d" "$db" )
    if [[ "${BITNAMI_DEBUG:-false}" = true ]]; then
        PGPASSWORD=$pass "${cmd[@]}" "${args[@]}"
    else
        PGPASSWORD=$pass "${cmd[@]}" "${args[@]}" >/dev/null 2>&1
    fi
}

########################
# Start PostgreSQL and wait until it is ready
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   None
#########################
postgresql_start_bg() {
    local -r pg_ctl_flags=("-w" "-D" "$POSTGRESQL_DATADIR" -l "$POSTGRESQL_LOGFILE" "-o" "--config-file=$POSTGRESQL_CONFFILE --external_pid_file=$POSTGRESQL_PIDFILE --hba_file=$POSTGRESQL_PGHBAFILE")
    info "Starting PostgreSQL in background..."
    is_postgresql_running && return
    "$POSTGRESQL_BINDIR"/pg_ctl "start" "${pg_ctl_flags[@]}"
    local -r pg_isready_args=("-U" "postgres")
    local counter=$POSTGRESQL_INIT_MAX_TIMEOUT
    while ! "$POSTGRESQL_BINDIR"/pg_isready "${pg_isready_args[@]}";do 
        sleep 1
        counter=$((counter - 1 ))
        if (( counter <= 0 ));then
            error "PostgreSQL is not ready after $POSTGRESQL_INIT_MAX_TIMEOUT seconds"
            exit 1
        fi
    done
}

########################
# Check if PostgreSQL is running
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_postgresql_running() {
    local pid
    pid="$(get_pid_from_file "$POSTGRESQL_PIDFILE")"

    if [[ -z "$pid" ]]; then
        false
    else
        is_service_running "$pid"
    fi
}

########################
# Initialize master node database by running initdb
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   Boolean
#########################
postgresql_master_init_db() {
    local initdb_args=()
    if [[ -n "${POSTGRESQL_INITDB_ARGS[*]}" ]];then
        initdb_args+=(${POSTGRESQL_INITDB_ARGS[@]})
    fi
    if [[ -n "$POSTGRESQL_INITDB_WALDIR" ]];then
        ensure_dir_exists "$POSTGRESQL_INITDB_WALDIR"
        am_i_root && chown "$DB_DAEMON_USER:$DB_DAEMON_GROUP" "$POSTGRESQL_INITDB_WALDIR"
        initdb_args+=("--waldir" "$POSTGRESQL_INITDB_WALDIR")
    fi
    if [[ -n "${initdb_args[*]:-}" ]];then
        info "Initializing PostgreSQL with ${initdb_args[*]} extra initdb arguments"
        "$POSTGRESQL_BINDIR/initdb" -E UTF8 -D "$POSTGRESQL_DATADIR" -U "postgres" "${initdb_args[@]}"
    else 
        "$POSTGRESQL_BINDIR/initdb" -E UTF8 -D "$POSTGRESQL_DATADIR" -U "postgres"
    fi
}

########################
# Initialize slave node by running pg_basebackup 
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   Boolean
#########################
postgresql_slave_init_db() {
    info "Waiting for replication master to accept connections (60s timeout)..."
    local -r check_args=("-U" "$POSTGRESQL_REPLICATION_USER" "-h" "$POSTGRESQL_MASTER_HOST" "-p" "$POSTGRESQL_MASTER_PORT_NUMBER" "-d" "postgres")
    local -r check_cmd=("$POSTGRESQL_BINDIR"/pg_isready)
    local ready_counter=$POSTGRESQL_INIT_MAX_TIMEOUT

    while ! PGPASSWORD=$POSTGRESQL_REPLICATION_PASSWORD "${check_cmd[@]}" "${check_args[@]}";do 
        sleep 1
        ready_counter=$(( ready_counter - 1 ))
        if (( ready_counter <= 0 ));then
            error "PostgreSQL master is not ready after $POSTGRESQL_INIT_MAX_TIMEOUT seconds"
            exit 1
        fi

    done
    info "Replicating the initial database"
    local -r backup_args=("-D" "$POSTGRESQL_DATADIR" "-U" "$POSTGRESQL_REPLICATION_USER" "-h" "$POSTGRESQL_MASTER_HOST" "-X" "stream" "-w" "-v" "-P")
    local -r backup_cmd=("$POSTGRESQL_BINDIR"/pg_basebackup)
    local replication_counter=$POSTGRESQL_INIT_MAX_TIMEOUT
    while ! PGPASSWORD=$POSTGRESQL_REPLICATION_PASSWORD "${backup_cmd[@]}" "${backup_args[@]}";do
        debug "Backup command failed. Sleeping and trying again"
        sleep 1
        replication_counter=$(( replication_counter - 1 ))
        if (( replication_counter <= 0 ));then
            error "Slave replication failed after trying for $POSTGRESQL_INIT_MAX_TIMEOUT seconds"
            exit 1
        fi
    done
    chmod 0700 "$POSTGRESQL_DATADIR"
}

########################
# Create recovery.conf in slave node 
# Globals:
#   POSTGRESQL_*
# Arguments:
#   None
# Returns:
#   Boolean
#########################
postgresql_configure_recovery() {
    info "Setting up streaming replication slave..."
    cp -f "$POSTGRESQL_BASEDIR/share/recovery.conf.sample" "$POSTGRESQL_RECOVERYFILE"
    chmod 600 "$POSTGRESQL_RECOVERYFILE"
    postgresql_set_property "standby_mode" "on" "$POSTGRESQL_RECOVERYFILE"
    postgresql_set_property "primary_conninfo" "host=$POSTGRESQL_MASTER_HOST port=$POSTGRESQL_MASTER_PORT_NUMBER user=$POSTGRESQL_REPLICATION_USER password=$POSTGRESQL_REPLICATION_PASSWORD application_name=$POSTGRESQL_CLUSTER_APP_NAME" "$POSTGRESQL_RECOVERYFILE"
    postgresql_set_property "trigger_file" "/tmp/postgresql.trigger.$POSTGRESQL_MASTER_PORT_NUMBER" "$POSTGRESQL_RECOVERYFILE"
}
