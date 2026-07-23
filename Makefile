# Pop!_OS Raspberry Pi image builder — Raspberry Pi 5 bring-up branch.
#
# This file intentionally remains close to System76's original Makefile while
# adding explicit image sizing, validation, release packaging, and development
# user provisioning.  It is intended to be extracted over adamjvr/raspi-img.

ARCH ?= arm64
UBUNTU_CODE ?= noble
UBUNTU_MIRROR ?= http://ports.ubuntu.com/ubuntu-ports

IMAGE_SIZE ?= 16G
BOOT_START_MIB ?= 1
BOOT_END_MIB ?= 1025
PROFILE ?= development

BUILD := build/$(UBUNTU_CODE)
DIST := dist
DEV_CONFIG ?= $(BUILD)/dev-user.conf
IMAGE := $(BUILD)/raspi.img
COMPRESSED_IMAGE := $(BUILD)/raspi.img.xz
RELEASE_BASENAME ?= pop-os_24.04_rpi5_arm64-dev0

SED = \
	s|UBUNTU_CODE|$(UBUNTU_CODE)|g; \
	s|UBUNTU_MIRROR|$(UBUNTU_MIRROR)|g

.PHONY: all image compressed configure deps check-host verify release flash clean distclean lint help

all: compressed

help:
	@printf '%s\n' \
		'make configure   Create build/dev-user.conf interactively' \
		'make image       Build the uncompressed Raspberry Pi image' \
		'make compressed  Build and compress the image' \
		'make verify      Inspect the image without booting it' \
		'make release     Copy a named image, checksum, and manifest to dist/' \
		'make flash DEVICE=/dev/sdX   Flash the named release image' \
		'make lint        Run shell syntax and ShellCheck validation' \
		'make clean       Remove image and release output but retain debootstrap' \
		'make distclean   Remove all generated build state'

check-host:
	@./scripts/check-host.sh

deps:
	@./scripts/check-host.sh --install-missing

configure:
	@mkdir -p "$(BUILD)"
	@./scripts/create-dev-config.sh "$(DEV_CONFIG)"

$(BUILD)/debootstrap:
	@mkdir -p "$(BUILD)"
	@sudo rm -rf --one-file-system "$@" "$@.partial"
	@echo "Bootstrapping Ubuntu $(UBUNTU_CODE) $(ARCH)..."
	@if ! sudo debootstrap \
		"--arch=$(ARCH)" \
		"$(UBUNTU_CODE)" \
		"$@.partial" \
		"$(UBUNTU_MIRROR)"; then \
		cat "$@.partial/debootstrap/debootstrap.log" 2>/dev/null || true; \
		false; \
	fi
	@sudo touch "$@.partial"
	@sudo mv "$@.partial" "$@"

$(IMAGE): $(BUILD)/debootstrap
	@mkdir -p "data/etc/apt/sources.list.d"
	@sed "$(SED)" "data/template/pop-os-release.sources" > \
		"data/etc/apt/sources.list.d/pop-os-release.sources"
	@sed "$(SED)" "data/template/system.sources" > \
		"data/etc/apt/sources.list.d/system.sources"
	@if [ "$(PROFILE)" = development ] && [ ! -f "$(DEV_CONFIG)" ]; then \
		echo "Missing $(DEV_CONFIG). Run 'make configure' first." >&2; \
		exit 1; \
	fi
	@sudo env \
		IMAGE_SIZE="$(IMAGE_SIZE)" \
		BOOT_START_MIB="$(BOOT_START_MIB)" \
		BOOT_END_MIB="$(BOOT_END_MIB)" \
		PROFILE="$(PROFILE)" \
		DEV_CONFIG="$(abspath $(DEV_CONFIG))" \
		data/image.sh "$@.partial" "$(BUILD)/mount" "$<"
	@sudo touch "$@.partial"
	@sudo mv "$@.partial" "$@"

image: $(IMAGE)

$(COMPRESSED_IMAGE): $(IMAGE)
	@rm -f "$@" "$@.partial"
	@xz --threads=0 --best --keep --stdout "$<" > "$@.partial"
	@mv "$@.partial" "$@"

compressed: $(COMPRESSED_IMAGE)

verify: $(IMAGE)
	@./scripts/verify-image.sh "$(IMAGE)"

release: verify $(COMPRESSED_IMAGE)
	@mkdir -p "$(DIST)"
	@cp "$(COMPRESSED_IMAGE)" "$(DIST)/$(RELEASE_BASENAME).img.xz"
	@sha256sum "$(DIST)/$(RELEASE_BASENAME).img.xz" > \
		"$(DIST)/$(RELEASE_BASENAME).img.xz.sha256"
	@./scripts/write-build-info.sh \
		"$(DIST)/$(RELEASE_BASENAME).build-info" \
		"$(RELEASE_BASENAME)" \
		"$(UBUNTU_CODE)" \
		"$(ARCH)" \
		"$(PROFILE)"
	@echo "Release artifacts written to $(DIST)/"

flash: release
	@test -n "$(DEVICE)" || { \
		echo 'Usage: make flash DEVICE=/dev/sdX' >&2; \
		exit 2; \
	}
	@sudo ./scripts/flash-image.sh \
		"$(DIST)/$(RELEASE_BASENAME).img.xz" \
		"$(DEVICE)"

lint:
	@bash -n data/image.sh data/chroot.sh scripts/*.sh \
		rootfs-overlay/usr/local/sbin/*
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck data/image.sh data/chroot.sh scripts/*.sh \
			rootfs-overlay/usr/local/sbin/*; \
	else \
		echo 'shellcheck is not installed; bash syntax checks passed.'; \
	fi

clean:
	@sudo rm -f "$(IMAGE)" "$(IMAGE).partial"
	@rm -f "$(COMPRESSED_IMAGE)" "$(COMPRESSED_IMAGE).partial"
	@rm -rf "$(DIST)"

distclean: clean
	@sudo rm -rf --one-file-system \
		"$(BUILD)/debootstrap" \
		"$(BUILD)/debootstrap.partial" \
		"$(BUILD)/mount"
	@rm -f "$(DEV_CONFIG)"
