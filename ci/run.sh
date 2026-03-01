#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=ci/lib.sh
source "${SCRIPT_DIR}/lib.sh"

ARCH_RAW="${ARCH:-x86_64}"
if ! ARCH="$(normalize_arch "${ARCH_RAW}")"; then
    echo "Unsupported ARCH='${ARCH_RAW}'. Use x86_64|arm|arm64|riscv." >&2
    exit 1
fi

OUT_DIR="${OUT_DIR:-${REPO_DIR}/out/${ARCH}}"
INITRAMFS_DIR="${INITRAMFS_DIR:-${REPO_DIR}/out/initramfs/${ARCH}}"
JOBS="${JOBS:-$(nproc)}"

make -C "${REPO_DIR}" --no-print-directory all \
    ARCH="${ARCH}" \
    OUT_DIR="${OUT_DIR}" \
    INITRAMFS_DIR="${INITRAMFS_DIR}" \
    JOBS="${JOBS}" \
    CROSS_COMPILE="${CROSS_COMPILE:-}" \
    OBJCOPY="${OBJCOPY:-}" \
    NM="${NM:-}" \
    LLVM="${LLVM:-}" \
    BUSYBOX_BIN="${BUSYBOX_BIN:-}" \
    BUSYBOX_DIR="${BUSYBOX_DIR:-}" \
    BUSYBOX_OUT_DIR="${BUSYBOX_OUT_DIR:-}" \
    BUSYBOX_STATIC="${BUSYBOX_STATIC:-}"

ARCH="${ARCH}" OUT_DIR="${OUT_DIR}" INITRAMFS_DIR="${INITRAMFS_DIR}" \
    "${SCRIPT_DIR}/check-artifacts.sh"

ARCH="${ARCH}" OUT_DIR="${OUT_DIR}" INITRAMFS_DIR="${INITRAMFS_DIR}" \
    CI_QEMU_TIMEOUT="${CI_QEMU_TIMEOUT:-90}" \
    KERNEL_CMDLINE="${KERNEL_CMDLINE:-}" \
    "${SCRIPT_DIR}/qemu-smoke.sh" "$@"
