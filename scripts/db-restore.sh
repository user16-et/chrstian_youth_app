#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "Usage: DATABASE_URL=... scripts/db-restore.sh /path/to/backup.dump" >&2
  exit 1
fi

BACKUP_FILE="$1"
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi
if [[ -f "$BACKUP_FILE.sha256" ]]; then
  sha256sum --check "$BACKUP_FILE.sha256"
fi

pg_restore --dbname="$DATABASE_URL" --clean --if-exists --no-owner --no-acl "$BACKUP_FILE"
