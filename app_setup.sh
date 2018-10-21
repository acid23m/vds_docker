#!/usr/bin/env bash

# --------------------------------------------------------------------
# THIS SCRIPT AUTOMATICALLY CONFIGURES DOCKER ORIENTED WEB APPLICATION
# --------------------------------------------------------------------


set -ae
. ./.env
set +a



if [[ $(id -u) != 0 ]]; then
    echo "Run script with superuser privileges!"
    exit 1
fi

if [[ -z $1 ]] || [[ -z $2 ]] || [[ -z $3 ]] || [[ -z $4 ]]; then
    echo "Usage: ./app_setup.sh [GIT ADDRESS] [PROJECT DIR NAME] [SITE_DOMAIN] [SITE_PORT]"
    echo "ex.: ./app_setup.sh git@bitbucket.org:acid23m/base-docker-app.git base base-app.com 8000"
    exit 2
fi

GIT_ADDRESS=$1
PROJECT_DIR_NAME=$2
SITE_DOMAIN=$3
SITE_PORT=$4



# nginx config
echo -e "\n *** Setup NGINX ***"
echo -e "-------------------------------------------\n"

service nginx stop
if [[ "$VDS_IS_REMOTE" = "y" ]]; then
    CERT_PATH="/etc/certs/${SITE_DOMAIN}/cert.crt"
    CERT_KEY_PATH="/etc/certs/${SITE_DOMAIN}/cert.key"
    mkdir -pv "/etc/certs/${SITE_DOMAIN}"
    # get letsencrypt certificate
    /root/.acme.sh/acme.sh --issue -d "${SITE_DOMAIN}" -d "www.${SITE_DOMAIN}" --standalone -k 4096 --force
    /root/.acme.sh/acme.sh --install-cert -d "${SITE_DOMAIN}" --key-file "${CERT_KEY_PATH}" --fullchain-file "${CERT_PATH}"
else
    CERT_PATH="/etc/certs/self-signed/cert.crt"
    CERT_KEY_PATH="/etc/certs/self-signed/cert.key"
fi
SITE_NGINX_CONF="${PROJECT_DIR_NAME}_${SITE_PORT}.conf"
sed -e "s|SITE_DOMAIN|${SITE_DOMAIN}|g; s|PORT|${SITE_PORT}|g; s|CERT_PATH|${CERT_PATH}|g; s|CERT_KEY_PATH|${CERT_KEY_PATH}|g" "$PWD/nginx/site.conf" > "/etc/nginx/conf.d/${SITE_NGINX_CONF}"
chmod 644 "/etc/nginx/conf.d/${SITE_NGINX_CONF}"
service nginx start



# get project
echo -e "\n *** Get project ***"
echo -e "-------------------------------------------\n"

git clone "${GIT_ADDRESS}" "/var/www/${PROJECT_DIR_NAME}"
chown -R "${VDS_USER}:www-data" "/var/www/${PROJECT_DIR_NAME}"



# install project
echo -e "\n *** Install project ***"
echo -e "-------------------------------------------\n"

INIT_DIR=$PWD
cd "/var/www/${PROJECT_DIR_NAME}"
cp -av .env.example .env
nano .env
/bin/bash "$PWD/start.sh"
/bin/bash "$PWD/install.sh"
cd ${INIT_DIR}



# result
echo -e "\n *** All Done! ***"
echo "-------------------------------------------"
echo "Visit web site at: https://${SITE_DOMAIN}"
echo "Docker manager: https://${PORTAINER_DOMAIN}"

exit 0
