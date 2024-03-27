#!/bin/bash

# Post configure hack for fastddsgen - Build .jar file and drop in
# debian patches to "build" the debian on Launchpad

# Clone the source directory
cp -r ${SRC_DIR} ${SRC_DIR}-hack

# Build the .jar file early
pushd ${SRC_DIR}-hack
./gradlew build -x test
popd

# Install in source package as a "patch"
mkdir -p ${SRC_DIR}/debian/patches/build/libs
cp ${SRC_DIR}-hack/build/libs/*.jar ${SRC_DIR}/debian/patches/build/libs/

# Don't need this anymore
rm -rf ${SRC_DIR}-hack
