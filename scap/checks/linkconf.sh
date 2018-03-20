#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

DEPLOY_DIR=/srv/deployment/netbox/deploy

# Create symlinks between configuration files and location netbox is expecting them
if [ ! -f ${DEPLOY_DIR}/netbox/netbox/netbox/configuration.py ]; then
	ln -s /etc/netbox-configuration.py ${DEPLOY_DIR}/netbox/netbox/netbox/configuration.py
fi

if [ ! -f ${DEPLOY_DIR}/netbox/netbox/netbox/ldap_config.py ]; then
    ln -s /etc/netbox-ldap.py ${DEPLOY_DIR}/netbox/netbox/netbox/ldap_config.py
fi
