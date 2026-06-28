#!/usr/bin/env bash
# Verify record path on EC2: CLI starts + recorder Chrome launches (no chromium-1223 mismatch).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PILOT_ROOT="$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-workflows.sh"
pilot_workflows_prepare
cd "${PILOT_WORKFLOWS}"

echo "[test-record-start] cli banner (15s timeout)..."
OUT="$(mktemp)"
set +e
timeout 15 xvfb-run -a -s '-screen 0 1280x720x24' .venv/bin/python cli.py create-workflow-no-ai >"$OUT" 2>&1
CODE=$?
set -e
cat "$OUT"

if grep -q "NameError: name 'llm_instance'" "$OUT"; then
  echo "FAIL: llm_instance NameError" >&2
  exit 1
fi
if grep -qE 'chromium-1223|chrome-linux64' "$OUT"; then
  echo "FAIL: playwright driver/browser version mismatch (chromium-1223)" >&2
  exit 1
fi
if ! grep -q "Starting semantic workflow recording session" "$OUT"; then
  echo "FAIL: never reached recording session start" >&2
  exit 1
fi
if [[ "$CODE" -ne 124 && "$CODE" -ne 0 ]]; then
  echo "FAIL: unexpected cli exit code $CODE" >&2
  exit 1
fi

echo "[test-record-start] recorder_smoke (headed chromium + extension)..."
xvfb-run -a -s '-screen 0 1280x720x24' .venv/bin/python "$ROOT/scripts/recorder_smoke.py"

echo "[test-record-start] OK"
