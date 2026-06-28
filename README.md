# Browser Automation Pilot

Teach-once / replay-many browser workflows using patched [workflow-use](https://github.com/browser-use/workflow-use) (NAVA recorder fixes).

## Quick start (Linux / Ubuntu EC2)

Prerequisites: `git`, Node 20+, `uv`, xRDP desktop for recording (headed Chrome needs `DISPLAY`).

```bash
git clone https://github.com/aa6622/nava-workflow-pilot.git
cd nava-workflow-pilot
bash scripts/setup-linux.sh
# From xRDP terminal only:
bash scripts/record.sh
bash scripts/replay.sh workflow-use/workflows/tmp/your.semantic.workflow.yaml
```

Optional on EC2 if Playwright browsers already exist:

```bash
export PLAYWRIGHT_BROWSERS_PATH=/opt/nava/playwright-browsers
```

## Windows (Git Bash)

```bash
bash scripts/setup-linux.sh   # or manual: extension npm build + uv sync in workflow-use/workflows
bash scripts/record.sh
```

## Repos

| Piece | Location |
|-------|----------|
| Patched workflow-use | `workflow-use/` (fork: `aa6622/workflow-use` branch `nava/recorder-fixes`) |
| Pilot scripts | `scripts/` |
| Full guide | [PILOT.md](PILOT.md) |

Runtime `browser-use` is installed via pip inside `workflow-use/workflows/.venv` — no `browser-use/` clone needed.

## Upstream

Recorder fixes are intended for PRs to [browser-use/workflow-use](https://github.com/browser-use/workflow-use) (see issue #99). Fork holds patches until merged.
