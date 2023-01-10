# Specialized makefile for building the deployment artifacts
# Debian version to build for
DEBIAN_VER ?= bullseye
echo:
	echo ${DEBIAN_VER}
# Global build dir
BUILD_DIR = $(CURDIR)/build
# Directory where the wheels are built
WHEELS_DIR = $(BUILD_DIR)/wheels
# Docker image
IMG_NAME := docker-registry.wikimedia.org/python3-build-$(DEBIAN_VER)
# Where to save the artficats
ARTIFACTS := $(WHEELS_DIR)/$(DEBIAN_VER)/artifacts.tar.gz# frozen-requirements related

### Build-related tasks ###
# task all
# clean the build environment, generate the new frozen requirements and recreate the wheels.
all: clean freeze artifacts

# task artifacts
# Build the wheels for the specific DISTRO inside a container, and get the tar.gz to the right place
artifacts: $(ARTIFACTS)
	cp $(ARTIFACTS) $(CURDIR)/artifacts/artifacts.$(DEBIAN_VER).tar.gz

$(ARTIFACTS): .docker_built freeze frozen-requirements-$(DEBIAN_VER).txt
	mkdir -p $(WHEELS_DIR)/$(DEBIAN_VER)
	rm -f frozen-requirements.txt
	ln -s frozen-requirements-$(DEBIAN_VER).txt frozen-requirements.txt
	docker run --rm -v $(CURDIR):/deploy:ro -v $(WHEELS_DIR)/$(DEBIAN_VER):/wheels:rw -v /etc/group:/etc/group:ro \
		-v /etc/passwd:/etc/passwd:ro --user=$(UID) netbox-$(DEBIAN_VER):local

# task clean
# clean docker artifacts for one distro
clean:
	- rm -rf $(WHEELS_DIR)/$(DEBIAN_VER)
	- rm -rf frozen-requirements.txt
	- rm -rf .docker_built
	- rm -rf Dockerfile.build

.docker_built: Dockerfile.build freeze_requirements.sh
	docker pull $(IMG_NAME):latest
	docker build --build-arg DEBIAN_VER=$(DEBIAN_VER) -f Dockerfile.build -t netbox-$(DEBIAN_VER):local .
	@touch $@

Dockerfile.build:
	sed 's|__IMG_NAME__|$(IMG_NAME)|' Dockerfile.build.in > Dockerfile.build
# If you want to refresh the frozen_requirements.txt file, you can do so with this task
freeze: .docker_built
	docker run --rm -v $(CURDIR):/deploy:rw -v /etc/group:/etc/group:ro \
		-v /etc/passwd:/etc/passwd:ro --user=$(UID) -w /deploy/src \
		netbox-$(DEBIAN_VER):local /bin/freeze $(DEBIAN_VER)

.PHONY: all artifacts clean freeze
