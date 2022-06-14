#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/certbot_certonly.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);

export PARENT_HOST=$PARENT_HOST
export POSTGRES_HOST=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' postgresql)
export POSTGRES_PORT=$POSTGRES_PORT
export POSTGRES_DB=$POSTGRES_DB
export POSTGRES_USER=$POSTGRES_USER
export POSTGRES_PASSWORD=$POSTGRES_PASSWORD
export DOMAIN_OWNER_EMAIL=DOMAIN_OWNER_EMAIL

domains_arr=$(python3 /var/site/neofincore-autodeploy/get_merchant_domains.py);
echo "NEW merchant domains:";
echo $domains_arr


for domain in $domains_arr; do
  docker compose -f docker-compose.yml run certbot-digitalocean-prod certonly --webroot -w /var/www/certbot --force-renewal --email ${DOMAIN_OWNER_EMAIL} -d $domain --agree-tos
done
