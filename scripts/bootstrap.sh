#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/ChenMiaoi/my_linux.git"
DEFAULT_SUBMODULES="linux busybox qemu"

usage() {
    cat <<EOF
Usage: bootstrap.sh

Clone and initialize the my_linux template repository. Intended for:
  curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/my_linux/main/scripts/bootstrap.sh | bash

Default behavior:
  - Clone over HTTPS from ${DEFAULT_REPO_URL}
  - Install into \${PWD}/my_linux unless INSTALL_DIR is set
  - Initialize shallow submodules needed by 'make run'
  - Refuse to overwrite a non-empty unrelated directory

Environment variables:
  REPO_URL          Git repository URL (default: ${DEFAULT_REPO_URL})
  INSTALL_DIR       Destination directory (default: \${PWD}/my_linux)
  BRANCH            Optional branch, tag, or commit-ish passed to git clone --branch
  SUBMODULE_DEPTH   Submodule clone depth; set to 0 or empty for full history (default: 1)
  SUBMODULES        Space-separated submodules to initialize (default: ${DEFAULT_SUBMODULES})
  ENSURE_BUILD_DEPS Set to 1 to let init-template.sh prepare build dependencies (default: 0)
  PYTHON_BIN        Python interpreter for dependency preparation (default: python3)

Examples:
  curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/my_linux/main/scripts/bootstrap.sh | bash
  INSTALL_DIR=~/src/qemu-linux curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/my_linux/main/scripts/bootstrap.sh | bash
  REPO_URL=https://github.com/me/my_linux.git BRANCH=main INSTALL_DIR=~/src/my_linux curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/my_linux/main/scripts/bootstrap.sh | bash
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

is_empty_dir() {
    local dir="$1"
    [[ -d "${dir}" ]] || return 1
    ( shopt -s nullglob dotglob; entries=("${dir}"/*); ((${#entries[@]} == 0)) )
}

repo_slug() {
    local url="$1"
    url="${url%.git}"
    url="${url#git@github.com:}"
    url="${url#https://github.com/}"
    url="${url#http://github.com/}"
    printf '%s\n' "${url}"
}

is_template_repo() {
    local dir="$1"
    local expected_slug actual_url actual_slug

    [[ -d "${dir}/.git" || -f "${dir}/.git" ]] || return 1
    [[ -f "${dir}/qemu-linux.mk" && -x "${dir}/scripts/init-template.sh" ]] || return 1

    expected_slug="$(repo_slug "${REPO_URL}")"
    actual_url="$(git -C "${dir}" remote get-url origin 2>/dev/null || true)"
    actual_slug="$(repo_slug "${actual_url}")"

    [[ "${actual_slug}" == "${expected_slug}" || "${actual_slug}" == "ChenMiaoi/my_linux" ]]
}

run_local_init() {
    local repo_dir="$1"
    echo "Initializing repository at ${repo_dir}"
    REPO_DIR="${repo_dir}" \
    SUBMODULE_DEPTH="${SUBMODULE_DEPTH}" \
    SUBMODULES="${SUBMODULES}" \
    ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS}" \
    PYTHON_BIN="${PYTHON_BIN}" \
        "${repo_dir}/scripts/init-template.sh"
}

REPO_URL="${REPO_URL:-${DEFAULT_REPO_URL}}"
INSTALL_DIR="${INSTALL_DIR:-${PWD}/my_linux}"
SUBMODULE_DEPTH="${SUBMODULE_DEPTH-1}"
SUBMODULES="${SUBMODULES-${DEFAULT_SUBMODULES}}"
ENSURE_BUILD_DEPS="${ENSURE_BUILD_DEPS:-0}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

require_cmd git

if [[ -e "${INSTALL_DIR}" ]]; then
    if is_template_repo "${INSTALL_DIR}"; then
        run_local_init "${INSTALL_DIR}"
        exit 0
    fi

    if [[ -d "${INSTALL_DIR}" ]] && is_empty_dir "${INSTALL_DIR}"; then
        clone_args=(clone)
    else
        echo "INSTALL_DIR exists and is not an empty directory or this template repository: ${INSTALL_DIR}" >&2
        echo "Choose another INSTALL_DIR, or remove/empty that directory yourself before retrying." >&2
        exit 1
    fi
else
    clone_args=(clone)
fi

clone_args+=("${REPO_URL}" "${INSTALL_DIR}")
if [[ -n "${BRANCH:-}" ]]; then
    clone_args=(clone --branch "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}")
fi

echo "Cloning ${REPO_URL} into ${INSTALL_DIR}"
git "${clone_args[@]}"
run_local_init "${INSTALL_DIR}"
