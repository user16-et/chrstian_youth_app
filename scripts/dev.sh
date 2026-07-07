#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/toor/pro/chrstian_app"
FLUTTER="$ROOT/.sdk/flutter/bin/flutter"
POSTGRES_HOST_PORT="${POSTGRES_HOST_PORT:-5432}"
REDIS_HOST_PORT="${REDIS_HOST_PORT:-6379}"
MEILI_HOST_PORT="${MEILI_HOST_PORT:-7700}"
MINIO_HOST_PORT="${MINIO_HOST_PORT:-9000}"
MINIO_CONSOLE_HOST_PORT="${MINIO_CONSOLE_HOST_PORT:-9001}"
export POSTGRES_HOST_PORT
export REDIS_HOST_PORT
export MEILI_HOST_PORT
export MINIO_HOST_PORT
export MINIO_CONSOLE_HOST_PORT
DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:${POSTGRES_HOST_PORT}/christian_super_app"
APP_DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:6432/christian_super_app"
APP_DATABASE_READ_URL="postgresql://postgres:postgres@127.0.0.1:6433/christian_super_app"
REDIS_URL="redis://127.0.0.1:${REDIS_HOST_PORT}"
SEARCH_PROVIDER="${SEARCH_PROVIDER:-meilisearch}"
MEILI_HOST="${MEILI_HOST:-http://127.0.0.1:${MEILI_HOST_PORT}}"
MEILI_MASTER_KEY="${MEILI_MASTER_KEY:-dev-master-key}"
SEARCH_INDEX_NAME="${SEARCH_INDEX_NAME:-global_search}"
MEDIA_STORAGE_PROVIDER="${MEDIA_STORAGE_PROVIDER:-minio}"
MEDIA_BUCKET="${MEDIA_BUCKET:-christian-super-app-media}"
MEDIA_REGION="${MEDIA_REGION:-us-east-1}"
MEDIA_ENDPOINT="${MEDIA_ENDPOINT:-}"
MEDIA_PUBLIC_BASE_URL="${MEDIA_PUBLIC_BASE_URL:-}"
MEDIA_ACCESS_KEY_ID="${MEDIA_ACCESS_KEY_ID:-minioadmin}"
MEDIA_SECRET_ACCESS_KEY="${MEDIA_SECRET_ACCESS_KEY:-minioadmin}"
MEDIA_FORCE_PATH_STYLE="${MEDIA_FORCE_PATH_STYLE:-true}"
REQUESTED_API_PORT="${API_PORT:-3000}"
API_PORT="$REQUESTED_API_PORT"
ADMIN_PORT="3001"
MOBILE_PORT="5173"

find_free_port() {
  local port="$1"
  while ss -ltn | awk -v target=":${port}" '$4 ~ target {found=1} END {exit !found}'; do
    port=$((port + 1))
  done
  printf '%s
' "$port"
}
LOG_DIR="$ROOT/.logs"
RUN_DIR="$ROOT/.run/dev"

mkdir -p "$LOG_DIR" "$RUN_DIR"

terminate_tree() {
  local pid="$1"
  local child
  while read -r child; do
    [[ -n "$child" ]] && terminate_tree "$child"
  done < <(pgrep -P "$pid" 2>/dev/null || true)
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
}

cleanup() {
  local pid
  while read -r pid; do
    [[ -n "$pid" ]] && terminate_tree "$pid"
  done < <(jobs -pr)
}
trap cleanup EXIT INT TERM

cd "$ROOT"

if [[ "$POSTGRES_HOST_PORT" == "5432" ]] && ss -ltn | awk '$4 ~ /:5432$/ {found=1} END {exit !found}'; then
  POSTGRES_HOST_PORT=5433
  DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:${POSTGRES_HOST_PORT}/christian_super_app"
  echo "Port 5432 is occupied, falling back to Postgres host port 5433."
fi

ADMIN_PORT="$(find_free_port "$ADMIN_PORT")"
if [[ "$ADMIN_PORT" != "3001" ]]; then
  echo "Port 3001 is occupied, using admin port $ADMIN_PORT."
fi

REQUESTED_MOBILE_PORT="$MOBILE_PORT"
MOBILE_PORT="$(find_free_port "$MOBILE_PORT")"
if [[ "$MOBILE_PORT" != "$REQUESTED_MOBILE_PORT" ]]; then
  echo "Port $REQUESTED_MOBILE_PORT is occupied, using mobile port $MOBILE_PORT."
