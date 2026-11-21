#!/usr/bin/env bash
# Compile Android common GKI Image and modules with the pinned Clang toolchain.
set -Eeuo pipefail

: "${WORK_DIR:=$(pwd)}"
: "${KERNEL_SRC:?KERNEL_SRC is required}"
: "${OUT_DIR:?OUT_DIR is required}"
: "${DIST_DIR:?DIST_DIR is required}"
: "${CLANG_DIR:?CLANG_DIR is required}"

export PATH="$CLANG_DIR/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"
export CCACHE_COMPILERCHECK="${CCACHE_COMPILERCHECK:-content}"
export CCACHE_BASEDIR="${CCACHE_BASEDIR:-${GITHUB_WORKSPACE:-$WORK_DIR}}"

cd "$KERNEL_SRC"
mkdir -p "$OUT_DIR" "$DIST_DIR"

if command -v ccache >/dev/null 2>&1; then
  ccache --zero-stats || true
  COMPILER="ccache clang"
else
  echo "[WARN] ccache is unavailable; using clang directly"
  COMPILER="clang"
fi

MAKE_ARGS=(
  -j"$(nproc)"
  O="$DIST_DIR"
  ARCH=arm64
  SUBARCH=arm64
  LLVM=1
  LLVM_IAS=1
  "CC=$COMPILER"
  LD=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  STRIP=llvm-strip
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  BRANCH=android13-5.15-lts
  KMI_GENERATION=8
  KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-builder}"
  KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github-actions}"
)

set -o pipefail
make "${MAKE_ARGS[@]}" Image modules 2>&1 | tee "${OUT_DIR}/build.log"

IMAGE="$DIST_DIR/arch/arm64/boot/Image"
[[ -s "$IMAGE" ]] || {
  echo "[ERROR] Build did not produce $IMAGE" >&2
  exit 1
}
cp "$IMAGE" "$DIST_DIR/Image"

if command -v ccache >/dev/null 2>&1; then
  ccache --show-stats || true
fi
echo "[BUILD] Image ready: $DIST_DIR/Image"
