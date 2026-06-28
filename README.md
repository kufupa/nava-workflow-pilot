# Browser Automation Pilot

Teach-once / replay-many browser workflows. Two stacks:

- **[workflow-use](https://github.com/browser-use/workflow-use)** — patched NAVA recorder (Python + extension)
- **[imprint](https://github.com/ashaychangwani/imprint)** — CDP capture → optional MCP compile (Bun)

## Quick start — workflow-use (Linux / EC2)

Prerequisites: `git`, Node 20+, `uv`, xRDP desktop for recording (headed Chrome needs `DISPLAY`).

```bash
git clone https://github.com/kufupa/nava-workflow-pilot.git
cd nava-workflow-pilot
bash scripts/setup-linux.sh
# From xRDP terminal only:
bash scripts/record.sh
bash scripts/replay.sh workflow-use/workflows/tmp/your.workflow.json
```

## Quick start — imprint (Windows Git Bash or Linux)

Prerequisites: Bun ≥ 1.3, headed desktop for record.

```bash
git clone https://github.com/kufupa/nava-workflow-pilot.git
cd nava-workflow-pilot
bash scripts/setup-imprint.sh
bash scripts/record-imprint.sh [site] [url]
```

Type `/done` in the terminal when finished recording.

## Both stacks

```bash
bash scripts/setup-all.sh
```

## Repos

| Piece | Location |
|-------|----------|
| Patched workflow-use | `workflow-use/` (vendored) |
| Imprint | `imprint/` (vendored @ v0.5.0) |
| Pilot scripts | `scripts/` |
| workflow-use guide | [PILOT.md](PILOT.md) |
| imprint guide | [PILOT-IMPRINT.md](PILOT-IMPRINT.md) |

Runtime `browser-use` is installed via pip inside `workflow-use/workflows/.venv`.

## Upstream

workflow-use recorder fixes intended for PRs to [browser-use/workflow-use](https://github.com/browser-use/workflow-use) (issue #99).
