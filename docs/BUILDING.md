# Building the Raspberry Pi 5 image

[Documentation index](README.md) · [Repository README](../README.md) · [Image guide](IMAGE.md) · [Troubleshooting](TROUBLESHOOTING.md)

## Supported workflow

The current build path is designed for a Linux host. An x86-64 host uses QEMU user-mode emulation and binfmt to execute ARM64 programs during the `systemd-nspawn` provisioning stage.

Use the `rpi5-minimal` branch:

```bash
git clone --branch rpi5-minimal \
    https://github.com/adamjvr/raspi-img.git
cd raspi-img
```

## Host requirements

The host checker installs or validates:

```text
debootstrap
systemd-container
qemu-user-static
binfmt-support
rsync
parted
dosfstools
e2fsprogs
util-linux
xz-utils
openssl
ca-certificates
file
cloud-guest-utils
```

The build filesystem should have at least 30 GiB free. More space is recommended for repeated builds and retained artifacts.

Install and validate:

```bash
make deps
make check-host
```

## Configure the development image

```bash
make configure
```

You will be prompted for:

- a username, defaulting to `adam`
- a password, stored as a SHA-512 hash
- an optional SSH public-key file

The result is stored at:

```text
build/noble/dev-user.conf
```

This file is ignored by Git and should never be committed.

## Validate the source tree

```bash
make lint
```

This runs Bash syntax checks and ShellCheck when it is installed.

## Build and package

```bash
make release
```

The release target performs these stages:

1. Build or reuse the Noble ARM64 debootstrap root
2. Create a sparse partitioned image
3. Format the FAT32 boot and ext4 root filesystems
4. Copy the bootstrap root into the image
5. Mount the boot filesystem
6. Enter the ARM64 root with `systemd-nspawn`
7. Configure Pop!_OS repositories and keys
8. Install Pop!_OS, kernel, firmware, networking, and Bluetooth packages
9. Create the development account
10. Install first-boot and update hooks
11. Synchronize kernel, initramfs, DTBs, overlays, and firmware
12. Clear machine identity and host keys
13. Verify the raw image
14. Compress it with XZ
15. Write checksums and build metadata to `dist/`

## Individual targets

```bash
make image       # build/noble/raspi.img
make verify      # inspect the raw image
make compressed  # build/noble/raspi.img.xz
make release     # verify and package into dist/
```

## Build variables

Defaults:

| Variable | Default | Purpose |
|---|---|---|
| `ARCH` | `arm64` | Target architecture |
| `UBUNTU_CODE` | `noble` | Ubuntu bootstrap suite |
| `UBUNTU_MIRROR` | Ubuntu ports mirror | ARM package source |
| `IMAGE_SIZE` | `16G` | Sparse raw image size |
| `BOOT_START_MIB` | `1` | Boot partition start |
| `BOOT_END_MIB` | `1025` | Boot partition end |
| `PROFILE` | `development` | Provisioning profile |
| `RELEASE_BASENAME` | `pop-os_24.04_rpi5_arm64-dev0` | Release artifact stem |

Example custom build:

```bash
make release \
    IMAGE_SIZE=24G \
    RELEASE_BASENAME=pop-os_24.04_rpi5_arm64-dev1
```

Do not reduce the image below the installed root filesystem's actual space requirements.

## Outputs

```text
build/noble/debootstrap/        reusable ARM64 base root
build/noble/dev-user.conf       ignored development credentials
build/noble/raspi.img           raw flashable disk image
build/noble/raspi.img.xz        compressed intermediate image
dist/*.img.xz                   named release image
dist/*.img.xz.sha256            checksum
dist/*.build-info               source and build metadata
```

## Cleanup and caching

Use:

```bash
make clean
```

when retrying image construction. It removes the image, compressed image, and `dist/`, but keeps the expensive debootstrap cache and development-user configuration.

Use:

```bash
make distclean
```

only when the bootstrap itself must be rebuilt. It removes the debootstrap tree, mount directory, images, release output, and development-user configuration.

## Successful build signature

A complete build ends with output resembling:

```text
Image verification passed: build/noble/raspi.img
Release artifacts written to dist/
```

XZ may reduce its thread count to stay inside the host memory limit. That is normal and does not indicate corruption.
