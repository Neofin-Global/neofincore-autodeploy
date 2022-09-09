#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/check_release.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);

# Activate ENV
source /var/site/neofincore-autodeploy/.env

AUTOUPDATE_ENABLED=$(curl -s "https://${CONTROL_PANEL_HOST}/api/v1/projects/${PROJECT_UID}/upgrades/?environment=${PROJECT_ENVIRONMENT}" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" | python3 -c "import sys, json; print(json.load(sys.stdin)['active_autoupdate'])")

echo "Autoupdate is enabled: ${AUTOUPDATE_ENABLED}";

if [[ "${AUTOUPDATE_ENABLED}" == "True" ]]; then

  if [[ "${PROJECT_ENVIRONMENT}" == "stage" ]]; then
    # update stage to latest
    echo "Update stage instance";

    # Get digest for django container
    # sha256:1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
    django_sha=$(docker inspect --format='{{index .Image}}' django)
    # 1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
    django_sha_clear=$(echo "$django_sha" | sed -r 's/(sha256:)//g')
    # echo "Django image digest ${django_sha_clear}"

    # index.docker.io/phonxis/neofincore_django_master:latest
    django_image=$(docker inspect --format='{{index .Config.Image}}' django)
    # echo "Django image ${django_image}"

    # phonxis/neofincore_django_master@sha256:4e2256e65c04778f16221ea85b249859400863a9d70fbe11962e43c69d371168
    repo_digest=$(docker inspect --format='{{index .RepoDigests 0}}' $django_sha_clear)
    echo "Current image digest ${repo_digest}"

    # sha256:4e2256e65c04778f16221ea85b249859400863a9d70fbe11962e43c69d371168
    image_digest=$(docker manifest inspect $django_image -v | python3 -c "import sys, json; print(json.load(sys.stdin)['Descriptor']['digest'])")
    echo "Newest image digest ${image_digest}"

    if [[ $repo_digest == *"$image_digest"* ]];
    then
        echo "Stage instance up to date"
    else
        echo "Stage instance updating..."

        # Get digest for celerybeat container
        # sha256:1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
        celerybeat_sha=$(docker inspect --format='{{index .Image}}' celerybeat)
        # 1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
        celerybeat_sha_clear=$(echo "$celerybeat_sha" | sed -r 's/(sha256:)//g')
        # echo "Celerybeat image digest ${celerybeat_sha_clear}"

        # Get digest for celeryworker container
        # sha256:1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
        celeryworker_sha=$(docker inspect --format='{{index .Image}}' celeryworker)
        # 1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
        celeryworker_sha_clear=$(echo "$celeryworker_sha" | sed -r 's/(sha256:)//g')
        # echo "Celeryworker image digest ${celeryworker_sha_clear}"

        # Get digest for flower container
        # sha256:1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
        flower_sha=$(docker inspect --format='{{index .Image}}' flower)
        # 1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
        flower_sha_clear=$(echo "$flower_sha" | sed -r 's/(sha256:)//g')
        # echo "Flower image digest ${flower_sha_clear}"

        NEW_VERSION="latest";
        echo "Current version: ${APPLICATION_VERSION}; New version: ${NEW_VERSION}";

        # Save current version
        PREV_VERSION=${APPLICATION_VERSION}
        # Set new verion to ENV
        sed -i "s/APPLICATION_VERSION=${APPLICATION_VERSION}/APPLICATION_VERSION=$NEW_VERSION/gI" /var/site/neofincore-autodeploy/.env
        # Activate ENV
        source /var/site/neofincore-autodeploy/.env
        # Update containers
        docker compose -f /var/site/neofincore-autodeploy/docker-compose.yml up --quiet-pull --build --no-start
        docker compose -f /var/site/neofincore-autodeploy/docker-compose.yml down
        # Remove cocrete images
        docker image rm ${django_sha_clear} -f
        docker image rm ${celerybeat_sha_clear} -f
        docker image rm ${celeryworker_sha_clear} -f
        docker image rm ${flower_sha_clear} -f

        docker compose -f /var/site/neofincore-autodeploy/docker-compose.yml up -d --quiet-pull
        # Remove old images
        docker image prune -a -f
        # Send notification about upgrade to Control Panel (neo-fin.com)
        curl --location --request POST "https://${CONTROL_PANEL_HOST}/api/v1/projects/${PROJECT_UID}/upgrades/notification/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"previous_version\": \"${PREV_VERSION}\", \"new_version\": \"${NEW_VERSION}\"}"
    fi

  else
    # update production to release version
    echo "Update production instance";

    # Get latest release version from Control Panel
    NEW_VERSION=$(curl -s "https://${CONTROL_PANEL_HOST}/api/v1/releases/latest/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" | python3 -c "import sys, json; print(json.load(sys.stdin)['stripped_tag'])")
    echo "Current version: ${APPLICATION_VERSION}; New version: ${NEW_VERSION}";

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
fi
