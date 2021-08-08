#!/bin/bash
set -e
set -x

cd $(dirname $0)
BASE_DIR=${PWD}
WORK_DIR=work
DEB_ARCHS="${1}"
export DEB_CODENAME=$(lsb_release -sc)
if [ -d /docker-user ]; then
    # Running within docker instance from runcross.sh
    GIT_ARGS="-f /docker-user/.gitconfig"
fi
GIT_USER=$(git config ${GIT_ARGS} --get user.name)
GIT_EMAIL=$(git config ${GIT_ARGS} --get user.email)
export DEB_MAINTAINER="${GIT_USER//@*/} <${GIT_EMAIL}>"

# If not specified, build for native architecture
#if [ $# -eq 1 ]; then
#    DEB_ARCHS=$(dpkg --print-architecture)
#fi

for PKG_DIR in ${BASE_DIR}/pkgdef/*.pkgdef; do

    # Skip disabled packages
    if [ -f ${PKG_DIR}/disable ]; then
        continue
    fi

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

    # Locate/get the code
    ARCHIVE_DIR=${BASE_DIR}/archive
    mkdir -p ${ARCHIVE_DIR}
    SRC_PKG_FILE=${DEB_PKG_NAME}_${DEB_VERSION}.orig.tar.gz
    SRC_PKG_PATH=${ARCHIVE_DIR}/${SRC_PKG_FILE}

    # Try to get from Ubuntu Launchpad if we don't have it yet
    if [ ! -f ${SRC_PKG_PATH} ]; then
        wget -P ${ARCHIVE_DIR} "https://launchpad.net/ubuntu/+archive/primary/+files/${SRC_PKG_FILE}" || true
    fi

    # Failing that, get from Github
    if [ ! -f ${SRC_PKG_PATH} ]; then
        case "${GIT_REPO}" in
            *.git)
                # Clone repository w/ history
                SRC_DIR_ORIG="$(basename "${GIT_REPO}" .git)-${GIT_TAG//v/}"
                git clone -b "${GIT_TAG}" "${GIT_REPO}" ${SRC_DIR_ORIG}
                tar czf ${SRC_PKG_PATH} ${SRC_DIR_ORIG}
                ;;

            *)
                # Download archive export
                if wget "${GIT_REPO}/archive/refs/tags/${GIT_TAG}.tar.gz"; then
                    mv ${GIT_TAG}.tar.gz ${SRC_PKG_PATH}
                fi
        esac
    fi

    # Still nothing?
    if [ ! -f ${SRC_PKG_PATH} ]; then
        echo "Cannot find source code .. abort"
        exit 1
    fi

    # Use existing code
    cp ${SRC_PKG_PATH} ${SRC_PKG_FILE}
    tar xf ${SRC_PKG_FILE}
    SRC_DIR_ORIG=*-${DEB_VERSION}

    # Date from downloaded file
    export DEB_DATE=$(date -Rr ${SRC_DIR_ORIG})

    # Rename original source to match debian conventions
    SRC_DIR=${DEB_PKG_NAME}-${DEB_VERSION}
    mv ${SRC_DIR_ORIG} ${SRC_DIR}

    # Copy debian template into place & configure
    mkdir ${SRC_DIR}/debian
    cp -r ${PKG_DIR}/debian ${SRC_DIR}/
    pushd ${SRC_DIR}/debian
    for file in $(find . -name '*.in' -type f -print); do
        envsubst < ${file} > ${file//.in/}
        rm ${file}
    done
    popd

    # Post configure adjustments
    if [ -f ${PKG_DIR}/postconf.sh ]; then
        . ${PKG_DIR}/postconf.sh
    fi

    # Build source package
    pushd ${SRC_DIR}
    debuild -S -uc -us --no-check-builddeps || \
        debuild -S -uc -us
    popd

    # Copy out source package
    DEB_BASE=${BASE_DIR}/debs/${DEB_CODENAME}
    mkdir -p ${DEB_BASE}/src
    cp *.dsc *tar* *.changes *.buildinfo ${DEB_BASE}/src || true

    # Build for all specified architectures
    for DEB_ARCH in ${DEB_ARCHS}; do

        # Skip "ARCH=all" only packages when cross compiling
        if [ "${DEB_ARCH}" != $(dpkg --print-architecture) ]; then
            if ! grep -q 'linux-any' ${SRC_DIR}/debian/control; then
                continue;
            fi
        fi

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
                    DEBIAN_FRONTEND=noninteractive apt-get install -y ${DEP}:${DEB_ARCH} ||
                        DEBIAN_FRONTEND=noninteractive apt-get install -y ${DEP}:all
                done
            fi
        fi

        # Build package(s)
        EXTRA_DPKG_ARGS="j4" # -uc -us
        dpkg-buildpackage -b ${EXTRA_BUILD_ARGS} -uc -us --host-arch=${DEB_ARCH}

        # Docker: Install dependencies in order
        if [ $UID -eq 0 ]; then
            debi
        fi

        # If building multiple targets, cleanup build products
        if [ "${DEB_ARCH}" != "${DEB_ARCHS}" ]; then
            rm -fr "obj-${TUPLE}"
        fi

        # (FIXME) Sort out build products
        popd
        mkdir -p ${DEB_BASE}/{all,${DEB_ARCH}}
        cp *_all.deb ${DEB_BASE}/all || true
        cp *_${DEB_ARCH}.deb ${DEB_BASE}/${DEB_ARCH} || true

    done

    popd
done
