#!/bin/bash
set -e

if [[ "$1" == "harpoon" && "$2" == "start" ]]; then
  status=`harpoon inspect $BITNAMI_APP_NAME`
  if [[ "$status" == *'"lifecycle": "unpacked"'* ]]; then
    harpoon initialize $BITNAMI_APP_NAME --password ${POSTGRES_PASSWORD:-password}
  fi
fi

# HACKS

mkdir -p /bitnami/$BITNAMI_APP_NAME

if [ ! -d /bitnami/$BITNAMI_APP_NAME/conf ]; then
  cp -a /opt/bitnami/$BITNAMI_APP_NAME/conf /bitnami/$BITNAMI_APP_NAME/conf
fi
rm -rf /opt/bitnami/$BITNAMI_APP_NAME/conf
ln -sf /bitnami/$BITNAMI_APP_NAME/conf /opt/bitnami/$BITNAMI_APP_NAME/conf

if [ ! -d /bitnami/$BITNAMI_APP_NAME/data ]; then
  cp -a /opt/bitnami/$BITNAMI_APP_NAME/data /bitnami/$BITNAMI_APP_NAME/data
fi
rm -rf /opt/bitnami/$BITNAMI_APP_NAME/data
ln -sf /bitnami/$BITNAMI_APP_NAME/data /opt/bitnami/$BITNAMI_APP_NAME/data

## END OF HACKS

chown $BITNAMI_APP_USER: /bitnami/$BITNAMI_APP_NAME || true

exec /entrypoint.sh "$@"
