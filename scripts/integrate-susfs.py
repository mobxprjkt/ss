#!/usr/bin/env python3
"""Integrate SUSFS 5.15 with the official SukiSU Ultra builtin branch.

SukiSU Ultra builtin provides CONFIG_KSU_SUSFS, CONFIG_KPM, susfs_init(),
and the SUSFS-aware KSU callbacks. This script applies the Linux-side 50_
patch, while omitting legacy devpts/reboot callback sections that are not
part of this selected SukiSU source layout. The namespace.c first hunk is
relocated after local includes when ACK 5.15 include context differs.
"""
from __future__ import annotations
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DROP_FILES = {
    "fs/devpts/inode.c",   # this SukiSU revision has no ksu_handle_devpts()
    "kernel/reboot.c",     # reboot is handled by SukiSU's own hook path
}
REQUIRED_SYMBOLS = (
    "ksu_input_hook", "ksu_handle_input_handle_event",
    "ksu_vfs_read_hook", "ksu_handle_sys_read",
    "ksu_execveat_hook", "ksu_handle_execveat",
    "ksu_handle_execveat_sucompat", "ksu_handle_faccessat",
    "ksu_handle_stat", "ksu_handle_setresuid",
    "is_ksu_domain", "susfs_is_current_ksu_domain",
    "susfs_ksu_sid", "susfs_priv_app_sid",
)


