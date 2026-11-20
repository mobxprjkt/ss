#!/usr/bin/env python3
"""Apply SUSFS patch while relocating its context-sensitive namespace.c hunk.

Only the first fs/namespace.c hunk (the include/declaration block) is relocated.
Every other upstream hunk remains intact and must pass a dry-run before any
changes are applied. This prevents silently skipping functional SUSFS changes.
"""
from pathlib import Path
import subprocess
import sys
import tempfile


def fail(message: str) -> None:
    raise SystemExit(f"[ERROR] {message}")


def run_patch(patch_file: Path, tree: Path, dry_run: bool) -> subprocess.CompletedProcess:
    args = ["patch", "-p1", "--batch", "--forward", "--fuzz=3"]
    if dry_run:
        args.append("--dry-run")
    args += ["-i", str(patch_file)]
    return subprocess.run(args, cwd=tree, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: apply-susfs-patch.py <patch-file> <kernel-source>")
    patch_path = Path(sys.argv[1]).resolve()
    tree = Path(sys.argv[2]).resolve()
    if not patch_path.is_file() or not tree.is_dir():
        fail("patch file or kernel source directory does not exist")

    lines = patch_path.read_text(errors="replace").splitlines(keepends=True)
    section = next((i for i, line in enumerate(lines)
                    if line.startswith("diff --git a/fs/namespace.c ")), None)
    if section is None:
        fail("fs/namespace.c section not found in SUSFS patch")
    first_hunk = next((i for i in range(section + 1, len(lines))
                       if lines[i].startswith("@@ ")), None)
    if first_hunk is None:
        fail("first fs/namespace.c hunk not found")
    end_hunk = next((i for i in range(first_hunk + 1, len(lines))
                     if lines[i].startswith("@@ ") or lines[i].startswith("diff --git ")),
                    len(lines))
    hunk = lines[first_hunk:end_hunk]
    additions = [line[1:].rstrip("\r\n") for line in hunk
                 if line.startswith("+") and not line.startswith("+++")]
    if not additions:
        fail("namespace.c first hunk contains no additions")

    target = tree / "fs/namespace.c"
    if not target.is_file():
        fail("fs/namespace.c is missing from kernel source")
    original = target.read_text(errors="replace")
    marker = "susfs_ksu_mnt_group_ida"
    already_relocated = marker in original

    # If our relocation marker is present, the remaining patch may already be
    # applied or partially applied. Require the full reverse patch to confirm.
    if already_relocated:
        reverse = subprocess.run(
            ["patch", "-p1", "--batch", "--reverse", "--dry-run", "-i", str(patch_path)],
            cwd=tree, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if reverse.returncode == 0:
            print("[SUSFS] Full patch already applied; skipping")
            return
        fail("namespace.c SUSFS block exists but the full patch is not consistently applied; clean the source tree")

    # Remove exactly the first namespace.c hunk; keep all other hunks mandatory.
    filtered_lines = lines[:first_hunk] + lines[end_hunk:]
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="", delete=False) as tmp:
            tmp.writelines(filtered_lines)
            temp_path = Path(tmp.name)
        check = run_patch(temp_path, tree, True)
        if check.returncode:
            sys.stderr.write(check.stdout)
            fail("remaining SUSFS hunks fail dry-run; no SUSFS changes were applied")
        applied = run_patch(temp_path, tree, False)
        if applied.returncode:
            sys.stderr.write(applied.stdout)
            fail("failed to apply remaining SUSFS hunks")
        if applied.stdout:
            print(applied.stdout, end="")
    finally:
        if temp_path:
            temp_path.unlink(missing_ok=True)

    # Insert the exact added lines from the skipped hunk immediately before
    # pnode.h, which is the stable boundary used by this kernel source family.
    current = target.read_text(errors="replace")
    if marker in current:
        fail("namespace.c integration appeared unexpectedly during patching")
    anchor = '#include "pnode.h"'
    if anchor not in current:
        fail('stable include anchor #include "pnode.h" not found in fs/namespace.c')
    block = "\n".join(additions) + "\n\n"
    current = current.replace(anchor, block + anchor, 1)
    target.write_text(current)
    print("[SUSFS] relocated namespace.c first-hunk additions before pnode.h")
    print("[SUSFS] all remaining upstream hunks applied successfully")


if __name__ == "__main__":
    main()
