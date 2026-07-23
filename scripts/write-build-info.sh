#!/usr/bin/env bash
set -Eeuo pipefail

OUTPUT="$1"
BASENAME="$2"
SUITE="$3"
ARCH="$4"
PROFILE="$5"

{
    echo "artifact=${BASENAME}.img.xz"
    echo "build_date=$(date --iso-8601=seconds)"
    echo "git_commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "ubuntu_suite=${SUITE}"
    echo "architecture=${ARCH}"
    echo "profile=${PROFILE}"
    echo "builder_host=$(uname -srmo)"
} > "${OUTPUT}"
