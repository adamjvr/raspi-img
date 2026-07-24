# Pop!_OS 24.04 Raspberry Pi 5 image

[Documentation index](README.md) · [Repository README](../README.md) · [Build](BUILDING.md) · [Flash](FLASHING.md) · [Test](TESTING.md)

## Overview

This project produces a directly flashable, compressed ARM64 disk image intended for the Raspberry Pi 5. The image uses Ubuntu Noble as its bootstrap base, adds the Pop!_OS Raspberry Pi desktop package set, installs the Raspberry Pi kernel and firmware, and configures direct boot through the Raspberry Pi firmware partition.

This is not an ISO installer. It is a complete partitioned disk image:

```text
pop-os_24.04_rpi5_arm64-dev0.img.xz
```

After decompression and flashing, the media contains both the boot and root filesystems.

## Current validation status

| Stage | Result |
|---|---|
| Build host prerequisites | Passing |
| ARM64 Noble bootstrap | Passing |
| Pop!_OS package installation | Passing |
| Pi kernel and firmware installation | Passing |
| Required Pi 5 boot-file verification | Passing |
| Raw image structural verification | Passing |
| XZ compression and checksums | Passing |
| Physical Raspberry Pi 5 boot | Not yet validated |
| COSMIC hardware acceleration | Not yet validated |
| Wi-Fi, Bluetooth, audio, USB, and PCIe | Not yet validated |
| Kernel-update boot survival | Not yet validated |

Until physical testing succeeds, the image should remain clearly labeled as a development build.

## Target

- Raspberry Pi 5 Model B
- ARM64 / AArch64
- 8 GB RAM target used for initial bring-up
- MicroSD boot for the first validation cycle
- Direct Raspberry Pi firmware boot
- Pop!_OS 24.04 / Ubuntu Noble userspace
- COSMIC graphical target

The first hardware test should avoid NVMe HATs, GPIO add-ons, USB audio interfaces, and other optional peripherals. Establish a console boot before expanding the hardware matrix.

## Disk layout

The default image is a 16 GiB sparse raw disk image.

| Partition | Default range | Filesystem | Label | Mount point |
|---|---:|---|---|---|
| 1 | 1 MiB–1025 MiB | FAT32 | `system-boot` | `/boot/firmware` |
| 2 | 1025 MiB–end | ext4 | `writable` | `/` |

The root partition is expanded on first boot by `pop-rpi-grow-root.service` so a larger SD card can use its remaining capacity.

## Boot flow

```text
Raspberry Pi EEPROM firmware
        ↓
FAT partition: config.txt and cmdline.txt
        ↓
vmlinuz + initrd.img
        ↓
bcm2712-rpi-5-b.dtb + VC4/V3D overlays
        ↓
ext4 root filesystem labeled writable
        ↓
systemd graphical.target
        ↓
COSMIC greeter or console login
```

The boot configuration enables:

- 64-bit ARM mode
- `vmlinuz` as the kernel
- `initrd.img` as the initramfs
- VC4/V3D full KMS
- UART for development diagnostics
- I²C and SPI
- Camera and display auto-detection

The kernel command line keeps console output visible during bring-up and mounts the root filesystem by label.

## Installed core components

The provisioning stage explicitly installs:

- `pop-desktop-raspi`
- `linux-image-raspi`
- `linux-firmware-raspi`
- `initramfs-tools`
- `cloud-guest-utils`
- `parted`
- `sudo`
- `network-manager`
- `bluez`
- `wireless-regdb`
- `wpasupplicant`

The Pop!_OS package transaction is permitted to perform coordinated dependency downgrades, while package removal remains prohibited during that transaction.

## Development profile

The default profile is `development`.

Running:

```bash
make configure
```

creates:

```text
build/noble/dev-user.conf
```

The file contains:

- the development username
- a SHA-512 password hash
- an optional SSH public key

It is mode `0600`, ignored by Git, copied into the target only for provisioning, and removed from the finished image.

## First-boot services

### Root expansion

`pop-rpi-grow-root.service` expands partition 2 and then grows the ext4 filesystem. A marker prevents repeated expansion.

### Boot synchronization

`pop-rpi-sync-boot` copies the active kernel, initramfs, device trees, overlays, and Raspberry Pi firmware to `/boot/firmware`.

Hooks are installed under:

```text
/etc/kernel/postinst.d/
/etc/initramfs/post-update.d/
```

This update path must be tested by installing kernel updates and rebooting before the image is considered stable.

## Identity and credential handling

Before finalization, the image:

- clears `/etc/machine-id`
- removes `/var/lib/dbus/machine-id`
- removes generated SSH host keys
- removes the temporary development-user configuration

Every flashed system should generate its own identity and host keys.

A development image may still contain the user account, password hash, and optional authorized key selected during `make configure`. Do not distribute a personal development image publicly.

## Release artifacts

`make release` writes:

```text
dist/pop-os_24.04_rpi5_arm64-dev0.img.xz
dist/pop-os_24.04_rpi5_arm64-dev0.img.xz.sha256
dist/pop-os_24.04_rpi5_arm64-dev0.build-info
```

The raw and intermediate images remain under `build/noble/`.

## Next steps

Proceed to:

1. [Flash the image](FLASHING.md)
2. [Run the hardware test plan](TESTING.md)
3. [Complete the release checklist](RELEASE_CHECKLIST.md)
