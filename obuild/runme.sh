#!/bin/bash
set -e
set -x

cd $(dirname $0)
BASE_DIR=${PWD}
WORK_DIR=work
DEB_ARCHS="${1}"
DEB_CODENAME=$(lsb_release -sc)
export DEB_MAINTAINER="$(whoami) <$(git config --get user.email)>"

# If not specified, build for native architecture
if [ -z "${DEB_ARCHS}" ]; then
    DEB_ARCHS=$(dpkg --print-architecture)
fi

for PKG_DIR in ${BASE_DIR}/pkgdef/*.pkgdef; do

    # Load package definition
    if [ ! -f ${PKG_DIR}/settings.sh ]; then
        continue
    fi
    . ${PKG_DIR}/settings.sh
    export DEB_RELEASE=1~${DEB_CODENAME}1

    # Set up work directory
    rm -rf ${WORK_DIR}
    mkdir -p ${WORK_DIR}
    pushd ${WORK_DIR}

    # Check out code
    SRC_DIR_ORIG=$(basename ${GIT_REPO} .git)
    git clone --branch ${GIT_TAG} --depth 1 ${GIT_REPO} ${SRC_DIR_ORIG}

    # Apply source patch if present
    if [ -f ${PKG_DIR}/changes.patch ]; then
        pushd ${SRC_DIR_ORIG}
        git apply ${PKG_DIR}/changes.patch
        popd
    fi

    # Package up original source
    tar zcf ${DEB_PKG_NAME}_${DEB_VERSION}.orig.tar.gz ${SRC_DIR_ORIG}

    # Rename original source to match debian conventions
    SRC_DIR=${DEB_PKG_NAME}-${DEB_VERSION}
    mv ${SRC_DIR_ORIG} ${SRC_DIR}

    # Get date from git for reproducable builds
    pushd ${SRC_DIR}
    export GIT_DATE=$(git log --date=rfc | grep Date | cut -d ' ' -f 4-)
    popd

    # Copy debian template into place & configure
    mkdir ${SRC_DIR}/debian
    cp -r ${PKG_DIR}/debian ${SRC_DIR}/
    pushd ${SRC_DIR}/debian
    for file in $(find . -name '*.in' -type f -print); do
        envsubst < ${file} > ${file//.in/}
        rm ${file}
    done
    popd

    # Build for all specified architectures
    for DEB_ARCH in ${DEB_ARCHS}; do

        # Set appropriate compiler for target architecture
        TUPLE=$(dpkg-architecture -q DEB_TARGET_GNU_TYPE -A ${DEB_ARCH})
        export CC=${TUPLE}-gcc
        export CXX=${TUPLE}-g++

        # Check build dependencies
        pushd ${SRC_DIR}
        if ! (dpkg-checkbuilddeps -a ${DEB_ARCH} > ../.depinfo 2>&1 ); then
            MISSING_DEPS=$(cut -d : -f 4- < ../.depinfo)
            if [ $UID -ne 0 ]; then
                echo "Missing Dependencies: ${MISSING_DEP}"
            else
                MISSING_PKGS=
                for DEP in ${MISSING_DEPS}; do
                    MISSING_PKGS+="${MISSING_PKGS} ${DEP}:${DEB_ARCH}"
                done
                if [ ! -z "${MISSING_PKGS}" ]; then
                    DEBIAN_FRONTEND=noninteractive apt-get install -y ${MISSING_PKGS}
                fi
            fi
        fi

        # Build package(s)
        dpkg-buildpackage -j4 -uc -us --host-arch=${DEB_ARCH}
        #dpkg-buildpackage -uc -us --host-arch=${DEB_ARCH}

        # Docker: Install dependencies in order
        if [ $UID -eq 0 ]; then
            debi
        fi

        # If building multiple targets, cleanup build products
        if [ "${DEB_ARCH}" != "${DEB_ARCHS}" ]; then
            rm -r "obj-${TUPLE}"
        fi

        # Copy out build products
        popd
        DEB_OUT=${BASE_DIR}/debs/${DEB_CODENAME}/${DEB_ARCH}
        mkdir -p ${DEB_OUT}
        cp *.deb *.dsc *tar* ${DEB_OUT}/

    done

    popd
done
