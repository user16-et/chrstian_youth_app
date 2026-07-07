#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-3001}"
find_free_port() {
  local port="$1"
  while ss -ltn | awk -v target=":${port}" '$4 ~ target {found=1} END {exit !found}'; do
    port=$((port + 1))
  done
  printf '%s\n' "$port"
}

PORT="$(find_free_port "$PORT")"
if [[ "$PORT" != "3001" ]]; then
  echo "Port 3001 is occupied, using admin port $PORT."
fi

rm -rf .next
exec next dev --port "$PORT"
