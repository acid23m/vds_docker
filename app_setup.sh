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

if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo "Usage: ./app_setup.sh [GIT ADDRESS] [PROJECT DIR NAME]"
    echo "ex.: ./app_setup.sh git@bitbucket.org:acid23m/base-docker-app.git base"
    exit 2
fi

GIT_ADDRESS=$1
PROJECT_DIR_NAME=$2



# get project
echo -e "\n *** Get project ***"
echo -e "-------------------------------------------\n"


cd /var/www
git clone "${GIT_ADDRESS}" "${PROJECT_DIR_NAME}"
chown -R "${VDS_USER}:www-data" "${PROJECT_DIR_NAME}"
cd "${PROJECT_DIR_NAME}"



exit 0
