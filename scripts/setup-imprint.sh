#!/usr/bin/env bash
# One-time imprint setup after git clone (Windows Git Bash or Linux).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"

mkdir -p "$IMPRINT_HOME"

echo "[setup-imprint] installing bun deps..."
cd "$ROOT/imprint"
bun install --frozen-lockfile

echo "[setup-imprint] installing Playwright Chromium..."
bunx playwright install chromium

echo "[setup-imprint] running doctor..."
bun src/cli.ts doctor

echo "[setup-imprint] done."
echo "Record: bash scripts/record-imprint.sh [site] [url]"
