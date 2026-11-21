#!/usr/bin/env bash
# Apply the Android 13 / 5.15 SUSFS kernel patch to the official SukiSU Ultra builtin tree.
set -Eeuo pipefail
: "${KERNEL_SRC:?KERNEL_SRC is required}"
: "${WORK_DIR:=$(pwd)}"

SUSFS_URL="${SUSFS_URL:-https://github.com/ndrancs/ShirkNeko_susfs4ksu.git}"
SUSFS_BRANCH="${SUSFS_BRANCH:-gki-android13-5.15}"
SUSFS_COMMIT="${SUSFS_COMMIT:-20d4ce65059bd99c2cf41cbde1ac90608ebdf16e}"
SUSFS_DIR="${SUSFS_DIR:-$WORK_DIR/susfs4ksu}"

[[ -d "$KERNEL_SRC/KernelSU/kernel" ]] || {
  echo "[ERROR] SukiSU Ultra must be installed before SUSFS" >&2; exit 1;
}
if [[ ! -d "$SUSFS_DIR/.git" ]]; then
  git clone --depth=1 --single-branch --branch "$SUSFS_BRANCH" "$SUSFS_URL" "$SUSFS_DIR"
fi
ORIGIN="$(git -C "$SUSFS_DIR" remote get-url origin)"
ORIGIN="${ORIGIN%.git}"
EXPECTED_ORIGIN="${SUSFS_URL%.git}"
[[ "$ORIGIN" == "$EXPECTED_ORIGIN" ]] || { echo "[ERROR] SUSFS origin mismatch: $ORIGIN" >&2; exit 1; }
git -C "$SUSFS_DIR" fetch --depth=1 origin "$SUSFS_COMMIT"
git -C "$SUSFS_DIR" checkout --detach "$SUSFS_COMMIT"
ACTUAL="$(git -C "$SUSFS_DIR" rev-parse HEAD)"
[[ "$ACTUAL" == "$SUSFS_COMMIT" ]] || {
  echo "[ERROR] SUSFS checkout mismatch: expected $SUSFS_COMMIT, got $ACTUAL" >&2; exit 1;
}

PATCH_FILE="$SUSFS_DIR/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
[[ -s "$PATCH_FILE" ]] || { echo "[ERROR] Missing SUSFS patch: $PATCH_FILE" >&2; exit 1; }
[[ -s "$SUSFS_DIR/kernel_patches/fs/susfs.c" ]] || {
  echo "[ERROR] SUSFS fs/susfs.c payload missing" >&2; exit 1;
}

python3 "$WORK_DIR/scripts/integrate-susfs.py" \
  --kernel-source "$KERNEL_SRC" \
  --sukisu-source "$KERNEL_SRC/KernelSU" \
  --susfs-source "$SUSFS_DIR" \
  --patch "$PATCH_FILE"

echo "[SUSFS] Android 13 / 5.15 integration completed at $ACTUAL"
