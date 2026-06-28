#!/usr/bin/env bash
# Preflight validation on NAVA EC2 — exit non-zero on first failure.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${HOME}/nava-logs"
LOG_FILE="${LOG_DIR}/pilot-preflight.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== pilot preflight $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "ROOT=$ROOT"

# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"

echo "[0/4] EC2 chromium env"
if [[ ! -f /opt/nava/ec2-playwright-chromium/env.sh ]]; then
  echo "FAIL: missing /opt/nava/ec2-playwright-chromium/env.sh" >&2
  exit 1
fi
# shellcheck disable=SC1091
source /opt/nava/ec2-playwright-chromium/env.sh
CHROME_BIN="$(find "${PLAYWRIGHT_BROWSERS_PATH}" -type f -name chrome -path '*/chrome-linux/*' 2>/dev/null | head -1 || true)"
if [[ -z "$CHROME_BIN" ]]; then
  echo "FAIL: no chromium binary under $PLAYWRIGHT_BROWSERS_PATH" >&2
  exit 1
fi
echo "OK: chromium=$CHROME_BIN"

echo "[1/4] validate.py (headless navigation)"
sudo bash -lc 'source /opt/nava/ec2-playwright-chromium/env.sh && /opt/nava/ec2-playwright-chromium/.venv/bin/python /opt/nava/ec2-playwright-chromium/validate.py'

echo "[2/4] extension build"
if [[ ! -d "$ROOT/workflow-use/extension/.output/chrome-mv3" ]]; then
  echo "FAIL: extension not built" >&2
  exit 1
fi
echo "OK: chrome-mv3 present"

echo "[3/4] recorder unit tests"
PILOT_ROOT="$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-workflows.sh"
pilot_workflows_prepare
cd "${PILOT_WORKFLOWS}"
uv pip install -q pytest-asyncio
.venv/bin/python -m pytest workflow_use/recorder/tests/ -q --asyncio-mode=auto

echo "[4/4] recorder_smoke (headed via xvfb)"
cd "${PILOT_WORKFLOWS}"
xvfb-run -a -s '-screen 0 1280x720x24' .venv/bin/python "$ROOT/scripts/recorder_smoke.py"

echo "=== pilot preflight PASSED ==="

echo "[bonus] record path start test"
bash "$ROOT/scripts/ec2-test-record-start.sh"
echo "=== record start test PASSED ==="
