#!/usr/bin/env bash
# Fails when something that must never be committed appears in the tree.
#
# This is a cheap backstop, not a replacement for a real scanner. It looks for the
# specific credential shapes this project actually handles, because a generic
# high-entropy search on a repository full of UUID seed data is all false positives.
#
# What genuinely must never land:
#   · a Supabase service role key (bypasses RLS entirely)
#   · a Razorpay live secret
#   · an FCM server credential / Firebase admin private key
#   · a signing keystore
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Everything generated, vendored, or legitimately holding a *publishable* key.
EXCLUDES=(
  ':(exclude)node_modules/**'
  ':(exclude)**/node_modules/**'
  ':(exclude).git/**'
  ':(exclude)**/.next/**'
  ':(exclude)**/build/**'
  ':(exclude)**/.dart_tool/**'
  ':(exclude)package-lock.json'
  ':(exclude)**/pubspec.lock'
  ':(exclude)scripts/check-secrets.sh'
)

fail=0

report() {
  echo "::error::$1"
  fail=1
}

search() {
  local pattern="$1"
  git grep -nIE --untracked "$pattern" -- . "${EXCLUDES[@]}" 2>/dev/null || true
}

echo "Scanning for committed credentials…"

# ── Supabase service role ──────────────────────────────────────────────────
# The new-style secret key, and the legacy JWT whose payload declares the role.
hits="$(search 'sb_secret_[A-Za-z0-9_-]{16,}')"
if [[ -n "$hits" ]]; then
  report "A Supabase secret key appears to be committed:"
  echo "$hits"
fi

hits="$(search '"role"[[:space:]]*:[[:space:]]*"service_role"')"
# The seed and the test harness legitimately set this claim locally to impersonate
# the service role against a throwaway database; a real key is what we care about.
hits="$(echo "$hits" | grep -vE '^(supabase/seeds/|supabase/tests/|docs/)' || true)"
if [[ -n "$hits" ]]; then
  report "A service_role claim appears outside the seed and test harness:"
  echo "$hits"
fi

# ── Razorpay ───────────────────────────────────────────────────────────────
hits="$(search 'rzp_live_[A-Za-z0-9]{10,}')"
if [[ -n "$hits" ]]; then
  report "A Razorpay live key appears to be committed:"
  echo "$hits"
fi

hits="$(search 'RAZORPAY_KEY_SECRET[[:space:]]*[=:][[:space:]]*["'\'']?[A-Za-z0-9]{12,}')"
if [[ -n "$hits" ]]; then
  report "A Razorpay secret appears to have a value assigned:"
  echo "$hits"
fi

# ── Private keys of any kind ───────────────────────────────────────────────
hits="$(search 'BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY')"
if [[ -n "$hits" ]]; then
  report "A private key block is committed:"
  echo "$hits"
fi

# ── Firebase admin / FCM server credentials ────────────────────────────────
hits="$(search '"type"[[:space:]]*:[[:space:]]*"service_account"')"
if [[ -n "$hits" ]]; then
  report "A Google service account JSON is committed:"
  echo "$hits"
fi

# ── Files that must never be tracked ───────────────────────────────────────
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  report "A file that must stay local is tracked: $path"
done < <(git ls-files \
  '*.jks' '*.keystore' \
  'apps/mobile/android/key.properties' \
  'apps/mobile/env/prod.json' 'apps/mobile/env/staging.json' \
  'apps/mobile/ios/Flutter/Maps.xcconfig' \
  '**/google-services.json' '**/GoogleService-Info.plist' \
  'supabase/functions/.env' 2>/dev/null)

if [[ $fail -eq 0 ]]; then
  echo "No committed credentials found."
fi

exit $fail
