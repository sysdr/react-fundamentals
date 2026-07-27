#!/usr/bin/env bash
# Stop app services, Docker containers, and remove caches / artifacts for react-vote-app.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_NAME="react-vote-app"
FULL_CLEAN="${1:-}"

log() { echo "[cleanup] $*"; }

# ---------------------------------------------------------------------------
# 1. Stop local app services
# ---------------------------------------------------------------------------
log "stopping local services…"
if [[ -x "${SCRIPT_DIR}/stop.sh" ]]; then
  bash "${SCRIPT_DIR}/stop.sh" 2>/dev/null || true
fi

pkill -f "${SCRIPT_DIR}/server.mjs" 2>/dev/null || true
pkill -f "vite --port 3000" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 2. Stop Docker services (project + compose)
# ---------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  log "stopping Docker services…"

  if [[ -f docker-compose.yml ]]; then
    docker compose down --remove-orphans 2>/dev/null \
      || docker-compose down --remove-orphans 2>/dev/null \
      || true
  fi

  # Stop containers matching this project name
  mapfile -t project_containers < <(
    docker ps -aq --filter "name=${PROJECT_NAME}" 2>/dev/null || true
  )
  if [[ ${#project_containers[@]} -gt 0 ]]; then
    docker stop "${project_containers[@]}" 2>/dev/null || true
    docker rm "${project_containers[@]}" 2>/dev/null || true
    log "removed ${#project_containers[@]} project container(s)"
  fi

  # Stop any container publishing port 3000/3001 (this app's ports)
  for port in 3000 3001; do
    mapfile -t port_containers < <(
      docker ps -q --filter "publish=${port}" 2>/dev/null || true
    )
    if [[ ${#port_containers[@]} -gt 0 ]]; then
      docker stop "${port_containers[@]}" 2>/dev/null || true
      docker rm "${port_containers[@]}" 2>/dev/null || true
      log "stopped container(s) on port ${port}"
    fi
  done

  log "pruning unused Docker resources…"
  docker container prune -f 2>/dev/null || true
  docker image prune -f 2>/dev/null || true
  docker network prune -f 2>/dev/null || true
  docker builder prune -f 2>/dev/null || true

  if [[ "$FULL_CLEAN" == "--full" ]]; then
    log "full Docker prune (unused volumes)…"
    docker volume prune -f 2>/dev/null || true
    docker system prune -af 2>/dev/null || true
  fi
else
  log "docker not available — skipping container cleanup"
fi

# ---------------------------------------------------------------------------
# 3. Remove Python / Node / Istio artifacts
# ---------------------------------------------------------------------------
log "removing node_modules, venv, pytest cache, pyc, istio files…"

# node_modules (all levels under project)
find "$SCRIPT_DIR" -type d -name 'node_modules' -prune -exec rm -rf {} + 2>/dev/null || true

# Python virtual environments
find "$SCRIPT_DIR" -type d \( -name 'venv' -o -name '.venv' -o -name 'env' \) -prune -exec rm -rf {} + 2>/dev/null || true

# pytest cache
find "$SCRIPT_DIR" -type d -name '.pytest_cache' -prune -exec rm -rf {} + 2>/dev/null || true

# __pycache__ and .pyc / .pyo
find "$SCRIPT_DIR" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find "$SCRIPT_DIR" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true

# Istio manifests / directories
find "$SCRIPT_DIR" -type d \( -name 'istio' -o -name 'istio-system' \) -prune -exec rm -rf {} + 2>/dev/null || true
find "$SCRIPT_DIR" -type f \( -iname '*istio*.yaml' -o -iname '*istio*.yml' -o -iname 'istio*.json' \) -delete 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4. Remove build / temp / runtime artifacts
# ---------------------------------------------------------------------------
log "removing build and temp artifacts…"
rm -rf \
  dist \
  build \
  .vite \
  coverage \
  .turbo \
  .cache \
  .parcel-cache \
  .npm \
  .yarn \
  .metrics.json \
  .server.pid \
  .server.log \
  tmp \
  temp \
  .tmp \
  .temp \
  2>/dev/null || true

find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.log' -delete 2>/dev/null || true

# Remove secrets / env files with keys (never commit these)
for envfile in .env .env.local .env.development .env.production; do
  if [[ -f "$envfile" ]]; then
    log "removing $envfile (may contain secrets)"
    rm -f "$envfile"
  fi
done

log "cleanup complete — sources retained in ${SCRIPT_DIR}"
echo "Usage: bash cleanup.sh          # standard cleanup"
echo "       bash cleanup.sh --full   # also prune all unused Docker images/volumes"
