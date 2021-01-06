#!/bin/bash
set -e

# Configuration (TBD - parse args)
export DISTRO=ubuntu
export CODENAME=xenial
export EXTRA_ARCH="armhf arm64"
BUILD_CONTEXT=build

# Reset build context
rm -rf ${BUILD_CONTEXT}
cp -r template ${BUILD_CONTEXT}

# Substitute variables
pushd ${BUILD_CONTEXT}
for file in $(find . -name '*.in' -type f -print); do
    envsubst < ${file} > ${file//.in/}
    rm ${file}
done
popd

# Build/run the image
TAG=obuild:${CODENAME}
docker rmi -f ${TAG}
docker build -t ${TAG} ${BUILD_CONTEXT}
docker image prune -f --filter label=stage=builder
docker run -it ${TAG} /bin/bash
