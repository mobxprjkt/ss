# Sapphire GKI 5.15 — SukiSU Ultra + SUSFS + KPM

Standalone GitHub Actions workflow for Xiaomi Redmi Note 13 4G (`sapphire` / `sapphiren`). It builds Android common GKI 5.15, integrates the official SukiSU Ultra `builtin` branch, applies the Android 13 / 5.15 SUSFS kernel patch, enables KPM, and packages an AnyKernel3 ZIP. It does not call a reusable workflow in `mobxprjkt/Kernul` and does not use `apply-update.sh` or `repair-ss.sh`.

## Source layout

- `KernelSource/` — Android common kernel source, `android13-5.15-lts`
- `ClangTool/` — Clang archive matching `CLANG_VERSION` in the kernel source
- `KernelSource/KernelSU/` — official SukiSU Ultra `builtin` branch
- `susfs4ksu/` — SUSFS 5.15 source and patch
- `SukiSU_KernelPatch_patch/` — official SukiSU Ultra KPM patcher source
- `AndroidNDK/` — Android NDK r29 used to build `patch_linux`
- `out/` — kernel output and release package

## SukiSU Ultra integration

This package uses `SukiSU-Ultra/SukiSU-Ultra`, branch `builtin`. The official integration guide documents `builtin` as the built-in integration branch and states that it carries the SUSFS options and `CONFIG_KPM`. The setup wrapper resolves the branch to an exact commit before invoking the upstream setup script, then verifies the final `KernelSU` checkout to prevent silent branch fallback. It also locates the SUSFS initialization call recursively, avoiding a false failure when Ultra stores it outside `kernel/ksu.c`.

The Ultra `builtin` Kconfig declares `CONFIG_KSU_SUSFS` and `CONFIG_KPM`; the setup checks for `susfs_init()` across the kernel C sources instead of assuming a fixed `ksu.c` path (the initialization file varies between source revisions). The configuration stage enables `CONFIG_KSU`, `CONFIG_KPM`, `CONFIG_KALLSYMS`, `CONFIG_KALLSYMS_ALL`, `CONFIG_KSU_SUSFS`, and all `CONFIG_KSU_SUSFS*` options actually declared by that checkout. It does not force a branch-specific inline-hook symbol that is absent from the official Ultra `builtin` Kconfig.

## SUSFS and KPM

SUSFS kernel-side integration uses `ndrancs/ShirkNeko_susfs4ksu`, branch `gki-android13-5.15`, pinned to commit `20d4ce65059bd99c2cf41cbde1ac90608ebdf16e`. The integration script checks the expected SukiSU Ultra SUSFS initialization and hook symbols, omits legacy `devpts` and `reboot` patch sections whose callback support is not part of this selected source layout, dry-runs the remaining patch before applying it, and relocates the `fs/namespace.c` declarations when the ACK include context differs.

KPM is built from the official `SukiSU-Ultra/SukiSU_KernelPatch_patch` repository. The builder resolves and records the exact `main` commit used, builds the patcher with Android NDK r29, and applies `patch_linux` to a temporary copy of `Image`. The unpatched image is preserved as `Image.pre-kpm` if the patcher succeeds.

## Run

Open **Actions → Sapphire | GKI 5.15 | SukiSU Ultra SUSFS KPM → Run workflow**. Select `testing` or `stable`.

## Compatibility warning

This workflow builds Android common GKI `android13-5.15-lts`, not the Xiaomi Sapphire vendor kernel. It does not build device-specific DTBO, vendor modules, vendor_boot, or Xiaomi vendor kernel changes. An AnyKernel3 codename check alone does not prove boot compatibility. Do not flash this package on a daily-use device without a known-good recovery/fastboot path and a matching device kernel baseline.

## Validation status

The ZIP is statically checked for Bash syntax, Python syntax, workflow metadata, ZIP integrity, and absence of updater/repair scripts. The full kernel compile, SUSFS patch dry-run against the exact ACK checkout, KPM toolchain build, and device boot test have not been run here. GitHub Actions must confirm those stages. A successful compile does not prove device bootability.

## Upstream references

- SukiSU Ultra: `https://github.com/SukiSU-Ultra/SukiSU-Ultra` — `builtin`
- SukiSU Ultra integration guide: `https://github.com/SukiSU-Ultra/SukiSU-Ultra/blob/main/docs/guide/how-to-integrate.md`
- SukiSU Ultra KPM patcher: `https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch` — `main`
- SUSFS source: `https://github.com/ndrancs/ShirkNeko_susfs4ksu` — `gki-android13-5.15`, `20d4ce65059bd99c2cf41cbde1ac90608ebdf16e`
- Android common kernel: `https://android.googlesource.com/kernel/common`, branch `android13-5.15-lts`

## Replacing older code

Extract this ZIP over the repository root and overwrite files with the same paths. Remove obsolete `scripts/apply-update.sh`, `scripts/repair-ss.sh`, `scripts/restore-susfs-context.py`, and old `scripts/apply-susfs-patch.py` if they are still present from earlier attempts. They are not used by this workflow.
