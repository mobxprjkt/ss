# Sapphire GKI Standalone Build

Standalone GitHub Actions workflow for Xiaomi Redmi Note 13 4G (`sapphire` / `sapphiren`). It does not call reusable workflows or scripts from `mobxprjkt/Kernul`.

## Included

- Android common kernel `android13-5.15-lts`
- SukiSU Ultra integration
- SUSFS 5.15 patch and kernel support files
- KPM patch step
- `ccache`
- AnyKernel3 package using the Sapphire device checks from `superuseryu/AnyKernel3`
- Optional GitHub Release publishing

## Install

Copy these files and folders into the root of your `mobxprjkt/ss` repository, preserving the paths:

```text
.github/workflows/build-gki-sapphire.yml
scripts/build-gki.sh
scripts/apply-kpm.sh
scripts/restore-susfs-context.py
README.md
```

Then open **Actions → Sapphire | GKI 5.15 | SukiSU Ultra → Run workflow**.

Choose `testing` or `stable`. Disable `publish_release` if you only want the workflow artifact.

## Output

The workflow uploads an AnyKernel3 ZIP as an Actions artifact. If release publishing is enabled, the same ZIP is attached to a GitHub Release.

## Important compatibility note

This workflow builds the Android common GKI 5.15 kernel. It does not compile the Sapphire vendor kernel source, device-specific DTBO, vendor modules, or vendor boot images. A successful build is not proof that the image is compatible with every Sapphire ROM or firmware. Verify the target ROM's boot/vendor_boot layout and test with a recoverable boot method before flashing. The AnyKernel3 installer checks `sapphire` and `sapphiren`, but that check alone does not guarantee boot compatibility.

The SUSFS patch, SukiSU integration, KPM patcher, external Clang archive, and AnyKernel3 upstream are fetched during the workflow; their upstream contents can change. This package has only been syntax-checked locally, not compiled or boot-tested on a device.
