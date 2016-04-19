#!/usr/bin/env bats

POSTGRES_DB=test_database
POSTGRES_USER=test_user
POSTGRES_PASSWORD=test_password

# source the helper script
APP_NAME=postgresql
VOL_PREFIX=/bitnami/$APP_NAME
VOLUMES=$VOL_PREFIX
SLEEP_TIME=20
container_link_and_run_command_DOCKER_ARGS="-e PGPASSWORD=$POSTGRES_PASSWORD"
load tests/docker_helper

# Link to container and execute psql client
# $1 : name of the container to link to
# ${@:2} : arguments for the psql command
psql_client() {
  container_link_and_run_command $1 psql -h $APP_NAME -p 5432 "${@:2}"
}

# Cleans up all running/stopped containers and host mounted volumes
cleanup_environment() {
  container_remove_full default
}

# Teardown called at the end of each test
teardown() {
  cleanup_environment
}

# cleanup the environment of any leftover containers and volumes before starting the tests
cleanup_environment

@test "Port 5432 exposed and accepting external connections" {
  container_create default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  # check if postgresql server is accepting connections
  run container_link_and_run_command default pg_isready -h $APP_NAME -p 5432 -t 5
  [[ "$output" =~ "accepting connections" ]]
}

@test "Root user created with custom password" {
  container_create default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  run psql_client default -U postgres -Axc "\l"
  [[ "$output" =~ "Name|postgres" ]]
}

@test "Root user is superuser" {
  container_create default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  run psql_client default -U postgres -Axc "SHOW is_superuser;"
  [[ $output =~ "is_superuser|on" ]]
}

@test "Root user can create databases" {
  container_create default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  psql_client default -U postgres -Axc "CREATE DATABASE $POSTGRES_DB;"
  run psql_client default -U postgres -Axc "\l"
  [[ "$output" =~ "Name|$POSTGRES_DB" ]]
}

@test "Root user can create users" {
  container_create default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  psql_client default -U postgres -Axc "CREATE ROLE $POSTGRES_USER with LOGIN CREATEDB PASSWORD '$POSTGRES_PASSWORD';"
  psql_client default -U postgres -Axc "CREATE DATABASE $POSTGRES_DB;"
  psql_client default -U postgres -Axc "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB to $POSTGRES_USER;"

  run psql_client default -U $POSTGRES_USER $POSTGRES_DB -Axc "\l"
  [[ "$output" =~ "Name|$POSTGRES_DB" ]]
}

@test "Data is preserved on container restart" {
  container_create default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  psql_client default -U postgres -Axc "CREATE ROLE $POSTGRES_USER with LOGIN CREATEDB PASSWORD '$POSTGRES_PASSWORD';"
  psql_client default -U postgres -Axc "CREATE DATABASE $POSTGRES_DB;"
  psql_client default -U postgres -Axc "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB to $POSTGRES_USER;"

  container_restart default

  run psql_client default -U $POSTGRES_USER $POSTGRES_DB -Axc "\l"
  [[ "$output" =~ "Name|$POSTGRES_DB" ]]
}

@test "All the volumes exposed" {
  container_create default -d

  run container_inspect default --format {{.Mounts}}
  [[ "$output" =~ "$VOL_PREFIX" ]]
}

@test "Data gets generated in volume if bind mounted in the host" {
  container_create_with_host_volumes default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  run container_exec default ls -la $VOL_PREFIX/data/
  [[ "$output" =~ "PG_VERSION" ]]
  [[ "$output" =~ "base" ]]

  run container_exec default ls -la $VOL_PREFIX/conf/
  [[ "$output" =~ "postgresql.conf" ]]
}

@test "If host mounted, password and settings are preserved after deletion" {
  container_create_with_host_volumes default -d \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD

  psql_client default -U postgres -Axc "CREATE ROLE $POSTGRES_USER with LOGIN CREATEDB PASSWORD '$POSTGRES_PASSWORD';"
  psql_client default -U postgres -Axc "CREATE DATABASE $POSTGRES_DB;"
  psql_client default -U postgres -Axc "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB to $POSTGRES_USER;"

  container_remove default
  container_create_with_host_volumes default -d

  run psql_client default -U $POSTGRES_USER $POSTGRES_DB -Axc "\l"
  [[ "$output" =~ "Name|$POSTGRES_DB" ]]
}
