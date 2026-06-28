#!/usr/bin/env bash
# Source before workflow-use CLI runs (Windows Git Bash or Linux).
export PYTHONIOENCODING=utf-8
export LANG="${LANG:-en_US.UTF-8}"

# Windows console UTF-8 (no-op on Linux)
if [[ "$(uname -s 2>/dev/null)" == MINGW* ]] || [[ "$(uname -s 2>/dev/null)" == MSYS* ]]; then
  export PYTHONUTF8=1
fi

# Optional: override pilot Chrome profile directory (record + replay share this path).
# export RECORDER_USER_DATA_DIR="$HOME/.local/share/nava-workflow-profile"

# Optional EC2: reuse pre-installed Playwright browsers
# export PLAYWRIGHT_BROWSERS_PATH=/opt/nava/playwright-browsers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PILOT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_ENV="$(cd "$PILOT_ROOT/.." && pwd)/.env"
if [[ -f "$PARENT_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$PARENT_ENV"
  set +a
fi
