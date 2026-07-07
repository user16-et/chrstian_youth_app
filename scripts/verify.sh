#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/toor/pro/chrstian_app"
FLUTTER="$ROOT/.sdk/flutter/bin/flutter"
MOBILE="$ROOT/apps/mobile"

cd "$ROOT"

npm --workspace services/api run build
npm --workspace services/api run lint
npm --workspace apps/admin run build
cd "$MOBILE"
"$FLUTTER" analyze
"$FLUTTER" build web
"$FLUTTER" build apk --debug
