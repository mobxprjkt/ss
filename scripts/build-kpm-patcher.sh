#!/usr/bin/env bash
# Build patch_linux from SukiSU Ultra's official KernelPatch source repository.
set -Eeuo pipefail
: "${WORK_DIR:=$(pwd)}"
KPM_REPO="${KPM_REPO:-https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch.git}"
KPM_BRANCH="${KPM_BRANCH:-main}"
KPM_DIR="${KPM_DIR:-$WORK_DIR/SukiSU_KernelPatch_patch}"
NDK_DIR="${ANDROID_NDK_HOME:-$WORK_DIR/AndroidNDK}"
NDK_ARCHIVE="${RUNNER_TEMP:-/tmp}/android-ndk-r29-linux.zip"
NDK_URL="${ANDROID_NDK_URL:-https://dl.google.com/android/repository/android-ndk-r29-linux.zip}"
NDK_SHA1="87e2bb7e9be5d6a1c6cdf5ec40dd4e0c6d07c30b"

if [[ ! -d "$KPM_DIR/.git" ]]; then
  git clone --depth=1 --single-branch --branch "$KPM_BRANCH" "$KPM_REPO" "$KPM_DIR"
fi

if [[ ! -x "$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ]]; then
  mkdir -p "$WORK_DIR"
  echo "[KPM] Downloading Android NDK r29"
  curl --fail --location --retry 3 --retry-delay 3 "$NDK_URL" -o "$NDK_ARCHIVE"
  echo "$NDK_SHA1  $NDK_ARCHIVE" | sha1sum --check --status || {
    echo "[ERROR] Android NDK r29 SHA-1 verification failed" >&2; exit 1;
  }
  mkdir -p "$WORK_DIR/ndk-unpack"
  unzip -q "$NDK_ARCHIVE" -d "$WORK_DIR/ndk-unpack"
  mv "$WORK_DIR/ndk-unpack/android-ndk-r29" "$NDK_DIR"
  rm -rf "$WORK_DIR/ndk-unpack" "$NDK_ARCHIVE"
fi

[[ -f "$KPM_DIR/build.sh" ]] || { echo "[ERROR] Official KernelPatch build.sh not found" >&2; exit 1; }
# Upstream build.sh currently hard-codes a maintainer workstation NDK path.
# Rewrite only that path in a temporary copy; all build steps remain upstream.
UPSTREAM_BUILD="$KPM_DIR/build.sh"
CI_BUILD="$KPM_DIR/build-ci.sh"
sed "s|/root/other/ndk/android-ndk-r29|$NDK_DIR|g" "$UPSTREAM_BUILD" > "$CI_BUILD"
chmod 0755 "$CI_BUILD"

export ANDROID_NDK_HOME="$NDK_DIR" NDK_HOME="$NDK_DIR" ANDROID_NDK="$NDK_DIR"
export PATH="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
cd "$KPM_DIR"
bash "$CI_BUILD"

[[ -x "$KPM_DIR/patch_linux" ]] || {
  echo "[ERROR] Official KernelPatch build did not produce patch_linux" >&2
  exit 1
}

printf '%s\n' "KPM_SOURCE_COMMIT=$(git -C "$KPM_DIR" rev-parse HEAD)" > "$WORK_DIR/out/kpm-build-info.txt"
echo "[KPM] Official patcher ready: $KPM_DIR/patch_linux"
