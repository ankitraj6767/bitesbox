#!/usr/bin/env bash
# Runs `supabase db lint` and fails the build on error-level findings.
#
# Why this wrapper exists.
#
# `supabase db lint` prints its findings and exits 0 regardless of severity. That
# is reasonable — most of what it reports is stylistic — but it means an *error*
# finding scrolls past in CI and nobody notices.
#
# Two of them turned out to be functions that threw on every single call:
#
#   public.search_suggestions   42803  "p.order_count" must appear in the GROUP BY
#   public.svc_audit            42804  actor_kind is an enum, expression was text
#
# `search_suggestions` is called by the customer search screen, so search was
# broken for every user including guests. Both installed cleanly through
# `supabase db reset`, because a plpgsql body is only resolved when it runs. The
# linter is the only thing in the toolchain that looks inside a function body
# before a user does, so its error findings are treated as build failures here.
#
# Warnings are still only printed. There are legitimate ones in this schema —
# `require_permission` is STABLE but calls a VOLATILE raise, unused loop variables
# in the code generators — and failing on those would mean disabling the whole
# check within a week.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LEVEL="${1:-warning}"
OUTPUT="$(mktemp)"
trap 'rm -f "$OUTPUT"' EXIT

echo "Linting the schema (reporting at: $LEVEL, failing on: error)…"

if ! supabase db lint --level "$LEVEL" > "$OUTPUT" 2>&1; then
  echo "::error::supabase db lint could not run. Is the local stack up?"
  cat "$OUTPUT"
  exit 1
fi

cat "$OUTPUT"

# The JSON is pretty-printed one key per line, so a line match is enough and
# avoids a jq dependency.
errors="$(grep -c '"level": "error"' "$OUTPUT" || true)"

if [[ "$errors" -gt 0 ]]; then
  echo
  echo "──────────────────────────────────────────"
  echo "::error::$errors error-level finding(s). These are functions that will"
  echo "         throw when called, not style problems. The function names are in"
  echo "         the output above, each directly before its \"issues\" block."
  exit 1
fi

echo
echo "──────────────────────────────────────────"
echo "  No error-level findings."
