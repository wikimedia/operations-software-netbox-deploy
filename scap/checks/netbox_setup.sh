#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

VENV=/srv/deployment/netbox/venv
NETBOX_ROOT=/srv/deployment/netbox/deploy/netbox
PYTHON=${VENV}/bin/python3

# Run database migration
python3 manage.py migrate
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py migrate

# Collect static files
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py collectstatic --no-input
