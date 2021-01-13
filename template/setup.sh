#!/bin/sh
set -e
set -x

DISTRO="${1}"
CODENAME="${2}"
EXTRA_ARCH="${3}"

for ARCH in ${EXTRA_ARCH}; do
    dpkg --add-architecture ${ARCH}
done

# Pull software lists
apt-get update

# Basic packages
export DEBIAN_FRONTEND=noninteractive
apt-get install -y qemu-user-static build-essential ccache cmake dpkg-dev devscripts debhelper git default-jdk

# Cross Compilers, basic libraries for each arch
for ARCH in ${EXTRA_ARCH}; do
    GCC_TUPLE=$(dpkg-architecture -q DEB_TARGET_GNU_TYPE -A ${ARCH})
    apt-get install -y libstdc++6:${ARCH} g++-${GCC_TUPLE}
done
