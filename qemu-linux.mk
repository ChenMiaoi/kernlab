# QEMU Linux template configuration.
#
# Edit this file once for your repository, then use the root Makefile entrypoints:
#   make run
#   make run ARCH=riscv
#
# Every setting uses ?= so command-line overrides still win.

# Target architecture: x86_64, arm, arm64, or riscv.
ARCH ?= x86_64

# Parallelism and source/output locations.
JOBS ?= $(shell nproc)
LINUX_DIR ?= $(REPO_DIR)/linux
BUSYBOX_DIR ?= $(REPO_DIR)/busybox
QEMU_DIR ?= $(REPO_DIR)/qemu
OUT_DIR ?= $(REPO_DIR)/out/$(ARCH)
INITRAMFS_DIR ?= $(REPO_DIR)/out/initramfs/$(ARCH_CANON)
BUSYBOX_OUT_DIR ?= $(REPO_DIR)/out/busybox/$(ARCH_CANON)
QEMU_BUILD_DIR ?= $(REPO_DIR)/out/qemu/$(ARCH_CANON)

# Kernel build configuration.
DEFCONFIG ?=
KERNEL_TARGET ?=
CROSS_COMPILE ?=
OBJCOPY ?=
NM ?=
LLVM ?= 1
KERNEL_DEBUG ?= 1
BEAR_BIN ?= bear

# BusyBox configuration. Leave BUSYBOX_BIN empty to use the repository-built binary.
BUSYBOX_BIN ?=
BUSYBOX_STATIC ?= auto

# Dependency helper configuration.
ENSURE_BUILD_DEPS ?= 1
PYTHON_BIN ?= python3

# Initramfs customization. INITRAMFS_EXTRA_DIR is copied over the generated rootfs.
INITRAMFS_HOSTNAME ?=
INITRAMFS_BANNER ?=
INITRAMFS_EXTRA_DIR ?=

# QEMU runtime configuration.
QEMU_BIN ?=
MEMORY ?=
SMP ?=
KERNEL_CMDLINE ?=
QEMU_ARGS ?=
