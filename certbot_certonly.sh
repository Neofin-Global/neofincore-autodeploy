#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/certbot_certonly.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);

source /var/site/neofincore-autodeploy/.env
#export POSTGRES_HOST=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' postgresql)
export POSTGRES_HOST=$(docker exec postgresql sh -c "hostname -i" | awk '{print $1}')

domains_arr=$(python3 /var/site/neofincore-autodeploy/get_merchant_domains.py --domain ${PARENT_HOST} --db_host ${POSTGRES_HOST} --db_port ${POSTGRES_PORT} --db_name ${POSTGRES_DB} --db_user ${POSTGRES_USER} --db_pass ${POSTGRES_PASSWORD});

if [[ "${PROJECT_ENVIRONMENT}" == "stage" ]]; then
  COMPOSE_FILE="docker-compose.yml"
else
  COMPOSE_FILE="docker-compose-app.yml"
fi
# Check if local.docker-compose.yml exists, use it, otherwise fallback to docker-compose.yml
if [ -f "/var/site/neofincore-autodeploy/local.docker-compose.yml" ]; then
  COMPOSE_FILE="local.docker-compose.yml"
fi

if [[ -n "$domains_arr" ]]; then
  echo "NEW merchant domains:";
  echo "$domains_arr"

  for domain in $domains_arr; do
    docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" run certbot-prod certonly --webroot -w /var/www/certbot --force-renewal --email ${DOMAIN_OWNER_EMAIL} -d $domain --agree-tos
    echo "server { listen 443 ssl http2; listen [::]:443 ssl http2; server_name $domain; ssl_certificate /etc/nginx/ssl/live/$domain/fullchain.pem; ssl_certificate_key /etc/nginx/ssl/live/$domain/privkey.pem; location / { proxy_pass http://webapp; } location /.well-known/acme-challenge/ { root /var/www/certbot; } location /media/ { alias /media/; } location /static/ { alias /static/; } }" >> /var/site/neofincore-autodeploy/nginx/default-production.conf
    docker compose -f "/var/site/neofincore-autodeploy/$COMPOSE_FILE" restart nginx-prod
  done
fi
