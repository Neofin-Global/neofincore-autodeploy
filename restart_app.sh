#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/restart_app.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);

# Activate ENV
source /var/site/neofincore-autodeploy/.env

COMPOSE_FILE="docker-compose.yml"
# Check if local.docker-compose.yml exists, use it, otherwise fallback to docker-compose.yml
if [ -f "/var/site/neofincore-autodeploy/local.docker-compose.yml" ]; then
  COMPOSE_FILE="local.docker-compose.yml"
fi

# Stop containers
docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" down
# Start containers
docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" up -d
