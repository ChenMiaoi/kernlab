#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: build-kernel.sh [--menuconfig] [--force-defconfig]

Build a Linux kernel for QEMU.

Environment variables:
  LINUX_DIR       Linux source tree path (default: <repo>/linux)
  ARCH            Kernel arch: x86_64|arm|arm64|riscv (default: x86_64)
  OUT_DIR         Out-of-tree build dir (default: <repo>/out/<arch>)
  DEFCONFIG       Kconfig defconfig target (default: arch-specific)
  JOBS            Parallel jobs for make (default: nproc)
  KERNEL_TARGET   Kernel make target (default: arch-specific)
  CROSS_COMPILE   Toolchain prefix for cross build (optional, auto-detected)
  OBJCOPY         Objcopy binary override (optional, auto-detected for riscv)
  NM              Nm binary override (optional, auto-detected for riscv)
  LLVM            Use LLVM toolchain when set (optional)
EOF
}

MENUCONFIG=0
FORCE_DEFCONFIG=0

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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --menuconfig)
            MENUCONFIG=1
            shift
            ;;
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENSURE_DEPS_PY="${SCRIPT_DIR}/ensure-build-deps.py"

LINUX_DIR="${LINUX_DIR:-${REPO_DIR}/linux}"
ARCH="${ARCH:-x86_64}"
case "${ARCH}" in
    x86_64|amd64)
        ARCH="x86_64"
        DEFCONFIG_DEFAULT="defconfig"
        KERNEL_TARGET_DEFAULT="bzImage"
        KERNEL_IMAGE_REL="arch/x86/boot/bzImage"
        ;;
    arm|arm32)
        ARCH="arm"
        DEFCONFIG_DEFAULT="multi_v7_defconfig"
        KERNEL_TARGET_DEFAULT="zImage"
        KERNEL_IMAGE_REL="arch/arm/boot/zImage"
        ;;
    arm64|aarch64|aarch)
        ARCH="arm64"
        DEFCONFIG_DEFAULT="defconfig"
        KERNEL_TARGET_DEFAULT="Image"
        KERNEL_IMAGE_REL="arch/arm64/boot/Image"
        ;;
    riscv|riscv64)
        ARCH="riscv"
        DEFCONFIG_DEFAULT="defconfig"
        KERNEL_TARGET_DEFAULT="Image"
        KERNEL_IMAGE_REL="arch/riscv/boot/Image"
        ;;
    *)
        echo "Unsupported ARCH='${ARCH}'. Use x86_64|arm|arm64|riscv." >&2
        exit 1
        ;;
esac
OUT_DIR="${OUT_DIR:-${REPO_DIR}/out/${ARCH}}"
DEFCONFIG="${DEFCONFIG:-${DEFCONFIG_DEFAULT}}"
JOBS="${JOBS:-$(nproc)}"
KERNEL_TARGET="${KERNEL_TARGET:-${KERNEL_TARGET_DEFAULT}}"
LLVM="${LLVM:-}"
CROSS_COMPILE="${CROSS_COMPILE:-}"
OBJCOPY="${OBJCOPY:-}"
NM="${NM:-}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [[ ! -d "${LINUX_DIR}" ]]; then
    echo "Linux source tree not found: ${LINUX_DIR}" >&2
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
        --component kernel
        --arch "${ARCH}"
    )
    if [[ -n "${CROSS_COMPILE}" ]]; then
        ensure_args+=(--cross-compile "${CROSS_COMPILE}")
    fi
    if [[ -n "${LLVM}" ]]; then
        ensure_args+=(--llvm)
    fi
    if [[ "${MENUCONFIG}" -eq 1 ]]; then
        ensure_args+=(--menuconfig)
    fi

    "${PYTHON_BIN}" "${ensure_args[@]}"
fi

mkdir -p "${OUT_DIR}"

if [[ -z "${CROSS_COMPILE}" && -z "${LLVM}" ]]; then
    if auto_prefix="$(detect_cross_compile_prefix "${ARCH}")"; then
        CROSS_COMPILE="${auto_prefix}"
        echo "Auto-selected CROSS_COMPILE=${CROSS_COMPILE}"
    elif [[ "${ARCH}" != "x86_64" ]]; then
        echo "No cross compiler found for ARCH=${ARCH}." >&2
        echo "Set CROSS_COMPILE manually, or install a toolchain (for riscv: riscv64-linux-gnu-gcc)." >&2
        echo "Alternatively use LLVM=1 to build with clang." >&2
        exit 1
    fi
fi

if [[ "${ARCH}" == "riscv" && -z "${LLVM}" ]]; then
    # llvm-objcopy/nm understand newer RISC-V GNU properties and avoid noisy warnings.
    if [[ -z "${OBJCOPY}" ]] && command -v llvm-objcopy >/dev/null 2>&1; then
        OBJCOPY="llvm-objcopy"
    fi
    if [[ -z "${NM}" ]] && command -v llvm-nm >/dev/null 2>&1; then
        NM="llvm-nm"
    fi
fi

MAKE_ARGS=(-C "${LINUX_DIR}" O="${OUT_DIR}" ARCH="${ARCH}")
if [[ -n "${CROSS_COMPILE}" ]]; then
    MAKE_ARGS+=(CROSS_COMPILE="${CROSS_COMPILE}")
fi
if [[ -n "${OBJCOPY}" ]]; then
    MAKE_ARGS+=(OBJCOPY="${OBJCOPY}")
fi
if [[ -n "${NM}" ]]; then
    MAKE_ARGS+=(NM="${NM}")
fi
if [[ -n "${LLVM}" ]]; then
    MAKE_ARGS+=(LLVM="${LLVM}")
fi

run_make() {
    local -a env_cmd=(env)

    # Empty exported vars override kernel defaults (e.g. OBJCOPY ?= ...),
    # so drop them from the environment when they are blank.
    if [[ -z "${CROSS_COMPILE}" ]]; then
        env_cmd+=(-u CROSS_COMPILE)
    fi
    if [[ -z "${OBJCOPY}" ]]; then
        env_cmd+=(-u OBJCOPY)
    fi
    if [[ -z "${NM}" ]]; then
        env_cmd+=(-u NM)
    fi
    if [[ -z "${LLVM}" ]]; then
        env_cmd+=(-u LLVM)
    fi

    "${env_cmd[@]}" make "${MAKE_ARGS[@]}" "$@"
}

if [[ "${FORCE_DEFCONFIG}" -eq 1 || ! -f "${OUT_DIR}/.config" ]]; then
    run_make "${DEFCONFIG}"
else
    run_make olddefconfig
fi

if [[ "${MENUCONFIG}" -eq 1 ]]; then
    run_make menuconfig
fi

run_make -j"${JOBS}" "${KERNEL_TARGET}"

echo "Kernel built successfully:"
echo "  ${OUT_DIR}/${KERNEL_IMAGE_REL}"
