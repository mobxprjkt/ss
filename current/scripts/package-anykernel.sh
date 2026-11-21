#!/usr/bin/env bash
# Package the built Image into the Sapphire AnyKernel3 installer.
set -Eeuo pipefail
: "${WORK_DIR:=$(pwd)}"
: "${OUT_DIR:?OUT_DIR is required}"
: "${DIST_DIR:?DIST_DIR is required}"
: "${BUILD_TYPE:=testing}"
: "${SUKISU_REF:=unknown}"
: "${SUSFS_COMMIT:=unknown}"
: "${KPM_REF:=unknown}"
: "${KERNEL_SRC:?KERNEL_SRC is required}"
IMAGE="$DIST_DIR/Image"
AK3_DIR="$OUT_DIR/AnyKernel3"
RELEASE_DIR="$OUT_DIR/release"
AK3_URL="${AK3_URL:-https://github.com/superuseryu/AnyKernel3}"

[[ -s "$IMAGE" ]] || { echo "[ERROR] Missing kernel Image: $IMAGE" >&2; exit 1; }
[[ "$BUILD_TYPE" == testing || "$BUILD_TYPE" == stable ]] || { echo "[ERROR] Invalid BUILD_TYPE" >&2; exit 1; }
rm -rf "$AK3_DIR"
git clone --depth=1 "$AK3_URL" "$AK3_DIR"
[[ -f "$AK3_DIR/anykernel.sh" ]] || { echo "[ERROR] AnyKernel3 installer not found" >&2; exit 1; }
grep -Eq '^device\.name1=sapphire$' "$AK3_DIR/anykernel.sh" || { echo "[ERROR] sapphire device check missing" >&2; exit 1; }
grep -Eq '^device\.name2=sapphiren$' "$AK3_DIR/anykernel.sh" || { echo "[ERROR] sapphiren device check missing" >&2; exit 1; }
cp "$IMAGE" "$AK3_DIR/Image"
mkdir -p "$RELEASE_DIR"
KERNEL_VERSION="$(strings "$IMAGE" | sed -n 's/.*Linux version \([^ ]*\).*/\1/p' | head -n1)"
[[ -n "$KERNEL_VERSION" ]] || KERNEL_VERSION="5.15"
SUFFIX=""; [[ "$BUILD_TYPE" == testing ]] && SUFFIX="-testing"
ZIP_NAME="Sapphire-GKI-SukiSU-Ultra-SUSFS-KPM-${KERNEL_VERSION}-$(date +%Y%m%d)${SUFFIX}.zip"
(
  cd "$AK3_DIR"
  zip -qr "$RELEASE_DIR/$ZIP_NAME" . -x '.git/*'
)
[[ -s "$RELEASE_DIR/$ZIP_NAME" ]] || { echo "[ERROR] ZIP was not created" >&2; exit 1; }

cat > "$RELEASE_DIR/build-info.txt" <<INFO
Device family: Xiaomi Redmi Note 13 4G (sapphire / sapphiren)
Kernel source: Android common android13-5.15-lts
SukiSU source: SukiSU-Ultra builtin branch resolved commit ${SUKISU_COMMIT:-unknown}
SUSFS source: susfs4ksu gki-android13-5.15 pinned at ${SUSFS_COMMIT}
SUSFS integration: kernel-side 50_ patch + SukiSU Ultra native SUSFS support
KPM source: SukiSU-Ultra KernelPatch patcher commit ${KPM_COMMIT:-unknown}
Build type: ${BUILD_TYPE}
Kernel version: ${KERNEL_VERSION}
Source commit: $(git -C "$KERNEL_SRC" rev-parse HEAD)
INFO

echo "[PACKAGE] $RELEASE_DIR/$ZIP_NAME"
