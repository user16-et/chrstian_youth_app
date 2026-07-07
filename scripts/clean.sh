#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf \
  "$ROOT/services/api/dist" \
  "$ROOT/apps/admin/.next" \
  "$ROOT/apps/mobile/build" \
  "$ROOT/apps/mobile/.dart_tool" \
  "$ROOT/.logs" \
  "$ROOT/.run"

printf "Removed generated build, cache, and runtime artifacts.\n"
