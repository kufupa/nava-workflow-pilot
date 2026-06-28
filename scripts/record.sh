#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PILOT_ROOT="$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-workflows.sh"
echo "Starting human teach session (create-workflow-no-ai)..."
echo "Chrome will open — click puzzle icon → browser-use-workflow-recorder → Start recording."
pilot_workflows_prepare
cd "${PILOT_WORKFLOWS}"
exec .venv/bin/python cli.py create-workflow-no-ai
