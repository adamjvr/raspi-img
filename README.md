# Pop!_OS 24.04 for Raspberry Pi 5

A direct-boot ARM64 image builder for running **Pop!_OS 24.04 (Noble)** on the **Raspberry Pi 5**.

This repository is a Raspberry Pi 5 bring-up fork of System76's `pop-os/raspi-img` project. It preserves the upstream image-builder approach while adding Pi 5 boot files, a larger boot partition, development-user provisioning, first-boot root expansion, kernel-to-boot-partition synchronization, host-side image validation, release packaging, and guarded flashing.

> [!IMPORTANT]
> This is an independent development project, not an official System76 or Raspberry Pi release.

## Project status

| Area | Status |
|---|---|
| ARM64 Noble bootstrap | Passing |
| Pop!_OS package provisioning | Passing |
| Raw image construction | Passing |
| Host-side image verification | Passing |
| XZ compression and release packaging | Passing |
| Raspberry Pi 5 hardware boot | Pending validation |
| COSMIC, Wi-Fi, Bluetooth, audio, and update survival | Pending validation |

The current branch produces a structurally valid image, but it must still pass the hardware test plan before it should be called a release candidate.

## Quick start

```bash
# Clone the Pi 5 development branch.
git clone --branch rpi5-minimal \
    https://github.com/adamjvr/raspi-img.git
cd raspi-img

# Install and validate the host toolchain.
make deps

# Create the ignored development-user configuration.
make configure

# Validate the scripts, build, verify, compress, and package the image.
make lint
make release
```

The default release artifact is:

```text
dist/pop-os_24.04_rpi5_arm64-dev0.img.xz
```

Flash it only after identifying the correct whole-disk device:

```bash
lsblk -p -o NAME,SIZE,MODEL,SERIAL,TRAN,MOUNTPOINTS
make flash DEVICE=/dev/sdX
```

`/dev/sdX` must be the complete SD card, not a partition such as `/dev/sdX1`.

## What this fork adds

- Raspberry Pi 5 BCM2712 device-tree validation
- Direct Raspberry Pi firmware boot without UEFI
- 64-bit kernel and initramfs boot configuration
- VC4/V3D full-KMS configuration for COSMIC and Wayland
- 16 GiB sparse image with a 1 GiB FAT boot partition
- Pop!_OS and Raspberry Pi package provisioning inside `systemd-nspawn`
- Ignored, interactive development-user configuration
- Optional development SSH public-key installation
- First-boot root partition and ext4 filesystem expansion
- Kernel, initramfs, DTB, overlay, and Pi firmware synchronization
- Host-side checks for required tools, QEMU, binfmt, and disk space
- Structural image verification before compression
- Checksummed release artifacts and build metadata
- Destructive-device confirmation before flashing

## Documentation

| Document | Purpose |
|---|---|
| [Documentation index](docs/README.md) | Entry point for all project documentation |
| [Image guide](docs/IMAGE.md) | What the image contains, how it boots, and current limitations |
| [Building](docs/BUILDING.md) | Host setup, build commands, variables, outputs, and cleanup |
| [Flashing](docs/FLASHING.md) | Safe SD-card flashing and post-flash inspection |
| [Hardware testing](docs/TESTING.md) | Staged Pi 5 validation plan and acceptance criteria |
| [Architecture](docs/ARCHITECTURE.md) | Builder flow, repository layout, and installed services |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Known build and boot failures with corrective procedures |
| [Release checklist](docs/RELEASE_CHECKLIST.md) | Requirements for promoting a development image |

The historical [`README-RPI5.md`](README-RPI5.md) is retained as a compatibility pointer to the image guide.

## Common commands

```bash
make help          # Show supported targets
make check-host    # Validate the host without installing packages
make deps          # Install missing host dependencies
make configure     # Create build/noble/dev-user.conf
make lint          # Run Bash syntax checks and ShellCheck when available
make image         # Build build/noble/raspi.img
make verify        # Inspect the raw image without booting it
make compressed    # Produce build/noble/raspi.img.xz
make release       # Verify and copy named artifacts into dist/
make flash DEVICE=/dev/sdX
make clean         # Remove image and dist/ but retain debootstrap and credentials
make distclean     # Remove all generated build state
```

## Branch model

| Branch | Role |
|---|---|
| `master` | Clean synchronization point with System76 upstream |
| `rpi5-minimal` | Minimal Pi 5 bring-up and current hardware-test branch |
| `release/rpi5-24.04` | Future stabilization branch after hardware validation |

The larger board/profile automation effort is maintained separately from this minimal upstream-oriented branch.

## Safety and security

- The development profile creates a local account from `build/noble/dev-user.conf`.
- That file is ignored by Git, copied into the image only during provisioning, and removed afterward.
- Passwords are stored as SHA-512 hashes rather than plaintext.
- Optional SSH access uses a public key supplied during `make configure`.
- Machine identity and SSH host keys are cleared before image finalization so each flashed system generates its own identity.
- The flashing helper refuses partition paths and requires the complete device path to be typed again.

Do not publish a development image containing personal credentials or SSH keys.

## Upstream and license

This fork is based on System76's `pop-os/raspi-img` project and retains its **GNU General Public License version 3** terms. See [`LICENSE`](LICENSE) and [`MODIFICATION_NOTICE.md`](MODIFICATION_NOTICE.md).

Pop!_OS and System76 are trademarks of System76, Inc. Raspberry Pi is a trademark of Raspberry Pi Ltd. This project is not endorsed by either organization.
