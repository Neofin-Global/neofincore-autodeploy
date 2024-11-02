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

  # Check if local.docker-compose.yml exists, use it, otherwise fallback to docker-compose.yml
  COMPOSE_FILE="docker-compose.yml"
  if [ -f "/var/site/neofincore-autodeploy/local.docker-compose.yml" ]; then
    COMPOSE_FILE="local.docker-compose.yml"
  fi

  if [[ "${PROJECT_ENVIRONMENT}" == "stage" ]]; then
    # update stage to latest
    echo "Update stage instance";


    # Get digest for django container
    # sha256:1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82 or set empty variable if django container not found
    django_sha=$(sudo docker inspect --format='{{index .Image}}' django) || django_sha=
    echo "Variable django_sha=${django_sha}"
    # Get django container hash
    # 1ecf52911a0c63d8c775cc6f0896ecd92fe0e4368623c587596b662335d16e82
    django_sha_clear=$(echo "$django_sha" | sed -r 's/(sha256:)//g')
    echo "Variable django_sha_clear=${django_sha_clear}"
    # Get django container image name
    # index.docker.io/phonxis/neofincore_django_master:latest or set empty variable if django container not found
    django_image=$(sudo docker inspect --format='{{index .Config.Image}}' django) || django_image=
    echo "Variable django_image=${django_image}"


    if [[ -z "$django_sha_clear" ]]; then
      # if django_sha_clear variable is empty then set repo_digest variable as empty
      repo_digest=
    else
      # phonxis/neofincore_django_master@sha256:4e2256e65c04778f16221ea85b249859400863a9d70fbe11962e43c69d371168
      repo_digest=$(sudo docker inspect --format='{{index .RepoDigests 0}}' $django_sha_clear) || repo_digest=
    fi
    echo "Variable repo_digest=${repo_digest}";


    if [[ -z "$django_image" ]]; then
      # if django_image variable is empty then set image_digest variable as empty
      image_digest=
    else
      # sha256:4e2256e65c04778f16221ea85b249859400863a9d70fbe11962e43c69d371168
      image_digest=$(sudo docker manifest inspect $django_image -v | python3 -c "import sys, json; print(json.load(sys.stdin)['Descriptor']['digest'])")
    fi
    echo "Variable image_digest=${image_digest}"


    # Check variables are empty or not
    if [[ -n "$repo_digest" && -n "$image_digest" ]]; then
      echo "Any of digests is not empty. Check digests equalness."
      if [[ $repo_digest == *"$image_digest"* ]]; then
        echo "Stage instance up to date"
      else
        echo "Stage instance updating..."

        NEW_VERSION="latest";
        echo "Current version: ${APPLICATION_VERSION}; New version: ${NEW_VERSION}";

        # Update containers
        docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} pull -q
        docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} down
        docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} up -d
        echo "Stage instance is starting up..."
        # Remove old images
        docker image prune -a -f
        # Remove unused volumes
        docker volume prune -f
        # Send notification about upgrade to Control Panel (neo-fin.com)
        curl --location --request POST "https://${CONTROL_PANEL_HOST}/api/v1/projects/${PROJECT_UID}/upgrades/notification/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"previous_version\": \"${PREV_VERSION}\", \"new_version\": \"${NEW_VERSION}\", \"environment\": \"stage\"}"
        # Execute initializing scripts (commands) like 'collectstatic', 'compilemessages' etc.
        docker exec django bash ./init.sh
        echo "Stage instance initialized"
      fi
    else
      echo "Both digests are empty."
      docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} down
      docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} pull -q
      docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} up -d
      echo "Stage instance is starting up..."
      # Send notification about upgrade to Control Panel (neo-fin.com)
      curl --location --request POST "https://${CONTROL_PANEL_HOST}/api/v1/projects/${PROJECT_UID}/upgrades/notification/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"previous_version\": \"${PREV_VERSION}\", \"new_version\": \"${NEW_VERSION}\", \"environment\": \"stage\"}"
      # Execute initializing scripts (commands) like 'collectstatic', 'compilemessages' etc.
      docker exec django bash ./init.sh
      echo "Stage instance initialized"
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

      # 0 - image exists
      # 1 - image not found
      image_not_found=$(docker manifest inspect phonxis/neofincore_django_master:${NEW_VERSION} > /dev/null ; echo $?)
      if [[ "${image_not_found}" == "1" ]]; then
        echo "Image phonxis/neofincore_django_master:${NEW_VERSION} not available"
      else
        # Save current version
        PREV_VERSION=${APPLICATION_VERSION}

        # Set new verion to ENV
        sed -i "s/APPLICATION_VERSION=${APPLICATION_VERSION}/APPLICATION_VERSION=$NEW_VERSION/gI" /var/site/neofincore-autodeploy/.env
        # Activate ENV
        source /var/site/neofincore-autodeploy/.env

        # Update containers
        docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} down
        docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} pull -q
        docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" --profile ${PROJECT_ENVIRONMENT} --profile ${PROVIDER_NAME} up -d
        echo "Production instance is starting up..."
        # Remove old images
        docker image prune -a -f
        # Remove unused volumes
        docker volume prune -f

        # Send notification about upgrade to Control Panel (neo-fin.com)
        curl --location --request POST "https://${CONTROL_PANEL_HOST}/api/v1/projects/${PROJECT_UID}/upgrades/notification/" --header "Authorization: Service-token ${CONTROL_PANEL_SERVICE_TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"previous_version\": \"${PREV_VERSION}\", \"new_version\": \"${NEW_VERSION}\", \"environment\": \"production\"}"

        # Execute initializing scripts (commands) like 'collectstatic', 'compilemessages' etc.
        docker exec django bash ./init.sh
        echo "Production instance initialized"
      fi
    fi
  fi
fi
