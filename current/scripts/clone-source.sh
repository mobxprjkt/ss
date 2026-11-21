#!/usr/bin/env bash
# Clone the pinned Android common GKI source.
set -Eeuo pipefail

: "${KERNEL_SRC:=${WORK_DIR:-$(pwd)}/KernelSource}"

GKI_URL="${GKI_URL:-https://android.googlesource.com/kernel/common}"
GKI_BRANCH="${GKI_BRANCH:-android13-5.15-lts}"

if [[ -e "$KERNEL_SRC" ]]; then
  if [[ -d "$KERNEL_SRC/.git" ]]; then
    echo "[SOURCE] Existing Git checkout found: $KERNEL_SRC"
    exit 0
  fi
  echo "[ERROR] Destination exists but is not a Git checkout: $KERNEL_SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$KERNEL_SRC")"
echo "[SOURCE] Cloning ${GKI_BRANCH}"
git clone --depth=1 --single-branch --branch "$GKI_BRANCH" "$GKI_URL" "$KERNEL_SRC"
git -C "$KERNEL_SRC" rev-parse --verify HEAD
