#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  build-essential bc bison flex libelf-dev libssl-dev \
  cpio gzip qemu-system-x86 busybox file binutils
