#!/usr/bin/env bash
# Fetch APKs from known upstream Actions artifacts.
# Required: GITHUB_TOKEN
# Optional: KSUN_MANAGER_ARTIFACT_ID, KSUN_MANAGER_SPOOFED_ARTIFACT_ID,
#           SUKI_MANAGER_ARTIFACT_ID
set -Eeuo pipefail
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"

mkdir -p manager_apks

fetch_apk() {
  local repo="$1" artifact_id="$2" label="$3"
  [[ -n "$artifact_id" ]] || { echo "[SKIP] No artifact ID for $label"; return 0; }

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  if ! curl -fLsS --retry 2 \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${repo}/actions/artifacts/${artifact_id}/zip" \
      -o "$tmp/artifact.zip"; then
    echo "[WARN] Could not download $label artifact" >&2
    return 0
  fi

  if ! unzip -Z1 "$tmp/artifact.zip" | grep -Eiq '\.apk$'; then
    echo "[WARN] No APK found in $label artifact" >&2
    return 0
  fi

  unzip -j -o "$tmp/artifact.zip" '*.apk' -d "$tmp/apks" >/dev/null
  local apk
  apk="$(find "$tmp/apks" -maxdepth 1 -type f -name '*.apk' -print -quit)"
  [[ -n "$apk" ]] || { echo "[WARN] APK extraction failed for $label"; return 0; }

  local dest="manager_apks/${label}-$(basename "$apk")"
  install -m 0644 "$apk" "$dest"
  echo "[OK] $(basename "$dest")"
}

fetch_apk "SukiSU-Ultra/SukiSU-Ultra" "${SUKI_MANAGER_ARTIFACT_ID:-}" "sukisu"
fetch_apk "KernelSU-Next/KernelSU-Next" "${KSUN_MANAGER_ARTIFACT_ID:-}" "ksun"
fetch_apk "KernelSU-Next/KernelSU-Next" "${KSUN_MANAGER_SPOOFED_ARTIFACT_ID:-}" "ksun-spoofed"
