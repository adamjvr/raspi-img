# Builder architecture

[Documentation index](README.md) · [Repository README](../README.md) · [Build](BUILDING.md) · [Image guide](IMAGE.md)

## Design goal

The `rpi5-minimal` branch intentionally stays close to System76's original builder. It adds the smallest practical set of changes needed to construct and validate a Pop!_OS 24.04 Raspberry Pi 5 image before any larger multi-board refactor.

## Build pipeline

```text
Makefile
  │
  ├─ check-host.sh
  │    validates native tools, QEMU, binfmt, and disk space
  │
  ├─ debootstrap
  │    creates reusable Ubuntu Noble ARM64 base root
  │
  ├─ image.sh
  │    creates partitions and filesystems
  │    copies rootfs, configuration, boot files, and overlay
  │    launches systemd-nspawn
  │
  ├─ chroot.sh
  │    configures repositories and keys
  │    installs Pop!_OS, kernel, firmware, and networking
  │    creates development user
  │    installs services and update hooks
  │    synchronizes boot files
  │    clears machine identity
  │
  ├─ verify-image.sh
  │    mounts the raw image and checks required state
  │
  ├─ xz
  │    compresses the raw image
  │
  └─ release metadata
       copies named artifact, checksum, and build information
```

## Repository layout

```text
.
├── Makefile
├── README.md
├── README-RPI5.md
├── LICENSE
├── MODIFICATION_NOTICE.md
│
├── data/
│   ├── boot/firmware/
│   │   ├── config.txt
│   │   └── cmdline.txt
│   ├── etc/
│   ├── template/
│   ├── image.sh
│   └── chroot.sh
│
├── rootfs-overlay/
│   ├── etc/systemd/system/
│   └── usr/local/sbin/
│
├── scripts/
│   ├── check-host.sh
│   ├── create-dev-config.sh
│   ├── verify-image.sh
│   ├── flash-image.sh
│   └── write-build-info.sh
│
├── docs/
├── build/                 generated, ignored
└── dist/                  generated, ignored
```

## Host execution model

On x86-64, `qemu-aarch64-static` and binfmt allow ARM64 executables inside the target root to run transparently. `systemd-nspawn` provides the build container and replaces the target resolver configuration with a usable host/uplink resolver mode.

## Image creation

`data/image.sh`:

1. creates a sparse raw file
2. writes an MBR partition table
3. creates a FAT32 boot partition and ext4 root partition
4. attaches the image through a loop device
5. formats and mounts both filesystems
6. copies the Noble bootstrap root
7. copies static boot configuration without unsupported Unix metadata on FAT
8. applies `rootfs-overlay`
9. installs the chroot script and development configuration
10. launches the ARM64 provisioning stage
11. cleans up mounts and loop devices through a trap

## Provisioning

`data/chroot.sh`:

- checks DNS before beginning network-dependent operations
- bootstraps the Pop!_OS archive key and verifies its fingerprint
- upgrades the Noble root
- installs Pop!_OS and Raspberry Pi packages
- allows coordinated Pop dependency downgrades but prohibits package removal
- creates the configured development account
- installs optional authorized keys
- enables root expansion, networking, Bluetooth, and COSMIC
- installs kernel and initramfs update hooks
- synchronizes the boot partition
- validates the Pi 5 DTB and VC4/V3D overlay
- clears machine and SSH host identity
- cleans package indexes and temporary files

## Boot partition synchronization

The Raspberry Pi firmware reads the FAT partition, while package updates normally place active kernels and initramfs files under `/boot` and firmware trees under `/lib/firmware`.

`pop-rpi-sync-boot` bridges those locations by copying:

- active kernel to `/boot/firmware/vmlinuz`
- active initramfs to `/boot/firmware/initrd.img`
- Broadcom DTBs to `/boot/firmware/`
- overlays to `/boot/firmware/overlays/`
- Raspberry Pi firmware files to `/boot/firmware/`

The same utility is invoked during image construction and after kernel/initramfs updates.

## First-boot root expansion

`pop-rpi-grow-root.service` determines the root block device, expands its partition with `growpart`, reloads the partition table, resizes the ext4 filesystem, and writes a completion marker.

## Structural verification

The verifier attaches and mounts the finished image, then checks:

- required boot files
- Pi 5 DTB
- VC4/V3D overlay
- one-line kernel command line
- expected root label and `rootwait`
- filesystem labels
- ARM64 root filesystem
- installed growth and synchronization utilities
- absence of temporary build credentials
- required Pop!_OS and Raspberry Pi packages

This verification proves image structure, not physical hardware behavior.
