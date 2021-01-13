#!/bin/bash
set -e

ARCHS="amd64 armhf arm64"
DISTROS="xenial focal"

for DISTRO in ${DISTROS}; do
    docker run -it -v ${PWD}:/obuild obuild:${DISTRO} /obuild/runme.sh "${ARCHS}"
done
