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
