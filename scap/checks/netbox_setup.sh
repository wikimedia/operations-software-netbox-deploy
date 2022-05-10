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

# Regenerate network paths
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py trace_paths --no-input

# Collect static files
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py collectstatic --no-input

# Delete any stale content types
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py remove_stale_contenttypes --no-input

# Delete any expired user sessions
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py clearsessions

# Clear all cached data
${PYTHON} ${NETBOX_ROOT}/netbox/manage.py clearcache
