#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

DEPLOY_DIR=/srv/deployment/netbox/deploy

# Create symlinks between configuration files and location netbox is expecting them

ln -s /etc/netbox-configuration.py ${DEPLOY_DIR}/netbox/netbox/netbox/configuration.py
ln -s /etc/netbox-ldap.py ${DEPLOY_DIR}/netbox/netbox/netbox/ldap_config.py.py
