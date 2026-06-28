# EC2 pilot preflight — handoff

Preflight passed on `i-008f737974a9ba9b3` (af-south-1).

## Morning: human record

1. SSM tunnel → RDP `localhost:3390`
2. xRDP terminal (not SSM shell):
   ```bash
   cd ~/nava-workflow-pilot
   bash scripts/record.sh
   ```

## What was verified overnight

- `/opt/nava/playwright-browsers` Chromium (Playwright 1.52.0 / chromium-1169)
- Extension built at `workflow-use/extension/.output/chrome-mv3`
- Recorder unit tests (pytest)
- Headed recorder Chrome + extension via xvfb (`recorder_smoke.py`)

## Logs

- `~/nava-logs/pilot-preflight.log` on EC2

## Repos

- Pilot: https://github.com/kufupa/nava-workflow-pilot
- Fork: https://github.com/kufupa/workflow-use/tree/nava/recorder-fixes

## Redeploy from laptop

```bash
export AWS_REGION=af-south-1 INSTANCE_ID=i-008f737974a9ba9b3
cd browser-automation-pilot
bash scripts/ec2-deploy-preflight-via-ssm.sh
```
