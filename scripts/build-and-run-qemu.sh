#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: build-and-run-qemu.sh [extra qemu args...]

Build the kernel and initramfs, then boot them with QEMU.

Environment variables match the root qemu-linux.mk configuration:
  ARCH, LINUX_DIR, OUT_DIR, DEFCONFIG, KERNEL_TARGET, JOBS
  BUSYBOX_DIR, BUSYBOX_OUT_DIR, BUSYBOX_BIN, BUSYBOX_STATIC
  QEMU_DIR, QEMU_BUILD_DIR, QEMU_BIN, MEMORY, SMP, KERNEL_CMDLINE
  INITRAMFS_DIR, INITRAMFS_HOSTNAME, INITRAMFS_BANNER, INITRAMFS_EXTRA_DIR
  CROSS_COMPILE, OBJCOPY, NM, LLVM, KERNEL_DEBUG, BEAR_BIN
  ENSURE_BUILD_DEPS, PYTHON_BIN
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

normalize_arch() {
    case "$1" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        arm|arm32)
            echo "arm"
            ;;
        arm64|aarch64|aarch)
            echo "arm64"
            ;;
        riscv|riscv64)
            echo "riscv"
            ;;
        *)
            return 1
            ;;
    esac
}

ARCH_RAW="${ARCH:-x86_64}"
if ! ARCH_NORM="$(normalize_arch "${ARCH_RAW}")"; then
    echo "Unsupported ARCH='${ARCH_RAW}'. Use x86_64|arm|arm64|riscv." >&2
    exit 1
fi
LINUX_DIR="${LINUX_DIR:-${REPO_DIR}/linux}"
OUT_DIR="${OUT_DIR:-${REPO_DIR}/out/${ARCH_NORM}}"
INITRAMFS_DIR="${INITRAMFS_DIR:-${REPO_DIR}/out/initramfs/${ARCH_NORM}}"
BUSYBOX_DIR="${BUSYBOX_DIR:-${REPO_DIR}/busybox}"
BUSYBOX_OUT_DIR="${BUSYBOX_OUT_DIR:-${REPO_DIR}/out/busybox/${ARCH_NORM}}"
QEMU_DIR="${QEMU_DIR:-${REPO_DIR}/qemu}"
QEMU_BUILD_DIR="${QEMU_BUILD_DIR:-${REPO_DIR}/out/qemu/${ARCH_NORM}}"
JOBS="${JOBS:-$(nproc)}"
CROSS_COMPILE="${CROSS_COMPILE:-}"
OBJCOPY="${OBJCOPY:-}"
NM="${NM:-}"
LLVM="${LLVM:-1}"
KERNEL_DEBUG="${KERNEL_DEBUG:-1}"
BEAR_BIN="${BEAR_BIN:-bear}"
ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS:-1}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
BUSYBOX_STATIC="${BUSYBOX_STATIC:-auto}"
BUSYBOX_BIN="${BUSYBOX_BIN:-}"
QEMU_BIN="${QEMU_BIN:-}"
MEMORY="${MEMORY:-}"
SMP="${SMP:-}"
KERNEL_CMDLINE="${KERNEL_CMDLINE:-}"
INITRAMFS_HOSTNAME="${INITRAMFS_HOSTNAME:-}"
INITRAMFS_BANNER="${INITRAMFS_BANNER:-}"
INITRAMFS_EXTRA_DIR="${INITRAMFS_EXTRA_DIR:-}"
DEFCONFIG="${DEFCONFIG:-}"
KERNEL_TARGET="${KERNEL_TARGET:-}"


if [[ -z "${BUSYBOX_BIN}" && "${ARCH_NORM}" != "x86_64" ]]; then
    ARCH="${ARCH_NORM}" BUSYBOX_DIR="${BUSYBOX_DIR}" BUSYBOX_OUT_DIR="${BUSYBOX_OUT_DIR}" \
        JOBS="${JOBS}" CROSS_COMPILE="${CROSS_COMPILE}" BUSYBOX_STATIC="${BUSYBOX_STATIC}" \
        ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS}" PYTHON_BIN="${PYTHON_BIN}" \
        "${SCRIPT_DIR}/build-busybox.sh"
    BUSYBOX_BIN="${BUSYBOX_OUT_DIR}/busybox"
fi

ARCH="${ARCH_NORM}" LINUX_DIR="${LINUX_DIR}" OUT_DIR="${OUT_DIR}" DEFCONFIG="${DEFCONFIG}" KERNEL_TARGET="${KERNEL_TARGET}" \
    JOBS="${JOBS}" CROSS_COMPILE="${CROSS_COMPILE}" OBJCOPY="${OBJCOPY}" NM="${NM}" LLVM="${LLVM}" \
    KERNEL_DEBUG="${KERNEL_DEBUG}" BEAR_BIN="${BEAR_BIN}" ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS}" PYTHON_BIN="${PYTHON_BIN}" \
    "${SCRIPT_DIR}/build-kernel.sh"
ARCH="${ARCH_NORM}" INITRAMFS_DIR="${INITRAMFS_DIR}" BUSYBOX_BIN="${BUSYBOX_BIN}" \
    INITRAMFS_HOSTNAME="${INITRAMFS_HOSTNAME}" INITRAMFS_BANNER="${INITRAMFS_BANNER}" INITRAMFS_EXTRA_DIR="${INITRAMFS_EXTRA_DIR}" \
    ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS}" PYTHON_BIN="${PYTHON_BIN}" \
    "${SCRIPT_DIR}/build-initramfs.sh"
exec env ARCH="${ARCH_NORM}" OUT_DIR="${OUT_DIR}" INITRAMFS_DIR="${INITRAMFS_DIR}" \
    QEMU_DIR="${QEMU_DIR}" QEMU_BUILD_DIR="${QEMU_BUILD_DIR}" QEMU_BIN="${QEMU_BIN}" \
    ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS}" PYTHON_BIN="${PYTHON_BIN}" JOBS="${JOBS}" \
    MEMORY="${MEMORY}" SMP="${SMP}" KERNEL_CMDLINE="${KERNEL_CMDLINE}" \
    "${SCRIPT_DIR}/run-qemu.sh" "$@"
