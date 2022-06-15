#!/bin/bash

set -e

# Redirect stdout and stderr to logging file
LOG_FILE="/var/log/certbot_certonly.log";
exec > >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done);
exec 2> >(while read -r line; do printf '[%s] %s\n' "$(date --rfc-3339=seconds)" "$line" | tee -a $LOG_FILE; done >&2);

source /var/site/neofincore-autodeploy/.env
export POSTGRES_HOST=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' postgresql)

domains_arr=$(python3 /var/site/neofincore-autodeploy/get_merchant_domains.py --domain ${PARENT_HOST} --db_host ${POSTGRES_HOST} --db_port ${POSTGRES_PORT} --db_name ${POSTGRES_DB} --db_user ${POSTGRES_USER} --db_pass ${POSTGRES_PASSWORD});

if [[ -n "$domains_arr" ]]; then
  echo "NEW merchant domains:";
  echo $domains_arr


  for domain in $domains_arr; do
    docker compose -f docker-compose.yml run certbot-digitalocean-prod certonly --webroot -w /var/www/certbot --force-renewal --email ${DOMAIN_OWNER_EMAIL} -d $domain --agree-tos
  done
fi
