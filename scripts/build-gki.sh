#!/usr/bin/env bash
# Standalone Android common GKI 5.15 build pipeline for Sapphire experiments.
set -Eeuo pipefail
: "${WORK_DIR:=$(pwd)}"
: "${KERNEL_SRC:=$WORK_DIR/KernelSource}"
: "${CLANG_DIR:=$WORK_DIR/ClangTool}"
: "${OUT_DIR:=$WORK_DIR/out}"
: "${DIST_DIR:=$OUT_DIR/dist}"
: "${BUILD_TYPE:=testing}"
: "${SUKISU_REF:=builtin}"
: "${SUSFS_COMMIT:=20d4ce65059bd99c2cf41cbde1ac90608ebdf16e}"
: "${KPM_REF:=main}"
export WORK_DIR KERNEL_SRC CLANG_DIR OUT_DIR DIST_DIR BUILD_TYPE
export SUKISU_REF SUSFS_COMMIT KPM_REF

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
[[ "$BUILD_TYPE" == testing || "$BUILD_TYPE" == stable ]] || { echo "[ERROR] BUILD_TYPE must be testing or stable" >&2; exit 1; }
mkdir -p "$WORK_DIR" "$OUT_DIR" "$DIST_DIR" "$HOME/.ccache"
export CCACHE_DIR="$HOME/.ccache" CCACHE_MAXSIZE=5G CCACHE_COMPILERCHECK=content
export CCACHE_BASEDIR="$WORK_DIR" CCACHE_SLOPPINESS=file_macro,time_macros

log "1/8 Clone Android common source into KernelSource"
bash "$WORK_DIR/scripts/clone-source.sh"

log "2/8 Setup pinned Clang into ClangTool"
bash "$WORK_DIR/scripts/setup-clang.sh"
[[ -x "$CLANG_DIR/bin/clang" ]] || { echo "[ERROR] Clang not found: $CLANG_DIR/bin/clang" >&2; exit 1; }
export PATH="$CLANG_DIR/bin:$PATH"

log "3/8 Integrate official SukiSU Ultra (builtin branch, SUSFS + KPM)"
bash "$WORK_DIR/scripts/setup-sukisu.sh"
if [[ -f "$WORK_DIR/sukisu-build-info.env" ]]; then
  # shellcheck disable=SC1091
  source "$WORK_DIR/sukisu-build-info.env"
  export SUKISU_COMMIT
fi

log "4/8 Apply SUSFS 5.15 kernel patch for SukiSU Ultra"
bash "$WORK_DIR/scripts/setup-susfs.sh"

log "5/8 Generate and verify GKI + SukiSU Ultra + SUSFS + KPM configuration"
bash "$WORK_DIR/scripts/setup-config.sh"

log "6/8 Compile kernel Image and modules"
bash "$WORK_DIR/scripts/build.sh"

log "7/8 Build matching KernelPatch tools and apply KPM"
bash "$WORK_DIR/scripts/build-kpm-patcher.sh"
if [[ -f "$OUT_DIR/kpm-build-info.txt" ]]; then
  KPM_COMMIT="$(sed -n 's/^KPM_SOURCE_COMMIT=//p' "$OUT_DIR/kpm-build-info.txt" | head -n1)"
  export KPM_COMMIT
fi
bash "$WORK_DIR/scripts/apply-kpm.sh" "$DIST_DIR/Image"

log "8/8 Package AnyKernel3"
bash "$WORK_DIR/scripts/package-anykernel.sh"
log "Build pipeline completed"
