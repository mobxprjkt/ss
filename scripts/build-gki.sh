#!/usr/bin/env bash
# Standalone orchestration entry point. Each build stage has its own script.
set -Eeuo pipefail

: "${WORK_DIR:=$(pwd)}"
: "${KERNEL_SRC:=$WORK_DIR/KernelSource}"
: "${OUT_DIR:=$WORK_DIR/out}"
: "${DIST_DIR:=$OUT_DIR/dist}"
: "${BUILD_TYPE:=testing}"

export WORK_DIR KERNEL_SRC OUT_DIR DIST_DIR BUILD_TYPE

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

[[ "$BUILD_TYPE" == testing || "$BUILD_TYPE" == stable ]] || {
  echo "[ERROR] BUILD_TYPE must be testing or stable" >&2
  exit 1
}

mkdir -p "$WORK_DIR" "$OUT_DIR" "$HOME/.ccache"
export CCACHE_DIR="$HOME/.ccache"
export CCACHE_MAXSIZE=5G
export CCACHE_COMPILERCHECK=content
export CCACHE_BASEDIR="$WORK_DIR"
export CCACHE_SLOPPINESS=file_macro,time_macros

log "1/8 Clone kernel source"
bash "$WORK_DIR/scripts/clone-source.sh"

log "2/8 Setup Clang"
bash "$WORK_DIR/scripts/setup-clang.sh"
CLANG_VERSION="$(sed -n 's/^CLANG_VERSION=//p' "$KERNEL_SRC/build.config.constants" | head -n1 | tr -d '"' | tr -d '\r')"
[[ -n "$CLANG_VERSION" ]] || { echo "[ERROR] Cannot resolve pinned CLANG_VERSION" >&2; exit 1; }
export CLANG_DIR="$WORK_DIR/ClangTool"
[[ -x "$CLANG_DIR/bin/clang" ]] || { echo "[ERROR] Clang not installed at $CLANG_DIR" >&2; exit 1; }

log "3/8 Setup SukiSU Ultra"
bash "$WORK_DIR/scripts/setup-sukisu.sh"

log "4/8 Setup SUSFS"
bash "$WORK_DIR/scripts/setup-susfs.sh"

log "5/8 Generate kernel configuration"
bash "$WORK_DIR/scripts/setup-config.sh"

log "6/8 Build Image and modules"
bash "$WORK_DIR/scripts/build.sh"

log "7/8 Apply KPM"
bash "$WORK_DIR/scripts/apply-kpm.sh" "$DIST_DIR/Image"

log "8/8 Package AnyKernel3"
bash "$WORK_DIR/scripts/package-anykernel.sh"

log "Build pipeline completed"
