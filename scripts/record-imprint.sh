#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"

SITE="${1:-nava-test}"
URL="${2:-https://example.com}"

mkdir -p "$IMPRINT_HOME"

echo "Starting imprint record: site=$SITE url=$URL" >&2
echo "Keep THIS Git Bash window focused to stop recording." >&2
echo "  /done   in this terminal  — stop and save" >&2
echo "  Ctrl+C  in this terminal  — stop and save" >&2
echo "  close Chromium window     — stop and save" >&2
echo "" >&2
cd "$ROOT/imprint"
exec bun src/cli.ts record "$SITE" --url "$URL"
