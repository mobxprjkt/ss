#!/usr/bin/env bash
# Build the official SukiSU Ultra KernelPatch patcher.
set -Eeuo pipefail
: "${WORK_DIR:=$(pwd)}"
KPM_REPO="${KPM_REPO:-https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch.git}"
KPM_REF="${KPM_REF:-main}"
KPM_DIR="${KPM_DIR:-$WORK_DIR/SukiSU_KernelPatch_patch}"
NDK_DIR="${ANDROID_NDK_HOME:-$WORK_DIR/AndroidNDK}"
NDK_ARCHIVE="${RUNNER_TEMP:-/tmp}/android-ndk-r29-linux.zip"
NDK_URL="${ANDROID_NDK_URL:-https://dl.google.com/android/repository/android-ndk-r29-linux.zip}"
NDK_SHA1="87e2bb7e9be5d6a1c6cdf5ec40dd4e0c6d07c30b"

if [[ ! -d "$KPM_DIR/.git" ]]; then
  git clone --depth=1 --single-branch --branch "$KPM_REF" "$KPM_REPO" "$KPM_DIR"
fi
git -C "$KPM_DIR" fetch --depth=1 origin "$KPM_REF"
if [[ "$KPM_REF" =~ ^[0-9a-f]{40}$ ]]; then
  EXPECTED_KPM_COMMIT="$KPM_REF"
else
  EXPECTED_KPM_COMMIT="$(git -C "$KPM_DIR" rev-parse FETCH_HEAD)"
fi
git -C "$KPM_DIR" checkout --detach "$EXPECTED_KPM_COMMIT"
ORIGIN="$(git -C "$KPM_DIR" remote get-url origin)"
ORIGIN="${ORIGIN%.git}"
EXPECTED_ORIGIN="${KPM_REPO%.git}"
[[ "$ORIGIN" == "$EXPECTED_ORIGIN" ]] || { echo "[ERROR] KernelPatch origin mismatch: $ORIGIN" >&2; exit 1; }
ACTUAL="$(git -C "$KPM_DIR" rev-parse HEAD)"
[[ "$ACTUAL" == "$EXPECTED_KPM_COMMIT" ]] || { echo "[ERROR] KernelPatch ref mismatch: expected $EXPECTED_KPM_COMMIT, got $ACTUAL" >&2; exit 1; }

if [[ ! -x "$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ]]; then
  echo "[KPM] Downloading Android NDK r29"
  curl --fail --location --retry 3 --retry-delay 3 "$NDK_URL" -o "$NDK_ARCHIVE"
  echo "$NDK_SHA1  $NDK_ARCHIVE" | sha1sum --check --status || {
    echo "[ERROR] Android NDK r29 SHA-1 verification failed" >&2; exit 1;
  }
  rm -rf "$NDK_DIR" "$WORK_DIR/ndk-unpack"
  mkdir -p "$(dirname "$NDK_DIR")" "$WORK_DIR/ndk-unpack"
  unzip -q "$NDK_ARCHIVE" -d "$WORK_DIR/ndk-unpack"
  mv "$WORK_DIR/ndk-unpack/android-ndk-r29" "$NDK_DIR"
  rm -rf "$WORK_DIR/ndk-unpack" "$NDK_ARCHIVE"
fi

[[ -f "$KPM_DIR/build.sh" ]] || { echo "[ERROR] Official KernelPatch build.sh not found" >&2; exit 1; }
# Upstream build.sh pins a maintainer-local NDK path; replace only that path in a CI copy.
sed "s|/root/other/ndk/android-ndk-r29|$NDK_DIR|g" "$KPM_DIR/build.sh" > "$KPM_DIR/build-ci.sh"
chmod 0755 "$KPM_DIR/build-ci.sh"
export ANDROID_NDK_HOME="$NDK_DIR" NDK_HOME="$NDK_DIR" ANDROID_NDK="$NDK_DIR"
export PATH="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
cd "$KPM_DIR"
bash "$KPM_DIR/build-ci.sh"
[[ -x "$KPM_DIR/patch_linux" ]] || { echo "[ERROR] KernelPatch did not produce patch_linux" >&2; exit 1; }
mkdir -p "$WORK_DIR/out"
printf 'KPM_SOURCE_COMMIT=%s\n' "$ACTUAL" > "$WORK_DIR/out/kpm-build-info.txt"
echo "[KPM] Official SukiSU Ultra patcher ready: $KPM_DIR/patch_linux"
