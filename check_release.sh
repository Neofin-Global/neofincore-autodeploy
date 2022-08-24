#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/check_release.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);

# Activate ENV
source /var/site/neofincore-autodeploy/.env

# Get latest release version from Control Panel
NEW_VERSION=$(curl -s "https://${CONTROL_PANEL_HOST}/api/v1/releases/latest/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" | python3 -c "import sys, json; print(json.load(sys.stdin)['stripped_tag'])")

AUTOUPDATE_ENABLED=$(curl -s "https://${CONTROL_PANEL_HOST}/api/v1/projects/${PROJECT_UID}/upgrades/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" | python3 -c "import sys, json; print(json.load(sys.stdin)['active_autoupdate'])")

echo "Current version: ${APPLICATION_VERSION}; New version: ${NEW_VERSION}; Autoupdate enabled: ${AUTOUPDATE_ENABLED}";

if [[ "${AUTOUPDATE_ENABLED}" == "True" ]]; then

  if [[ "${APPLICATION_VERSION}" == "$NEW_VERSION" ]]; then
    echo "Versions equal";
  else
    echo "Versions NOT equal";

    # Save current version
    PREV_VERSION=${APPLICATION_VERSION}

    # Set new verion to ENV
    sed -i "s/APPLICATION_VERSION=${APPLICATION_VERSION}/APPLICATION_VERSION=$NEW_VERSION/gI" /var/site/neofincore-autodeploy/.env
    # Activate ENV
    source /var/site/neofincore-autodeploy/.env

    # Update containers
    docker compose -f /var/site/neofincore-autodeploy/docker-compose.yml up --quiet-pull --build --no-start
    docker compose -f /var/site/neofincore-autodeploy/docker-compose.yml up -d --quiet-pull
    # Remove old images
    docker image prune -a -f

    # Send notification about upgrade to Control Panel (neo-fin.com)
    curl --location --request POST "https://${CONTROL_PANEL_HOST}/api/v1/projects/${PROJECT_UID}/upgrades/notification/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"previous_version\": \"${PREV_VERSION}\", \"new_version\": \"${NEW_VERSION}\"}"

  fi
fi
