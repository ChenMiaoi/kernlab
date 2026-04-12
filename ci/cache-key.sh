#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: cache-key.sh <toolchain|build|qemu>

Print a stable SHA-256 cache key fragment for the requested CI cache domain.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 1
fi

git_object_id() {
    git -C "${REPO_DIR}" rev-parse "HEAD:$1"
}

submodule_rev() {
    git -C "${REPO_DIR}/$1" rev-parse HEAD
}

tool_line() {
    local cmd="$1"
    local label="${2:-$1}"
    local line=""

    if ! command -v "${cmd}" >/dev/null 2>&1; then
        printf '%s=missing\n' "${label}"
        return
    fi

    line="$("${cmd}" --version 2>&1 | sed -n '1p' || true)"
    if [[ -z "${line}" ]]; then
        line="$("${cmd}" -version 2>&1 | sed -n '1p' || true)"
    fi

    printf '%s=%s\n' "${label}" "${line:-unknown}"
}

sha256_stream() {
    sha256sum | awk '{print $1}'
}

toolchain_fingerprint() {
    tool_line clang
    tool_line ld.lld lld
    tool_line gcc
    tool_line cc
    tool_line ninja
    tool_line python3
    tool_line make
}

build_fingerprint() {
    printf 'makefile=%s\n' "$(git_object_id Makefile)"
    printf 'ci-makefile=%s\n' "$(git_object_id ci/Makefile)"
    printf 'ci-run=%s\n' "$(git_object_id ci/run.sh)"
    printf 'ci-check-artifacts=%s\n' "$(git_object_id ci/check-artifacts.sh)"
    printf 'build-kernel=%s\n' "$(git_object_id scripts/build-kernel.sh)"
    printf 'build-busybox=%s\n' "$(git_object_id scripts/build-busybox.sh)"
    printf 'build-initramfs=%s\n' "$(git_object_id scripts/build-initramfs.sh)"
    printf 'linux=%s\n' "$(submodule_rev linux)"
    printf 'busybox=%s\n' "$(submodule_rev busybox)"
}

qemu_fingerprint() {
    printf 'makefile=%s\n' "$(git_object_id Makefile)"
    printf 'ci-makefile=%s\n' "$(git_object_id ci/Makefile)"
    printf 'ci-qemu-smoke=%s\n' "$(git_object_id ci/qemu-smoke.sh)"
    printf 'build-qemu=%s\n' "$(git_object_id scripts/build-qemu.sh)"
    printf 'run-qemu=%s\n' "$(git_object_id scripts/run-qemu.sh)"
    printf 'qemu=%s\n' "$(submodule_rev qemu)"
}

case "$1" in
    toolchain)
        toolchain_fingerprint | sha256_stream
        ;;
    build)
        build_fingerprint | sha256_stream
        ;;
    qemu)
        qemu_fingerprint | sha256_stream
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
