#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/toor/pro/chrstian_app"
RUN_DIR="$ROOT/.run/dev"

terminate_tree() {
  local pid="$1"
  local child
  while read -r child; do
    [[ -n "$child" ]] && terminate_tree "$child"
  done < <(pgrep -P "$pid" 2>/dev/null || true)
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
}

kill_pid_file() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file")
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      terminate_tree "$pid"
    fi
    rm -f "$pid_file"
  fi
}

kill_pid_file "$RUN_DIR/api.pid"
kill_pid_file "$RUN_DIR/worker.pid"
kill_pid_file "$RUN_DIR/admin.pid"
kill_pid_file "$RUN_DIR/mobile.pid"

docker compose down

echo "Stopped dev stack."
