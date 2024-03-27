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
apt-get install -y qemu-user build-essential ccache cmake dpkg-dev devscripts debhelper git default-jdk wget

# This is the location of the qemu workaround for doubling up argv[0]
# If it's not here (20.04 and earlier), then try and set something up ...
if [ ! -d /usr/libexec/qemu-binfmt ]; then
    mkdir /usr/libexec/qemu-binfmt
    g++ -Wall /qemu-binfmt-fixer.cpp -o /usr/libexec/qemu-binfmt/qemu-binfmt-fixer
    QEMU_ARCHS="aarch64 aarch64_be alpha arm armeb cris hexagon hppa i386 m68k microblaze microblazeel mips mips64 mips64el mipsel mipsn32 mipsn32el nios2 or1k ppc ppc64 ppc64le riscv32 riscv64 s390x sh4 sh4eb sparc sparc32plus sparc64 x86_64 xtensa xtensaeb"
    for ARCH in $QEMU_ARCHS; do
	ln -s qemu-binfmt-fixer "/usr/libexec/qemu-binfmt/${ARCH}-binfmt-P"
    done
fi

# Cross Compilers, basic libraries for each arch
for ARCH in ${EXTRA_ARCH}; do
    GCC_TUPLE=$(dpkg-architecture -q DEB_TARGET_GNU_TYPE -A ${ARCH})
    apt-get install -y libstdc++6:${ARCH} g++-${GCC_TUPLE}
done
