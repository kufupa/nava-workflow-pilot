# Imprint pilot runbook

[Imprint](https://github.com/ashaychangwani/imprint) — record browser session, compile to deterministic MCP tool (optional LLM at compile time).

## Prerequisites

- [Bun](https://bun.sh) ≥ 1.3 (you have 1.3.x)
- Headed desktop for **record** (Windows or xRDP on EC2)
- **Compile** (`teach` / `generate`): local `claude` or `codex` on PATH (auto-detected)

## One-time setup

```bash
cd browser-automation-pilot
bash scripts/setup-imprint.sh
```

## Record (no LLM)

```bash
bash scripts/record-imprint.sh [site] [url]
# default: nava-test https://example.com
```

Drive the browser. Stop recording (any of these):

- Type **`/done`** in the **same Git Bash terminal** (prompt on stderr after browser opens)
- **`Ctrl+C`** in that terminal
- **Close the Chromium window**

Sessions land in `imprint-data/<site>/sessions/` (`IMPRINT_HOME`).

**Windows Git Bash:** click the terminal window before typing — stdin goes to the terminal, not the browser.

## Compile later (LLM once)

Uses local Claude CLI by default (`IMPRINT_PROVIDER=claude` in `pilot-env.sh`):

```bash
cd imprint
bun src/cli.ts teach my-site --url https://your-site.com
```

Runtime MCP calls are deterministic — zero tokens after compile.

## Doctor / smoke

```bash
bash scripts/imprint-doctor.sh
bash scripts/imprint-smoke.sh    # full CI check + echo MCP + record smoke
```

## vs workflow-use

| | workflow-use | imprint |
|--|--------------|---------|
| Record | Playwright + MV3 extension | CDP + Chromium |
| Stop recording | Extension side panel | Terminal `/done` |
| Output | `tmp/*.workflow.json` | `imprint-data/.../sessions/*.json` |
| Replay | browser-use (Python) | MCP tool / backend ladder |
| LLM on record | No | No |
| LLM on compile | Optional (healing) | Yes for `teach` |

## Troubleshooting

Run `bash scripts/imprint-doctor.sh` first.

| Issue | Fix |
|-------|-----|
| `bun: command not found` | `pilot-env.sh` adds `~/.pnpm-global/bun` to PATH |
| Chromium missing | `bash scripts/setup-imprint.sh` (Playwright install) |
| Corporate Chrome blocks CDP | Imprint uses Playwright bundled Chromium |
| Windows doctor false-negative | Pilot patches `chromium.ts` + `doctor.ts` for `%LOCALAPPDATA%/ms-playwright` |
| `IMPRINT_HOME` wrong | Default: `browser-automation-pilot/imprint-data/` |

Overnight fixes logged in `imprint-data/RCA.md` (gitignored).

## Data layout

```
imprint-data/
  <site>/
    sessions/
      <timestamp>.json
      <timestamp>.jsonl
  RCA.md
```
