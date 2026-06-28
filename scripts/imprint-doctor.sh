#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
cd "$ROOT/imprint"
exec bun src/cli.ts doctor
