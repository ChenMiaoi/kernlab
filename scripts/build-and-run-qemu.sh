#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

if [[ -z "${BUSYBOX_BIN:-}" && "${ARCH_NORM}" != "x86_64" ]]; then
    BUSYBOX_OUT_DIR="${BUSYBOX_OUT_DIR:-${REPO_DIR}/out/busybox/${ARCH_NORM}}"
    ARCH="${ARCH_NORM}" BUSYBOX_OUT_DIR="${BUSYBOX_OUT_DIR}" "${SCRIPT_DIR}/build-busybox.sh"
    BUSYBOX_BIN="${BUSYBOX_OUT_DIR}/busybox"
    export BUSYBOX_BIN
fi

"${SCRIPT_DIR}/build-kernel.sh"
"${SCRIPT_DIR}/build-initramfs.sh"
exec "${SCRIPT_DIR}/run-qemu.sh" "$@"
