#!/usr/bin/env bash
# Runs SQL against the local Supabase Postgres.
#
#   scripts/psql.sh -c "select 1"
#   scripts/psql.sh -q -f supabase/tests/010_rbac_rls.test.sql
#   echo "select 1" | scripts/psql.sh
#
# Two transports, tried in order:
#
#   1. A psql binary on PATH, against SUPABASE_DB_URL. This is what CI uses, and
#      what a developer with libpq installed gets.
#   2. `docker exec` into the stack's own database container, which always has
#      psql. The container is found by Supabase's own label rather than by a
#      hard-coded name, because the name is derived from the project directory.
#
# A -f path is resolved on the host and streamed over stdin, so it works
# identically through either transport.
set -uo pipefail

DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

args=()
file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f | --file)
      file="$2"
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$file" && ! -f "$file" ]]; then
  echo "No such SQL file: $file" >&2
  exit 1
fi

# bash 3.2 (macOS) treats an empty array as unbound under `set -u`.
expand_args() { printf '%s\n' ${args[@]+"${args[@]}"}; }

run_with_psql() {
  if [[ -n "$file" ]]; then
    psql "$DB_URL" -v ON_ERROR_STOP=1 ${args[@]+"${args[@]}"} <"$file"
  else
    psql "$DB_URL" -v ON_ERROR_STOP=1 ${args[@]+"${args[@]}"}
  fi
}

run_with_docker() {
  local container="${SUPABASE_DB_CONTAINER:-}"

  if [[ -z "$container" ]]; then
    # Supabase labels its database container; fall back to a name match.
    container="$(docker ps --filter 'label=com.supabase.cli.project' \
      --filter 'name=supabase_db' --format '{{.Names}}' | head -1)"
  fi

  if [[ -z "$container" ]]; then
    container="$(docker ps --format '{{.Names}}' | grep '^supabase_db' | head -1)"
  fi

  if [[ -z "$container" ]]; then
    echo "No Supabase database container is running, and psql is not installed." >&2
    echo "Start the stack with: supabase start" >&2
    exit 1
  fi

  if [[ -n "$file" ]]; then
    docker exec -i "$container" psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 ${args[@]+"${args[@]}"} <"$file"
  else
    docker exec -i "$container" psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 ${args[@]+"${args[@]}"}
  fi
}

if command -v psql >/dev/null 2>&1; then
  run_with_psql
  exit $?
fi

if command -v docker >/dev/null 2>&1; then
  run_with_docker
  exit $?
fi

echo "Neither psql nor docker is available." >&2
exit 1
