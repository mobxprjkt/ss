#!/usr/bin/env bash
# Install official SukiSU Ultra builtin branch and verify the exact resolved commit.
set -Eeuo pipefail
: "${KERNEL_SRC:?KERNEL_SRC is required}"

SUKISU_REPO="${SUKISU_REPO:-https://github.com/SukiSU-Ultra/SukiSU-Ultra.git}"
SUKISU_REF="${SUKISU_REF:-builtin}"
RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
mkdir -p "$RUNNER_TEMP"
KSU_REPO_DIR="$KERNEL_SRC/KernelSU"

if [[ -e "$KSU_REPO_DIR" && ! -d "$KSU_REPO_DIR/.git" ]]; then
  echo "[ERROR] $KSU_REPO_DIR exists but is not a Git checkout" >&2
  exit 1
fi
if [[ ! -d "$KSU_REPO_DIR/.git" ]]; then
  echo "[SukiSU Ultra] Cloning $SUKISU_REF"
  git clone --depth=1 --single-branch --branch "$SUKISU_REF" "$SUKISU_REPO" "$KSU_REPO_DIR"
fi

ORIGIN="$(git -C "$KSU_REPO_DIR" remote get-url origin)"
ORIGIN="${ORIGIN%.git}"
EXPECTED_ORIGIN="${SUKISU_REPO%.git}"
[[ "$ORIGIN" == "$EXPECTED_ORIGIN" ]] || {
  echo "[ERROR] SukiSU origin mismatch: expected $EXPECTED_ORIGIN, got $ORIGIN" >&2; exit 1;
}

# Resolve the branch/tag once, then pass the exact SHA to upstream setup.sh.
# This prevents its documented silent fallback from selecting another branch.
if [[ "$SUKISU_REF" =~ ^[0-9a-f]{40}$ ]]; then
  git -C "$KSU_REPO_DIR" fetch --depth=1 origin "$SUKISU_REF"
  RESOLVED_REF="$SUKISU_REF"
else
  git -C "$KSU_REPO_DIR" fetch --depth=1 origin "$SUKISU_REF"
  RESOLVED_REF="$(git -C "$KSU_REPO_DIR" rev-parse FETCH_HEAD)"
fi
# Keep the checkout on its branch: upstream setup.sh runs git pull before checking out RESOLVED_REF.

SETUP_URL="${SUKISU_SETUP_URL:-https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/$SUKISU_REF/kernel/setup.sh}"
curl --fail --location --retry 3 --retry-delay 2 --silent --show-error "$SETUP_URL" -o "$RUNNER_TEMP/sukisu-ultra-setup.sh"
cd "$KERNEL_SRC"
bash "$RUNNER_TEMP/sukisu-ultra-setup.sh" "$RESOLVED_REF"

ACTUAL="$(git -C "$KSU_REPO_DIR" rev-parse HEAD)"
[[ "$ACTUAL" == "$RESOLVED_REF" ]] || {
  echo "[ERROR] SukiSU setup selected $ACTUAL instead of $RESOLVED_REF" >&2; exit 1;
}
KSU_DIR="$KSU_REPO_DIR/kernel"
[[ -d "$KSU_DIR" ]] || { echo "[ERROR] SukiSU Ultra kernel directory missing" >&2; exit 1; }
for token in 'config KSU_SUSFS' 'config KPM'; do
  grep -qF "$token" "$KSU_DIR/Kconfig" || {
    echo "[ERROR] SukiSU Ultra source is missing $token" >&2; exit 1;
  }
done
# SukiSU Ultra's builtin tree places initialization in core/init.c on some
# revisions; do not assume the legacy kernel/ksu.c path.
SUSFS_INIT_FILE="$(grep -RIlE 'susfs_init[[:space:]]*\(' "$KSU_DIR" --include='*.c' --include='*.h' | head -n1 || true)"
[[ -n "$SUSFS_INIT_FILE" ]] || {
  echo "[ERROR] SukiSU Ultra source has no susfs_init() call in kernel C/H files" >&2; exit 1;
}
echo "[SukiSU Ultra] SUSFS init found in ${SUSFS_INIT_FILE#"$KSU_DIR/"}"

printf 'SUKISU_COMMIT=%s\n' "$ACTUAL" > "$WORK_DIR/sukisu-build-info.env"
echo "[SukiSU Ultra] Verified branch=$SUKISU_REF commit=$ACTUAL (SUSFS + KPM)"
