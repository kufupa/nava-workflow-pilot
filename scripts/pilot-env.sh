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

# EC2: reuse pre-installed Playwright Chromium at /opt/nava/playwright-browsers
if [[ -f /opt/nava/ec2-playwright-chromium/env.sh ]]; then
  # shellcheck disable=SC1091
  source /opt/nava/ec2-playwright-chromium/env.sh
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PILOT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Imprint: local data dir (sessions, emitted tools) — not ~/.imprint
export IMPRINT_HOME="${IMPRINT_HOME:-$PILOT_ROOT/imprint-data}"

# Bun (Windows Git Bash: common install locations)
export PATH="$HOME/.pnpm-global/bun:$HOME/.bun/bin:$PATH"

# Imprint compile: prefer local Claude CLI when teach/generate runs
export IMPRINT_PROVIDER="${IMPRINT_PROVIDER:-claude}"

PARENT_ENV="$(cd "$PILOT_ROOT/.." && pwd)/.env"
if [[ -f "$PARENT_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$PARENT_ENV"
  set +a
fi
