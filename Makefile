SHELL := /usr/bin/env bash

ARCH ?= x86_64
ARCH_CANON := $(ARCH)
ifneq ($(filter $(ARCH_CANON),amd64),)
ARCH_CANON := x86_64
endif
ifneq ($(filter $(ARCH_CANON),arm32),)
ARCH_CANON := arm
endif
ifneq ($(filter $(ARCH_CANON),aarch64 aarch),)
ARCH_CANON := arm64
endif
ifneq ($(filter $(ARCH_CANON),riscv64),)
ARCH_CANON := riscv
endif
JOBS ?= $(shell nproc)
CROSS_COMPILE ?=
OBJCOPY ?=
NM ?=
BUSYBOX_BIN ?=
BUSYBOX_DIR ?= $(REPO_DIR)/busybox
BUSYBOX_OUT_DIR ?= $(REPO_DIR)/out/busybox/$(ARCH_CANON)
BUSYBOX_STATIC ?= auto
QEMU_DIR ?= $(REPO_DIR)/qemu
QEMU_BUILD_DIR ?= $(REPO_DIR)/out/qemu/$(ARCH_CANON)
LLVM ?= 1
KERNEL_DEBUG ?= 1
BEAR_BIN ?= bear
ENSURE_BUILD_DEPS ?= 1
PYTHON_BIN ?= python3
.DEFAULT_GOAL := x86

REPO_DIR := $(CURDIR)
SCRIPTS_DIR := $(REPO_DIR)/scripts

OUT_DIR ?= $(REPO_DIR)/out/$(ARCH)
INITRAMFS_DIR ?= $(REPO_DIR)/out/initramfs/$(ARCH_CANON)

BUILD_KERNEL_SH := $(SCRIPTS_DIR)/build-kernel.sh
BUILD_BUSYBOX_SH := $(SCRIPTS_DIR)/build-busybox.sh
BUILD_QEMU_SH := $(SCRIPTS_DIR)/build-qemu.sh
BUILD_INITRAMFS_SH := $(SCRIPTS_DIR)/build-initramfs.sh
BUILD_AND_RUN_QEMU_SH := $(SCRIPTS_DIR)/build-and-run-qemu.sh
RUN_QEMU_SH := $(SCRIPTS_DIR)/run-qemu.sh

QEMU_ARGS ?=
KERNEL_CMDLINE ?=
CROSS_ARCH_ALIASES := arm arm32 arm64 aarch64 aarch riscv riscv64

.PHONY: help all kernel busybox qemu menuconfig initramfs run build-and-run clean x86 x86_64 arm arm64 aarch64 riscv

help:
	@echo "Kernel + QEMU workflow"
	@echo ""
	@echo "Targets:"
	@echo "  make (default)      Build+run x86_64 kernel in QEMU"
	@echo "  make x86            Build+run x86_64 kernel in QEMU"
	@echo "  make arm            Build+run arm kernel in QEMU"
	@echo "  make arm64          Build+run arm64 kernel in QEMU"
	@echo "  make riscv          Build+run riscv kernel in QEMU"
	@echo "  make kernel         Build kernel to out/\$$ARCH"
	@echo "  make busybox        Build busybox from ./busybox to out/busybox/\$$ARCH"
	@echo "  make qemu           Build qemu from ./qemu to out/qemu/\$$ARCH"
	@echo "  make menuconfig     Open kernel menuconfig (then build)"
	@echo "  make initramfs      Build initramfs to out/initramfs/\$$ARCH"
	@echo "  make all            Build kernel + busybox + initramfs"
	@echo "  make run            Build all then boot with QEMU"
	@echo "  make build-and-run  Build + run via scripts/build-and-run-qemu.sh"
	@echo "  make clean          Remove out/\$$ARCH, out/initramfs/\$$ARCH, out/busybox/\$$ARCH, out/qemu/\$$ARCH, compile_commands.json"
	@echo ""
	@echo "Common variables:"
	@echo "  ARCH=$(ARCH)  # x86_64|arm|arm64|riscv"
	@echo "  JOBS=$(JOBS)"
	@echo "  CROSS_COMPILE=$(CROSS_COMPILE)  # empty: auto-detect for arm/arm64/riscv"
	@echo "  OBJCOPY=$(OBJCOPY)  # empty: riscv defaults to llvm-objcopy when available"
	@echo "  NM=$(NM)            # empty: riscv defaults to llvm-nm when available"
	@echo "  BUSYBOX_BIN=$(BUSYBOX_BIN)  # empty: auto-detect per ARCH; cross-arch needs target busybox"
	@echo "  BUSYBOX_DIR=$(BUSYBOX_DIR)"
	@echo "  BUSYBOX_OUT_DIR=$(BUSYBOX_OUT_DIR)"
	@echo "  BUSYBOX_STATIC=$(BUSYBOX_STATIC)  # auto: cross=static, native=dynamic"
	@echo "  QEMU_DIR=$(QEMU_DIR)"
	@echo "  QEMU_BUILD_DIR=$(QEMU_BUILD_DIR)"
	@echo "  LLVM=$(LLVM)  # 1: use clang/lld by default; 0: use GCC/binutils"
	@echo "  KERNEL_DEBUG=$(KERNEL_DEBUG)  # 1: generate compile_commands.json via bear"
	@echo "  BEAR_BIN=$(BEAR_BIN)"
	@echo "  ENSURE_BUILD_DEPS=$(ENSURE_BUILD_DEPS)  # 1: auto-check/install build deps"
	@echo "  PYTHON_BIN=$(PYTHON_BIN)"
	@echo "  OUT_DIR=$(OUT_DIR)"
	@echo "  INITRAMFS_DIR=$(INITRAMFS_DIR)"
	@echo "  KERNEL_CMDLINE=$(KERNEL_CMDLINE)  # empty means per-arch default"
	@echo "  QEMU_ARGS=$(QEMU_ARGS)"

