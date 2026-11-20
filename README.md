# Sapphire GKI 5.15 — SukiSU Ultra + SUSFS Extra

This ZIP is an **overlay/bootstrap pack**, not a complete kernel source tree.
It contains the dedicated GitHub Actions entry workflow and helper scripts for
the `mobxprjkt/Kernul` build layout.

## Target

- Device: Xiaomi Redmi Note 13 4G
- Codename: `sapphire` / `sapphiren`
- Kernel source family: Android Common Kernel `android13-5.15-lts`
- Root: SukiSU Ultra
- SUSFS: Android 13 / 5.15 patch series
- KPM: `CONFIG_KPM=y` plus the SukiSU KPM image patch stage
- Packaging: AnyKernel3

## Important: import the base repository first

The workflow intentionally reuses these existing files from the base project:

- `.github/workflows/build-kernel.yml`
- `.github/workflows/release.yml`
- `.github/actions/setup-env/`
- `.github/actions/setup-ksu/`
- `.github/actions/setup-configs/`
- `scripts/clone-source.sh`
- `scripts/setup-ksu.sh`
- `scripts/setup-configs.sh`
- `scripts/build.sh`
- `scripts/verify-kernel.sh`
- `scripts/pack-zip.sh`
- `scripts/resolve-versions.sh`
- `scripts/pack-release.sh`
- `scripts/fetch-manager-apks.sh` (this overlay provides a hardened replacement)

### Recommended setup

1. Create a new empty GitHub repository.
2. Import the full contents of `mobxprjkt/Kernul`, branch `testing-build`, into it.
3. Copy the files from this overlay over the imported repository, preserving paths.
4. Commit and push.
5. Open **Actions → GKI 5.15 | Sapphire | SukiSU Ultra → Run workflow**.
6. Start with `testing`, inspect the complete build logs, and only then consider `stable`.

Do not upload this overlay by itself and expect a kernel build: the reusable build
workflow and integration scripts listed above are supplied by the base project.

## Configuration checks before first build

The base reusable workflow must be audited to ensure:

- ccache restore/save runs for both `testing` and `stable` builds;
- SukiSU is integrated before Kconfig is resolved;
- the selected SUSFS patch is specifically for `gki-android13-5.15`;
- `CONFIG_KSU=y`, `CONFIG_KPROBES=y`, and `CONFIG_KPM=y` survive `olddefconfig`;
- the KPM patch step runs after the kernel image is built and before ZIP packaging;
- the AnyKernel3 installer checks `sapphire` and `sapphiren`;
- the produced ZIP contains the correct image and does not flash unrelated partitions.

## KPM helper

`scripts/apply-kpm.sh` is a fail-closed helper. It downloads the SukiSU patch
utility, works on a temporary copy, requires a non-empty `oImage`, and only then
replaces the requested image. Integrate it into the reusable build workflow after
kernel verification and before AnyKernel3 packaging:

```yaml
- name: Apply KPM
  if: inputs.ksu_type == 'suki'
  env:
    IMAGE: ${{ env.WORK_DIR }}/out/dist/Image
  run: bash scripts/apply-kpm.sh
```

Do not run both this helper and a second independent `patch_linux` step.

## Manager APKs

`scripts/fetch-manager-apks.sh` downloads APKs only when valid upstream artifact
IDs are supplied. It does not guess artifact IDs. The workflow's version resolver
must discover the latest successful upstream run and its artifact IDs, or the
corresponding environment variables must be supplied.

For private upstream artifacts, use a fine-grained GitHub token with Actions
read access to the relevant upstream repositories. Store it as a repository
secret, never in the workflow YAML.

## Device and boot safety

A generic GKI `Image` is not by itself proof of device compatibility. Confirm
the Sapphire boot image layout, vendor modules, KMI/ABI, DTB/DTBO handling,
AVB state, and ROM Android version. Keep a known-good stock boot image and
recovery path. First test on a spare/restore-capable setup; do not flash based
only on a successful CI compile.
