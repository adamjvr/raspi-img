#!/usr/bin/env bash
# Safely flash a compressed image after explicit destructive confirmation.

set -Eeuo pipefail

IMAGE="${1:-}"
DEVICE="${2:-}"

[[ -f "${IMAGE}" ]] || { echo "Image not found: ${IMAGE}" >&2; exit 2; }
[[ -b "${DEVICE}" ]] || { echo "Not a block device: ${DEVICE}" >&2; exit 2; }

if [[ "$(lsblk --noheadings --output TYPE "${DEVICE}" | head -n 1 | xargs)" != disk ]]; then
    echo "Target must be a whole disk, not a partition: ${DEVICE}" >&2
    exit 2
fi

echo "WARNING: this will destroy all data on ${DEVICE}."
lsblk -p -o NAME,SIZE,MODEL,TRAN,FSTYPE,MOUNTPOINTS "${DEVICE}"
read -r -p "Type the full device path to continue: " confirmation
[[ "${confirmation}" == "${DEVICE}" ]] || { echo "Cancelled."; exit 1; }

while read -r partition; do
    [[ -n "${partition}" ]] && umount "${partition}" 2>/dev/null || true
done < <(lsblk --noheadings --paths --output NAME "${DEVICE}" | tail -n +2)

xz --decompress --stdout "${IMAGE}" | \
    dd of="${DEVICE}" bs=16M iflag=fullblock status=progress conv=fsync
sync
echo "Flashed ${IMAGE} to ${DEVICE}."
