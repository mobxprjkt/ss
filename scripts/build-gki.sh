#!/usr/bin/env bash
# Standalone Sapphire GKI build: SukiSU Ultra + SUSFS + KPM + AnyKernel3.
set -Eeuo pipefail

: "${WORK_DIR:=$(pwd)}"
: "${KERNEL_SRC:=${WORK_DIR}/kernel_src}"
: "${BUILD_TYPE:=testing}"

readonly GKI_BRANCH="android13-5.15-lts"
readonly GKI_URL="https://android.googlesource.com/kernel/common"
readonly SUSFS_URL="https://github.com/ndrancs/ShirkNeko_susfs4ksu.git"
readonly SUSFS_BRANCH="gki-android13-5.15"
readonly AK3_URL="https://github.com/superuseryu/AnyKernel3"
readonly OUT_DIR="${WORK_DIR}/out"
readonly DIST_DIR="${OUT_DIR}/dist"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ "$BUILD_TYPE" == testing || "$BUILD_TYPE" == stable ]] || fail "Invalid BUILD_TYPE: $BUILD_TYPE"
[[ ! -e "$KERNEL_SRC" ]] || fail "${KERNEL_SRC} already exists; remove it before starting a clean build"
mkdir -p "$WORK_DIR" "$OUT_DIR" "$HOME/.ccache"
export CCACHE_DIR="$HOME/.ccache"
export CCACHE_MAXSIZE=5G
export CCACHE_COMPILERCHECK=content
export CCACHE_BASEDIR="$WORK_DIR"
export CCACHE_SLOPPINESS=file_macro,time_macros

log "Cloning Android common ${GKI_BRANCH}"
git clone --depth=1 --branch "$GKI_BRANCH" "$GKI_URL" "$KERNEL_SRC"
cd "$KERNEL_SRC"

log "Installing SukiSU Ultra"
curl -fsSL https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh \
  | bash -s main
[[ -d KernelSU/kernel ]] || fail "SukiSU setup did not create KernelSU/kernel"

log "Cloning SUSFS ${SUSFS_BRANCH}"
git clone --depth=1 --branch "$SUSFS_BRANCH" "$SUSFS_URL" susfs4ksu
SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
[[ -s "$SUSFS_PATCH" ]] || fail "SUSFS patch missing: $SUSFS_PATCH"

python3 "$WORK_DIR/scripts/restore-susfs-context.py" "$SUSFS_PATCH" "$KERNEL_SRC"
if patch -p1 --batch --dry-run --forward --fuzz=3 < "$SUSFS_PATCH" >/tmp/susfs-patch-check.log 2>&1; then
  patch -p1 --batch --forward --fuzz=3 < "$SUSFS_PATCH"
elif patch -p1 --batch --dry-run --reverse --fuzz=3 < "$SUSFS_PATCH" >/dev/null 2>&1; then
  log "SUSFS patch already present; skipping"
else
  cat /tmp/susfs-patch-check.log >&2
  fail "SUSFS patch does not apply cleanly to ${GKI_BRANCH}"
fi

SUSFS_PAYLOAD="susfs4ksu/kernel_patches"
[[ -d "$SUSFS_PAYLOAD/fs" && -d "$SUSFS_PAYLOAD/include/linux" ]] \
  || fail "SUSFS kernel_patches/fs or kernel_patches/include/linux is missing"
cp -a "$SUSFS_PAYLOAD/fs/." fs/
cp -a "$SUSFS_PAYLOAD/include/linux/." include/linux/

log "Integrating SUSFS initialization into SukiSU"
KSU_INIT="KernelSU/kernel/ksu.c"
[[ -f "$KSU_INIT" ]] || KSU_INIT="KernelSU/kernel/core/init.c"
[[ -f "$KSU_INIT" ]] || fail "Could not locate SukiSU init source"
python3 - "$KSU_INIT" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
if re.search(r'\bsusfs_init\s*\(', s):
    print('[SUSFS] init call already exists')
    raise SystemExit(0)
inc = '#include <linux/susfs.h>'
if inc not in s:
    m = re.search(r'(?m)^#include <linux/[^>]+>\s*$', s)
    if not m:
        raise SystemExit('[ERROR] Cannot find include insertion point in ' + str(p))
    s = s[:m.end()] + '\n' + inc + s[m.end():]
block = '\n#ifdef CONFIG_KSU_SUSFS\n\tsusfs_init();\n#endif\n'
if 'ksu_core_init();' in s:
    s = s.replace('ksu_core_init();', 'ksu_core_init();' + block, 1)
