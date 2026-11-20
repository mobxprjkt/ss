#!/usr/bin/env python3
"""Restore only SUSFS patch context includes omitted by some GKI 5.15 trees."""
import pathlib
import re
import sys

INCLUDE_RE = re.compile(r'^#include\s+(?P<inc><trace/hooks/[^>]+>)')
ANY_INCLUDE = re.compile(r'^#include\s+(?P<inc>[<\"][^>\"]+[>\"])')


def parse_patch(text):
    files, current, in_first, hunk = {}, None, False, []

    def flush():
        nonlocal hunk, in_first
        if current is not None and in_first:
            includes = []
            for line in hunk:
                if line.startswith(' '):
                    match = ANY_INCLUDE.match(line[1:].strip())
                    if match:
                        includes.append(match.group('inc'))
            if includes:
                files[current] = includes
        hunk = []
        in_first = False

    for line in text.splitlines():
        if line.startswith('diff --git '):
            flush()
            match = re.match(r'diff --git a/(\S+) b/', line)
            current = match.group(1) if match else None
        elif line.startswith('@@'):
            if in_first:
                flush()
                current = None
            else:
                in_first = True
        elif in_first:
            hunk.append(line)
    flush()
    return files


def ensure_stub(tree, include):
    relative = include.strip('<>')
    path = tree / 'include' / relative
    if path.exists():
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    guard = '_SUSFS_CONTEXT_STUB_' + re.sub(r'\W', '_', relative).upper()
    path.write_text(
        '/* SUSFS patch context-only stub; no symbols are used. */\n'
        f'#ifndef {guard}\n#define {guard}\n#endif\n'
    )
    return True


def main():
    if len(sys.argv) < 2:
        raise SystemExit('usage: restore-susfs-context.py <patch> [kernel-tree]')
    patch_path = pathlib.Path(sys.argv[1])
    tree = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else '.')
    added, stubs = [], []
    for relative, includes in parse_patch(patch_path.read_text(errors='replace')).items():
        if not any(INCLUDE_RE.match('#include ' + item) for item in includes):
            continue
        target = tree / relative
        if not target.exists():
            continue
        lines = target.read_text(errors='replace').splitlines(keepends=True)
        present = [line.strip() for line in lines]
        cursor = 0
        changed = False
        for include in includes:
            wanted = '#include ' + include
            try:
                index = present.index(wanted, cursor)
            except ValueError:
                index = None
            if index is not None:
                cursor = index + 1
                continue
            if not INCLUDE_RE.match(wanted):
                continue
            lines.insert(cursor, wanted + '\n')
            present.insert(cursor, wanted)
            added.append(f'{relative}: {wanted}')
            if ensure_stub(tree, include):
                stubs.append(include)
            cursor += 1
            changed = True
        if changed:
            target.write_text(''.join(lines))
    for item in added:
        print('[SUSFS] restored context ' + item)
    for item in stubs:
        print('[SUSFS] created context-only header ' + item)
    if not added:
        print('[SUSFS] context already complete')


if __name__ == '__main__':
    main()
