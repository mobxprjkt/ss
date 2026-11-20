#!/usr/bin/env bash
# Generate GKI defconfig and enable SukiSU, SUSFS and KPM options.
set -Eeuo pipefail

: "${KERNEL_SRC:?KERNEL_SRC is required}"
: "${DIST_DIR:?DIST_DIR is required}"

cd "$KERNEL_SRC"
mkdir -p "$DIST_DIR"

export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1

make O="$DIST_DIR" gki_defconfig

scripts/config --file "$DIST_DIR/.config" \
  -e KSU \
  -e KPROBES \
  -e KSU_SUSFS \
  -e KSU_SUSFS_SUS_MAP \
  -e KSU_SUSFS_SUS_PATH \
  -e KSU_SUSFS_SUS_MOUNT \
  -e KSU_SUSFS_SUS_KSTAT \
  -e KSU_SUSFS_SPOOF_UNAME \
  -e KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
  -e KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
  -e KSU_SUSFS_TRY_UMOUNT \
  -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
  -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
  -e KSU_SUSFS_OPEN_REDIRECT \
  -e KSU_SUSFS_SUS_SU \
  -e KPM

make O="$DIST_DIR" olddefconfig

for symbol in CONFIG_KSU CONFIG_KSU_SUSFS CONFIG_KPM; do
  grep -qx "${symbol}=y" "$DIST_DIR/.config" || {
    echo "[ERROR] $symbol was not enabled by Kconfig" >&2
    exit 1
  }
done

echo "[CONFIG] GKI + SukiSU + SUSFS + KPM configuration ready"
