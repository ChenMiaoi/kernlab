#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: build-busybox.sh [--force-defconfig]

Build busybox from local source tree (static for cross-arch by default).

Environment variables:
  BUSYBOX_DIR      Busybox source dir (default: <repo>/busybox)
  ARCH             Target arch: x86_64|arm|arm64|riscv (default: x86_64)
  BUSYBOX_OUT_DIR  Busybox out dir (default: <repo>/out/busybox/<arch>)
  CROSS_COMPILE    Toolchain prefix for cross build (optional, auto-detected)
  JOBS             Parallel jobs (default: nproc)
  BUSYBOX_CONFIG_MODE  initramfs_minimal|defconfig (default: initramfs_minimal)
  BUSYBOX_STATIC   Build static busybox: auto|1|0 (default: auto)
EOF
}

FORCE_DEFCONFIG=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force-defconfig)
            FORCE_DEFCONFIG=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

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

detect_cross_compile_prefix() {
    local arch="$1"
    local -a candidates=()

    case "${arch}" in
        arm)
            candidates=(
                "arm-linux-gnueabihf-"
                "arm-linux-gnueabi-"
                "arm-none-linux-gnueabihf-"
            )
            ;;
        arm64)
            candidates=(
                "aarch64-linux-gnu-"
                "aarch64-none-linux-gnu-"
            )
            ;;
        riscv)
            candidates=(
                "riscv64-linux-gnu-"
                "riscv64-unknown-linux-gnu-"
            )
            ;;
        *)
            return 1
            ;;
    esac

    local prefix
    for prefix in "${candidates[@]}"; do
        if command -v "${prefix}gcc" >/dev/null 2>&1; then
            printf '%s\n' "${prefix}"
            return 0
        fi
    done
    return 1
}

set_kconfig_option() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    local tmp_file

    tmp_file="$(mktemp "${config_file}.XXXXXX")"
    awk -v key="${key}" -v value="${value}" '
        BEGIN { updated = 0 }
        $0 ~ ("^" key "=") {
            print key "=" value
            updated = 1
            next
        }
        $0 ~ ("^# " key " is not set$") {
            print key "=" value
            updated = 1
            next
        }
        { print }
        END {
            if (!updated) {
                print key "=" value
            }
        }
    ' "${config_file}" > "${tmp_file}"
    mv "${tmp_file}" "${config_file}"
}

set_busybox_minimal_initramfs_config() {
    local config_file="$1"
    local -a enable_opts=(
        "CONFIG_SH_IS_ASH"
        "CONFIG_BASH_IS_NONE"
        "CONFIG_ASH"
        "CONFIG_ASH_OPTIMIZE_FOR_SIZE"
        "CONFIG_MOUNT"
        "CONFIG_UMOUNT"
        "CONFIG_CAT"
        "CONFIG_ECHO"
        "CONFIG_LS"
        "CONFIG_DMESG"
        "CONFIG_POWEROFF"
        "CONFIG_REBOOT"
        "CONFIG_UNAME"
        "CONFIG_SETSID"
        "CONFIG_CTTYHACK"
    )

    local opt
    for opt in "${enable_opts[@]}"; do
        set_kconfig_option "${config_file}" "${opt}" "y"
    done
}

expected_machine_for_arch() {
    case "$1" in
        x86_64) echo "Advanced Micro Devices X86-64" ;;
        arm) echo "ARM" ;;
        arm64) echo "AArch64" ;;
        riscv) echo "RISC-V" ;;
        *) return 1 ;;
    esac
}

elf_machine() {
    local bin="$1"
    readelf -h "${bin}" 2>/dev/null \
        | awk -F: '/Machine:/{gsub(/^[ \t]+/, "", $2); print $2; exit}'
}

