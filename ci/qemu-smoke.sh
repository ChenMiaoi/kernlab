#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_QEMU_SH="${REPO_DIR}/scripts/run-qemu.sh"

# shellcheck source=ci/lib.sh
source "${SCRIPT_DIR}/lib.sh"

ARCH_RAW="${ARCH:-x86_64}"
if ! ARCH="$(normalize_arch "${ARCH_RAW}")"; then
    echo "Unsupported ARCH='${ARCH_RAW}'. Use x86_64|arm|arm64|riscv." >&2
    exit 1
fi

OUT_DIR="${OUT_DIR:-${REPO_DIR}/out/${ARCH}}"
INITRAMFS_DIR="${INITRAMFS_DIR:-${REPO_DIR}/out/initramfs/${ARCH}}"
CI_QEMU_TIMEOUT="${CI_QEMU_TIMEOUT:-90}"

CONSOLE="$(console_for_arch "${ARCH}")"
KERNEL_CMDLINE="${KERNEL_CMDLINE:-console=${CONSOLE} rdinit=/init loglevel=7 printk.time=1 panic=1}"

LOG_DIR="${REPO_DIR}/out/ci"
LOG_FILE="${LOG_DIR}/qemu-${ARCH}.log"
mkdir -p "${LOG_DIR}"
rm -f "${LOG_FILE}"

qemu_rc=0
ARCH="${ARCH}" OUT_DIR="${OUT_DIR}" INITRAMFS_DIR="${INITRAMFS_DIR}" KERNEL_CMDLINE="${KERNEL_CMDLINE}" \
    timeout "${CI_QEMU_TIMEOUT}" "${RUN_QEMU_SH}" "$@" >"${LOG_FILE}" 2>&1 || qemu_rc=$?

if [[ "${qemu_rc}" -ne 0 && "${qemu_rc}" -ne 124 ]]; then
    echo "QEMU run failed. Output:" >&2
    cat "${LOG_FILE}" >&2
    exit 1
fi

if ! grep -Fq "== custom kernel booted ==" "${LOG_FILE}"; then
    echo "QEMU boot marker not found. Output:" >&2
    cat "${LOG_FILE}" >&2
    exit 1
fi

echo "QEMU smoke run passed (boot marker found)."
echo "Log: ${LOG_FILE}"
