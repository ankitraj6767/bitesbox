#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is required}"

VERSION=""
BUILD=""
NOTES=""
MANDATORY="false"
ARM64=""
ARMV7=""
X64=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --build) BUILD="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    --mandatory) MANDATORY="$2"; shift 2 ;;
    --arm64) ARM64="$2"; shift 2 ;;
    --armv7) ARMV7="$2"; shift 2 ;;
    --x64) X64="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$VERSION" || -z "$BUILD" || -z "$ARM64" || -z "$ARMV7" || -z "$X64" ]]; then
  echo "version, build and all split APK paths are required." >&2
  exit 2
fi

ORIGIN="${SUPABASE_URL%/}"
BUCKET="app-releases"
MANIFEST="update-manifest.json"
AUTH=(-H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")
API=(-H "apikey: $SUPABASE_SERVICE_ROLE_KEY")

sha256() { sha256sum "$1" | awk '{print $1}'; }

upload() {
  local file="$1" name="$2" size hash
  [[ -f "$file" ]] || { echo "Missing artifact: $file" >&2; exit 1; }
  size="$(stat -c '%s' "$file")"
  if (( size >= 52428800 )); then
    echo "$name exceeds the 50 MB Supabase Free-plan upload limit." >&2
    exit 1
  fi
  hash="$(sha256 "$file")"
  curl -fsSL -X POST "$ORIGIN/storage/v1/object/$BUCKET/$name" \
    "${AUTH[@]}" "${API[@]}" \
    -H 'x-upsert: true' \
    -H 'Cache-Control: public, max-age=31536000, immutable' \
    -H 'Content-Type: application/vnd.android.package-archive' \
    --data-binary "@$file" -o /dev/null
  printf '%s\n' "$hash"
}

ARM64_NAME="bitesbox-android-v${VERSION}-${BUILD}-arm64-v8a.apk"
ARMV7_NAME="bitesbox-android-v${VERSION}-${BUILD}-armeabi-v7a.apk"
X64_NAME="bitesbox-android-v${VERSION}-${BUILD}-x86_64.apk"
ARM64_HASH="$(upload "$ARM64" "$ARM64_NAME")"
ARMV7_HASH="$(upload "$ARMV7" "$ARMV7_NAME")"
X64_HASH="$(upload "$X64" "$X64_NAME")"

CURRENT="$(mktemp)"
UPDATED="$(mktemp)"
trap 'rm -f "$CURRENT" "$UPDATED"' EXIT

if ! curl -fsSL "$ORIGIN/storage/v1/object/$BUCKET/$MANIFEST" \
  "${AUTH[@]}" "${API[@]}" -o "$CURRENT" 2>/dev/null || ! jq empty "$CURRENT" >/dev/null 2>&1; then
  echo '{}' > "$CURRENT"
fi

jq \
  --arg version "$VERSION" --argjson build "$BUILD" --arg notes "$NOTES" \
  --argjson mandatory "$MANDATORY" \
  --arg arm64Url "$ORIGIN/storage/v1/object/public/$BUCKET/$ARM64_NAME" \
  --arg arm64Hash "$ARM64_HASH" --arg arm64File "$ARM64_NAME" \
  --arg armv7Url "$ORIGIN/storage/v1/object/public/$BUCKET/$ARMV7_NAME" \
  --arg armv7Hash "$ARMV7_HASH" --arg armv7File "$ARMV7_NAME" \
  --arg x64Url "$ORIGIN/storage/v1/object/public/$BUCKET/$X64_NAME" \
  --arg x64Hash "$X64_HASH" --arg x64File "$X64_NAME" \
  '.android = {
    version: $version,
    buildNumber: $build,
    notes: $notes,
    mandatory: $mandatory,
    artifacts: [
      {abi: "arm64-v8a", url: $arm64Url, sha256: $arm64Hash, fileName: $arm64File},
      {abi: "armeabi-v7a", url: $armv7Url, sha256: $armv7Hash, fileName: $armv7File},
      {abi: "x86_64", url: $x64Url, sha256: $x64Hash, fileName: $x64File}
    ]
  } | .updatedAt = (now | todate)' "$CURRENT" > "$UPDATED"

curl -fsSL -X POST "$ORIGIN/storage/v1/object/$BUCKET/$MANIFEST" \
  "${AUTH[@]}" "${API[@]}" \
  -H 'x-upsert: true' -H 'Cache-Control: no-cache' \
  -H 'Content-Type: application/json' --data-binary "@$UPDATED" -o /dev/null

echo "Published Bites Box Android $VERSION+$BUILD."
