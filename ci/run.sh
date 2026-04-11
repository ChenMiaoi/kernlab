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

MAKE_ARGS=(
    -C "${REPO_DIR}"
    --no-print-directory
    all
    ARCH="${ARCH}"
    OUT_DIR="${OUT_DIR}"
    INITRAMFS_DIR="${INITRAMFS_DIR}"
    JOBS="${JOBS}"
)
if [[ -n "${CROSS_COMPILE:-}" ]]; then
    MAKE_ARGS+=(CROSS_COMPILE="${CROSS_COMPILE}")
fi
if [[ -n "${OBJCOPY:-}" ]]; then
    MAKE_ARGS+=(OBJCOPY="${OBJCOPY}")
fi
if [[ -n "${NM:-}" ]]; then
    MAKE_ARGS+=(NM="${NM}")
fi
if [[ -n "${LLVM:-}" ]]; then
    MAKE_ARGS+=(LLVM="${LLVM}")
fi
if [[ -n "${BUSYBOX_BIN:-}" ]]; then
    MAKE_ARGS+=(BUSYBOX_BIN="${BUSYBOX_BIN}")
fi
if [[ -n "${BUSYBOX_DIR:-}" ]]; then
    MAKE_ARGS+=(BUSYBOX_DIR="${BUSYBOX_DIR}")
fi
if [[ -n "${BUSYBOX_OUT_DIR:-}" ]]; then
    MAKE_ARGS+=(BUSYBOX_OUT_DIR="${BUSYBOX_OUT_DIR}")
fi
if [[ -n "${BUSYBOX_STATIC:-}" ]]; then
    MAKE_ARGS+=(BUSYBOX_STATIC="${BUSYBOX_STATIC}")
fi

make "${MAKE_ARGS[@]}"

ARCH="${ARCH}" OUT_DIR="${OUT_DIR}" INITRAMFS_DIR="${INITRAMFS_DIR}" \
    "${SCRIPT_DIR}/check-artifacts.sh"

ARCH="${ARCH}" OUT_DIR="${OUT_DIR}" INITRAMFS_DIR="${INITRAMFS_DIR}" \
    CI_QEMU_TIMEOUT="${CI_QEMU_TIMEOUT:-300}" \
    KERNEL_CMDLINE="${KERNEL_CMDLINE:-}" \
    "${SCRIPT_DIR}/qemu-smoke.sh" "$@"
