#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTGRES_HOST_PORT="${POSTGRES_HOST_PORT:-5433}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:${POSTGRES_HOST_PORT}/christian_super_app}"
SEED_PORT="${SEED_PORT:-3099}"
LOG_FILE="${TMPDIR:-/tmp}/christian-super-app-seed.log"

if [[ "${1:-}" != "--yes" ]]; then
  printf "This replaces the local christian_super_app schema and all local data.\n"
  printf "Run: npm run demo:reset -- --yes\n"
  exit 2
fi

command -v psql >/dev/null || { printf "psql is required.\n" >&2; exit 1; }
command -v curl >/dev/null || { printf "curl is required.\n" >&2; exit 1; }

cd "$ROOT"
POSTGRES_HOST_PORT="$POSTGRES_HOST_PORT" docker compose up -d postgres
until psql "$DATABASE_URL" -c "select 1" >/dev/null 2>&1; do sleep 1; done

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "drop schema public cascade; create schema public;" >/dev/null
for migration in services/api/database/migrations/*.sql; do
  printf "Applying %s\n" "$(basename "$migration")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
done

npm --workspace services/api run build >/dev/null
DATABASE_URL="$DATABASE_URL" PORT="$SEED_PORT" node services/api/dist/main.js >"$LOG_FILE" 2>&1 &
seed_pid=$!
cleanup() { kill "$seed_pid" >/dev/null 2>&1 || true; }
trap cleanup EXIT

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${SEED_PORT}/health" >/dev/null; then
    printf "Demo database reset and seeded.\n"
    printf "Demo login: 0910000001 / password123\n"
    exit 0
  fi
  if ! kill -0 "$seed_pid" >/dev/null 2>&1; then
    cat "$LOG_FILE" >&2
    exit 1
  fi
  sleep 1
done

cat "$LOG_FILE" >&2
printf "Timed out waiting for seed API.\n" >&2
exit 1
