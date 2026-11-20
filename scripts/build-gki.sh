#!/usr/bin/env bash
# Standalone orchestration entry point for Android common GKI 5.15.
set -Eeuo pipefail
: "${WORK_DIR:=$(pwd)}"
: "${KERNEL_SRC:=$WORK_DIR/KernelSource}"
: "${OUT_DIR:=$WORK_DIR/out}"
: "${DIST_DIR:=$OUT_DIR/dist}"
: "${BUILD_TYPE:=testing}"
: "${SUKISU_BRANCH:=susfs-main}"
export WORK_DIR KERNEL_SRC OUT_DIR DIST_DIR BUILD_TYPE SUKISU_BRANCH

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
[[ "$BUILD_TYPE" == testing || "$BUILD_TYPE" == stable ]] || { echo "[ERROR] BUILD_TYPE must be testing or stable" >&2; exit 1; }
mkdir -p "$WORK_DIR" "$OUT_DIR" "$DIST_DIR" "$HOME/.ccache"
export CCACHE_DIR="$HOME/.ccache" CCACHE_MAXSIZE=5G CCACHE_COMPILERCHECK=content
export CCACHE_BASEDIR="$WORK_DIR" CCACHE_SLOPPINESS=file_macro,time_macros

log "1/8 Clone Android common source into KernelSource"
bash "$WORK_DIR/scripts/clone-source.sh"

log "2/8 Setup pinned Clang into ClangTool"
bash "$WORK_DIR/scripts/setup-clang.sh"
CLANG_DIR="$WORK_DIR/ClangTool"
[[ -x "$CLANG_DIR/bin/clang" ]] || { echo "[ERROR] Clang not found: $CLANG_DIR/bin/clang" >&2; exit 1; }
export CLANG_DIR
export PATH="$CLANG_DIR/bin:$PATH"

log "3/8 Integrate official SukiSU Ultra SUSFS branch"
bash "$WORK_DIR/scripts/setup-sukisu.sh"

log "4/8 Verify upstream SUSFS integration (no external patching)"
bash "$WORK_DIR/scripts/setup-susfs.sh"

log "5/8 Generate GKI + SukiSU + SUSFS + KPM configuration"
bash "$WORK_DIR/scripts/setup-config.sh"

log "6/8 Compile kernel Image and modules"
bash "$WORK_DIR/scripts/build.sh"

log "7/8 Build official KernelPatch and apply KPM"
bash "$WORK_DIR/scripts/build-kpm-patcher.sh"
bash "$WORK_DIR/scripts/apply-kpm.sh" "$DIST_DIR/Image"

log "8/8 Package AnyKernel3"
bash "$WORK_DIR/scripts/package-anykernel.sh"
log "Build pipeline completed"
