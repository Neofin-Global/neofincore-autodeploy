#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/restart_app.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);

# Activate ENV
source /var/site/neofincore-autodeploy/.env

# Stop containers
docker compose -f /var/site/neofincore-autodeploy/docker-compose.yml --profile "${PROJECT_ENVIRONMENT}" --profile "${PROVIDER_NAME}" down
# Start containers
docker compose -f /var/site/neofincore-autodeploy/docker-compose.yml --profile "${PROJECT_ENVIRONMENT}" --profile "${PROVIDER_NAME}" up -d
