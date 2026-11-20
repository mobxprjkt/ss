# Sapphire GKI 5.15 — SukiSU Ultra + SUSFS + KPM

Standalone GitHub Actions build scaffold for Xiaomi Redmi Note 13 4G (`sapphire` / `sapphiren`). No reusable workflow dependency on `mobxprjkt/Kernul`.

## Layout

- `KernelSource/` — Android common kernel source (`android13-5.15-lts`)
- `ClangTool/` — Clang archive matching `CLANG_VERSION` in the kernel source
- `SukiSU_KernelPatch_patch/` — official SukiSU KernelPatch source used to build `patch_linux`
- `out/` — kernel output and release package

## Integration strategy

1. SukiSU is installed using the official `susfs-main` branch through upstream `kernel/setup.sh`.
2. SUSFS is provided by that SukiSU branch. The workflow deliberately does **not** apply the separate `susfs4ksu` patch, does not relocate `fs/namespace.c` hunks, and does not create fake trace-hook headers. This avoids applying two different SUSFS integration mechanisms to the same kernel tree.
3. `setup-config.sh` discovers actual `CONFIG_KSU_SUSFS*` symbols in the selected upstream Kconfig and enables only symbols that exist. It verifies `CONFIG_KSU=y`, `CONFIG_KSU_SUSFS=y`, and `CONFIG_KPM=y` after `olddefconfig`.
4. KPM patcher is built from `SukiSU-Ultra/SukiSU_KernelPatch_patch` using its upstream `build.sh`. The CI wrapper only replaces the maintainer-specific hard-coded NDK path with the downloaded Android NDK r29 path. The NDK archive is SHA-1 checked before extraction.
5. The generated `patch_linux` is run against a temporary copy of `Image`; the original image is retained as `Image.pre-kpm` and only replaced if `oImage` is produced.

## Run

Open **Actions → Sapphire | GKI 5.15 | SukiSU Ultra SUSFS KPM → Run workflow**. Select `testing` or `stable`.

## Important compatibility warning

This workflow builds Android common GKI `android13-5.15-lts`, not the Xiaomi Sapphire vendor kernel. It does not build the device-specific DTBO, vendor modules, vendor_boot, or vendor kernel changes. The AnyKernel3 codename check does not establish device/ROM boot compatibility. Do not flash without a known-good recovery/fastboot path.

## Validation status

This ZIP is checked for shell syntax, Python syntax (if present), archive integrity, and internal path consistency. The full Android kernel compile, the upstream KernelPatch toolchain build, the exact `susfs-main` branch's compatibility with this Android common commit, and device boot have **not** been executed in this environment. GitHub Actions must confirm those stages; a successful compile still does not prove bootability.

## Upstream sources

- SukiSU Ultra: https://github.com/SukiSU-Ultra/SukiSU-Ultra
- SukiSU KernelPatch patch: https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch
- Android common kernel: https://android.googlesource.com/kernel/common
- Android NDK r29: https://github.com/android/ndk/releases/tag/r29

## Files to remove from an older checkout

After extracting this ZIP over the repository, delete the obsolete patch-relocation helpers listed in `REMOVE_OLD_FILES.txt`. They are intentionally not included in this package because the `susfs-main` branch supplies SUSFS directly.
