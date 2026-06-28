#!/usr/bin/env bash
# Ship nava-workflow-pilot from laptop to EC2 via SSM, setup, preflight.
# RCA loop: re-run this script after local fixes — no git push until preflight green.
set -euo pipefail
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1

REGION="${AWS_REGION:-af-south-1}"
INSTANCE_ID="${INSTANCE_ID:-i-008f737974a9ba9b3}"
REMOTE_PILOT="/home/ubuntu/nava-workflow-pilot"
NAVA_CODE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PILOT_DIR="${PILOT_DIR:-${NAVA_CODE}/browser-automation-pilot}"
CHROMIUM_DEPLOY="${NAVA_CODE}/scripts/ec2-playwright-chromium/deploy-via-ssm.sh"

if command -v py >/dev/null 2>&1; then
  PY=(py -3)
elif command -v python >/dev/null 2>&1; then
  PY=(python)
else
  echo "no python for SSM JSON encoding" >&2
  exit 1
fi

json_status() {
  echo "$1" | "${PY[@]}" -c "import json,sys; data=sys.stdin.read(); start=data.find('{'); print(json.loads(data[start:])['Status'])"
}

send_ssm() {
  local comment="$1"
  local timeout="$2"
  shift 2
  local -a cmds=("$@")
  local params_json
  params_json="$("${PY[@]}" -c 'import json,sys; print(json.dumps({"commands": sys.argv[1:]}))' "${cmds[@]}")"
  local command_id
  command_id="$(aws ssm send-command \
    --region "${REGION}" \
    --instance-ids "${INSTANCE_ID}" \
    --document-name AWS-RunShellScript \
    --comment "${comment}" \
    --timeout-seconds "${timeout}" \
    --parameters "${params_json}" \
    --query 'Command.CommandId' \
    --output text)"
  echo "SSM ${command_id} (${comment})" >&2
  aws ssm wait command-executed \
    --region "${REGION}" \
    --command-id "${command_id}" \
    --instance-id "${INSTANCE_ID}" || true
  aws ssm get-command-invocation \
    --region "${REGION}" \
    --command-id "${command_id}" \
    --instance-id "${INSTANCE_ID}" \
    --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
    --output json
}

ensure_chromium() {
  echo "=== [0] verify EC2 chromium stack ==="
  local val_out status
  val_out="$(send_ssm "Chromium validate probe" 300 \
    "bash -lc 'test -f /opt/nava/ec2-playwright-chromium/env.sh && source /opt/nava/ec2-playwright-chromium/env.sh && /opt/nava/ec2-playwright-chromium/.venv/bin/python /opt/nava/ec2-playwright-chromium/validate.py'"
  )"
  echo "$val_out"
  status="$(json_status "$val_out")"
  if [[ "$status" == "Success" ]]; then
    echo "chromium stack OK"
    return 0
  fi
  echo "chromium validate failed ($status) — running bootstrap via deploy-via-ssm.sh" >&2
  if [[ ! -f "$CHROMIUM_DEPLOY" ]]; then
    echo "missing $CHROMIUM_DEPLOY" >&2
    exit 1
  fi
  AWS_REGION="$REGION" INSTANCE_ID="$INSTANCE_ID" bash "$CHROMIUM_DEPLOY"
}

b64_file() {
  local f="$1"
  if base64 --help 2>&1 | grep -q '\-w'; then
    base64 -w 0 "$f"
  else
    base64 "$f" | tr -d '\n'
  fi
}

# Local-only files overlaid on git clone (small — fits SSM; no 41MB tarball).
OVERLAY_FILES=(
  scripts/pilot-env.sh
  scripts/setup-ec2.sh
  scripts/ec2-verify-preflight.sh
  scripts/ec2-test-record-start.sh
  workflow-use/extension/src/lib/utils.ts
)

deploy_pilot() {
  echo "=== [1] clone/pull pilot + overlay local scripts ==="
  local out status
  out="$(send_ssm "Git clone nava-workflow-pilot" 300 \
    "sudo -u ubuntu git config --global --add safe.directory ${REMOTE_PILOT}" \
    "sudo -u ubuntu bash -lc 'if [[ -d ${REMOTE_PILOT}/.git ]]; then cd ${REMOTE_PILOT} && git fetch origin && git reset --hard origin/main; else git clone --depth 1 https://github.com/kufupa/nava-workflow-pilot.git ${REMOTE_PILOT}; fi'" \
    "sudo chown -R ubuntu:ubuntu ${REMOTE_PILOT}" \
    "ls -la ${REMOTE_PILOT}"
  )"
  echo "$out"
  status="$(json_status "$out")"
  if [[ "$status" != "Success" ]]; then
    echo "git clone/pull failed: $status" >&2
    exit 1
  fi

  local -a overlay_cmds=()
  local f b64 out status
  for f in "${OVERLAY_FILES[@]}"; do
    b64="$(b64_file "${PILOT_DIR}/${f}")"
    overlay_cmds=(
      "mkdir -p $(dirname ${REMOTE_PILOT}/${f})"
      "echo ${b64} | base64 -d > ${REMOTE_PILOT}/${f}"
      "sed -i 's/\\r$//' ${REMOTE_PILOT}/${f} 2>/dev/null || true"
    )
    out="$(send_ssm "Overlay ${f}" 120 "${overlay_cmds[@]}")"
    status="$(json_status "$out")"
    if [[ "$status" != "Success" ]]; then
      echo "overlay failed for ${f}: $status" >&2
      echo "$out"
      exit 1
    fi
  done
  out="$(send_ssm "Overlay chmod" 60 \
    "chmod +x ${REMOTE_PILOT}/scripts/*.sh" \
    "chown -R ubuntu:ubuntu ${REMOTE_PILOT}" \
    "ls -la ${REMOTE_PILOT}/scripts"
  )"
  echo "$out"
  status="$(json_status "$out")"
  if [[ "$status" != "Success" ]]; then
    echo "overlay failed: $status" >&2
    exit 1
  fi
}

run_setup() {
  if [[ "${SKIP_SETUP:-0}" == "1" ]]; then
    echo "=== [2] setup-ec2 SKIPPED (SKIP_SETUP=1) ==="
    return 0
  fi
  echo "=== [2] setup-ec2 ==="
  local out status
  out="$(send_ssm "Pilot setup-ec2" 1800 \
    "sudo -u ubuntu bash -lc 'cd ${REMOTE_PILOT} && bash scripts/setup-ec2.sh'"
  )"
  echo "$out"
  status="$(json_status "$out")"
  if [[ "$status" != "Success" ]]; then
    echo "setup-ec2 failed: $status" >&2
    exit 1
  fi
}

run_preflight() {
  echo "=== [3] ec2-verify-preflight ==="
  local out status
  out="$(send_ssm "Pilot preflight verify" 900 \
    "sudo -u ubuntu bash -lc 'cd ${REMOTE_PILOT} && bash scripts/ec2-verify-preflight.sh'"
  )"
  echo "$out"
  status="$(json_status "$out")"
  if [[ "$status" != "Success" ]]; then
    echo "preflight failed: $status" >&2
    exit 1
  fi
}

ensure_chromium
deploy_pilot
run_setup
run_preflight
echo "=== pilot deploy + preflight OK on ${INSTANCE_ID} ==="
