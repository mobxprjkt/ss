#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_PATH="${1:?Usage: apply-kpm.sh /path/to/Image}"
[[ -s "$IMAGE_PATH" ]] || { echo "[ERROR] Kernel Image not found: $IMAGE_PATH" >&2; exit 1; }

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

curl -fL --retry 3 --retry-delay 2 \
  https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/main/kpm/patch_linux \
  -o "$WORK/patch_linux"
chmod 0755 "$WORK/patch_linux"
cp "$IMAGE_PATH" "$WORK/Image"
(
  cd "$WORK"
  ./patch_linux
)
[[ -s "$WORK/oImage" ]] || { echo "[ERROR] KPM patcher did not produce oImage" >&2; exit 1; }
mv "$WORK/oImage" "$IMAGE_PATH"
echo "[OK] KPM patch applied to $(basename "$IMAGE_PATH")"
