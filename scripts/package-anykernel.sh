#!/usr/bin/env bash
# Package the built Image into the Sapphire AnyKernel3 installer.
set -Eeuo pipefail

: "${WORK_DIR:=$(pwd)}"
: "${OUT_DIR:?OUT_DIR is required}"
: "${DIST_DIR:?DIST_DIR is required}"
: "${BUILD_TYPE:=testing}"

IMAGE="$DIST_DIR/Image"
AK3_DIR="$OUT_DIR/AnyKernel3"
RELEASE_DIR="$OUT_DIR/release"
AK3_URL="${AK3_URL:-https://github.com/superuseryu/AnyKernel3}"

[[ -s "$IMAGE" ]] || { echo "[ERROR] Missing kernel Image: $IMAGE" >&2; exit 1; }
[[ "$BUILD_TYPE" == testing || "$BUILD_TYPE" == stable ]] || {
  echo "[ERROR] Invalid BUILD_TYPE: $BUILD_TYPE" >&2
  exit 1
}

rm -rf "$AK3_DIR"
git clone --depth=1 "$AK3_URL" "$AK3_DIR"
[[ -f "$AK3_DIR/anykernel.sh" ]] || { echo "[ERROR] AnyKernel3 installer not found" >&2; exit 1; }

# Verify that the installer targets the Sapphire family before packaging.
grep -Eq '^device\.name1=sapphire$' "$AK3_DIR/anykernel.sh" || {
  echo "[ERROR] AnyKernel3 device.name1=sapphire check is missing" >&2
  exit 1
}
grep -Eq '^device\.name2=sapphiren$' "$AK3_DIR/anykernel.sh" || {
  echo "[ERROR] AnyKernel3 device.name2=sapphiren check is missing" >&2
  exit 1
}

cp "$IMAGE" "$AK3_DIR/Image"
mkdir -p "$RELEASE_DIR"

KERNEL_VERSION="$(strings "$IMAGE" | sed -n 's/.*Linux version \([^ ]*\).*/\1/p' | head -n1)"
[[ -n "$KERNEL_VERSION" ]] || KERNEL_VERSION="5.15"
SUFFIX=""
[[ "$BUILD_TYPE" == testing ]] && SUFFIX="-testing"
ZIP_NAME="Sapphire-GKI-SukiSU-${KERNEL_VERSION}-$(date +%Y%m%d)${SUFFIX}.zip"

(
  cd "$AK3_DIR"
  zip -qr "$RELEASE_DIR/$ZIP_NAME" . -x '.git/*'
)

[[ -s "$RELEASE_DIR/$ZIP_NAME" ]] || { echo "[ERROR] ZIP was not created" >&2; exit 1; }

cat > "$RELEASE_DIR/build-info.txt" <<EOF
Device family: Xiaomi Redmi Note 13 4G (sapphire / sapphiren)
Source: Android common android13-5.15-lts
Root: SukiSU Ultra
SUSFS: gki-android13-5.15
KPM: patch step completed
Build type: $BUILD_TYPE
Kernel version: $KERNEL_VERSION
Source commit: $(git -C "$KERNEL_SRC" rev-parse --short HEAD)
EOF

echo "[PACKAGE] $RELEASE_DIR/$ZIP_NAME"
