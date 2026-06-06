#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: build-initramfs.sh

Create a minimal initramfs with busybox.

Environment variables:
  ARCH            Target arch: x86_64|arm|arm64|riscv (default: x86_64)
  INITRAMFS_DIR   Initramfs output dir (default: <repo>/out/initramfs/<arch>)
  ROOTFS_DIR      Staging rootfs dir (default: <INITRAMFS_DIR>/rootfs)
  INITRAMFS_IMAGE Output archive path (default: <INITRAMFS_DIR>/initramfs.cpio.gz)
  BUSYBOX_BIN       Busybox binary path (default: auto-detect per ARCH)
  INITRAMFS_HOSTNAME Optional /etc/hostname content (default: none)
  INITRAMFS_BANNER   Boot banner printed by init scripts (default: == custom kernel booted ==)
  INITRAMFS_EXTRA_DIR Optional rootfs overlay copied before packing
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

detect_busybox_bin() {
    local arch="$1"
    local -a candidate_bins=()
    local candidate=""

    case "${arch}" in
        x86_64)
            candidate_bins=(
                "${REPO_DIR}/out/busybox/x86_64/busybox"
                "${REPO_DIR}/out/busybox/amd64/busybox"
                "busybox"
            )
            ;;
        arm)
            candidate_bins=(
                "${REPO_DIR}/out/busybox/arm/busybox"
                "${REPO_DIR}/out/busybox/arm32/busybox"
                "arm-linux-gnueabihf-busybox"
                "arm-linux-gnueabi-busybox"
                "/usr/arm-linux-gnueabihf/bin/busybox"
                "/usr/arm-linux-gnueabi/bin/busybox"
            )
            ;;
        arm64)
            candidate_bins=(
                "${REPO_DIR}/out/busybox/arm64/busybox"
                "${REPO_DIR}/out/busybox/aarch64/busybox"
                "${REPO_DIR}/out/busybox/aarch/busybox"
                "aarch64-linux-gnu-busybox"
                "/usr/aarch64-linux-gnu/bin/busybox"
            )
            ;;
        riscv)
            candidate_bins=(
                "${REPO_DIR}/out/busybox/riscv/busybox"
                "${REPO_DIR}/out/busybox/riscv64/busybox"
                "riscv64-linux-gnu-busybox"
                "riscv64-unknown-linux-gnu-busybox"
                "/usr/riscv64-linux-gnu/bin/busybox"
                "/usr/riscv64-unknown-linux-gnu/bin/busybox"
            )
            ;;
        *)
            return 1
            ;;
    esac

    for candidate in "${candidate_bins[@]}"; do
        if [[ "${candidate}" == */* ]]; then
            if [[ -x "${candidate}" ]]; then
                printf '%s\n' "${candidate}"
                return 0
            fi
        elif resolved="$(command -v "${candidate}" 2>/dev/null)"; then
            if [[ -x "${resolved}" ]]; then
                printf '%s\n' "${resolved}"
                return 0
            fi
        fi
    done

    return 1
}

copy_into_rootfs() {
    local src="$1"
    local dst="${ROOTFS_DIR}${src}"
    mkdir -p "$(dirname "${dst}")"
    cp -L "${src}" "${dst}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENSURE_DEPS_PY="${SCRIPT_DIR}/ensure-build-deps.py"

ARCH_RAW="${ARCH:-x86_64}"
if ! ARCH="$(normalize_arch "${ARCH_RAW}")"; then
    echo "Unsupported ARCH='${ARCH_RAW}'. Use x86_64|arm|arm64|riscv." >&2
    exit 1
fi

INITRAMFS_DIR="${INITRAMFS_DIR:-${REPO_DIR}/out/initramfs/${ARCH}}"
ROOTFS_DIR="${ROOTFS_DIR:-${INITRAMFS_DIR}/rootfs}"
INITRAMFS_IMAGE="${INITRAMFS_IMAGE:-${INITRAMFS_DIR}/initramfs.cpio.gz}"
BUSYBOX_BIN="${BUSYBOX_BIN:-}"
INITRAMFS_HOSTNAME="${INITRAMFS_HOSTNAME:-}"
INITRAMFS_BANNER="${INITRAMFS_BANNER:-== custom kernel booted ==}"
INITRAMFS_EXTRA_DIR="${INITRAMFS_EXTRA_DIR:-}"
HOST_ARCH="$(normalize_arch "$(uname -m)" 2>/dev/null || true)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [[ -n "${INITRAMFS_EXTRA_DIR}" && ! -d "${INITRAMFS_EXTRA_DIR}" ]]; then
    echo "INITRAMFS_EXTRA_DIR does not exist or is not a directory: ${INITRAMFS_EXTRA_DIR}" >&2
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
        --component initramfs
        --arch "${ARCH}"
    )

    "${PYTHON_BIN}" "${ensure_args[@]}"
fi

if [[ -z "${BUSYBOX_BIN}" ]]; then
    BUSYBOX_BIN="$(detect_busybox_bin "${ARCH}" || true)"
fi

require_cmd cpio
require_cmd gzip
require_cmd readelf
require_cmd file

if [[ -z "${BUSYBOX_BIN}" || ! -x "${BUSYBOX_BIN}" ]]; then
    echo "No busybox found for ARCH=${ARCH}." >&2
    echo "Set BUSYBOX_BIN=/path/to/<target-arch>-busybox and retry." >&2
    if [[ "${ARCH}" != "x86_64" ]]; then
        echo "For cross-arch boot, use a static busybox built for ${ARCH}." >&2
    fi
    exit 1
fi

EXPECTED_MACHINE="$(expected_machine_for_arch "${ARCH}")"
ACTUAL_MACHINE="$(elf_machine "${BUSYBOX_BIN}" || true)"
if [[ -z "${ACTUAL_MACHINE}" || "${ACTUAL_MACHINE}" != "${EXPECTED_MACHINE}" ]]; then
    echo "Busybox architecture mismatch." >&2
    echo "  ARCH=${ARCH} expects ELF machine: ${EXPECTED_MACHINE}" >&2
    echo "  BUSYBOX_BIN=${BUSYBOX_BIN} has: ${ACTUAL_MACHINE:-unknown}" >&2
    echo "Provide a busybox binary built for ARCH=${ARCH}." >&2
    exit 1
fi

if [[ "${ARCH}" != "${HOST_ARCH}" ]] && ! is_static_elf "${BUSYBOX_BIN}"; then
    echo "Cross-arch busybox must be static to avoid missing runtime loader/libs in initramfs." >&2
    echo "  ARCH=${ARCH} HOST_ARCH=${HOST_ARCH:-unknown}" >&2
    echo "  BUSYBOX_BIN=${BUSYBOX_BIN}" >&2
    echo "Please use a statically linked busybox for ARCH=${ARCH}." >&2
    exit 1
fi


rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"/{bin,sbin,etc/init.d,proc,sys,dev,tmp,usr/bin,usr/sbin,run}

cp -L "${BUSYBOX_BIN}" "${ROOTFS_DIR}/bin/busybox"
chmod 0755 "${ROOTFS_DIR}/bin/busybox"

for applet in sh mount umount cat echo ls dmesg poweroff reboot uname setsid cttyhack hostname; do
    ln -sf /bin/busybox "${ROOTFS_DIR}/bin/${applet}"
done
ln -sf /bin/busybox "${ROOTFS_DIR}/sbin/init"

if [[ -n "${INITRAMFS_HOSTNAME}" ]]; then
    printf '%s\n' "${INITRAMFS_HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
fi
printf '%s\n' "${INITRAMFS_BANNER}" > "${ROOTFS_DIR}/etc/banner"


cat > "${ROOTFS_DIR}/etc/inittab" <<'EOF'
::sysinit:/etc/init.d/rcS
::respawn:/etc/init.d/console-login
::ctrlaltdel:/bin/reboot -f
::shutdown:/bin/umount -a -r
EOF

cat > "${ROOTFS_DIR}/etc/init.d/console-login" <<'EOF'
#!/bin/sh
set -eu

# Use cttyhack when available; otherwise fall back to plain sh.
if /bin/cttyhack --help >/dev/null 2>&1; then
    exec /bin/cttyhack /bin/sh
fi

exec /bin/sh
EOF
chmod 0755 "${ROOTFS_DIR}/etc/init.d/console-login"

{
    cat <<'EOF'
#!/bin/sh
set -eu

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

EOF
    if [[ -n "${INITRAMFS_HOSTNAME}" ]]; then
        cat <<'EOF'
if [ -r /etc/hostname ] && command -v hostname >/dev/null 2>&1; then
    hostname "$(cat /etc/hostname)"
fi

EOF
    fi
    printf '%s\n' 'cat /etc/banner'
    cat <<'EOF'
echo "kernel: $(uname -a)"
echo "console: /dev/console"
echo "type 'reboot -f' to quit QEMU"
EOF
} > "${ROOTFS_DIR}/etc/init.d/rcS"
chmod 0755 "${ROOTFS_DIR}/etc/init.d/rcS"

{
    cat <<'EOF'
#!/bin/sh
set -eu

# Prefer busybox init so we get a persistent console.
if /sbin/init --help >/dev/null 2>&1; then
    exec /sbin/init
fi

mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

EOF
    if [[ -n "${INITRAMFS_HOSTNAME}" ]]; then
        cat <<'EOF'
if [ -r /etc/hostname ] && command -v hostname >/dev/null 2>&1; then
    hostname "$(cat /etc/hostname)"
fi

EOF
    fi
    printf '%s\n' 'cat /etc/banner'
    cat <<'EOF'
echo "kernel: $(uname -a)"
echo "type 'reboot -f' to quit QEMU"

# cttyhack gives /bin/sh a controlling TTY so job control works.
if command -v setsid >/dev/null 2>&1 && command -v cttyhack >/dev/null 2>&1; then
    exec setsid cttyhack /bin/sh
fi

exec /bin/sh </dev/console >/dev/console 2>&1
EOF
} > "${ROOTFS_DIR}/init"
chmod 0755 "${ROOTFS_DIR}/init"

if ! is_static_elf "${BUSYBOX_BIN}"; then
    require_cmd ldd
    LDD_OUT="$(mktemp)"
    trap 'rm -f "${LDD_OUT}"' EXIT

    ldd "${BUSYBOX_BIN}" >"${LDD_OUT}" 2>/dev/null || true
    if ! grep -q "not a dynamic executable" "${LDD_OUT}" 2>/dev/null; then
        while IFS= read -r line; do
            # Extract the first absolute path token, covering both:
            #   libm.so.6 => /lib64/libm.so.6 (...)
            #   /lib64/ld-linux-x86-64.so.2 (...)
            lib_path="$(awk '{for (i = 1; i <= NF; i++) if ($i ~ /^\//) {print $i; exit}}' <<<"${line}")"

            if [[ -n "${lib_path}" && -f "${lib_path}" ]]; then
                copy_into_rootfs "${lib_path}"
            fi
        done < "${LDD_OUT}"
    fi
fi
if [[ -n "${INITRAMFS_EXTRA_DIR}" ]]; then
    cp -a "${INITRAMFS_EXTRA_DIR}/." "${ROOTFS_DIR}/"
fi


mkdir -p "$(dirname "${INITRAMFS_IMAGE}")"
(
    cd "${ROOTFS_DIR}"
    find . -print0 \
      | cpio --null -o --format=newc 2>/dev/null \
      | gzip -9 > "${INITRAMFS_IMAGE}"
)

echo "Initramfs built successfully:"
echo "  ${INITRAMFS_IMAGE}"
