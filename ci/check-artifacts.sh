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

KERNEL_IMAGE="$(kernel_image_for_arch "${ARCH}" "${OUT_DIR}")"
INITRAMFS_IMAGE="${INITRAMFS_DIR}/initramfs.cpio.gz"

test -f "${KERNEL_IMAGE}"
test -f "${INITRAMFS_IMAGE}"

echo "Artifacts found:"
echo "  ${KERNEL_IMAGE}"
echo "  ${INITRAMFS_IMAGE}"
