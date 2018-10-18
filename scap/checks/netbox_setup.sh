#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

VENV=/srv/deployment/netbox/venv
NETBOX_ROOT=/srv/deployment/netbox/deploy/src
PYTHON=${VENV}/bin/python3

# Delete stale bytecode
find "${NETBOX_ROOT}" -name "*.pyc" -delete

# Run database migration
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py migrate

# Collect static files
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py collectstatic --no-input
