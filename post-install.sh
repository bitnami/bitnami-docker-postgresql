#!/bin/bash
cd $BITNAMI_APP_DIR

set_pg_param() {
  local key=${1}
  local value=${2}

  if [[ -n ${value} ]]; then
    local current=$(sed -n -e "s/^\(${key} = '\)\([^ ']*\)\(.*\)$/\2/p" $BITNAMI_APP_DIR/conf/postgresql.conf)
    if [[ "${current}" != "${value}" ]]; then
      value="$(echo "${value}" | sed 's|[&]|\\&|g')"
      sed -i "s|^[#]*[ ]*${key} = .*|${key} = '${value}'|" $BITNAMI_APP_DIR/conf/postgresql.conf
    fi
  fi
}

set_hba_param() {
  local value=${1}
  if ! grep -q "$(sed "s| | \\\+|g" <<< ${value})" $BITNAMI_APP_DIR/conf/pg_hba.conf; then
    echo -e "\n${value}" >> $BITNAMI_APP_DIR/conf/pg_hba.conf
  fi
}

# set up default configs
mv $BITNAMI_APP_DIR/data/pg_hba.conf $BITNAMI_APP_DIR/conf/
mv $BITNAMI_APP_DIR/data/pg_ident.conf $BITNAMI_APP_DIR/conf/

# default
set_pg_param "listen_addresses" "*"
set_pg_param "logging_collector" "on"
set_pg_param "log_directory" "$BITNAMI_APP_DIR/logs"
set_pg_param "log_filename" "postgresql.log"

# hot standby
set_pg_param "wal_level" "hot_standby"
set_pg_param "max_wal_senders" "16"
set_pg_param "checkpoint_segments" "8"
set_pg_param "wal_keep_segments" "32"
set_pg_param "hot_standby" "on"

set_hba_param "host all all 0.0.0.0/0 md5"
set_hba_param "host replication all 0.0.0.0/0 md5"

mv $BITNAMI_APP_DIR/conf $BITNAMI_APP_DIR/conf.defaults

# remove existing default data
rm -rf $BITNAMI_APP_DIR/data

# symlink mount points at root to install dir
ln -s $BITNAMI_APP_DIR/data $BITNAMI_APP_VOL_PREFIX/data
ln -s $BITNAMI_APP_DIR/logs $BITNAMI_APP_VOL_PREFIX/logs
ln -s $BITNAMI_APP_DIR/conf $BITNAMI_APP_VOL_PREFIX/conf
