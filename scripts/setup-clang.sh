#!/usr/bin/env bash
# Download the Clang release matching Android common's pinned CLANG_VERSION.
set -Eeuo pipefail

: "${KERNEL_SRC:?KERNEL_SRC is required}"
: "${WORK_DIR:=$(pwd)}"

CONSTANTS="$KERNEL_SRC/build.config.constants"
[[ -f "$CONSTANTS" ]] || { echo "[ERROR] Missing $CONSTANTS" >&2; exit 1; }

CLANG_VERSION="$(sed -n 's/^CLANG_VERSION=//p' "$CONSTANTS" | head -n1 | tr -d '"' | tr -d '\r')"
[[ -n "$CLANG_VERSION" ]] || {
  echo "[ERROR] CLANG_VERSION is not defined in $CONSTANTS" >&2
  exit 1
}

CLANG_BASE_URL="${CLANG_BASE_URL:-https://github.com/yurika-sudo/clang-repo/releases/download/clang-1}"
CLANG_DIR="${CLANG_DIR:-$WORK_DIR/ClangTool}"
ARCHIVE="${RUNNER_TEMP:-/tmp}/clang-${CLANG_VERSION}.tar.gz"

if [[ -x "$CLANG_DIR/bin/clang" ]]; then
  echo "[CLANG] Reusing $CLANG_DIR"
else
  mkdir -p "$CLANG_DIR"
  echo "[CLANG] Downloading pinned Clang $CLANG_VERSION"
  curl --fail --location --retry 3 --retry-delay 2 \
    "$CLANG_BASE_URL/clang-${CLANG_VERSION}.tar.gz" -o "$ARCHIVE"
  tar -xzf "$ARCHIVE" -C "$CLANG_DIR"
  rm -f "$ARCHIVE"
fi

[[ -x "$CLANG_DIR/bin/clang" ]] || {
  echo "[ERROR] clang binary not found under $CLANG_DIR/bin" >&2
  exit 1
}

echo "CLANG_DIR=$CLANG_DIR" >> "${GITHUB_ENV:-/dev/null}"
echo "[CLANG] Ready: $("$CLANG_DIR/bin/clang" --version | head -n1)"
