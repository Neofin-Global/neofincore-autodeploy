#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/certbot_renew.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);


# Activate ENV
source /var/site/neofincore-autodeploy/.env

if [[ "${PROVIDER_NAME}" == "digitalocean" ]]; then
  CERTBOT_CONTAINER="certbot-digitalocean-stage";
elif [[ "${PROVIDER_NAME}" == "ec2" ]]; then
  CERTBOT_CONTAINER="certbot-aws-stage";
elif [[ "${PROVIDER_NAME}" == "azure" ]]; then
  CERTBOT_CONTAINER="certbot-azure-stage";
elif [[ "${PROVIDER_NAME}" == "gce" ]]; then
  CERTBOT_CONTAINER="certbot-google-stage";
fi

COMPOSE_FILE="docker-compose.yml"
# Check if local.docker-compose.yml exists, use it, otherwise fallback to docker-compose.yml
if [ -f "/var/site/neofincore-autodeploy/local.docker-compose.yml" ]; then
  COMPOSE_FILE="local.docker-compose.yml"
fi

if [[ -n "$CERTBOT_CONTAINER" ]]; then
  if [[ "${PROJECT_ENVIRONMENT}" == "stage" ]]; then
    if [[ "${PROVIDER_NAME}" == "azure" ]]; then
      docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" run ${CERTBOT_CONTAINER} certbot renew --quiet
    else
      docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" run ${CERTBOT_CONTAINER} renew --quiet
    fi
    docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" restart nginx
  else
    docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" run certbot-prod renew --quiet
    docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" restart nginx-prod
  fi
fi
