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
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "version must use MAJOR.MINOR.PATCH format." >&2
  exit 2
fi
if [[ ! "$BUILD" =~ ^[1-9][0-9]*$ ]]; then
  echo "build must be a positive Android version code." >&2
  exit 2
fi
if [[ "$MANDATORY" != "true" && "$MANDATORY" != "false" ]]; then
  echo "mandatory must be true or false." >&2
  exit 2
fi

ORIGIN="${SUPABASE_URL%/}"
BUCKET="app-releases"
MANIFEST="update-manifest.json"
AUTH=(-H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")
API=(-H "apikey: $SUPABASE_SERVICE_ROLE_KEY")

sha256() { sha256sum "$1" | awk '{print $1}'; }

CURRENT="$(mktemp)"
UPDATED="$(mktemp)"
trap 'rm -f "$CURRENT" "$UPDATED"' EXIT

if ! STATUS="$(curl -sS "$ORIGIN/storage/v1/object/$BUCKET/$MANIFEST" \
  "${AUTH[@]}" "${API[@]}" -o "$CURRENT" -w '%{http_code}')"; then
  echo "Could not read the current Android update manifest." >&2
  exit 1
fi
case "$STATUS" in
  200)
    if ! jq -e 'type == "object" and ((.android? == null) or (.android | type == "object"))' "$CURRENT" >/dev/null; then
      echo "The current update manifest is invalid; refusing to replace it." >&2
      exit 1
    fi
    ;;
  404) echo '{}' > "$CURRENT" ;;
  *)
    echo "Reading the current update manifest returned HTTP $STATUS." >&2
    exit 1
    ;;
esac

CURRENT_VERSION="$(jq -r '.android.version // "0.0.0"' "$CURRENT")"
CURRENT_BUILD="$(jq -r '.android.buildNumber // 0' "$CURRENT")"
if ! python3 - "$VERSION" "$BUILD" "$CURRENT_VERSION" "$CURRENT_BUILD" <<'PY'
import re
import sys

new_version, new_build, current_version, current_build = sys.argv[1:]
version_pattern = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
new_match = version_pattern.fullmatch(new_version)
current_match = version_pattern.fullmatch(current_version)
if not new_match or not current_match or not current_build.isdigit():
    print("The current or requested release version is invalid.", file=sys.stderr)
    raise SystemExit(1)

if tuple(map(int, new_match.groups())) < tuple(map(int, current_match.groups())):
    print(
        f"Refusing to publish {new_version}; the current release is {current_version}.",
        file=sys.stderr,
    )
    raise SystemExit(1)
if int(new_build) <= int(current_build):
    print(
        f"Refusing build {new_build}; the published Android build is {current_build}. "
        "Android requires a higher version code for in-place updates.",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
then
  exit 1
fi

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
