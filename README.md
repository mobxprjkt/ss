# Sapphire GKI Standalone Build

Standalone GitHub Actions workflow for Xiaomi Redmi Note 13 4G (`sapphire` / `sapphiren`). It does not call reusable workflows from `mobxprjkt/Kernul`.

## Build directories

- Android common GKI source: `KernelSource/`
- Pinned Clang toolchain: `ClangTool/`
- Build output: `out/`

## SUSFS patch handling

The upstream `gki-android13-5.15` patch has a context-sensitive first hunk in `fs/namespace.c`. The workflow now uses `scripts/apply-susfs-patch.py`: it relocates only that hunk's added include/declaration block to the stable location immediately before `#include "pnode.h"`. All other upstream hunks are preserved and must pass a dry-run. The script stops if any remaining hunk fails; it does not silently ignore functional changes.

## Run

Open **Actions → Sapphire | GKI 5.15 | SukiSU Ultra → Run workflow** and choose `testing` or `stable`. Disable `publish_release` if only an Actions artifact is wanted.

## Compatibility warning

This workflow builds Android common GKI `android13-5.15-lts`, not the Sapphire vendor kernel. It does not build device DTBO, vendor modules, or vendor_boot. A successful build and the AnyKernel3 codename checks do not guarantee boot compatibility with a particular ROM or firmware. Test only with a recoverable boot method.

External SUSFS, SukiSU, KPM, Clang archive, and AnyKernel3 sources are fetched at build time. This package has passed local syntax and archive checks only; a full CI compile and device boot test are still required.
