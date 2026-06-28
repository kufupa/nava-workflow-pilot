#!/usr/bin/env bash
# Shared workflow-use venv runner. Source from record.sh / replay.sh after pilot-env.sh.
# On EC2: pins playwright==1.52.0 to match /opt/nava/playwright-browsers (chromium-1169).
# Do NOT use `uv run` here — it reinstalls playwright 1.60 from the lockfile and breaks EC2.

pilot_workflows_prepare() {
  local root="${PILOT_ROOT:?set PILOT_ROOT before sourcing pilot-workflows.sh}"
  PILOT_WORKFLOWS="$root/workflow-use/workflows"
  export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:/usr/local/bin:/usr/local/uv:${PATH}"

  if [[ ! -x "${PILOT_WORKFLOWS}/.venv/bin/python" ]]; then
    echo "Missing Python venv at ${PILOT_WORKFLOWS}/.venv" >&2
    echo "Run once: bash scripts/setup-ec2.sh" >&2
    exit 1
  fi

  if [[ -z "${PLAYWRIGHT_BROWSERS_PATH:-}" ]] || [[ ! -d "${PLAYWRIGHT_BROWSERS_PATH}" ]]; then
    return 0
  fi

  local chrome
  chrome="$(find "${PLAYWRIGHT_BROWSERS_PATH}" -type f -name chrome -path '*/chrome-linux/*' 2>/dev/null | head -1 || true)"
  if [[ -z "$chrome" ]]; then
    echo "No chromium binary under PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH}" >&2
    echo "Run: sudo bash /opt/nava/ec2-playwright-chromium/bootstrap.sh" >&2
    exit 1
  fi

  if grep -q '"playwright>=' "${PILOT_WORKFLOWS}/pyproject.toml" 2>/dev/null; then
    sed -i.bak 's/"playwright>=[^"]*"/"playwright==1.52.0"/' "${PILOT_WORKFLOWS}/pyproject.toml"
  fi

  (cd "${PILOT_WORKFLOWS}" && uv pip install -q 'playwright==1.52.0')

  local ver
  ver="$("${PILOT_WORKFLOWS}/.venv/bin/python" -c 'import importlib.metadata as m; print(m.version("playwright"))' 2>/dev/null | tr -d ' ')"
  if [[ "$ver" != "1.52.0" ]]; then
    echo "Aligning playwright to 1.52.0 (had ${ver:-unknown}) for EC2 chromium..." >&2
    (cd "${PILOT_WORKFLOWS}" && uv pip install -q 'playwright==1.52.0' --reinstall-package playwright)
  fi

  echo "EC2 browser: ${chrome}"
  echo "Playwright driver: 1.52.0 (use this venv — not bare 'playwright install')"
}

pilot_python() {
  pilot_workflows_prepare
  cd "${PILOT_WORKFLOWS}"
  exec .venv/bin/python "$@"
}
