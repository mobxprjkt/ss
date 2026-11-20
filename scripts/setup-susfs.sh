#!/usr/bin/env bash
# Validate SUSFS supplied by SukiSU's official susfs-* branch.
# Do not apply a second external patch to fs/namespace.c.
set -Eeuo pipefail
: "${KERNEL_SRC:?KERNEL_SRC is required}"
: "${SUKISU_BRANCH:=susfs-main}"

KSU_DIR="$KERNEL_SRC/drivers/kernelsu"
[[ -d "$KSU_DIR" ]] || { echo "[ERROR] drivers/kernelsu is missing; run setup-sukisu first" >&2; exit 1; }

case "$SUKISU_BRANCH" in
  susfs-main|susfs-*) ;;
  *) echo "[ERROR] SUSFS integration requires a susfs-* SukiSU branch" >&2; exit 1 ;;
esac

if ! grep -RqsE '^[[:space:]]*config[[:space:]]+KSU_SUSFS([[:space:]]|$)' "$KSU_DIR"; then
  echo "[ERROR] The selected SukiSU branch does not define CONFIG_KSU_SUSFS" >&2
  exit 1
fi
if ! grep -Rqs 'susfs_init' "$KSU_DIR"; then
  echo "[ERROR] The selected SukiSU branch has no SUSFS init integration" >&2
  exit 1
fi

# Ensure the external SUSFS patch flow is not accidentally enabled.
if [[ -n "${SUSFS_PATCH_FILE:-}" ]]; then
  echo "[ERROR] SUSFS_PATCH_FILE is unsupported with susfs-*; do not double-patch the kernel" >&2
  exit 1
fi

echo "[SUSFS] Integrated SUSFS source verified in upstream SukiSU branch: $SUKISU_BRANCH"