fi

MINIO_HOST_PORT="$(find_free_port "$MINIO_HOST_PORT")"
MINIO_CONSOLE_HOST_PORT="$(find_free_port "$MINIO_CONSOLE_HOST_PORT")"
while [[ "$MINIO_CONSOLE_HOST_PORT" == "$MINIO_HOST_PORT" ]]; do
  MINIO_CONSOLE_HOST_PORT="$(find_free_port "$((MINIO_CONSOLE_HOST_PORT + 1))")"
done
export MINIO_HOST_PORT
export MINIO_CONSOLE_HOST_PORT
MEDIA_ENDPOINT="${MEDIA_ENDPOINT:-http://127.0.0.1:$MINIO_HOST_PORT}"
MEDIA_PUBLIC_BASE_URL="${MEDIA_PUBLIC_BASE_URL:-http://127.0.0.1:$MINIO_HOST_PORT/christian-super-app-media}"

API_PORT="$(find_free_port "$API_PORT")"
while [[ "$API_PORT" == "$ADMIN_PORT" || "$API_PORT" == "$MOBILE_PORT" ]]; do
  API_PORT="$(find_free_port "$((API_PORT + 1))")"
done
API_URL="http://127.0.0.1:$API_PORT"
if [[ "$API_PORT" != "$REQUESTED_API_PORT" ]]; then
  echo "Port $REQUESTED_API_PORT is occupied, using API port $API_PORT."
fi

docker compose up -d postgres
docker compose up -d pgbouncer-primary pgbouncer-replica
docker compose up -d redis
docker compose up -d meilisearch
docker compose up -d minio minio-init

if command -v psql >/dev/null 2>&1; then
  until psql "$DATABASE_URL" -c 'select 1' >/dev/null 2>&1; do
    sleep 1
  done
  if psql "$DATABASE_URL" -tAc "select to_regclass('public.users')" | grep -q 'users'; then
    echo "Schema already present, skipping base migration."
  else
    psql "$DATABASE_URL" -f services/api/database/migrations/001_init.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.prayer_requests')" | grep -q 'prayer_requests'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/002_engagement.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.courtship_profiles')" | grep -q 'courtship_profiles'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/003_courtship.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.bible_notes')" | grep -q 'bible_notes'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/004_bible_notes.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.group_memberships')" | grep -q 'group_memberships'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/005_groups.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.church_branches')" | grep -q 'church_branches'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/006_church_ecosystem.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.ministry_memberships')" | grep -q 'ministry_memberships'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/007_ministry_management.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.bible_daily_verses')" | grep -q 'bible_daily_verses'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/008_bible_ecosystem.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.post_comments')" | grep -q 'post_comments'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/009_social.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.church_follows')" | grep -q 'church_follows'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/010_follows.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.prayer_chains')" | grep -q 'prayer_chains'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/011_growth_prayer.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.opportunities')" | grep -q 'opportunities'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/012_discovery.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.church_announcements')" | grep -q 'church_announcements'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/013_youth_expansion.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.mentor_follows')" | grep -q 'mentor_follows'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/014_mentor_follows.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.notifications')" | grep -q 'notifications'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/015_platform_core.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.user_profiles')" | grep -q 'user_profiles'; then
    psql "$DATABASE_URL" -f services/api/database/migrations/016_believer_journey.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.conversations')" | grep -q 'conversations'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/017_connected_life.sql >/dev/null
  fi
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/018_connected_life_seed.sql >/dev/null
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.post_reactions')" | grep -q 'post_reactions'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/019_youth_social.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.church_verifications')" | grep -q 'church_verifications'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/020_church_operations.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.ministry_announcements')" | grep -q 'ministry_announcements'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/021_ministry_operations.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.community_discussions')" | grep -q 'community_discussions'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/022_community_network.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.event_volunteers')" | grep -q 'event_volunteers'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/023_events_engine.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.relationship_connections')" | grep -q 'relationship_connections'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/024_relationship_ecosystem.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.user_saved_content')" | grep -q 'user_saved_content'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/025_profile_identity.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.bible_versions')" | grep -q 'bible_versions'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/026_bible_study_ecosystem.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.api_audit_logs')" | grep -q 'api_audit_logs'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/027_production_foundation.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.posts_created_idx')" | grep -q 'posts_created_idx'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/028_query_performance_indexes.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.media_assets')" | grep -q 'media_assets'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/029_media_assets.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.feed_events')" | grep -q 'feed_events'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/030_database_production_design.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='posts' and column_name='like_count')" | grep -q 't'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/031_feed_social_scaling.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.notification_deliveries')" | grep -q 'notification_deliveries'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/032_notifications_system.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='media_assets' and column_name='scan_status')" | grep -q 't'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/033_security_trust.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select to_regclass('public.admin_sessions')" | grep -q 'admin_sessions'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/034_admin_auth.sql >/dev/null
  fi
  if ! psql "$DATABASE_URL" -tAc "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='seller_id')" | grep -q 't'; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f services/api/database/migrations/035_marketplace_seller_posts.sql >/dev/null
  fi
