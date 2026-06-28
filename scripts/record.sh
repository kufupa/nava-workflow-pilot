#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
cd "$ROOT/workflow-use/workflows"
echo "Starting human teach session (create-workflow-no-ai)..."
echo "Chrome will open — click puzzle icon → browser-use-workflow-recorder → Start recording."
uv run python cli.py create-workflow-no-ai
