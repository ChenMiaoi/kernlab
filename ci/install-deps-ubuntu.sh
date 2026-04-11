#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  build-essential gcc g++ make perl \
  bc bison flex libelf-dev libssl-dev clang lld llvm \
  cpio gzip busybox file binutils bear \
  python3 python3-venv ninja-build pkg-config \
  libglib2.0-dev libpixman-1-dev zlib1g-dev
