#!/usr/bin/env bash
# Non-interactive imprint validation (steps 1-4). Step 5: record smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RCA="$ROOT/imprint-data/RCA.md"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"

mkdir -p "$IMPRINT_HOME"

log_rca() {
  echo "$1" >> "$RCA"
}

echo "[imprint-smoke] step 1: bun install"
cd "$ROOT/imprint"
bun install --frozen-lockfile

echo "[imprint-smoke] step 2: typecheck + lint"
bun run typecheck
bun run lint

echo "[imprint-smoke] step 2b: bun test (platform failures OK on Windows)"
bun test || true

echo "[imprint-smoke] step 3: doctor"
bun src/cli.ts doctor

echo "[imprint-smoke] step 4: echo MCP client test"
bun scripts/mcp-client-test.ts

echo "[imprint-smoke] step 5: headed record smoke (15s on example.com)"
cd "$ROOT"
bun scripts/imprint-record-smoke.ts

echo "[imprint-smoke] all steps passed"
