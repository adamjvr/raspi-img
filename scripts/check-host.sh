#!/usr/bin/env bash
# Validate or install the host-side image-building toolchain.

set -Eeuo pipefail

INSTALL_MISSING=false
[[ "${1:-}" == --install-missing ]] && INSTALL_MISSING=true

PACKAGES=(
    debootstrap systemd-container qemu-user-static binfmt-support rsync parted
    dosfstools e2fsprogs util-linux xz-utils openssl ca-certificates file
    cloud-guest-utils
)
COMMANDS=(
    debootstrap systemd-nspawn rsync parted mkfs.vfat mkfs.ext4 losetup xz
    openssl file
)

if [[ "$(uname -m)" == x86_64 ]]; then
    COMMANDS+=(qemu-aarch64-static)
fi

if ${INSTALL_MISSING}; then
    sudo apt-get update
    sudo apt-get install --yes "${PACKAGES[@]}"
fi

missing=0
for command_name in "${COMMANDS[@]}"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Missing command: ${command_name}" >&2
        missing=1
    fi
done

if [[ "$(uname -m)" == x86_64 ]]; then
    sudo update-binfmts --enable qemu-aarch64 >/dev/null 2>&1 || true
    sudo systemctl restart systemd-binfmt.service >/dev/null 2>&1 || true

    if [[ ! -r /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
        echo "qemu-aarch64 binfmt entry is missing" >&2
        missing=1
    elif ! grep -q '^enabled' /proc/sys/fs/binfmt_misc/qemu-aarch64; then
        echo "qemu-aarch64 binfmt entry is disabled" >&2
        missing=1
    fi
fi

available_kib="$(df --output=avail -k . | tail -n 1 | xargs)"
if (( available_kib < 30 * 1024 * 1024 )); then
    echo "Warning: less than 30 GiB is available in the build filesystem." >&2
fi

if (( missing != 0 )); then
    echo "Host validation failed. Run: $0 --install-missing" >&2
    exit 1
fi

echo "Host validation passed."
