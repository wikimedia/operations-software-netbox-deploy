#!/usr/bin/env bash
# Helper to refresh the frozen requirements file
# This is supposed to be run inside a docker container via
# the Makefile.build file
set -o errexit
set -o nounset
set -o pipefail
DISTRO=${1:-bullseye}
BASE=/deploy
BUILD=${BASE}/build
REQUIREMENTS=${BASE}/requirements.txt
REQUIREMENTS_FIXED=${BASE}/frozen-requirements-${DISTRO}.txt

pip3 install -r "$REQUIREMENTS"
pip3 install ${BASE}/plugins/ntc-netbox-plugin-metrics-ext
pip3 list --format=freeze --local > "$REQUIREMENTS_FIXED"
# https://github.com/pypa/pip/issues/4668
sed -i '/pkg-resources==0.0.0/d' "$REQUIREMENTS_FIXED"
echo "${REQUIREMENTS_FIXED} updated, please commit it to git."