else
  echo "psql is not installed; apply services/api/database/migrations/001_init.sql manually before starting the API."
fi

npm --workspace packages/shared run build
npm --workspace services/api run build
npm --workspace services/worker run build

(
  cd "$ROOT"
  DATABASE_URL="$APP_DATABASE_URL" REDIS_URL="$REDIS_URL" SEARCH_PROVIDER="$SEARCH_PROVIDER" MEILI_HOST="$MEILI_HOST" MEILI_MASTER_KEY="$MEILI_MASTER_KEY" SEARCH_INDEX_NAME="$SEARCH_INDEX_NAME" npm --workspace services/worker run start
) >"$LOG_DIR/worker.log" 2>&1 &
WORKER_PID=$!
printf '%s
' "$WORKER_PID" > "$RUN_DIR/worker.pid"

echo "Worker running (pid $WORKER_PID, log $LOG_DIR/worker.log)"

(
  cd "$ROOT"
  PORT="$API_PORT" DATABASE_URL="$APP_DATABASE_URL" DATABASE_READ_URL="$APP_DATABASE_READ_URL" REDIS_URL="$REDIS_URL" MEDIA_STORAGE_PROVIDER="$MEDIA_STORAGE_PROVIDER" MEDIA_BUCKET="$MEDIA_BUCKET" MEDIA_REGION="$MEDIA_REGION" MEDIA_ENDPOINT="$MEDIA_ENDPOINT" MEDIA_PUBLIC_BASE_URL="$MEDIA_PUBLIC_BASE_URL" MEDIA_ACCESS_KEY_ID="$MEDIA_ACCESS_KEY_ID" MEDIA_SECRET_ACCESS_KEY="$MEDIA_SECRET_ACCESS_KEY" MEDIA_FORCE_PATH_STYLE="$MEDIA_FORCE_PATH_STYLE" SEARCH_PROVIDER="$SEARCH_PROVIDER" MEILI_HOST="$MEILI_HOST" MEILI_MASTER_KEY="$MEILI_MASTER_KEY" SEARCH_INDEX_NAME="$SEARCH_INDEX_NAME" npm --workspace services/api run start
) >"$LOG_DIR/api.log" 2>&1 &
API_PID=$!
printf '%s
' "$API_PID" > "$RUN_DIR/api.pid"

echo "API running at $API_URL (pid $API_PID, log $LOG_DIR/api.log)"

(
  cd "$ROOT"
  PORT="$ADMIN_PORT" API_BASE_URL="$API_URL" npm --workspace apps/admin run dev
) >"$LOG_DIR/admin.log" 2>&1 &
ADMIN_PID=$!
printf '%s
' "$ADMIN_PID" > "$RUN_DIR/admin.pid"

echo "Admin running at http://127.0.0.1:$ADMIN_PORT (pid $ADMIN_PID, log $LOG_DIR/admin.log)"

(
  cd "$ROOT/apps/mobile"
  "$FLUTTER" run -d web-server --web-port "$MOBILE_PORT" --dart-define=API_BASE_URL="$API_URL"
) >"$LOG_DIR/mobile.log" 2>&1 &
MOBILE_PID=$!
printf '%s
' "$MOBILE_PID" > "$RUN_DIR/mobile.pid"

echo "Flutter web running at http://127.0.0.1:$MOBILE_PORT (pid $MOBILE_PID, log $LOG_DIR/mobile.log)"

echo "Press Ctrl+C to stop all services."
wait
