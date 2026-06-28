#!/usr/bin/env bash
# Verify record path starts on EC2 (no BROWSER_USE_API_KEY, no NameError).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
cd "$ROOT/workflow-use/workflows"
uv pip install -q 'playwright==1.52.0' pytest-asyncio 2>/dev/null || true

echo "[test-record-start] cli import + create-workflow-no-ai banner (15s timeout)..."
OUT="$(mktemp)"
set +e
timeout 15 xvfb-run -a -s '-screen 0 1280x720x24' .venv/bin/python cli.py create-workflow-no-ai >"$OUT" 2>&1
CODE=$?
set -e
cat "$OUT"

if grep -q "NameError: name 'llm_instance'" "$OUT"; then
  echo "FAIL: llm_instance NameError after skipping API key" >&2
  exit 1
fi
if ! grep -q "Starting semantic workflow recording session" "$OUT"; then
  echo "FAIL: never reached recording session start" >&2
  exit 1
fi
# timeout 124 = recording session started and blocked on browser (expected without human)
if [[ "$CODE" -ne 124 && "$CODE" -ne 0 ]]; then
  echo "FAIL: unexpected exit code $CODE" >&2
  exit 1
fi
echo "[test-record-start] OK"
