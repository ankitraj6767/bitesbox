#!/usr/bin/env bash
# Runs the SQL test suite against the local Supabase stack.
#
#   supabase/tests/run.sh              # every suite
#   supabase/tests/run.sh 040          # only suites whose name contains "040"
#
# Each suite runs inside a transaction that rolls back, so the seed data is
# untouched and suites cannot leak fixtures into one another. The harness raises
# on the first failed assertion and psql runs with ON_ERROR_STOP=1, so a failure
# is a non-zero exit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="$ROOT/scripts/psql.sh"
TESTS_DIR="$ROOT/supabase/tests"
FILTER="${1:-}"

if [[ ! -x "$PSQL" ]]; then
  echo "scripts/psql.sh is missing or not executable" >&2
  exit 1
fi

echo "Installing test harness…"
if ! "$PSQL" -q -f "$TESTS_DIR/_harness.sql" >/dev/null 2>/dev/null; then
  echo "Could not install the test harness. Is the stack running (supabase start)?" >&2
  exit 1
fi

passed=0
failed=0
failed_names=()

for suite in "$TESTS_DIR"/*.test.sql; do
  name="$(basename "$suite")"

  if [[ -n "$FILTER" && "$name" != *"$FILTER"* ]]; then
    continue
  fi

  output="$("$PSQL" -q -t -A -f "$suite" 2>&1)"
  status=$?

  if [[ $status -eq 0 ]]; then
    echo "PASS  $name"
    passed=$((passed + 1))
  else
    echo "FAIL  $name"
    # Only the assertions and the failure; the void return of every helper call is
    # noise that buries the one line that matters.
    echo "$output" | grep -E "NOTICE|ERROR|FAILED|DETAIL|HINT" | sed 's/^/      /'
    failed=$((failed + 1))
    failed_names+=("$name")
  fi
done

echo
echo "──────────────────────────────────────────"
echo "  $passed passed, $failed failed"

if [[ $failed -gt 0 ]]; then
  printf '  failing: %s\n' "${failed_names[*]}"
  exit 1
fi
