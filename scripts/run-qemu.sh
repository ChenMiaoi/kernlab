#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: run-qemu.sh [extra qemu args...]

Boot compiled kernel and initramfs in QEMU.

Environment variables:
  ARCH             Kernel arch: x86_64|arm|arm64|riscv (default: x86_64)
  OUT_DIR          Build output dir (default: <repo>/out/<arch>)
  KERNEL_IMAGE     Kernel image path (default: arch-specific)
  INITRAMFS_DIR    Initramfs dir (default: <repo>/out/initramfs/<arch>)
  INITRAMFS_IMAGE  Initramfs image path (default: <INITRAMFS_DIR>/initramfs.cpio.gz)
  QEMU_DIR         QEMU source tree path (default: <repo>/qemu)
  QEMU_BUILD_DIR   QEMU build dir (default: <repo>/out/qemu/<arch>)
  QEMU_BIN         QEMU binary override (default: build local qemu/<arch> binary)
  QEMU_MACHINE     QEMU machine type (default: arch-specific)
  QEMU_CPU         QEMU CPU model (default: arch-specific)
  QEMU_BIOS        QEMU bios/firmware (optional, riscv defaults to "default")
  MEMORY           Guest memory in MB (default: 2048)
  SMP              vCPU count (default: 2)
  KERNEL_CMDLINE   Kernel cmdline (default keeps verbose boot logs)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_QEMU_SH="${SCRIPT_DIR}/build-qemu.sh"

ARCH="${ARCH:-x86_64}"
case "${ARCH}" in
    x86_64|amd64)
        ARCH="x86_64"
        KERNEL_IMAGE_DEFAULT="arch/x86/boot/bzImage"
        QEMU_BIN_NAME_DEFAULT="qemu-system-x86_64"
        QEMU_MACHINE_DEFAULT="q35,accel=kvm:tcg"
        QEMU_CPU_DEFAULT="max"
        CONSOLE_DEFAULT="ttyS0,115200"
        QEMU_BIOS_DEFAULT=""
        ;;
    arm|arm32)
        ARCH="arm"
        KERNEL_IMAGE_DEFAULT="arch/arm/boot/zImage"
        QEMU_BIN_NAME_DEFAULT="qemu-system-arm"
        QEMU_MACHINE_DEFAULT="virt"
        QEMU_CPU_DEFAULT="cortex-a15"
        CONSOLE_DEFAULT="ttyAMA0"
        QEMU_BIOS_DEFAULT=""
        ;;
    arm64|aarch64|aarch)
        ARCH="arm64"
        KERNEL_IMAGE_DEFAULT="arch/arm64/boot/Image"
        QEMU_BIN_NAME_DEFAULT="qemu-system-aarch64"
        QEMU_MACHINE_DEFAULT="virt"
        QEMU_CPU_DEFAULT="max"
        CONSOLE_DEFAULT="ttyAMA0"
        QEMU_BIOS_DEFAULT=""
        ;;
    riscv|riscv64)
        ARCH="riscv"
        KERNEL_IMAGE_DEFAULT="arch/riscv/boot/Image"
        QEMU_BIN_NAME_DEFAULT="qemu-system-riscv64"
        QEMU_MACHINE_DEFAULT="virt"
        QEMU_CPU_DEFAULT="rv64"
        CONSOLE_DEFAULT="ttyS0"
        QEMU_BIOS_DEFAULT="default"
        ;;
    *)
        echo "Unsupported ARCH='${ARCH}'. Use x86_64|arm|arm64|riscv." >&2
        exit 1
        ;;
esac

OUT_DIR="${OUT_DIR:-${REPO_DIR}/out/${ARCH}}"
KERNEL_IMAGE="${KERNEL_IMAGE:-${OUT_DIR}/${KERNEL_IMAGE_DEFAULT}}"
INITRAMFS_DIR="${INITRAMFS_DIR:-${REPO_DIR}/out/initramfs/${ARCH}}"
INITRAMFS_IMAGE="${INITRAMFS_IMAGE:-${INITRAMFS_DIR}/initramfs.cpio.gz}"
QEMU_DIR="${QEMU_DIR:-${REPO_DIR}/qemu}"
QEMU_BUILD_DIR="${QEMU_BUILD_DIR:-${REPO_DIR}/out/qemu/${ARCH}}"
QEMU_BIN_INPUT="${QEMU_BIN:-}"
QEMU_BIN="${QEMU_BIN_INPUT:-${QEMU_BUILD_DIR}/${QEMU_BIN_NAME_DEFAULT}}"
QEMU_MACHINE="${QEMU_MACHINE:-${QEMU_MACHINE_DEFAULT}}"
QEMU_CPU="${QEMU_CPU:-${QEMU_CPU_DEFAULT}}"
QEMU_BIOS="${QEMU_BIOS:-${QEMU_BIOS_DEFAULT}}"
MEMORY="${MEMORY:-2048}"
SMP="${SMP:-2}"
KERNEL_CMDLINE="${KERNEL_CMDLINE:-console=${CONSOLE_DEFAULT} rdinit=/init loglevel=7 printk.time=1 panic=-1}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
JOBS="${JOBS:-$(nproc)}"

if [[ -z "${QEMU_BIN_INPUT}" && ! -x "${QEMU_BIN}" ]]; then
    ARCH="${ARCH}" QEMU_DIR="${QEMU_DIR}" QEMU_BUILD_DIR="${QEMU_BUILD_DIR}" \
        JOBS="${JOBS}" ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS:-1}" PYTHON_BIN="${PYTHON_BIN}" \
        "${BUILD_QEMU_SH}"
fi

if [[ -z "${QEMU_BIN}" || ! -x "${QEMU_BIN}" ]]; then
    echo "QEMU binary not found for ARCH=${ARCH}: ${QEMU_BIN}" >&2
    echo "Build it with ./scripts/build-qemu.sh, or override QEMU_BIN=/path/to/${QEMU_BIN_NAME_DEFAULT}." >&2
    exit 1
fi
if [[ ! -f "${KERNEL_IMAGE}" ]]; then
    echo "Kernel image not found: ${KERNEL_IMAGE}" >&2
    exit 1
fi
if [[ ! -f "${INITRAMFS_IMAGE}" ]]; then
    echo "Initramfs image not found: ${INITRAMFS_IMAGE}" >&2
    exit 1
fi

QEMU_CMD=(
    "${QEMU_BIN}"
    -machine "${QEMU_MACHINE}"
    -cpu "${QEMU_CPU}"
    -smp "${SMP}"
    -m "${MEMORY}"
    -kernel "${KERNEL_IMAGE}"
    -initrd "${INITRAMFS_IMAGE}"
    -append "${KERNEL_CMDLINE}"
    -nographic
    -no-reboot
)

if [[ -n "${QEMU_BIOS}" ]]; then
    QEMU_CMD+=(-bios "${QEMU_BIOS}")
fi

QEMU_CMD+=("$@")
exec "${QEMU_CMD[@]}"
