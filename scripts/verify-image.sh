#!/usr/bin/env bash
# Inspect a completed raw image without booting it.

set -Eeuo pipefail

IMAGE="${1:-build/noble/raspi.img}"
[[ -f "${IMAGE}" ]] || { echo "Image not found: ${IMAGE}" >&2; exit 1; }

MOUNT_DIR="$(mktemp --directory)"
LOOP_DEVICE=""

cleanup() {
    local status=$?
    set +e
    mountpoint --quiet "${MOUNT_DIR}/boot/firmware" && \
        sudo umount "${MOUNT_DIR}/boot/firmware"
    mountpoint --quiet "${MOUNT_DIR}" && sudo umount "${MOUNT_DIR}"
    [[ -n "${LOOP_DEVICE}" ]] && \
        sudo losetup --detach "${LOOP_DEVICE}" 2>/dev/null
    rmdir "${MOUNT_DIR}" 2>/dev/null || true
    exit "${status}"
}
trap cleanup EXIT INT TERM

LOOP_DEVICE="$(sudo losetup --find --show --partscan "${IMAGE}")"
# Verification must never alter the filesystem being inspected.
sudo mount -o ro,noload "${LOOP_DEVICE}p2" "${MOUNT_DIR}"

if [[ ! -d "${MOUNT_DIR}/boot/firmware" ]]; then
    echo "Missing /boot/firmware mount point in root filesystem" >&2
    exit 1
fi

sudo mount -o ro "${LOOP_DEVICE}p1" "${MOUNT_DIR}/boot/firmware"

BOOT="${MOUNT_DIR}/boot/firmware"
for file_name in config.txt cmdline.txt vmlinuz initrd.img bcm2712-rpi-5-b.dtb; do
    [[ -f "${BOOT}/${file_name}" ]] || {
        echo "Missing required boot file: ${file_name}" >&2
        exit 1
    }
done

[[ -d "${BOOT}/overlays" ]]
find "${BOOT}/overlays" -maxdepth 1 -type f \
    -iname '*vc4*kms*v3d*.dtbo' -print -quit | grep -q .

[[ "$(wc -l < "${BOOT}/cmdline.txt")" -eq 1 ]]
grep -q 'root=LABEL=writable' "${BOOT}/cmdline.txt"
grep -q 'rootwait' "${BOOT}/cmdline.txt"

[[ "$(sudo blkid -s LABEL -o value "${LOOP_DEVICE}p1")" == system-boot ]]
[[ "$(sudo blkid -s LABEL -o value "${LOOP_DEVICE}p2")" == writable ]]

file "${MOUNT_DIR}/bin/bash" | grep -Eq 'ARM aarch64|ARM64'
test -x "${MOUNT_DIR}/usr/local/sbin/pop-rpi-grow-root"
test -x "${MOUNT_DIR}/usr/local/sbin/pop-rpi-sync-boot"

if [[ -e "${MOUNT_DIR}/root/rpi-image-build.conf" ]]; then
    echo "Build credentials leaked into the image" >&2
    exit 1
fi

# System directory ownership is security-critical. Repository overlays must
# never transfer the build user's UID/GID or checkout directory modes into
# the finished operating-system image.
check_root_owned() {
    local target_path="$1"
    local actual_owner

    actual_owner="$(sudo stat -c '%u:%g' "${MOUNT_DIR}${target_path}")"

    if [[ "${actual_owner}" != "0:0" ]]; then
        echo             "System path is not root-owned: ${target_path} (${actual_owner})"             >&2
        exit 1
    fi
}

for target_path in \
    / \
    /etc \
    /usr \
    /var \
    /boot \
    /root \
    /home
do
    check_root_owned "${target_path}"
done

check_mode() {
    local target_path="$1"
    local expected_mode="$2"
    local actual_mode

    actual_mode="$(sudo stat -c '%a' "${MOUNT_DIR}${target_path}")"

    if [[ "${actual_mode}" != "${expected_mode}" ]]; then
        echo             "Unexpected mode on ${target_path}: ${actual_mode}; expected ${expected_mode}"             >&2
        exit 1
    fi
}

check_mode / 755
check_mode /etc 755
check_mode /usr 755

sudo dpkg-query \
    --admindir="${MOUNT_DIR}/var/lib/dpkg" \
    -W pop-desktop-raspi linux-image-raspi linux-firmware-raspi >/dev/null

echo "Image verification passed: ${IMAGE}"
