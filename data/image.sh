#!/usr/bin/env bash
# Build a partitioned, directly flashable Raspberry Pi disk image.
#
# Arguments:
#   1. output image path
#   2. temporary mount directory
#   3. completed debootstrap root filesystem

set -Eeuo pipefail

if [[ $# -ne 3 || ! -d "$3" ]]; then
    echo "Usage: $0 IMAGE MOUNT_DIR DEBOOTSTRAP_ROOT" >&2
    exit 2
fi

IMAGE="$(realpath -m "$1")"
MOUNT_DIR="$(realpath -m "$2")"
DEBOOTSTRAP_ROOT="$(realpath "$3")"

IMAGE_SIZE="${IMAGE_SIZE:-16G}"
BOOT_START_MIB="${BOOT_START_MIB:-1}"
BOOT_END_MIB="${BOOT_END_MIB:-1025}"
PROFILE="${PROFILE:-development}"
DEV_CONFIG="${DEV_CONFIG:-}"
LOOP_DEVICE=""

cleanup() {
    local status=$?
    set +e

    if mountpoint --quiet "${MOUNT_DIR}/boot/firmware"; then
        umount "${MOUNT_DIR}/boot/firmware"
    fi

    if mountpoint --quiet "${MOUNT_DIR}"; then
        umount "${MOUNT_DIR}"
    fi

    if [[ -n "${LOOP_DEVICE}" ]]; then
        losetup --detach "${LOOP_DEVICE}" 2>/dev/null || true
    fi

    exit "${status}"
}
trap cleanup EXIT INT TERM

rm -rf --one-file-system "${MOUNT_DIR}"
rm -f "${IMAGE}"
mkdir -p "$(dirname "${IMAGE}")" "${MOUNT_DIR}"

# truncate creates a sparse host-side image, avoiding needless allocation of
# every unused byte before compression.
truncate --size "${IMAGE_SIZE}" "${IMAGE}"

parted --script "${IMAGE}" mktable msdos
parted --script "${IMAGE}" \
    mkpart primary fat32 "${BOOT_START_MIB}MiB" "${BOOT_END_MIB}MiB"
parted --script "${IMAGE}" set 1 boot on
parted --script "${IMAGE}" \
    mkpart primary ext4 "${BOOT_END_MIB}MiB" 100%

LOOP_DEVICE="$(losetup --find --show --partscan "${IMAGE}")"
udevadm settle

mkfs.vfat -F 32 -n system-boot "${LOOP_DEVICE}p1"
mkfs.ext4 -F -L writable "${LOOP_DEVICE}p2"

mount "${LOOP_DEVICE}p2" "${MOUNT_DIR}"

rsync \
    --archive \
    --acls \
    --hard-links \
    --numeric-ids \
    --sparse \
    --whole-file \
    --xattrs \
    "${DEBOOTSTRAP_ROOT}/" "${MOUNT_DIR}/"

rsync --archive "data/etc/" "${MOUNT_DIR}/etc/"

mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "${LOOP_DEVICE}p1" "${MOUNT_DIR}/boot/firmware"
rsync --archive "data/boot/firmware/" "${MOUNT_DIR}/boot/firmware/"

if [[ -d rootfs-overlay ]]; then
    rsync \
        --archive \
        --acls \
        --hard-links \
        --numeric-ids \
        --xattrs \
        "rootfs-overlay/" "${MOUNT_DIR}/"
fi

install -m 0755 data/chroot.sh "${MOUNT_DIR}/root/rpi-image-chroot.sh"

if [[ "${PROFILE}" == development ]]; then
    if [[ -z "${DEV_CONFIG}" || ! -f "${DEV_CONFIG}" ]]; then
        echo "Development profile requires DEV_CONFIG" >&2
        exit 1
    fi
    install -m 0600 "${DEV_CONFIG}" \
        "${MOUNT_DIR}/root/rpi-image-build.conf"
fi

systemd-nspawn \
    --quiet \
    --register=no \
    --machine=pop-rpi5-build \
    --directory="${MOUNT_DIR}" \
    --resolv-conf=copy-host \
    --setenv="IMAGE_PROFILE=${PROFILE}" \
    /bin/bash /root/rpi-image-chroot.sh

rm -f "${MOUNT_DIR}/root/rpi-image-chroot.sh"
sync
