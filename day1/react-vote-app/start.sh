#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT="${PORT:-3000}"
API_PORT="${API_PORT:-3001}"
PID_FILE="${SCRIPT_DIR}/.server.pid"
LOG_FILE="${SCRIPT_DIR}/.server.log"
MODE="${1:-}"

usage() {
  echo "Usage: bash start.sh [--serve|--demo|--test|--dev]"
  echo "  --serve   start dashboard + metrics API (default)"
  echo "  --demo    run demo against running server (or start then demo)"
  echo "  --test    run vitest suite"
  echo "  --dev     force Vite dev + API"
}

is_listening() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tln 2>/dev/null | grep -q ":${p} "
  else
    (echo >/dev/tcp/127.0.0.1/"$p") >/dev/null 2>&1
  fi
}

count_listeners() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | grep -c ":${p} " || true
  else
    echo 0
  fi
}

wait_healthy() {
  local tries=40
  for i in $(seq 1 "$tries"); do
    if curl -sf "http://127.0.0.1:${API_PORT}/api/health" >/dev/null 2>&1 \
      || curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

start_server() {
  if is_listening "$PORT"; then
    local n
    n="$(count_listeners "$PORT")"
    echo "[warn] port ${PORT} already in use (listeners≈${n}). Checking health…"
    if curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1 \
      || curl -sf "http://127.0.0.1:${API_PORT}/api/health" >/dev/null 2>&1; then
      echo "[ok] existing healthy service on port ${PORT}/${API_PORT} — not starting duplicate"
      return 0
    fi
    echo "[error] port ${PORT} busy but not healthy. Run: bash stop.sh"
    exit 1
  fi

  if [[ ! -d node_modules ]]; then
    echo "[info] installing dependencies…"
    npm install
  fi

  # Prefer built static serve when dist exists
  if [[ -f dist/index.html ]]; then
    export SERVE_MODE=static
    export PORT
    nohup node server.mjs >"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
  else
    export SERVE_MODE=dev
    export PORT
    export API_PORT
    nohup node server.mjs >"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
  fi

  if wait_healthy; then
    echo "[ok] dashboard at http://127.0.0.1:${PORT}"
    echo "[ok] metrics API healthy"
  else
    echo "[error] server failed to become healthy. See $LOG_FILE"
    tail -n 40 "$LOG_FILE" || true
    exit 1
  fi
}

case "${MODE}" in
  ""|"--serve"|"serve")
    start_server
    ;;
  "--demo"|"demo")
    if ! curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1 \
      && ! curl -sf "http://127.0.0.1:${API_PORT}/api/health" >/dev/null 2>&1; then
      start_server
    fi
    bash "${SCRIPT_DIR}/demo.sh"
    ;;
  "--test"|"test")
    npm test
    ;;
  "--dev"|"dev")
    export SERVE_MODE=dev
    start_server
    ;;
  "-h"|"--help")
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
