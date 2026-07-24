# Raspberry Pi 5 hardware test plan

[Documentation index](README.md) · [Repository README](../README.md) · [Image guide](IMAGE.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Release checklist](RELEASE_CHECKLIST.md)

## Test philosophy

Validate the image in layers. Do not begin with every accessory attached. A staged test makes it possible to distinguish firmware, kernel, root filesystem, graphics, desktop, networking, and peripheral failures.

## Stage 1 — Minimum hardware boot

Use:

- Raspberry Pi 5
- active cooling
- microSD card containing the image
- one HDMI display
- USB keyboard
- Ethernet
- known-good power supply

Do not attach NVMe, GPIO boards, USB storage, audio interfaces, or hubs.

### First success criterion

A usable console login is the first milestone. COSMIC may fail independently while the base operating system is functional.

Expected flow:

```text
firmware → kernel → initramfs → writable root → systemd → login or COSMIC
```

## Stage 2 — Identity, root, and system state

After login:

```bash
tr -d '\0' < /proc/device-tree/model; echo
uname -a
cat /etc/os-release
dpkg --print-architecture
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
findmnt /
findmnt /boot/firmware
df -hT /
systemctl is-system-running || true
systemctl --failed --no-pager || true
```

Expected:

- device model identifies Raspberry Pi 5
- architecture is `arm64`
- root is mounted from the `writable` filesystem
- boot is mounted from `system-boot`
- no critical failed services

### Root expansion

```bash
systemctl status pop-rpi-grow-root.service --no-pager
lsblk
df -hT /
sudo test -e /var/lib/pop-rpi/root-grown &&
    echo "Root expansion completed"
```

Partition 2 and the ext4 filesystem should grow to use the SD card.

## Stage 3 — Ethernet and DNS

```bash
nmcli general status
nmcli device status
ip -brief address
ip route
ping -c 4 1.1.1.1
getent hosts ports.ubuntu.com
getent hosts system76.com
```

Validate Ethernet before Wi-Fi.

## Stage 4 — Graphics and COSMIC

```bash
ls -l /dev/dri
lsmod | grep -E 'vc4|v3d|drm' || true
sudo journalctl -b -k --no-pager |
    grep -Ei 'vc4|v3d|drm|hdmi|framebuffer'

systemctl status cosmic-greeter.service --no-pager
journalctl -b -u cosmic-greeter.service --no-pager
```

Inside COSMIC, test:

- login and logout
- terminal and settings launch
- window movement and resizing
- display resolution
- keyboard and mouse input
- warm reboot
- clean shutdown

## Stage 5 — Wi-Fi

```bash
nmcli radio wifi
nmcli device wifi list
nmcli --ask device wifi connect "YOUR_SSID"
nmcli connection show --active
ping -c 4 1.1.1.1
getent hosts system76.com
```

Disconnect Ethernet and verify Wi-Fi remains functional.

## Stage 6 — Bluetooth

```bash
rfkill list
systemctl status bluetooth.service --no-pager
bluetoothctl show
```

Then use `bluetoothctl` to power on, scan, pair, connect, and reconnect a known device.

## Stage 7 — Audio

```bash
systemctl --user status pipewire.service --no-pager
systemctl --user status wireplumber.service --no-pager
wpctl status
speaker-test -c 2 -t wav
```

Test HDMI first, followed by USB and Bluetooth audio only after their underlying buses are validated.

## Stage 8 — USB and optional hardware

Connect one device at a time:

1. mouse
2. USB storage
3. USB audio
4. powered hub
5. optional GPIO or PCIe hardware

Monitor each attachment:

```bash
lsusb
lsblk -f
sudo dmesg --color=always | tail -n 80
```

## Stage 9 — Power and thermal behavior

```bash
awk '{printf "%.1f C\n", $1/1000}' \
    /sys/class/thermal/thermal_zone0/temp

if command -v vcgencmd >/dev/null 2>&1; then
    vcgencmd get_throttled
    vcgencmd measure_temp
fi
```

Optional load test:

```bash
sudo apt update
sudo apt install stress-ng
stress-ng \
    --cpu "$(nproc)" \
    --vm 2 \
    --vm-bytes 60% \
    --timeout 5m \
    --metrics-brief
```

Check the journal for undervoltage, thermal, or throttling warnings afterward.

## Stage 10 — Reboot matrix

Perform at least:

- three warm reboots
- two cold boots
- one terminal shutdown
- one desktop shutdown

```bash
sudo reboot
sudo poweroff
```

Every boot should return to a usable console or COSMIC session.

## Stage 11 — Kernel and initramfs update survival

Before updating:

```bash
uname -a
sudo sha256sum \
    /boot/firmware/vmlinuz \
    /boot/firmware/initrd.img \
    /boot/firmware/bcm2712-rpi-5-b.dtb
```

Update and synchronize:

```bash
sudo apt update
sudo apt full-upgrade
sudo /usr/local/sbin/pop-rpi-sync-boot
sudo reboot
```

After reboot:

```bash
uname -a
systemctl --failed --no-pager
ls -l --full-time \
    /boot/firmware/vmlinuz \
    /boot/firmware/initrd.img \
    /boot/firmware/bcm2712-rpi-5-b.dtb
```

The system must boot with the updated kernel and retain the Pi 5 DTB and overlays.

## Diagnostic capture

```bash
mkdir -p "$HOME/rpi5-test-results"

sudo dmesg --color=never \
    > "$HOME/rpi5-test-results/dmesg.txt"

sudo journalctl -b --no-pager \
    > "$HOME/rpi5-test-results/journal.txt"

sudo journalctl -b -p warning..alert --no-pager \
    > "$HOME/rpi5-test-results/warnings.txt"

dpkg-query -W -f='${binary:Package}\t${Version}\n' |
    sort > "$HOME/rpi5-test-results/packages.txt"

tar -C "$HOME" -cJf "$HOME/rpi5-test-results.tar.xz" \
    rpi5-test-results
```

## Acceptance matrix

| Area | Pass requirement |
|---|---|
| Firmware | Loads kernel from microSD |
| Kernel | Detects Raspberry Pi 5 and BCM2712 |
| Root filesystem | Mounts and expands successfully |
| Login | Development account works |
| Graphics | VC4/V3D load and `/dev/dri` exists |
| Desktop | COSMIC greeter and session are usable |
| Ethernet | DHCP, routing, DNS, and Internet work |
| Wi-Fi | Scans, connects, reconnects, and works without Ethernet |
| Bluetooth | Controller initializes and a device can pair/connect |
| Audio | At least HDMI output works |
| USB | Keyboard, mouse, and storage work |
| Power and thermals | No persistent undervoltage or thermal faults |
| Reboots | Warm and cold boots are repeatable |
| Updates | Kernel update synchronizes boot files and reboots |

Only after every required row passes should the image be promoted beyond development status.
