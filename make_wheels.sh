#!/usr/bin/env bash
# Build wheels for distribution
set -o errexit
set -o nounset
set -o pipefail

BASE=$(realpath $(dirname $0))
BUILD=${BASE}/_build
VENV=${BUILD}/venv
WHEEL_DIR=${BASE}/wheels
REQUIREMENTS=${BASE}/requirements_tmp.txt
REQUIREMENTS_FIXED=${BASE}/requirements.txt

PIP=${VENV}/bin/pip

mkdir -p $VENV
virtualenv --python python3 $VENV || /bin/true
$PIP install -r $REQUIREMENTS
$PIP freeze --local --requirement $REQUIREMENTS_FIXED > $REQUIREMENTS_FIXED
# https://github.com/pypa/pip/issues/4668
sed -i '/pkg-resources==0.0.0/d' $REQUIREMENTS_FIXED
$PIP install wheel
$PIP wheel --find-links $WHEEL_DIR \
	    --wheel-dir $WHEEL_DIR \
	        --requirement $REQUIREMENTS_FIXED

