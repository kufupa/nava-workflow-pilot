#!/usr/bin/env bash
# One-time setup after git clone (Linux / Ubuntu EC2).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[setup-linux] building recorder extension..."
cd "$ROOT/workflow-use/extension"
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
npm run build

echo "[setup-linux] syncing Python env..."
cd "$ROOT/workflow-use/workflows"
uv sync
uv run python -m playwright install chromium --with-deps

echo "[setup-linux] done."
echo "From an xRDP desktop terminal (DISPLAY must be set):"
echo "  bash scripts/record.sh"