kernel:
	@ARCH="$(ARCH)" OUT_DIR="$(OUT_DIR)" JOBS="$(JOBS)" \
		CROSS_COMPILE="$(CROSS_COMPILE)" OBJCOPY="$(OBJCOPY)" NM="$(NM)" LLVM="$(LLVM)" KERNEL_DEBUG="$(KERNEL_DEBUG)" BEAR_BIN="$(BEAR_BIN)" \
		ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)" \
		"$(BUILD_KERNEL_SH)"

busybox:
	@ARCH="$(ARCH)" BUSYBOX_DIR="$(BUSYBOX_DIR)" BUSYBOX_OUT_DIR="$(BUSYBOX_OUT_DIR)" \
		JOBS="$(JOBS)" CROSS_COMPILE="$(CROSS_COMPILE)" BUSYBOX_STATIC="$(BUSYBOX_STATIC)" \
		ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)" \
		"$(BUILD_BUSYBOX_SH)"

qemu:
	@ARCH="$(ARCH)" QEMU_DIR="$(QEMU_DIR)" QEMU_BUILD_DIR="$(QEMU_BUILD_DIR)" \
		JOBS="$(JOBS)" ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)" \
		"$(BUILD_QEMU_SH)"

menuconfig:
	@ARCH="$(ARCH)" OUT_DIR="$(OUT_DIR)" JOBS="$(JOBS)" \
		CROSS_COMPILE="$(CROSS_COMPILE)" OBJCOPY="$(OBJCOPY)" NM="$(NM)" LLVM="$(LLVM)" KERNEL_DEBUG="$(KERNEL_DEBUG)" BEAR_BIN="$(BEAR_BIN)" \
		ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)" \
		"$(BUILD_KERNEL_SH)" --menuconfig

initramfs:
	@ARCH="$(ARCH)" INITRAMFS_DIR="$(INITRAMFS_DIR)" BUSYBOX_BIN="$(BUSYBOX_BIN)" \
		ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)" \
		"$(BUILD_INITRAMFS_SH)"

ALL_DEPS := kernel busybox initramfs

all: $(ALL_DEPS)

run: all qemu
	@ARCH="$(ARCH)" OUT_DIR="$(OUT_DIR)" INITRAMFS_DIR="$(INITRAMFS_DIR)" \
		QEMU_DIR="$(QEMU_DIR)" QEMU_BUILD_DIR="$(QEMU_BUILD_DIR)" \
		ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)" \
		KERNEL_CMDLINE="$(KERNEL_CMDLINE)" \
		"$(RUN_QEMU_SH)" $(QEMU_ARGS)

x86 x86_64:
	@$(MAKE) run ARCH=x86_64 BUSYBOX_BIN="$(REPO_DIR)/out/busybox/x86_64/busybox"

arm:
	@$(MAKE) run ARCH=arm BUSYBOX_BIN="$(REPO_DIR)/out/busybox/arm/busybox"

arm64 aarch64:
	@$(MAKE) run ARCH=arm64 BUSYBOX_BIN="$(REPO_DIR)/out/busybox/arm64/busybox"

riscv:
	@$(MAKE) run ARCH=riscv BUSYBOX_BIN="$(REPO_DIR)/out/busybox/riscv/busybox"

build-and-run:
	@bb_bin="$(BUSYBOX_BIN)"; \
	if [[ -z "$$bb_bin" || ! -x "$$bb_bin" ]]; then \
		bb_bin="$(BUSYBOX_OUT_DIR)/busybox"; \
		$(MAKE) busybox ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)" JOBS="$(JOBS)" BUSYBOX_STATIC="$(BUSYBOX_STATIC)" ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)"; \
	fi; \
	ARCH="$(ARCH)" OUT_DIR="$(OUT_DIR)" INITRAMFS_DIR="$(INITRAMFS_DIR)" \
		JOBS="$(JOBS)" CROSS_COMPILE="$(CROSS_COMPILE)" OBJCOPY="$(OBJCOPY)" NM="$(NM)" BUSYBOX_BIN="$$bb_bin" LLVM="$(LLVM)" KERNEL_DEBUG="$(KERNEL_DEBUG)" BEAR_BIN="$(BEAR_BIN)" \
		QEMU_DIR="$(QEMU_DIR)" QEMU_BUILD_DIR="$(QEMU_BUILD_DIR)" \
		ENSURE_BUILD_DEPS="$(ENSURE_BUILD_DEPS)" PYTHON_BIN="$(PYTHON_BIN)" \
		KERNEL_CMDLINE="$(KERNEL_CMDLINE)" \
		"$(BUILD_AND_RUN_QEMU_SH)" $(QEMU_ARGS)

clean:
	@rm -rf "$(OUT_DIR)" "$(INITRAMFS_DIR)" "$(BUSYBOX_OUT_DIR)" "$(QEMU_BUILD_DIR)" \
		"$(REPO_DIR)/compile_commands.json" \
		"$(REPO_DIR)/out/initramfs/initramfs.cpio.gz" \
		"$(REPO_DIR)/out/initramfs/rootfs"
