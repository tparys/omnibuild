#!/bin/bash
set -e

PACKAGES="qemu-user-static build-essential cmake"
PACKAGES+=" libstdc++6:armhf g++-arm-linux-gnueabihf"
PACKAGES+=" libstdc++6:arm64 g++-aarch64-linux-gnu"

make_apt_sources()
{
    cat <<EOF
# x86 Debians
deb [arch=i386,amd64] http://us.archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe
deb [arch=i386,amd64] http://us.archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe
deb [arch=i386,amd64] http://us.archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe

# ARM Debians
deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME} main restricted universe
deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-updates main restricted universe
deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-security main restricted universe
EOF
}

make_docker_file()
{
    cat <<EOF
FROM ${DISTRO}:${CODENAME} as builder
LABEL stage=builder

# Multiarch apt
RUN dpkg --add-architecture armhf
RUN dpkg --add-architecture arm64
COPY sources.list /etc/apt/
RUN apt-get update

# Development packages
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y ${PACKAGES}

# Helpful stuff
COPY hello.c /
COPY hello.cpp /

# Compile some stuff!
RUN x86_64-linux-gnu-gcc -o hello_c_amd64 hello.c
RUN x86_64-linux-gnu-g++ -o hello_cpp_amd64 hello.cpp
RUN arm-linux-gnueabihf-gcc -o hello_c_armhf hello.c
RUN arm-linux-gnueabihf-g++ -o hello_cpp_armhf hello.cpp
RUN aarch64-linux-gnu-gcc -o hello_c_arm64 hello.c
RUN aarch64-linux-gnu-g++ -o hello_cpp_arm64 hello.cpp

# Stuff that doesn't need to be kept
#RUN rm -fr /var/lib/apt/lists/*
#RUN rm -fr /var/cache/apt/archives/*
EOF
}

DISTRO=ubuntu
CODENAME=focal
TAG=omnibuild:${CODENAME}
docker rmi -f ${TAG}
make_apt_sources > sources.list
make_docker_file ${DISTRO} ${CODENAME} > Dockerfile
docker build -t ${TAG} .
docker image prune -f --filter label=stage=builder
docker run -it ${TAG} /bin/bash
