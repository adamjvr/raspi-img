# Documentation index

[Back to the repository README](../README.md)

This documentation separates the image itself from the tooling used to build, flash, and validate it.

## User documentation

- [Image guide](IMAGE.md) — target hardware, partition layout, installed software, boot flow, first boot, and security model
- [Flashing](FLASHING.md) — checksum verification, device identification, guarded flashing, and post-flash inspection
- [Hardware testing](TESTING.md) — staged console, desktop, networking, peripheral, thermal, reboot, and upgrade tests
- [Troubleshooting](TROUBLESHOOTING.md) — build failures, boot failures, graphics, root expansion, and recovery

## Developer documentation

- [Building](BUILDING.md) — host requirements, commands, variables, caching, and artifacts
- [Architecture](ARCHITECTURE.md) — build pipeline, repository layout, boot synchronization, and first-boot services
- [Release checklist](RELEASE_CHECKLIST.md) — promotion criteria and release-record requirements

## Recommended reading paths

### Building an image

1. [Building](BUILDING.md)
2. [Image guide](IMAGE.md)
3. [Flashing](FLASHING.md)
4. [Hardware testing](TESTING.md)

### Debugging a failed build or boot

1. [Troubleshooting](TROUBLESHOOTING.md)
2. [Architecture](ARCHITECTURE.md)
3. [Hardware testing](TESTING.md)

### Preparing a public test release

1. [Hardware testing](TESTING.md)
2. [Release checklist](RELEASE_CHECKLIST.md)
3. [Image guide](IMAGE.md)