def run_patch(args: list[str], patch_text: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, input=patch_text, cwd=cwd, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def split_sections(text: str) -> list[str]:
    parts = re.split(r"(?=^diff --git )", text, flags=re.M)
    return [p for p in parts if p.strip()]


def trim_patch_and_namespace_hunk(patch_text: str) -> tuple[str, list[str]]:
    out: list[str] = []
    namespace_additions: list[str] = []
    namespace_seen = False
    for section in split_sections(patch_text):
        m = re.match(r"diff --git a/(\S+) b/", section)
        if not m:
            out.append(section)
            continue
        path = m.group(1)
        if path in DROP_FILES:
            print(f"[SUSFS] omit unsupported legacy hook section: {path}")
            continue
        if path != "fs/namespace.c":
            out.append(section)
            continue
        if namespace_seen:
            raise RuntimeError("Patch contains more than one fs/namespace.c section")
        namespace_seen = True
        lines = section.splitlines(keepends=True)
        hunk_starts = [i for i, line in enumerate(lines) if line.startswith("@@")]
        if not hunk_starts:
            raise RuntimeError("fs/namespace.c patch has no hunks")
        first = hunk_starts[0]
        end = hunk_starts[1] if len(hunk_starts) > 1 else len(lines)
        hunk = lines[first:end]
        namespace_additions = [
            line[1:].rstrip("\r\n") for line in hunk
            if line.startswith("+") and not line.startswith("+++")
        ]
        if not namespace_additions:
            raise RuntimeError("fs/namespace.c first hunk has no additions to relocate")
        # Keep the file header and every namespace hunk after the first one.
        out.append("".join(lines[:first] + lines[end:]))
    if not namespace_seen:
        raise RuntimeError("SUSFS patch has no fs/namespace.c section")
    return "".join(out), namespace_additions


def copy_payload(susfs: Path, kernel: Path) -> None:
    payload = susfs / "kernel_patches"
    for rel in ("fs", "include/linux"):
        src = payload / rel
        if not src.is_dir():
            raise RuntimeError(f"SUSFS payload directory missing: {src}")
        dst = kernel / rel
        dst.mkdir(parents=True, exist_ok=True)
        for item in src.iterdir():
            target = dst / item.name
            if item.is_file():
                shutil.copy2(item, target)
            elif item.is_dir():
                if target.exists():
                    shutil.rmtree(target)
                shutil.copytree(item, target)


def verify_sukisu(ksu: Path) -> None:
    source = ksu / "kernel"
    if not (source / "Kconfig").is_file() or not (source / "ksu.c").is_file():
        raise RuntimeError(f"Unexpected SukiSU Ultra source layout: {source}")
    if "susfs_init();" not in (source / "ksu.c").read_text(errors="replace"):
        raise RuntimeError("SukiSU Ultra source does not call susfs_init(); refusing mismatched branch")
    files = list(source.rglob("*.c")) + list(source.rglob("*.h"))
    contents = "\n".join(p.read_text(errors="ignore") for p in files)
    missing = [symbol for symbol in REQUIRED_SYMBOLS if symbol not in contents]
    if missing:
        raise RuntimeError("SukiSU Ultra builtin source lacks required SUSFS hook symbols: " + ", ".join(missing))
    for symbol in ("config KSU_SUSFS", "config KPM"):
        if symbol not in (source / "Kconfig").read_text(errors="replace"):
            raise RuntimeError(f"SukiSU Ultra Kconfig missing {symbol}")


def inject_namespace_additions(kernel: Path, additions: list[str]) -> None:
    target = kernel / "fs/namespace.c"
    text = target.read_text(errors="replace")
    if all(line.strip() in text for line in additions if line.strip()):
        print("[SUSFS] namespace.c first-hunk declarations already present")
        return
    partial = [line for line in additions if line.strip() and line.strip() in text]
    if partial:
        raise RuntimeError("namespace.c contains only part of the relocated SUSFS declarations; refusing duplicate/partial insertion")
    anchor = '#include "internal.h"'
    if text.count(anchor) != 1:
        raise RuntimeError(f"namespace.c expected one {anchor!r} anchor, found {text.count(anchor)}")
    block = "\n".join(additions) + "\n"
    text = text.replace(anchor, anchor + "\n" + block.rstrip("\n"), 1)
    target.write_text(text)
    print(f"[SUSFS] relocated {len(additions)} namespace.c declarations after local includes")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel-source", required=True, type=Path)
    ap.add_argument("--sukisu-source", required=True, type=Path)
    ap.add_argument("--susfs-source", required=True, type=Path)
    ap.add_argument("--patch", required=True, type=Path)
    args = ap.parse_args()
    kernel, ksu, susfs = args.kernel_source.resolve(), args.sukisu_source.resolve(), args.susfs_source.resolve()
    if not (kernel / "fs/namespace.c").is_file():
        raise RuntimeError(f"Not an Android common kernel tree: {kernel}")
    verify_sukisu(ksu)
    copy_payload(susfs, kernel)
    original = args.patch.read_text(errors="replace")
    trimmed, namespace_additions = trim_patch_and_namespace_hunk(original)

    with tempfile.TemporaryDirectory(prefix="susfs-patch-") as tmp:
        temp_patch = Path(tmp) / "susfs-50-trimmed.patch"
        temp_patch.write_text(trimmed)
        forward = run_patch(["patch", "-p1", "--batch", "--forward", "--fuzz=3", "--dry-run"], trimmed, kernel)
        if forward.returncode == 0:
            applied = run_patch(["patch", "-p1", "--batch", "--forward", "--fuzz=3"], trimmed, kernel)
            if applied.returncode != 0:
                raise RuntimeError("SUSFS patch failed after successful dry-run:\n" + applied.stdout[-12000:])
            print("[SUSFS] kernel-side patch applied")
        else:
            reverse = run_patch(["patch", "-p1", "--batch", "--reverse", "--fuzz=3", "--dry-run"], trimmed, kernel)
            if reverse.returncode == 0:
                print("[SUSFS] kernel-side patch already applied")
            else:
                raise RuntimeError("SUSFS patch does not apply cleanly to this ACK 5.15 tree:\n" + forward.stdout[-16000:])

    inject_namespace_additions(kernel, namespace_additions)
    print("[SUSFS] SukiSU Ultra native domain/SID helpers verified; no duplicate glue injected")
    if not (kernel / "fs/susfs.c").is_file() or not (kernel / "include/linux/susfs.h").is_file():
        raise RuntimeError("SUSFS source/header payload did not land in KernelSource")
    print("[SUSFS] integration preflight complete")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)
