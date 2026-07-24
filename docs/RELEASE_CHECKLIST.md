# Release checklist

[Documentation index](README.md) · [Repository README](../README.md) · [Image guide](IMAGE.md) · [Hardware testing](TESTING.md)

This project is currently in development-image status. Complete every required item before creating a release branch or describing an image as hardware validated.

## Source state

- [ ] Work is on `rpi5-minimal`
- [ ] Working tree is clean
- [ ] All fixes are committed and pushed
- [ ] `make lint` passes
- [ ] Build commit SHA is recorded
- [ ] Release basename is unique and not an older development identifier

## Build

- [ ] `make check-host` passes
- [ ] `make release` completes
- [ ] `scripts/verify-image.sh` passes
- [ ] XZ compression completes
- [ ] SHA-256 checksum validates
- [ ] Build metadata exists
- [ ] Release artifacts are archived unchanged

## Security and identity

- [ ] Temporary build configuration is absent from the image
- [ ] `/etc/machine-id` is empty before first boot
- [ ] SSH host keys are absent before first boot
- [ ] No private SSH key exists in the image
- [ ] No unintended personal authorized key exists in a public image
- [ ] No plaintext password exists in the source tree or artifacts
- [ ] Public release account strategy is documented

## Boot and storage

- [ ] Raspberry Pi 5 firmware loads the image
- [ ] BCM2712 kernel boots
- [ ] Root filesystem mounts by label
- [ ] Console login works
- [ ] FAT boot partition mounts at `/boot/firmware`
- [ ] Root partition expands on a larger SD card
- [ ] Repeated warm reboot passes
- [ ] Repeated cold boot passes
- [ ] Clean shutdown passes

## Graphics and desktop

- [ ] VC4 module loads
- [ ] V3D module loads
- [ ] `/dev/dri` exists
- [ ] COSMIC greeter starts
- [ ] COSMIC session starts
- [ ] Window movement and resizing work
- [ ] Display resolution is correct
- [ ] Logout and login work

## Connectivity and peripherals

- [ ] Ethernet works
- [ ] DNS works
- [ ] Wi-Fi scans and connects
- [ ] Wi-Fi works without Ethernet
- [ ] Bluetooth scans, pairs, and reconnects
- [ ] HDMI audio works
- [ ] USB keyboard and mouse work
- [ ] USB storage works
- [ ] Optional USB audio tested or documented as untested
- [ ] Optional PCIe/NVMe tested or documented as untested

## Stability

- [ ] No persistent critical systemd failures
- [ ] No persistent undervoltage warnings
- [ ] No unexpected thermal throttling
- [ ] Sustained CPU and memory load completes
- [ ] System remains usable after load

## Update survival

- [ ] `apt update` succeeds
- [ ] `apt full-upgrade` succeeds
- [ ] Kernel update hooks run
- [ ] `vmlinuz` is synchronized to the FAT partition
- [ ] `initrd.img` is synchronized to the FAT partition
- [ ] Pi 5 DTB remains present
- [ ] VC4/V3D overlays remain present
- [ ] Updated system reboots successfully

## Evidence

- [ ] First-boot journal saved
- [ ] First-boot kernel log saved
- [ ] Post-update journal saved
- [ ] Post-update kernel log saved
- [ ] Package manifest saved
- [ ] Hardware configuration recorded
- [ ] Power supply and cooling recorded
- [ ] SD-card model and capacity recorded
- [ ] Known issues documented

## Promotion

After all required checks pass:

```bash
git switch rpi5-minimal
git pull --ff-only

git tag -a rpi5-dev0-working \
    -m "First hardware-validated Pop OS 24.04 Raspberry Pi 5 image"

git push origin rpi5-dev0-working
```

A stabilization branch may then be created:

```bash
git switch -c release/rpi5-24.04
git push -u origin release/rpi5-24.04
```

Do not move an older tag. Create a new immutable tag for each meaningful build or hardware-validation milestone.
