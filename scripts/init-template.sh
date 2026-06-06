#!/usr/bin/env bash
set -euo pipefail

DEFAULT_SUBMODULES="linux busybox qemu"

usage() {
    cat <<EOF
Usage: init-template.sh

Prepare an existing kernlab checkout for 'make run'. Safe to run repeatedly.

Environment variables:
  REPO_DIR          Repository root override (default: parent of this script)
  SUBMODULE_DEPTH   Submodule clone depth; set to 0 or empty for full history (default: 1)
  SUBMODULES        Space-separated submodules to initialize (default: ${DEFAULT_SUBMODULES})
                    Set to empty to skip submodule updates.
  ENSURE_BUILD_DEPS Set to 1 to run scripts/ensure-build-deps.py explicitly (default: 0)
  PYTHON_BIN        Python interpreter for dependency preparation (default: python3)

Examples:
  ./scripts/init-template.sh
  make init
  SUBMODULES="linux busybox" ./scripts/init-template.sh
  SUBMODULE_DEPTH=0 ./scripts/init-template.sh
  ENSURE_BUILD_DEPS=1 ./scripts/init-template.sh
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
SUBMODULE_DEPTH="${SUBMODULE_DEPTH-1}"
SUBMODULES="${SUBMODULES-${DEFAULT_SUBMODULES}}"
ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS:-0}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [[ ! -d "${REPO_DIR}" ]]; then
    echo "Repository directory does not exist: ${REPO_DIR}" >&2
    exit 1
fi

if [[ ! -f "${REPO_DIR}/qemu-linux.mk" || ! -f "${REPO_DIR}/.gitmodules" ]]; then
    echo "Not a kernlab repository root: ${REPO_DIR}" >&2
    echo "Set REPO_DIR to the checkout root and retry." >&2
    exit 1
fi

require_cmd git

if [[ "${ENSURE_BUILD_DEPS}" == "1" ]]; then
    require_cmd "${PYTHON_BIN}"
    "${PYTHON_BIN}" "${REPO_DIR}/scripts/ensure-build-deps.py" \
        --component kernel \
        --component busybox \
        --component initramfs \
        --component qemu \
        --llvm \
        --kernel-debug
elif [[ "${ENSURE_BUILD_DEPS}" != "0" ]]; then
    echo "ENSURE_BUILD_DEPS must be 0 or 1; got '${ENSURE_BUILD_DEPS}'." >&2
    exit 1
fi

cd "${REPO_DIR}"

git submodule sync --recursive

if [[ -n "${SUBMODULES}" ]]; then
    read -r -a submodules <<<"${SUBMODULES}"
    update_args=(submodule update --init --recursive)
    if [[ -n "${SUBMODULE_DEPTH}" && "${SUBMODULE_DEPTH}" != "0" ]]; then
        update_args+=(--depth "${SUBMODULE_DEPTH}")
    fi
    update_args+=("${submodules[@]}")
    git "${update_args[@]}"
else
    echo "SUBMODULES is empty; skipping submodule updates."
fi

repo_dir_cmd="$(printf '%q' "${REPO_DIR}")"
editor_cmd="${EDITOR:-editor}"

cat <<EOF

Repository initialized: ${REPO_DIR}
Next steps:
  cd ${repo_dir_cmd}
  ${editor_cmd} qemu-linux.mk   # optional
  make run
EOF
