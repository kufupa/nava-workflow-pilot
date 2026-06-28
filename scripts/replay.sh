#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
cd "$ROOT/workflow-use/workflows"
WF="${1:?Usage: replay.sh path/to/workflow.json}"
uv run python cli.py run-workflow-no-ai "$WF"
