#!/usr/bin/env bash
# Replay smoke: patch workflow extract step if missing, run run-workflow-no-ai, fail on step errors.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="${1:-workflow-use/workflows/tmp/3y_srn4b.semantic.workflow.yaml}"
PILOT_ROOT="$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-env.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/pilot-workflows.sh"
pilot_workflows_prepare
cd "${PILOT_WORKFLOWS}"

WF_PATH="$ROOT/$WF"
if [[ ! -f "$WF_PATH" ]]; then
  echo "FAIL: workflow not found: $WF_PATH" >&2
  exit 1
fi

# Ensure terminal extract step (schema requirement).
python3 - <<'PY' "$WF_PATH"
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    d = yaml.safe_load(f)
steps = d.get('steps') or []
if not steps or steps[-1].get('type') not in ('extract', 'extract_page_content'):
    steps.append({
        'description': 'Capture final page state',
        'type': 'extract_page_content',
        'goal': 'Extract page title and main visible text',
        'output': 'final_page',
    })
    d['steps'] = steps
    with open(path, 'w') as f:
        yaml.dump(d, f, sort_keys=False, default_flow_style=False)
    print('patched extract step')
else:
    print('extract step already present')
PY

# Rebuild from raw recording when present (restores per-step urls).
STEM="$(basename "$WF" .semantic.workflow.yaml)"
REC="$ROOT/workflow-use/workflows/tmp/temp_recording_${STEM}.json"
if [[ -f "$REC" ]]; then
  echo "[replay-test] rebuilding semantic yaml from $REC (preserves step urls)..."
  REC="$REC" OUT="$WF_PATH" python3 - <<'PY'
import json, os, sys, yaml
rec_path = os.environ['REC']
out_path = os.environ['OUT']
with open(rec_path) as f:
    rec = json.load(f)
steps = []
for s in rec.get('steps') or []:
    st = {'description': s.get('description') or f"{s.get('type')} step", 'type': s.get('type')}
    if s.get('url'):
        st['url'] = s['url']
    if s.get('target_text'):
        st['target_text'] = s['target_text']
    elif s.get('elementText'):
        st['target_text'] = s['elementText']
    if s.get('type') == 'navigation' and s.get('url'):
        st['url'] = s['url']
    steps.append(st)
if not steps or steps[-1].get('type') not in ('extract', 'extract_page_content'):
    steps.append({
        'description': 'Capture final page state',
        'type': 'extract_page_content',
        'goal': 'Extract page title and main visible text',
        'output': 'final_page',
    })
doc = {
    'workflow_analysis': rec.get('workflow_analysis', 'Replay test workflow'),
    'name': rec.get('name', 'Recorded Workflow'),
    'description': rec.get('description', 'EC2 replay test'),
    'version': '1.0',
    'steps': steps,
    'input_schema': [],
}
with open(out_path, 'w') as f:
    yaml.dump(doc, f, sort_keys=False, default_flow_style=False)
print(f'rebuilt {len(steps)} steps -> {out_path}')
PY
fi

LOG="${HOME}/nava-logs/replay-test.log"
mkdir -p "${HOME}/nava-logs"
echo "[replay-test] running $WF_PATH (log: $LOG)"
set +e
timeout 300 xvfb-run -a -s '-screen 0 1280x720x24' .venv/bin/python cli.py run-workflow-no-ai "$WF_PATH" >"$LOG" 2>&1
CODE=$?
set -e
grep -E '^(INFO|ERROR|Loading|Workflow|Running workflow|No selector|Unsupported step|Workflow execution)' "$LOG" | tail -40 || true
tail -8 "$LOG" || true

if grep -q 'Error loading workflow' "$LOG"; then
  echo "FAIL: workflow schema/load error" >&2
  exit 1
fi
if grep -qE 'No selector available|Unsupported step type' "$LOG"; then
  echo "FAIL: replay step error (see $LOG)" >&2
  exit 1
fi
if ! grep -q 'Workflow execution completed' "$LOG"; then
  echo "FAIL: replay did not complete (exit $CODE)" >&2
  exit 1
fi
echo "[replay-test] OK"
