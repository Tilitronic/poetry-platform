# Research-to-Persistence Pipeline

**Date:** 2026-08-07
**Source:** Internal audit of research/conspecter workflow gap
**Status:** Implemented

## Pattern

The OpenCode orchestrator system routes standalone research to `@researcher`, but `@researcher` is conversation-only — it returns findings in conversation and does not persist them. `@conspecter` is the designated persistence agent (downloads sources → writes MLA-cited conspect → registers in memory shelf). The gap: no routing rule connects researcher findings to conspecter persistence.

## Root Cause

- `@researcher` had no `orchestratorPrompt` and no `.md` agent file — no output contract defined
- Orchestrator routing rules had no follow-up step for research persistence
- The official persistence chain (global AGENTS.md §11) defined `conspect → analysis → memory shelf` but omitted researcher

## Incidents

Two confirmed missing knowledge artifacts:
1. 2026-08-06: "General silent-logging research" — findings in conversation only; caught by developer, fixed manually (→ res002)
2. 2026-08-06: "Verify OpenCode plugin API pattern" — findings in conversation only; no res003 exists

## Fix (Implemented)

Two-level intervention:
1. **Orchestrator skill** (`research-pipeline/SKILL.md`): 4-phase workflow (Research → Decide → Persist → Verify) loaded when research should produce knowledge artifacts
2. **Researcher agent tuning**: `.opencode/agents/researcher.md` defines output contract with `PERSISTENCE_RECOMMENDED` flag; `orchestratorPrompt` in oh-my-opencode-slim.jsonc tells orchestrator about the handoff

## Plugin Mechanical Detection (DIA-057/DIA-058)

Phase-6 extension (ai--4 review fold-in): the orchestrator hard-gates persistence via a plugin trigger rather than relying on reading subagent output:

- The `task()` tool output wraps the subagent's final result in `<task_result>...</task_result>` with `state: completed` present on completion (per OMO `src/utils/task.ts` `parseTaskResultFromOutput`) — this is what makes mechanical detection possible. Note the split contract: `state: completed` lives in the task HEADER (before the `<task_result>` tag, per `getTaskHeader`), while the subagent's final result text lives inside the body.
- The detector regex `/PERSISTENCE_RECOMMENDED:\s*true/i` fires only when `state: completed` AND the flag is present AND the task is on the **researcher lane** (`input.args.subagent_type === "researcher"`, falling back to the resolved child session agent). The flag regex is applied to the extracted `<task_result>` body only — a quote of the flag string in another agent's prompt or meta-comment cannot trip it.
- The flag file is `.opencode/session/persistence-pending.json` (overwrite-based, latest event wins; written by `delegation-observer.ts` `tool.execute.after`, fail-soft try/catch + `console.warn`, pure-additive).

## Key Decision

Researcher stays read-only. It recommends persistence; the orchestrator decides (practice-protected); conspecter executes. The two existing agents (researcher + conspecter) are composed by the orchestrator via the skill, rather than merging responsibilities into one agent.

## References

- Anthropic Multi-Agent Research System (2025-06-13): "Subagent output to a filesystem to minimize the game of telephone"
- OpenCode Skills Documentation: skills loaded on-demand via `skill` tool
- OMO orchestratorPrompt mechanism: injected into boss prompt for delegation guidance