else:
    fn = re.search(r'int\s+__init\s+kernelsu_init\s*\([^)]*\)\s*\{', s)
    if not fn:
        raise SystemExit('[ERROR] Unsupported SukiSU init layout in ' + str(p))
    tail = s[fn.end():]
    declaration = re.search(r'\n[ \t]*(?:int|bool|long|unsigned\s+\w+|struct\s+\w+\s*\*)\s+\w+[^;]*;', tail)
    if not declaration:
        raise SystemExit('[ERROR] Cannot find a local declaration in kernelsu_init() in ' + str(p))
    pos = fn.end() + declaration.end()
    s = s[:pos] + block + s[pos:]
p.write_text(s)
PY

log "Preparing GKI configuration"
mkdir -p "$DIST_DIR"
export ARCH=arm64 SUBARCH=arm64 LLVM=1 LLVM_IAS=1
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
  grep -qx "${symbol}=y" "$DIST_DIR/.config" || fail "$symbol was not enabled by Kconfig"
done

log "Installing pinned Clang toolchain"
CLANG_VERSION="$(sed -n 's/^CLANG_VERSION=//p' build.config.constants | head -n1 | tr -d '\"')"
[[ -n "$CLANG_VERSION" ]] || fail "CLANG_VERSION not found in build.config.constants"
CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}"
mkdir -p "$CLANG_DIR"
CLANG_ARCHIVE="${RUNNER_TEMP:-/tmp}/clang-${CLANG_VERSION}.tar.gz"
curl -fL --retry 3 --retry-delay 2 \
  "https://github.com/yurika-sudo/clang-repo/releases/download/clang-1/clang-${CLANG_VERSION}.tar.gz" \
  -o "$CLANG_ARCHIVE"
tar -xzf "$CLANG_ARCHIVE" -C "$CLANG_DIR"
[[ -x "$CLANG_DIR/bin/clang" ]] || fail "Clang binary missing from extracted toolchain"
export PATH="$CLANG_DIR/bin:$PATH"

log "Building Image and kernel modules"
MAKE_ARGS=(
  -j"$(nproc)" O="$DIST_DIR" ARCH=arm64 SUBARCH=arm64
  LLVM=1 LLVM_IAS=1 CC="ccache clang" LD=ld.lld AR=llvm-ar NM=llvm-nm
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  BRANCH="$GKI_BRANCH" KMI_GENERATION=8
  KBUILD_BUILD_USER="$KBUILD_BUILD_USER" KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST"
)
set -o pipefail
make "${MAKE_ARGS[@]}" Image modules 2>&1 | tee "$OUT_DIR/build.log"
IMAGE="$DIST_DIR/arch/arm64/boot/Image"
[[ -s "$IMAGE" ]] || fail "Build completed without producing Image"
cp "$IMAGE" "$DIST_DIR/Image"

log "Applying KPM patch"
bash "$WORK_DIR/scripts/apply-kpm.sh" "$DIST_DIR/Image"

log "Preparing AnyKernel3 package"
git clone --depth=1 "$AK3_URL" "$OUT_DIR/AnyKernel3"
[[ -f "$OUT_DIR/AnyKernel3/anykernel.sh" ]] || fail "AnyKernel3 installer is missing"
cp "$DIST_DIR/Image" "$OUT_DIR/AnyKernel3/Image"
mkdir -p "$OUT_DIR/release"
KERNEL_VERSION="$(strings "$DIST_DIR/Image" | sed -n 's/.*Linux version \([0-9][^ ]*\).*/\1/p' | head -n1)"
[[ -n "$KERNEL_VERSION" ]] || KERNEL_VERSION="5.15"
SUFFIX=""
[[ "$BUILD_TYPE" == testing ]] && SUFFIX="-testing"
ZIP_NAME="Sapphire-GKI-SukiSU-${KERNEL_VERSION}-$(date +%Y%m%d)${SUFFIX}.zip"
(
  cd "$OUT_DIR/AnyKernel3"
  zip -qr "$OUT_DIR/release/$ZIP_NAME" . -x '.git/*'
)
[[ -s "$OUT_DIR/release/$ZIP_NAME" ]] || fail "AnyKernel3 ZIP was not created"

cat > "$OUT_DIR/release/build-info.txt" <<EOF
Device: Xiaomi Redmi Note 13 4G (Sapphire)
Source: Android common ${GKI_BRANCH}
Root: SukiSU Ultra
SUSFS: ${SUSFS_BRANCH}
KPM: enabled and patch step completed
Build type: ${BUILD_TYPE}
Kernel version: ${KERNEL_VERSION}
Commit: $(git -C "$KERNEL_SRC" rev-parse --short HEAD)
EOF
log "Build package ready: $OUT_DIR/release/$ZIP_NAME"
