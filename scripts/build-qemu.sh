#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: build-qemu.sh

Build the local QEMU submodule for the selected ARCH.

Environment variables:
  QEMU_DIR         QEMU source tree path (default: <repo>/qemu)
  ARCH             Target arch: x86_64|arm|arm64|riscv (default: x86_64)
  QEMU_BUILD_DIR   QEMU build dir (default: <repo>/out/qemu/<arch>)
  QEMU_TARGET_LIST QEMU --target-list override (default: arch-specific softmmu)
  JOBS             Parallel jobs (default: nproc)
  PYTHON_BIN       Python interpreter for dependency checks (default: python3)
  NINJA_BIN        Ninja binary (default: ninja)
  QEMU_CONFIGURE_ARGS
                   Extra flags appended to QEMU ./configure
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

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

default_qemu_target_list() {
    case "$1" in
        x86_64) echo "x86_64-softmmu" ;;
        arm) echo "arm-softmmu" ;;
        arm64) echo "aarch64-softmmu" ;;
        riscv) echo "riscv64-softmmu" ;;
        *) return 1 ;;
    esac
}

qemu_binary_name_for_arch() {
    case "$1" in
        x86_64) echo "qemu-system-x86_64" ;;
        arm) echo "qemu-system-arm" ;;
        arm64) echo "qemu-system-aarch64" ;;
        riscv) echo "qemu-system-riscv64" ;;
        *) return 1 ;;
    esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENSURE_DEPS_PY="${SCRIPT_DIR}/ensure-build-deps.py"

ARCH_RAW="${ARCH:-x86_64}"
if ! ARCH="$(normalize_arch "${ARCH_RAW}")"; then
    echo "Unsupported ARCH='${ARCH_RAW}'. Use x86_64|arm|arm64|riscv." >&2
    exit 1
fi

QEMU_DIR="${QEMU_DIR:-${REPO_DIR}/qemu}"
QEMU_BUILD_DIR="${QEMU_BUILD_DIR:-${REPO_DIR}/out/qemu/${ARCH}}"
QEMU_TARGET_LIST="${QEMU_TARGET_LIST:-$(default_qemu_target_list "${ARCH}")}"
QEMU_BIN_NAME="$(qemu_binary_name_for_arch "${ARCH}")"
QEMU_BIN="${QEMU_BUILD_DIR}/${QEMU_BIN_NAME}"
JOBS="${JOBS:-$(nproc)}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
NINJA_BIN="${NINJA_BIN:-ninja}"
CONFIGURE_BIN="${QEMU_DIR}/configure"

if [[ ! -f "${CONFIGURE_BIN}" ]]; then
    echo "QEMU source tree not found or incomplete: ${QEMU_DIR}" >&2
    echo "Run 'git submodule update --init --recursive --depth 1 qemu' and retry." >&2
    exit 1
fi

if [[ "${ENSURE_BUILD_DEPS:-1}" != "0" ]]; then
    if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
        echo "Missing required command: ${PYTHON_BIN}" >&2
        echo "Install Python 3, or set ENSURE_BUILD_DEPS=0 to skip automatic dependency preparation." >&2
        exit 1
    fi

    ensure_args=(
        "${ENSURE_DEPS_PY}"
        --component qemu
        --arch "${ARCH}"
    )

    "${PYTHON_BIN}" "${ensure_args[@]}"
fi

require_cmd "${NINJA_BIN}"

mkdir -p "${QEMU_BUILD_DIR}"

TARGET_STAMP="${QEMU_BUILD_DIR}/.qemu-target-list"
SOURCE_STAMP="${QEMU_BUILD_DIR}/.qemu-source-dir"
need_configure=0

if [[ ! -f "${QEMU_BUILD_DIR}/build.ninja" ]]; then
    need_configure=1
elif [[ ! -f "${TARGET_STAMP}" || "$(cat "${TARGET_STAMP}")" != "${QEMU_TARGET_LIST}" ]]; then
    need_configure=1
elif [[ ! -f "${SOURCE_STAMP}" || "$(cat "${SOURCE_STAMP}")" != "${QEMU_DIR}" ]]; then
    need_configure=1
fi

if [[ "${need_configure}" -eq 1 ]]; then
    configure_args=(
        "${CONFIGURE_BIN}"
        "--target-list=${QEMU_TARGET_LIST}"
        "--disable-docs"
        "--enable-download"
        "--disable-werror"
    )

    if [[ -n "${QEMU_CONFIGURE_ARGS:-}" ]]; then
        read -r -a extra_configure_args <<<"${QEMU_CONFIGURE_ARGS}"
        configure_args+=("${extra_configure_args[@]}")
    fi

    (
        cd "${QEMU_BUILD_DIR}"
        "${configure_args[@]}"
    )

    printf '%s\n' "${QEMU_TARGET_LIST}" > "${TARGET_STAMP}"
    printf '%s\n' "${QEMU_DIR}" > "${SOURCE_STAMP}"
fi

"${NINJA_BIN}" -C "${QEMU_BUILD_DIR}" -j"${JOBS}" "${QEMU_BIN_NAME}"

if [[ ! -x "${QEMU_BIN}" ]]; then
    echo "QEMU build completed but binary not found: ${QEMU_BIN}" >&2
    exit 1
fi

echo "QEMU built successfully:"
echo "  ${QEMU_BIN}"
