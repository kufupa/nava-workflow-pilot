#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"

SITE="${1:-nava-test}"
URL="${2:-https://example.com}"

mkdir -p "$IMPRINT_HOME"

echo "Starting imprint record: site=$SITE url=$URL"
echo "Drive the workflow in Chromium. Type /done in this terminal when finished."
cd "$ROOT/imprint"
exec bun src/cli.ts record "$SITE" --url "$URL"
