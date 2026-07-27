#!/usr/bin/env bash
# Stop app + Docker services; remove caches, node_modules, venv, and unused Docker resources.
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
if [[ -f "${SCRIPT_DIR}/stop.sh" ]]; then
  bash "${SCRIPT_DIR}/stop.sh" 2>/dev/null || true
fi

pkill -f "${SCRIPT_DIR}/server.mjs" 2>/dev/null || true
pkill -f "vite --port 3000" 2>/dev/null || true
pkill -f "vite --port 3001" 2>/dev/null || true

for p in 3000 3001; do
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${p}/tcp" 2>/dev/null || true
  fi
done

# ---------------------------------------------------------------------------
# 2. Stop Docker containers and remove unused Docker resources
# ---------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  log "stopping Docker services…"

  if [[ -f docker-compose.yml ]] || [[ -f compose.yml ]]; then
    docker compose down --remove-orphans 2>/dev/null \
      || docker-compose down --remove-orphans 2>/dev/null \
      || true
  fi

  mapfile -t project_containers < <(
    docker ps -aq --filter "name=${PROJECT_NAME}" 2>/dev/null || true
  )
  if [[ ${#project_containers[@]} -gt 0 ]]; then
    docker stop "${project_containers[@]}" 2>/dev/null || true
    docker rm "${project_containers[@]}" 2>/dev/null || true
    log "removed ${#project_containers[@]} project container(s)"
  fi

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

  log "removing unused Docker containers, images, networks, builders…"
  docker container prune -f 2>/dev/null || true
  docker image prune -af 2>/dev/null || true
  docker network prune -f 2>/dev/null || true
  docker builder prune -af 2>/dev/null || true

  if [[ "$FULL_CLEAN" == "--full" ]]; then
    log "full Docker prune (volumes + system)…"
    docker volume prune -f 2>/dev/null || true
    docker system prune -af --volumes 2>/dev/null || true
  fi
else
  log "docker not available — skipping container cleanup"
fi

# ---------------------------------------------------------------------------
# 3. Remove node_modules, venv, pytest cache, .pyc, Istio files
# ---------------------------------------------------------------------------
log "removing node_modules, venv, pytest cache, pyc, istio files…"

find "$SCRIPT_DIR" -type d -name 'node_modules' -prune -exec rm -rf {} + 2>/dev/null || true
find "$SCRIPT_DIR" -type d \( -name 'venv' -o -name '.venv' -o -name 'env' \) -prune -exec rm -rf {} + 2>/dev/null || true
find "$SCRIPT_DIR" -type d -name '.pytest_cache' -prune -exec rm -rf {} + 2>/dev/null || true
find "$SCRIPT_DIR" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find "$SCRIPT_DIR" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true
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

# ---------------------------------------------------------------------------
# 5. Remove API keys / secrets env files
# ---------------------------------------------------------------------------
for envfile in .env .env.local .env.development .env.production .env.development.local .env.production.local; do
  if [[ -f "$envfile" ]]; then
    log "removing $envfile (may contain API keys/secrets)"
    rm -f "$envfile"
  fi
done

log "cleanup complete — sources retained in ${SCRIPT_DIR}"
echo "Usage: bash cleanup.sh          # standard cleanup"
echo "       bash cleanup.sh --full   # also prune all unused Docker volumes/system"
