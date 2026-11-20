#!/usr/bin/env bash
# Integrate SukiSU Ultra into the kernel source tree.
set -Eeuo pipefail

: "${KERNEL_SRC:?KERNEL_SRC is required}"

cd "$KERNEL_SRC"
SETUP_URL="${SUKISU_SETUP_URL:-https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh}"
SUKISU_BRANCH="${SUKISU_BRANCH:-main}"

echo "[SukiSU] Running upstream setup ($SUKISU_BRANCH)"
curl --fail --location --silent --show-error "$SETUP_URL" \
  | bash -s "$SUKISU_BRANCH"

[[ -d KernelSU/kernel ]] || {
  echo "[ERROR] SukiSU setup did not create KernelSU/kernel" >&2
  exit 1
}

echo "[SukiSU] Source integration directory found"
