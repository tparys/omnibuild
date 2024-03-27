#!/bin/bash
set -e

ARCHS="amd64" # armhf arm64"
DISTROS="focal" # jammy"

for DISTRO in ${DISTROS}; do
    CACHE_DIR=${PWD}/ccache/${DISTRO}
    mkdir -p ${CACHE_DIR}
    docker run -it --rm -v ${PWD}:/obuild \
           -v ${CACHE_DIR}:/root/.ccache \
           -v ${HOME}:/docker-user \
	   obuild:${DISTRO} /obuild/runme.sh "${ARCHS}"
    docker system prune -f
done
