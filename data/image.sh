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
NSPAWN_RESOLV_CONF="${NSPAWN_RESOLV_CONF:-}"
LOOP_DEVICE=""

# A debootstrap root may contain /etc/resolv.conf as a symlink.  The
# systemd-nspawn "copy-host" mode deliberately leaves non-regular files such
# as symlinks untouched, which can leave the container pointing at a resolver
# path or local stub that does not work inside the build environment.
#
# Prefer systemd-resolved's uplink file because it contains the real upstream
# DNS servers.  Fall back to replacing the container file with the host's
# resolver configuration on systems that do not provide the uplink file.
if [[ -z "${NSPAWN_RESOLV_CONF}" ]]; then
    if [[ -s /run/systemd/resolve/resolv.conf ]]; then
        NSPAWN_RESOLV_CONF="replace-uplink"
    else
        NSPAWN_RESOLV_CONF="replace-host"
    fi
fi

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

# Repository files belong to the developer on the build host, but they
# become operating-system files inside the target image. Never allow the
# host checkout's UID, GID, or group-writable directory modes to leak into
# the target filesystem.
rsync \
    --archive \
    --chown=0:0 \
    --chmod=D755,Fgo-w \
    "data/etc/" "${MOUNT_DIR}/etc/"

mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "${LOOP_DEVICE}p1" "${MOUNT_DIR}/boot/firmware"
# FAT does not support normal Unix ownership, group, permission, ACL, or
# extended-attribute semantics. Preserve file contents and timestamps, but do
# not ask rsync to apply metadata that VFAT cannot represent.
rsync \
    --archive \
    --no-perms \
    --no-owner \
    --no-group \
    --omit-dir-times \
    --modify-window=1 \
    "data/boot/firmware/" "${MOUNT_DIR}/boot/firmware/"

if [[ -d rootfs-overlay ]]; then
    # rootfs-overlay is stored in Git, so host-side ownership, ACLs, xattrs,
    # and checkout directory modes are not authoritative target metadata.
    # Explicitly install the overlay as root-owned system content.
    rsync \
        --archive \
        --hard-links \
        --chown=0:0 \
        --chmod=D755,Fgo-w \
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

echo "Using systemd-nspawn DNS mode: ${NSPAWN_RESOLV_CONF}"

systemd-nspawn \
    --quiet \
    --register=no \
    --machine=pop-rpi5-build \
    --directory="${MOUNT_DIR}" \
    --resolv-conf="${NSPAWN_RESOLV_CONF}" \
    --setenv="IMAGE_PROFILE=${PROFILE}" \
    /bin/bash /root/rpi-image-chroot.sh

rm -f "${MOUNT_DIR}/root/rpi-image-chroot.sh"
sync
