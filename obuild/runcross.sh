#!/bin/bash
set -e

usage()
{
    cat > /dev/stderr <<EOF
Usage:
  runcross.sh <opts>

Where:
  -h          - Show help
  -a <arch>   - Comma separated deb arches
  -d <distro> - Comma separated deb distro codenames
EOF
}

ARCHS=$(dpkg --print-architecture)
DISTROS=$(lsb_release -sc)

while getopts 'ha:d:' opt; do
    case "$opt" in
	a)
	    ARCHS="${OPTARG}"
	    ;;
	d)
	    DISTROS="${OPTARG}"
	    ;;
	h)
	    usage
	    exit 0
	    ;;
	*)
	    echo "UNHANDLED - $opt"
	    usage
	    exit 1
    esac
done

for DISTRO in $(tr ',' ' ' <<< "${DISTROS}"); do
    CACHE_DIR=${PWD}/ccache/${DISTRO}
    mkdir -p ${CACHE_DIR}
    docker run -it --rm -v ${PWD}:/obuild \
           -v ${CACHE_DIR}:/root/.ccache \
           -v ${HOME}:/docker-user \
	   obuild:${DISTRO} /obuild/runme.sh "${ARCHS}"
    docker system prune -f
done
