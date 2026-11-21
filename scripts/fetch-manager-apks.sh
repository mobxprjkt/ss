#!/usr/bin/env bash
# Optional APK fetcher for known upstream Actions artifacts.
set -Eeuo pipefail
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
mkdir -p manager_apks
fetch_apk() {
  local repo="$1" artifact_id="$2" label="$3"
  [[ -n "$artifact_id" ]] || { echo "[SKIP] No artifact ID for $label"; return 0; }
  local tmp; tmp="$(mktemp -d)"
  if ! curl -fLsS --retry 2 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${repo}/actions/artifacts/${artifact_id}/zip" -o "$tmp/artifact.zip"; then
    echo "[WARN] Could not download $label artifact" >&2; rm -rf "$tmp"; return 0
  fi
  if ! unzip -Z1 "$tmp/artifact.zip" | grep -Eiq '\.apk$'; then
    echo "[WARN] No APK found in $label artifact" >&2; rm -rf "$tmp"; return 0
  fi
  mkdir -p "$tmp/apks"
  unzip -j -o "$tmp/artifact.zip" '*.apk' -d "$tmp/apks" >/dev/null
  local apk; apk="$(find "$tmp/apks" -maxdepth 1 -type f -name '*.apk' -print -quit)"
  if [[ -n "$apk" ]]; then install -m 0644 "$apk" "manager_apks/${label}-$(basename "$apk")"; fi
  rm -rf "$tmp"
}
fetch_apk "SukiSU-Ultra/SukiSU-Ultra" "${SUKI_MANAGER_ARTIFACT_ID:-}" "sukisu-ultra"
fetch_apk "KernelSU-Next/KernelSU-Next" "${KSUN_MANAGER_ARTIFACT_ID:-}" "ksun"
