#!/usr/bin/env bash
set -euo pipefail

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

kernel_image_for_arch() {
    local arch="$1"
    local out_dir="$2"

    case "${arch}" in
        x86_64)
            echo "${out_dir}/arch/x86/boot/bzImage"
            ;;
        arm)
            echo "${out_dir}/arch/arm/boot/zImage"
            ;;
        arm64)
            echo "${out_dir}/arch/arm64/boot/Image"
            ;;
        riscv)
            echo "${out_dir}/arch/riscv/boot/Image"
            ;;
        *)
            return 1
            ;;
    esac
}

console_for_arch() {
    case "$1" in
        x86_64)
            echo "ttyS0,115200"
            ;;
        arm|arm64)
            echo "ttyAMA0"
            ;;
        riscv)
            echo "ttyS0"
            ;;
        *)
            return 1
            ;;
    esac
}
