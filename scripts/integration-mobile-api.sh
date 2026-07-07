#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/toor/pro/chrstian_app"
FLUTTER="$ROOT/.sdk/flutter/bin/flutter"
API_URL="${API_URL:-http://127.0.0.1:3000}"
PHONE="${INTEGRATION_PHONE:-0910000000}"
PASSWORD="${INTEGRATION_PASSWORD:-password123}"
FIXTURE="$(mktemp)"
trap 'rm -f "$FIXTURE"' EXIT

if ! curl -fsS --max-time 5 "$API_URL/health" >/dev/null; then
  printf 'API is not available at %s. Run npm run dev first.\n' "$API_URL" >&2
  exit 1
fi

cd "$ROOT/apps/mobile"
"$FLUTTER" test test/api_frontend_integration_test.dart \
  --dart-define="INTEGRATION_API_URL=$API_URL" \
  --dart-define="INTEGRATION_PHONE=$PHONE" \
  --dart-define="INTEGRATION_PASSWORD=$PASSWORD"

auth="$(curl -fsS --max-time 10 \
  -H 'content-type: application/json' \
  -d "{\"phoneNumber\":\"$PHONE\",\"password\":\"$PASSWORD\"}" \
  "$API_URL/auth/login")"
token="$(printf '%s' "$auth" | jq -er '.token')"
curl -fsS --max-time 10 \
  -H "authorization: Bearer $token" \
  "$API_URL/connected-life/dashboard" >"$FIXTURE"

"$FLUTTER" test test/api_frontend_render_integration_test.dart \
  --dart-define="INTEGRATION_FIXTURE_PATH=$FIXTURE"
