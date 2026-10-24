# cebula Preset Revert: flash→pro→flash (2026-08-07)

## Context

Commit `2e0c4f3e6cacb3d3120f6c5db44ea21f18e724da` changed 7 agent model assignments
in the `cebula` preset from `deepseek-v4-flash` to `deepseek-v4-pro`. This was a
cost-critical leak — pro models are ~5-10x more expensive than flash.

## Discovery Chain

1. DIA-062 was filed when the orchestrator's system prompt showed it was running on
   `deepseek-v4-pro` instead of `deepseek-v4-flash`.
2. DIA-062 fixed ONLY the orchestrator (to single-string
   `"opencode-go/deepseek-v4-flash"`, missing the `opencode/deepseek-v4-flash`
   fallback).
3. Subsequent investigation revealed the remaining 6 cebula agents (coder, conspecter,
   resource-manager, memory-manager, code-navigator, researcher) were ALL still on pro
   models — the commit had affected the entire preset, not just the orchestrator.

## Before/After Table (per commit 2e0c4f3e)

| Agent | Pre-commit (flash) | Post-commit (pro) |
|-------|-------------------|-------------------|
| orchestrator | `["opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]` | `["opencode-go/deepseek-v4-pro", "opencode/deepseek-v4-pro"]` |
| coder | `["opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]` | `["opencode-go/deepseek-v4-pro", "opencode/deepseek-v4-pro"]` |
| conspecter | `["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]` | `"opencode-go/deepseek-v4-pro"` |
| resource-manager | `["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]` | `"opencode-go/deepseek-v4-pro"` |
| memory-manager | `["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]` | `["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-pro", "opencode/deepseek-v4-pro"]` |
| code-navigator | `["github-copilot/gpt-5-mini", "opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]` | `"opencode-go/deepseek-v4-pro"` |
| researcher | `["opencode-go/deepseek-v4-flash", "opencode/deepseek-v4-flash"]` | `["opencode-go/deepseek-v4-pro", "opencode/deepseek-v4-pro"]` |

## Resolution

Developer approved **Option A: full revert** of all 7 agents back to their pre-commit,
all-flash model assignments. Implemented 2026-08-07 via §10 Phase 4 (code-executor,
ses_0248c2da2ffeiZ6QcUdui50id5) — DIA-064.

Additionally, 5 agents (conspecter, resource-manager, code-navigator, memory-manager)
regained their `github-copilot/gpt-5-mini` primary entry, which had been stripped
by the commit (switched from array to single-string model).

## Lesson

**Preset model changes in config commits need explicit review before merge.**
The commit 2e0c4f3e changed 7 agent models in one shot — a batch flash→pro upgrade
that went undetected until DIA-062 (orchestrator) and DIA-064 (full preset).
Config diffs touching model assignments in more than one agent should be flagged
for explicit cost-impact review in the PR process.

## Related

- DIA-062: Orchestrator running on deepseek-v4-pro instead of deepseek-v4-flash
- DIA-064: Full cebula preset revert (this resolution)
- Commit: 2e0c4f3e6cacb3d3120f6c5db44ea21f18e724da
