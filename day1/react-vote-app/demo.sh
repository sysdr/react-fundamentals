#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT="${PORT:-3000}"
API_PORT="${API_PORT:-3001}"

base=""
for candidate in "http://127.0.0.1:${PORT}" "http://127.0.0.1:${API_PORT}"; do
  if curl -sf "${candidate}/api/health" >/dev/null 2>&1; then
    base="$candidate"
    break
  fi
done

if [[ -z "$base" ]]; then
  echo "[error] server not running. Start with: bash ${SCRIPT_DIR}/start.sh --serve"
  exit 1
fi

echo "[demo] posting /api/demo to ${base}"
before=$(curl -sf "${base}/api/metrics")
echo "[demo] before: $before"

after=$(curl -sf -X POST "${base}/api/demo")
echo "[demo] after:  $after"

# Validate non-zero / updated metrics
python3 - <<'PY' "$before" "$after"
import json, sys
before = json.loads(sys.argv[1])
payload = json.loads(sys.argv[2])
after = payload.get("metrics", payload)

checks = [
  ("totalVotes", after["totalVotes"] > before.get("totalVotes", 0)),
  ("clickEvents", after["clickEvents"] > before.get("clickEvents", 0)),
  ("mainThreadBlocks", after["mainThreadBlocks"] > 0),
  ("lastBlockDurationMs", after["lastBlockDurationMs"] > 0),
  ("uiFreezeDetected", after["uiFreezeDetected"] is True),
  ("responsivenessScore", after["responsivenessScore"] < 100),
  ("demoRuns", after["demoRuns"] > before.get("demoRuns", 0)),
]
failed = [name for name, ok in checks if not ok]
if failed:
    print("[FAIL] metrics not updated:", ", ".join(failed))
    print(json.dumps(after, indent=2))
    sys.exit(1)
print("[PASS] dashboard metrics updated by demo:")
for k in ["totalVotes","clickEvents","mainThreadBlocks","lastBlockDurationMs","uiFreezeDetected","responsivenessScore","demoRuns"]:
    print(f"  {k}: {after[k]}")
PY
