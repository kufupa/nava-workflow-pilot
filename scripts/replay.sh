#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PILOT_ROOT="$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-workflows.sh"
cd "${ROOT}/workflow-use/workflows"
WF="${1:?Usage: replay.sh path/to/workflow.json}"
pilot_workflows_prepare
exec .venv/bin/python cli.py run-workflow-no-ai "$WF"
