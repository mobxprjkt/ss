#!/usr/bin/env bash
set -Eeuo pipefail

: "${IMAGE:?IMAGE must point to the built kernel Image}"
: "${KPM_PATCH_URL:=https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/main/kpm/patch_linux}"

[[ -s "$IMAGE" ]] || { echo "[KPM] Missing kernel image: $IMAGE" >&2; exit 1; }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

curl -fL --retry 3 --retry-delay 2 "$KPM_PATCH_URL" -o "$workdir/patch_linux"
chmod 0755 "$workdir/patch_linux"

cp "$IMAGE" "$workdir/Image"
cd "$workdir"
./patch_linux

[[ -s "$workdir/oImage" ]] || {
  echo "[KPM] patch_linux did not produce oImage; refusing to replace Image" >&2
  exit 1
}

install -m 0644 "$workdir/oImage" "$IMAGE"
echo "[KPM] Patched image installed: $IMAGE"
