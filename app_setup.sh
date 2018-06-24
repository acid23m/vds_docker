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
    CERT_DIR=${SITE_DOMAIN}
    # get letsencrypt certificate
    acme.sh --issue -d "${SITE_DOMAIN}" --standalone -k 4096
    acme.sh --install-cert -d "${SITE_DOMAIN}" --key-file "/etc/certs/${CERT_DIR}/cert.key" --fullchain-file "/etc/certs/${CERT_DIR}/cert.crt"
else
    CERT_DIR="self-signed"
fi
sed -e "s/SITE_DOMAIN/${SITE_DOMAIN}/g; s/PORT/${SITE_PORT}/g; s/CERT_DIR/${CERT_DIR}/g" "$PWD/nginx/site.conf" > "/etc/nginx/conf.d/${PROJECT_DIR_NAME}.conf"
chmod 644 "/etc/nginx/conf.d/${PROJECT_DIR_NAME}.conf"
service nginx start



# get project
echo -e "\n *** Get project ***"
echo -e "-------------------------------------------\n"


cd /var/www
git clone "${GIT_ADDRESS}" "${PROJECT_DIR_NAME}"
chown -R "${VDS_USER}:www-data" "${PROJECT_DIR_NAME}"
cd "${PROJECT_DIR_NAME}"



# install project
echo -e "\n *** Get project ***"
echo -e "-------------------------------------------\n"

cp -av .env.example .env
nano .env



# result
echo -e "\n *** All Done! ***"
echo "-------------------------------------------"
echo "Visit web site at: https://${SITE_DOMAIN}"
echo "Docker manager: https://${PORTAINER_DOMAIN}"

exit 0
