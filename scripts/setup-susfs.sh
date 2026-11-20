#!/usr/bin/env bash
# Apply SUSFS 5.15 patch, copy support files, and integrate SUSFS init.
set -Eeuo pipefail

: "${KERNEL_SRC:?KERNEL_SRC is required}"
: "${WORK_DIR:=$(pwd)}"

SUSFS_URL="${SUSFS_URL:-https://github.com/ndrancs/ShirkNeko_susfs4ksu.git}"
SUSFS_BRANCH="${SUSFS_BRANCH:-gki-android13-5.15}"
SUSFS_DIR="${SUSFS_DIR:-$WORK_DIR/susfs4ksu}"
PATCH_REL="kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"

[[ -d "$KERNEL_SRC/KernelSU/kernel" ]] || {
  echo "[ERROR] SukiSU must be installed before SUSFS" >&2
  exit 1
}

if [[ ! -d "$SUSFS_DIR/.git" ]]; then
  git clone --depth=1 --single-branch --branch "$SUSFS_BRANCH" "$SUSFS_URL" "$SUSFS_DIR"
fi

PATCH_FILE="$SUSFS_DIR/$PATCH_REL"
[[ -s "$PATCH_FILE" ]] || { echo "[ERROR] Missing SUSFS patch: $PATCH_FILE" >&2; exit 1; }

python3 "$WORK_DIR/scripts/restore-susfs-context.py" "$PATCH_FILE" "$KERNEL_SRC"
python3 "$WORK_DIR/scripts/apply-susfs-patch.py" "$PATCH_FILE" "$KERNEL_SRC"
cd "$KERNEL_SRC"

PAYLOAD="$SUSFS_DIR/kernel_patches"
[[ -d "$PAYLOAD/fs" && -d "$PAYLOAD/include/linux" ]] || {
  echo "[ERROR] SUSFS support files missing under $PAYLOAD" >&2
  exit 1
}
mkdir -p fs include/linux
cp -a "$PAYLOAD/fs/." fs/
cp -a "$PAYLOAD/include/linux/." include/linux/

KSU_INIT="KernelSU/kernel/ksu.c"
[[ -f "$KSU_INIT" ]] || KSU_INIT="KernelSU/kernel/core/init.c"
[[ -f "$KSU_INIT" ]] || { echo "[ERROR] Cannot locate SukiSU init source" >&2; exit 1; }

python3 - "$KSU_INIT" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text()

if re.search(r'\bsusfs_init\s*\(', source):
    print(f"[SUSFS] Init already integrated in {path}")
    raise SystemExit(0)

include = "#include <linux/susfs.h>"
if include not in source:
    match = re.search(r"(?m)^#include <linux/[^>]+>\s*$", source)
    if not match:
        raise SystemExit(f"[ERROR] Cannot find include insertion point in {path}")
    source = source[:match.end()] + "\n" + include + source[match.end():]

block = "\n#ifdef CONFIG_KSU_SUSFS\n\tsusfs_init();\n#endif\n"
if "ksu_core_init();" in source:
    source = source.replace("ksu_core_init();", "ksu_core_init();" + block, 1)
else:
    function = re.search(r"int\s+__init\s+kernelsu_init\s*\([^)]*\)\s*\{", source)
    if not function:
        raise SystemExit(f"[ERROR] Unsupported SukiSU init layout in {path}")
    tail = source[function.end():]
    declaration = re.search(
        r"\n[ \t]*(?:int|bool|long|unsigned\s+\w+|struct\s+\w+\s*\*)\s+\w+[^;]*;",
        tail,
    )
    if not declaration:
        raise SystemExit(f"[ERROR] Cannot locate local declaration in kernelsu_init() in {path}")
    position = function.end() + declaration.end()
    source = source[:position] + block + source[position:]

path.write_text(source)
print(f"[SUSFS] Init integrated in {path}")
PY

echo "[SUSFS] Integration complete ($SUSFS_BRANCH)"
