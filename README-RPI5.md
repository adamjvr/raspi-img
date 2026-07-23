# Pop!_OS 24.04 Raspberry Pi 5 minimal modernization

This directory is a drop-in overlay for `adamjvr/raspi-img`. It retains the
System76 image-builder model while adding direct Pi 5 boot support, a larger
boot partition, first-boot root expansion, kernel-update synchronization,
image verification, and safer flashing.

## Apply over the fork

```bash
cd ~/GitHub/raspi-img
git switch -c rpi5-minimal
unzip -o /path/to/raspi-img-rpi5-minimal-overlay.zip -d .
git add -A
git commit -m "Add Raspberry Pi 5 image bring-up"
```

## Build

```bash
make deps
make configure
make lint
make release
```

## Flash

```bash
make flash DEVICE=/dev/sdX
```

The release artifact is written to:

```text
dist/pop-os_24.04_rpi5_arm64-dev0.img.xz
```

This is development code. Validate console boot, KMS, COSMIC, networking,
root expansion, and kernel-update survival before describing the image as a
release candidate.