is_static_elf() {
    local bin="$1"
    file "${bin}" | grep -q "statically linked"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARCH_RAW="${ARCH:-x86_64}"
if ! ARCH="$(normalize_arch "${ARCH_RAW}")"; then
    echo "Unsupported ARCH='${ARCH_RAW}'. Use x86_64|arm|arm64|riscv." >&2
    exit 1
fi

BUSYBOX_DIR="${BUSYBOX_DIR:-${REPO_DIR}/busybox}"
BUSYBOX_OUT_DIR="${BUSYBOX_OUT_DIR:-${REPO_DIR}/out/busybox/${ARCH}}"
JOBS="${JOBS:-$(nproc)}"
BUSYBOX_CONFIG_MODE="${BUSYBOX_CONFIG_MODE:-initramfs_minimal}"
BUSYBOX_STATIC="${BUSYBOX_STATIC:-auto}"
CROSS_COMPILE="${CROSS_COMPILE:-}"
HOST_ARCH="$(normalize_arch "$(uname -m)" 2>/dev/null || true)"

if [[ "${BUSYBOX_STATIC}" == "auto" ]]; then
    if [[ "${ARCH}" == "${HOST_ARCH}" ]]; then
        BUSYBOX_STATIC="0"
    else
        BUSYBOX_STATIC="1"
    fi
fi
if [[ "${BUSYBOX_STATIC}" != "0" && "${BUSYBOX_STATIC}" != "1" ]]; then
    echo "Invalid BUSYBOX_STATIC='${BUSYBOX_STATIC}'. Use auto|1|0." >&2
    exit 1
fi

require_cmd make
require_cmd readelf
require_cmd file

if [[ ! -f "${BUSYBOX_DIR}/Makefile" || ! -f "${BUSYBOX_DIR}/Config.in" ]]; then
    echo "Busybox source tree not found or incomplete: ${BUSYBOX_DIR}" >&2
    exit 1
fi

if [[ -f "${BUSYBOX_DIR}/.config" ]]; then
    echo "Busybox source tree is not clean: ${BUSYBOX_DIR}/.config exists." >&2
    echo "Run 'make -C ${BUSYBOX_DIR} mrproper' (or remove .config) and retry." >&2
    exit 1
fi

if [[ -z "${CROSS_COMPILE}" && "${ARCH}" != "${HOST_ARCH}" ]]; then
    if auto_prefix="$(detect_cross_compile_prefix "${ARCH}")"; then
        CROSS_COMPILE="${auto_prefix}"
        echo "Auto-selected CROSS_COMPILE=${CROSS_COMPILE}"
    else
        echo "No cross compiler found for ARCH=${ARCH}." >&2
        echo "Set CROSS_COMPILE manually (for riscv: riscv64-linux-gnu-)." >&2
        exit 1
    fi
fi

mkdir -p "${BUSYBOX_OUT_DIR}"

MAKE_ARGS=(
    -C "${BUSYBOX_DIR}"
    O="${BUSYBOX_OUT_DIR}"
    ARCH="${ARCH}"
)
if [[ -n "${CROSS_COMPILE}" ]]; then
    MAKE_ARGS+=(CROSS_COMPILE="${CROSS_COMPILE}")
fi

export CCACHE_DISABLE="${CCACHE_DISABLE:-1}"

case "${BUSYBOX_CONFIG_MODE}" in
    initramfs_minimal|minimal)
        # Rebuild from allnoconfig each time to keep deterministic minimal applet set.
        make "${MAKE_ARGS[@]}" allnoconfig >/dev/null
        set_busybox_minimal_initramfs_config "${BUSYBOX_OUT_DIR}/.config"
        ;;
    defconfig)
        if [[ "${FORCE_DEFCONFIG}" -eq 1 || ! -f "${BUSYBOX_OUT_DIR}/.config" ]]; then
            make "${MAKE_ARGS[@]}" defconfig >/dev/null
        fi
        ;;
    *)
        echo "Unsupported BUSYBOX_CONFIG_MODE='${BUSYBOX_CONFIG_MODE}'." >&2
        echo "Use initramfs_minimal|defconfig." >&2
        exit 1
        ;;
esac

if [[ "${BUSYBOX_STATIC}" == "1" ]]; then
    set_kconfig_option "${BUSYBOX_OUT_DIR}/.config" "CONFIG_STATIC" "y"
    set_kconfig_option "${BUSYBOX_OUT_DIR}/.config" "CONFIG_STATIC_LIBGCC" "y"
fi

make "${MAKE_ARGS[@]}" silentoldconfig

BUILD_LOG="$(mktemp)"
trap 'rm -f "${BUILD_LOG}"' EXIT
if ! (make "${MAKE_ARGS[@]}" -j"${JOBS}" busybox 2>&1 | tee "${BUILD_LOG}"); then
    if grep -q "byteswap.h: No such file or directory" "${BUILD_LOG}"; then
        echo "Busybox build failed: missing target libc headers for ${ARCH} toolchain." >&2
        echo "Install cross libc dev package, then retry." >&2
    elif grep -q "cannot find -lm" "${BUILD_LOG}"; then
        echo "Busybox static build failed: missing static libc/libm for toolchain." >&2
        echo "Install static libc development package, or set BUSYBOX_STATIC=0." >&2
    fi
    exit 1
fi

BUSYBOX_BIN="${BUSYBOX_OUT_DIR}/busybox"
if [[ ! -x "${BUSYBOX_BIN}" ]]; then
    echo "Build completed but busybox binary not found: ${BUSYBOX_BIN}" >&2
    exit 1
fi

EXPECTED_MACHINE="$(expected_machine_for_arch "${ARCH}")"
ACTUAL_MACHINE="$(elf_machine "${BUSYBOX_BIN}" || true)"
if [[ -z "${ACTUAL_MACHINE}" || "${ACTUAL_MACHINE}" != "${EXPECTED_MACHINE}" ]]; then
    echo "Built busybox architecture mismatch." >&2
    echo "  ARCH=${ARCH} expects: ${EXPECTED_MACHINE}" >&2
    echo "  built binary has: ${ACTUAL_MACHINE:-unknown}" >&2
    exit 1
fi

if [[ "${BUSYBOX_STATIC}" == "1" ]] && ! is_static_elf "${BUSYBOX_BIN}"; then
    echo "Expected static busybox, but built binary is dynamic: ${BUSYBOX_BIN}" >&2
    exit 1
fi

echo "Busybox built successfully:"
echo "  ${BUSYBOX_BIN}"
