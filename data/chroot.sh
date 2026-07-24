#!/usr/bin/env bash
# Customize the Noble ARM64 root filesystem into a Pop!_OS Raspberry Pi image.

set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
IMAGE_PROFILE="${IMAGE_PROFILE:-development}"
POP_KEY_FINGERPRINT="63C46DF0140D738961429F4E204DD8AEC33A7AFF"
POP_SOURCE="/etc/apt/sources.list.d/pop-os-release.sources"
POP_SOURCE_DISABLED="/root/pop-os-release.sources.disabled-for-key-bootstrap"

# The Pop repository cannot be authenticated until its archive key is present.
# Temporarily hide that source while installing GnuPG from Ubuntu.
if [[ -f "${POP_SOURCE}" ]]; then
    mv "${POP_SOURCE}" "${POP_SOURCE_DISABLED}"
fi

# Stop immediately with useful resolver diagnostics instead of allowing APT
# to continue with missing or stale indexes.
if ! getent hosts ports.ubuntu.com >/dev/null 2>&1; then
    echo "DNS resolution is unavailable inside the build container." >&2
    echo "Contents of /etc/resolv.conf:" >&2
    cat /etc/resolv.conf >&2 || true
    exit 1
fi

apt-get -o Acquire::Retries=5 update
apt-get -o Acquire::Retries=5 install --yes --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    gnupg \
    ubuntu-keyring

mkdir -p /etc/apt/keyrings /tmp/pop-keyring
chmod 0700 /tmp/pop-keyring

if ! gpg \
    --batch \
    --homedir /tmp/pop-keyring \
    --keyserver hkps://keyserver.ubuntu.com \
    --recv-keys "${POP_KEY_FINGERPRINT}"; then
    curl --fail --silent --show-error --location \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${POP_KEY_FINGERPRINT}" |
        gpg --batch --homedir /tmp/pop-keyring --import
fi

if ! gpg --batch --homedir /tmp/pop-keyring --with-colons \
    --fingerprint "${POP_KEY_FINGERPRINT}" | \
    awk -F: '$1 == "fpr" { print $10 }' | \
    grep -Fxq "${POP_KEY_FINGERPRINT}"; then
    echo "Imported Pop!_OS archive key fingerprint did not match" >&2
    exit 1
fi

gpg \
    --batch \
    --homedir /tmp/pop-keyring \
    --export "${POP_KEY_FINGERPRINT}" \
    > /etc/apt/keyrings/pop-os-archive.gpg

chmod 0644 /etc/apt/keyrings/pop-os-archive.gpg
rm -rf /tmp/pop-keyring

if [[ -f "${POP_SOURCE_DISABLED}" ]]; then
    mv "${POP_SOURCE_DISABLED}" "${POP_SOURCE}"
fi

apt-get -o Acquire::Retries=5 update
apt-get -o Acquire::Retries=5 dist-upgrade --yes -o Dpkg::Options::="--force-confnew"

# Keep the explicit Raspberry Pi kernel and firmware packages in this list even
# though the Pop metapackage may already depend on some of them.  The image must
# always contain Ubuntu's Pi-specific BCM2712 kernel, DTBs, and firmware.
apt-get -o Acquire::Retries=5 install --yes -o Dpkg::Options::="--force-confnew" \
    pop-desktop-raspi \
    linux-image-raspi \
    linux-firmware-raspi \
    initramfs-tools \
    cloud-guest-utils \
    parted \
    sudo \
    network-manager \
    bluez \
    wireless-regdb \
    wpasupplicant

update-initramfs -u -k all

if [[ "${IMAGE_PROFILE}" == development ]]; then
    CONFIG=/root/rpi-image-build.conf
    if [[ ! -f "${CONFIG}" ]]; then
        echo "Missing development-user configuration" >&2
        exit 1
    fi

    # shellcheck disable=SC1090
    source "${CONFIG}"
    rm -f "${CONFIG}"

    if [[ ! "${IMAGE_USER}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Invalid IMAGE_USER: ${IMAGE_USER}" >&2
        exit 1
    fi

    if ! id "${IMAGE_USER}" >/dev/null 2>&1; then
        useradd --create-home --shell /bin/bash "${IMAGE_USER}"
    fi

    for group in sudo adm audio video render input plugdev netdev; do
        if getent group "${group}" >/dev/null; then
            usermod --append --groups "${group}" "${IMAGE_USER}"
        fi
    done

    usermod --password "${IMAGE_PASSWORD_HASH}" "${IMAGE_USER}"

    if [[ -n "${IMAGE_SSH_PUBLIC_KEY:-}" ]]; then
        install -d -m 0700 -o "${IMAGE_USER}" -g "${IMAGE_USER}" \
            "/home/${IMAGE_USER}/.ssh"
        printf '%s\n' "${IMAGE_SSH_PUBLIC_KEY}" \
            > "/home/${IMAGE_USER}/.ssh/authorized_keys"
        chown "${IMAGE_USER}:${IMAGE_USER}" \
            "/home/${IMAGE_USER}/.ssh/authorized_keys"
        chmod 0600 "/home/${IMAGE_USER}/.ssh/authorized_keys"
    fi
fi

# Ensure update hooks invoke the same synchronization code used at build time.
mkdir -p /etc/kernel/postinst.d /etc/initramfs/post-update.d
ln -sf /usr/local/sbin/pop-rpi-sync-boot \
    /etc/kernel/postinst.d/zz-pop-rpi-sync-boot
ln -sf /usr/local/sbin/pop-rpi-sync-boot \
    /etc/initramfs/post-update.d/zz-pop-rpi-sync-boot

systemctl enable pop-rpi-grow-root.service
systemctl enable NetworkManager.service || true
systemctl enable bluetooth.service || true
systemctl enable cosmic-greeter.service || true
systemctl set-default graphical.target

# The FAT boot partition is mounted throughout this chroot operation.
/usr/local/sbin/pop-rpi-sync-boot

if [[ ! -f /boot/firmware/bcm2712-rpi-5-b.dtb ]]; then
    echo "Raspberry Pi 5 DTB is missing after synchronization" >&2
    exit 1
fi

if ! find /boot/firmware/overlays \
    -maxdepth 1 \
    -type f \
    -iname '*vc4*kms*v3d*.dtbo' \
    -print -quit | grep -q .; then
    echo "VC4/V3D KMS overlay is missing" >&2
    exit 1
fi

# Every flashed machine must generate its own identity and, if installed, SSH
# host keys on first boot.
truncate --size 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id /etc/ssh/ssh_host_*

touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
