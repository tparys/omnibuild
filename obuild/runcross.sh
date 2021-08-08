#!/bin/bash
set -e

ARCHS="" # amd64 armhf arm64"
DISTROS="xenial bionic focal"

for DISTRO in ${DISTROS}; do
    CACHE_DIR=${PWD}/ccache/${DISTRO}
    mkdir -p ${CACHE_DIR}
    docker run -it -v ${PWD}:/obuild \
           -v ${CACHE_DIR}:/root/.ccache \
           -v ${HOME}:/docker-user \
           obuild:${DISTRO} /obuild/runme.sh "${ARCHS}"
    docker system prune -f
done
