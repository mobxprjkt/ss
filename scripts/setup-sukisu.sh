#!/usr/bin/env bash
# Integrate the upstream SukiSU Ultra SUSFS-enabled branch.
set -Eeuo pipefail
: "${KERNEL_SRC:?KERNEL_SRC is required}"

cd "$KERNEL_SRC"
SETUP_URL="${SUKISU_SETUP_URL:-https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh}"
SUKISU_BRANCH="${SUKISU_BRANCH:-susfs-main}"

case "$SUKISU_BRANCH" in
  susfs-main|susfs-*) ;;
  *) echo "[ERROR] This workflow requires an upstream SUSFS-enabled branch (susfs-main or susfs-*), got: $SUKISU_BRANCH" >&2; exit 1 ;;
esac

echo "[SukiSU] Running official setup: branch=$SUKISU_BRANCH"
curl --fail --location --retry 3 --retry-delay 2 --silent --show-error "$SETUP_URL" \
  | bash -s "$SUKISU_BRANCH"

KSU_DIR="$KERNEL_SRC/drivers/kernelsu"
[[ -d "$KSU_DIR" ]] || { echo "[ERROR] Upstream setup did not create drivers/kernelsu" >&2; exit 1; }
[[ -f "$KSU_DIR/Kconfig" && -f "$KSU_DIR/Makefile" ]] || {
  echo "[ERROR] drivers/kernelsu is missing Kconfig or Makefile" >&2; exit 1;
}

echo "[SukiSU] Integrated source: $KSU_DIR"
