#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

BACKUP_DIR="${BACKUP_DIR:-/tmp/christian-super-app-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/christian_super_app_$TIMESTAMP.dump"

mkdir -p "$BACKUP_DIR"
pg_dump "$DATABASE_URL" --format=custom --compress=9 --no-owner --no-acl --file="$OUT"
sha256sum "$OUT" > "$OUT.sha256"
find "$BACKUP_DIR" -name 'christian_super_app_*.dump' -type f -mtime +"$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -name 'christian_super_app_*.dump.sha256' -type f -mtime +"$RETENTION_DAYS" -delete

printf '%s\n' "$OUT"
