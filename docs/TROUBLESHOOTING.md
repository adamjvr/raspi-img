# Troubleshooting

[Documentation index](README.md) · [Repository README](../README.md) · [Build](BUILDING.md) · [Hardware testing](TESTING.md)

## `No rule to make target configure`, `lint`, or `release`

Cause: the checkout is on `master`, which contains the upstream Makefile, rather than the Pi 5 branch.

Check:

```bash
git branch -vv
git branch -r
```

Switch to the existing remote branch:

```bash
git fetch origin --prune
git switch --track origin/rpi5-minimal
```

If the local branch already exists:

```bash
git switch rpi5-minimal
```

Confirm:

```bash
make help
```

## FAT boot copy fails with `Operation not permitted`

Typical output:

```text
rsync: chown ... /boot/firmware ... Operation not permitted
rsync error: code 23
```

Cause: FAT32 cannot store normal Unix ownership, group, permission, ACL, or extended-attribute metadata.

The boot copy must use `rsync` with metadata preservation disabled:

```text
--no-perms --no-owner --no-group --omit-dir-times
```

Runtime overlay and firmware copies must not use `cp -a` against the FAT mount.

Do not run the internal `rsync` command manually in your shell. `MOUNT_DIR` is set by `data/image.sh`; when unset, the destination may incorrectly expand to the host's `/boot/firmware`.

After correcting the script:

```bash
make clean
make release
```

`make clean` preserves the debootstrap cache.

## Container cannot resolve package hosts

Typical output:

```text
Temporary failure resolving 'ports.ubuntu.com'
```

Cause: the target's resolver symlink or local stub is unusable inside `systemd-nspawn`.

The builder selects `replace-uplink` when the host's systemd-resolved uplink file exists, otherwise `replace-host`.

Test the reusable bootstrap directly:

```bash
if [[ -s /run/systemd/resolve/resolv.conf ]]; then
    DNS_MODE=replace-uplink
else
    DNS_MODE=replace-host
fi

sudo systemd-nspawn \
    --quiet \
    --register=no \
    --machine=pop-rpi5-dns-test \
    --directory="$PWD/build/noble/debootstrap" \
    --resolv-conf="$DNS_MODE" \
    /usr/bin/getent hosts ports.ubuntu.com
```

## APT refuses Pop!_OS package downgrades

Typical output:

```text
Packages were downgraded and -y was used without --allow-downgrades
```

Cause: the Pop repository may provide a coordinated package set whose version numbers are lower than currently installed Noble updates.

The Pop desktop transaction uses:

```text
--allow-downgrades --no-remove
```

The first option permits dependency-driven downgrades; the second prevents the transaction from silently removing packages.

Never add `--force-yes` or `--allow-remove-essential`.

## Build fails after image creation

Retain the reusable bootstrap:

```bash
make clean
```

Confirm:

```bash
test -d build/noble/debootstrap && echo "Bootstrap retained"
test -f build/noble/dev-user.conf && echo "Credentials retained"
```

Check stale state:

```bash
findmnt -R "$PWD/build/noble/mount" || true
sudo losetup --list | grep "$PWD/build/noble" || true
```

The image script normally cleans mounts and loop devices through its exit trap.

## Full rebuild is required

Use only when the Noble bootstrap itself is corrupt or must be regenerated:

```bash
make distclean
make configure
make release
```

## Pi shows no HDMI output

Do not immediately assume the entire image failed.

Check:

- SD-card activity and status LEDs
- alternate HDMI port and cable
- console over UART if available
- whether the system obtains an Ethernet address
- whether SSH works using the configured public key

After console access:

```bash
ls -l /dev/dri
lsmod | grep -E 'vc4|v3d|drm' || true
sudo journalctl -b -k --no-pager |
    grep -Ei 'vc4|v3d|drm|hdmi|framebuffer'
```

## Console works but COSMIC does not

This is still a successful kernel and root-filesystem bring-up.

Collect:

```bash
systemctl status cosmic-greeter.service --no-pager
journalctl -b -u cosmic-greeter.service --no-pager
systemctl --failed --no-pager
ls -l /dev/dri
```

Keep graphics and greeter debugging separate from base boot debugging.

## Root filesystem did not expand

```bash
systemctl status pop-rpi-grow-root.service --no-pager
journalctl -b -u pop-rpi-grow-root.service --no-pager
findmnt -no SOURCE /
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
df -hT /
```

Do not manually resize until the logs and device mapping have been captured.

## Kernel update causes a boot failure

Before changing the card, inspect the FAT partition from another Linux system and verify:

```text
vmlinuz
initrd.img
bcm2712-rpi-5-b.dtb
overlays/
config.txt
cmdline.txt
```

Compare timestamps and file sizes. The kernel and initramfs update hooks should invoke `/usr/local/sbin/pop-rpi-sync-boot`.

A kernel-update boot failure blocks release-candidate status even when the original image boots.
