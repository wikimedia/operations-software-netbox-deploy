#!/usr/bin/env bash
# Create/update a python virtualenv using the wheel binaries
set -o errexit
set -o nounset
set -o pipefail

BASE_DIR=/srv/deployment/netbox-dev
VENV=${BASE_DIR}/venv
DEPLOY_DIR=${BASE_DIR}/deploy
WHEEL_DIR=${DEPLOY_DIR}/artifacts
DISTRO=$(lsb_release -sc)
REQUIREMENTS=${DEPLOY_DIR}/frozen-requirements-${DISTRO}.txt
PIP=${VENV}/bin/pip

# Ensure that the virtual environment exists
mkdir -p $VENV
virtualenv --python python3 $VENV || /bin/true

# Extract the wheels
(cd ${WHEEL_DIR} && tar --owner=$UID -zxvf "artifacts.${DISTRO}.tar.gz")

# Install first pip dependencies from wheel cache
$PIP install \
    --no-index \
    --find-links ${WHEEL_DIR} \
    --upgrade \
    --force-reinstall \
    pip wheel setuptools

# Install or upgrade all requirements from wheel cache
$PIP install \
    --no-index \
    --find-links ${WHEEL_DIR} \
    --upgrade \
    --force-reinstall \
    --requirement $REQUIREMENTS
