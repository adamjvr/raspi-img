# Flashing the image

[Documentation index](README.md) · [Repository README](../README.md) · [Image guide](IMAGE.md) · [Hardware testing](TESTING.md)

> [!CAUTION]
> Flashing destroys all data on the selected device. Confirm the whole-disk path, model, size, and transport before proceeding.

## Verify the release artifact

```bash
cd ~/GitHub/raspi-img
ls -lh dist/
sha256sum -c dist/*.sha256
```

Do not flash an artifact whose checksum fails.

## Identify the SD card

Insert the card and run:

```bash
lsblk -p -o NAME,SIZE,MODEL,SERIAL,TRAN,FSTYPE,MOUNTPOINTS
```

Identify the whole disk, such as:

```text
/dev/sdb
```

Do not use a partition path such as:

```text
/dev/sdb1
```

## Guarded project flashing

```bash
make flash DEVICE=/dev/sdX
```

The helper:

- verifies the image exists
- verifies the target is a block device
- rejects partition targets
- displays the device model, size, transport, filesystems, and mounts
- requires the complete device path to be typed again
- unmounts child partitions
- streams the XZ image into `dd`
- flushes writes with `sync`

## Manual fallback

Use only after identifying the correct target:

```bash
xz --decompress --stdout \
    dist/pop-os_24.04_rpi5_arm64-dev0.img.xz |
sudo dd \
    of=/dev/sdX \
    bs=16M \
    iflag=fullblock \
    status=progress \
    conv=fsync

sync
```

## Post-flash inspection

Remove and reinsert the card, then run:

```bash
lsblk -f /dev/sdX
```

Expected labels:

```text
system-boot
writable
```

Optional mount and inspection:

```bash
sudo mkdir -p /mnt/pop-rpi-test
sudo mount /dev/sdX2 /mnt/pop-rpi-test
sudo mount /dev/sdX1 /mnt/pop-rpi-test/boot/firmware

ls -lh /mnt/pop-rpi-test/boot/firmware

test -f /mnt/pop-rpi-test/boot/firmware/bcm2712-rpi-5-b.dtb &&
    echo "Pi 5 DTB present"

sudo umount /mnt/pop-rpi-test/boot/firmware
sudo umount /mnt/pop-rpi-test
```

## First hardware configuration

For the first boot, use only:

- Raspberry Pi 5
- active cooling
- known-good microSD card
- HDMI display
- USB keyboard and mouse
- Ethernet
- suitable USB-C power supply

Do not attach NVMe, GPIO hardware, USB audio, storage hubs, or other optional devices until the console and desktop boot path is established.

Continue with the [hardware test plan](TESTING.md).
