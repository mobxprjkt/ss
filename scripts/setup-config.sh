#!/usr/bin/env bash
# Enable only SUSFS symbols declared by the pinned SukiSU Kconfig.
set -Eeuo pipefail
: "${KERNEL_SRC:?KERNEL_SRC is required}"
: "${DIST_DIR:?DIST_DIR is required}"
: "${CLANG_DIR:?CLANG_DIR is required}"

export PATH="$CLANG_DIR/bin:$PATH"
export ARCH=arm64 SUBARCH=arm64 LLVM=1 LLVM_IAS=1
cd "$KERNEL_SRC"
mkdir -p "$DIST_DIR"
KSU_DIR="$KERNEL_SRC/KernelSU/kernel"
[[ -d "$KSU_DIR" ]] || { echo "[ERROR] KernelSU/kernel missing" >&2; exit 1; }

make O="$DIST_DIR" gki_defconfig
CONFIG="$DIST_DIR/.config"
CONFIG_TOOL="$KERNEL_SRC/scripts/config"
[[ -x "$CONFIG_TOOL" ]] || { echo "[ERROR] scripts/config missing or not executable" >&2; exit 1; }

"$CONFIG_TOOL" --file "$CONFIG" -e KSU -e KPM -e KALLSYMS -e KALLSYMS_ALL -e KSU_SUSFS
mapfile -t SUSFS_SYMBOLS < <(
  grep -RhoE '^[[:space:]]*config[[:space:]]+KSU_SUSFS[A-Za-z0-9_]*' "$KSU_DIR/Kconfig" \
    | awk '{print $2}' | sort -u
)
((${#SUSFS_SYMBOLS[@]} > 0)) || { echo "[ERROR] No CONFIG_KSU_SUSFS* symbols found" >&2; exit 1; }
for symbol in "${SUSFS_SYMBOLS[@]}"; do
  "$CONFIG_TOOL" --file "$CONFIG" -e "$symbol"
done

make O="$DIST_DIR" olddefconfig
for symbol in CONFIG_KSU CONFIG_KPM CONFIG_KSU_SUSFS; do
  grep -qx "${symbol}=y" "$CONFIG" || {
    echo "[ERROR] Required option $symbol was dropped by Kconfig" >&2
    grep -E '^# CONFIG_(KSU|KPM|KALLSYMS|KSU_SUSFS)' "$CONFIG" >&2 || true
    exit 1
  }
done
for symbol in "${SUSFS_SYMBOLS[@]}"; do
  grep -Eq "^${symbol}=y$" "$CONFIG" || {
    echo "[ERROR] SUSFS option ${symbol} was not enabled after olddefconfig" >&2; exit 1;
  }
done

echo "[CONFIG] KSU Ultra/KPM/SUSFS config verified (${#SUSFS_SYMBOLS[@]} SUSFS symbols)"
