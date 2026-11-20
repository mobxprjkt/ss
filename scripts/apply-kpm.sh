#!/usr/bin/env bash
# Apply the freshly built official SukiSU KernelPatch patcher to Image.
set -Eeuo pipefail
: "${WORK_DIR:=$(pwd)}"
IMAGE_PATH="${1:?Usage: apply-kpm.sh /path/to/Image}"
KPM_DIR="${KPM_DIR:-$WORK_DIR/SukiSU_KernelPatch_patch}"
PATCHER="$KPM_DIR/patch_linux"

[[ -s "$IMAGE_PATH" ]] || { echo "[ERROR] Kernel Image not found: $IMAGE_PATH" >&2; exit 1; }
[[ -x "$PATCHER" ]] || { echo "[ERROR] Official patch_linux not built: $PATCHER" >&2; exit 1; }

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
cp "$IMAGE_PATH" "$TMP/Image"
(
  cd "$TMP"
  "$PATCHER"
)
[[ -s "$TMP/oImage" ]] || { echo "[ERROR] patch_linux did not produce oImage; original Image preserved" >&2; exit 1; }

# Keep a copy of the unpatched image for diagnosis, then atomically replace Image.
cp -f "$IMAGE_PATH" "${IMAGE_PATH}.pre-kpm"
mv -f "$TMP/oImage" "$IMAGE_PATH"
echo "[KPM] Applied official KernelPatch patcher to $(basename "$IMAGE_PATH")"
