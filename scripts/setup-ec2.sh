#!/usr/bin/env bash
# One-time setup on NAVA EC2 after pilot tree is present (uses /opt/nava Chromium).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/local/uv:$PATH"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"

echo "[setup-ec2] pilot root: $ROOT"

if [[ -z "${PLAYWRIGHT_BROWSERS_PATH:-}" ]]; then
  echo "[setup-ec2] WARN: PLAYWRIGHT_BROWSERS_PATH unset — sourcing /opt/nava env"
  if [[ -f /opt/nava/ec2-playwright-chromium/env.sh ]]; then
    # shellcheck disable=SC1091
    source /opt/nava/ec2-playwright-chromium/env.sh
  fi
fi

if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/v//' | cut -d. -f1)" -lt 18 ]]; then
  echo "[setup-ec2] installing Node 20..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo "[setup-ec2] node $(node -v) npm $(npm -v)"

echo "[setup-ec2] building recorder extension..."
cd "$ROOT/workflow-use/extension"
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
npm run build

if [[ ! -d .output/chrome-mv3 ]]; then
  echo "[setup-ec2] FAIL: extension build missing .output/chrome-mv3" >&2
  exit 1
fi

echo "[setup-ec2] syncing Python env (playwright==1.52.0 for EC2 browsers)..."
cd "$ROOT/workflow-use/workflows"
if ! command -v uv >/dev/null 2>&1; then
  echo "[setup-ec2] installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
echo "[setup-ec2] uv $(uv --version)"

if [[ -n "${PLAYWRIGHT_BROWSERS_PATH:-}" ]] && find "${PLAYWRIGHT_BROWSERS_PATH}" -maxdepth 1 -type d -name 'chromium-1169' 2>/dev/null | grep -q .; then
  echo "[setup-ec2] pinning playwright==1.52.0 in pyproject.toml (matches chromium-1169)"
  sed -i.bak 's/"playwright>=[^"]*"/"playwright==1.52.0"/' pyproject.toml
fi
uv sync
uv pip install 'playwright==1.52.0' pytest pytest-asyncio

CHROME_BIN="$(find "${PLAYWRIGHT_BROWSERS_PATH:-/opt/nava/playwright-browsers}" -type f -name chrome -path '*/chrome-linux/*' 2>/dev/null | head -1 || true)"
if [[ -n "$CHROME_BIN" ]]; then
  echo "[setup-ec2] reusing EC2 chromium: $CHROME_BIN"
else
  echo "[setup-ec2] no chromium under PLAYWRIGHT_BROWSERS_PATH — installing..."
  export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/nava/playwright-browsers}"
  uv run python -m playwright install chromium --with-deps
fi

echo "[setup-ec2] done."
