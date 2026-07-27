#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT="${PORT:-3000}"
API_PORT="${API_PORT:-3001}"
PID_FILE="${SCRIPT_DIR}/.server.pid"

stop_pid() {
  local pid="$1"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 0.5
    kill -9 "$pid" 2>/dev/null || true
    echo "[ok] stopped pid $pid"
  fi
}

if [[ -f "$PID_FILE" ]]; then
  stop_pid "$(cat "$PID_FILE")"
  rm -f "$PID_FILE"
fi

# Also clear anything listening on our ports (vite children, duplicates)
for p in "$PORT" "$API_PORT"; do
  if command -v ss >/dev/null 2>&1; then
    pids=$(ss -tlnp 2>/dev/null | grep ":${p} " | grep -oP 'pid=\K[0-9]+' | sort -u || true)
    for pid in $pids; do
      stop_pid "$pid"
    done
  fi
  # fuser fallback
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${p}/tcp" 2>/dev/null || true
  fi
done

# Kill orphaned vite for this project
pkill -f "vite --port ${PORT}" 2>/dev/null || true
pkill -f "${SCRIPT_DIR}/server.mjs" 2>/dev/null || true

echo "[done] dashboard/server stopped"
