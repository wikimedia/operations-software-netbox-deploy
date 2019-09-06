# Specialized makefile for building the deployment artifacts
# Global build dir
BUILD_DIR = $(CURDIR)/build
# Directory where the wheels are built
WHEELS_DIR = $(BUILD_DIR)/wheels
IMG_BASENAME := docker-registry.wikimedia.org/python3-build
BUSTER_ARTIFACTS = $(WHEELS_DIR)/buster/artifacts.tar.gz
# frozen-requirements related
VENV=$(BUILD_DIR)/venv


### Build-related tasks ###
# task all
# clean the build environment, and recreate the wheels.
all: clean frozen_requirements.txt artifacts

# task artifacts
# Build the wheels for all or a specific DISTRO inside a container, and get the tar to the right place
artifacts: $(BUSTER_ARTIFACTS)
	cp $(BUSTER_ARTIFACTS) $(CURDIR)/artifacts/artifacts.buster.tar.gz

$(BUSTER_ARTIFACTS): .docker_built
	mkdir -p $(WHEELS_DIR)/buster
	docker run --rm -v $(CURDIR):/deploy:ro -v $(WHEELS_DIR)/buster:/wheels:rw -v /etc/group:/etc/group:ro \
		-v /etc/passwd:/etc/passwd:ro --user=$(UID) netbox-build:local

# task clean[-DISTRO]
# clean docker artifacts for one distro, or all artifacts
clean:
	- rm -rf $(WHEELS_DIR)
	- rm -rf .docker_built

.docker_built: Dockerfile.build freeze_requirements.sh
	docker pull $(IMG_BASENAME)-buster:latest
	docker build -f Dockerfile.build -t netbox-build:local .
	@touch $@

# If you want to refresh the frozen_requirements.txt file, you can do so with this task
frozen_requirements.txt: .docker_built requirements.txt src/requirements.txt
	docker run --rm -v $(CURDIR):/deploy:rw -v /etc/group:/etc/group:ro \
		-v /etc/passwd:/etc/passwd:ro --user=$(UID) netbox-build:local /bin/freeze

.PHONY: artifacts all wheels clean
