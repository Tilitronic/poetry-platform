# s1gd preset swap - surface inventory, shared-model trap, auditor independence, live catalog, lane frequency

## Context

DIA-260927-s1gd requests three changes: rename the active preset "Muse Balanced" to "Mimo Balanced"; replace the architector lane model with Kimi K3 High; move ai-auditor off GLM-5.3-Flash. Gate research was read-only on 2026-09-28.

## Preset name is pinned by four live gates

Renaming the preset key without editing these breaks the build:
- scripts/check-orchestrator-prompt-drift.sh:61 - default PRESETS list. Wired into make test-config (Makefile:263). A rename without this edit yields "FAIL: muse-balanced: orchestrator prompt missing entirely".
- scripts/test-interview-enforcement.sh:74 - preset tuple, plus message strings at 81 and 83. make test-config prerequisite (Makefile:254).
- scripts/__tests__/preset-single-path.bats:28,32,36,81 - make test-shell.
- scripts/__tests__/workspace-preset-selection.bats:17,21,38 - make test-shell.

Declarations and docs to update in lockstep: .opencode/oh-my-opencode-slim.jsonc:3 (root "preset" pointer), :263 (preset key), :14 (header composition comment, which also names the ai-auditor model); docs/dev-infra/preset-single-path.md:13,28,61.

NOT affected: AGENTS.md section 9 and scripts/validate-agent-names.sh verify AGENT inner keys, not preset names or model values. No validator pins a MODEL ID.

## Shared-model trap (surgical edit required)

`opencode-go/deepseek-v4.1-flash` is the architector PRIMARY and is ALSO used in muse-balanced by orchestrator (:266), openspec-plan (:305), reviewer (:341), ai-specialist (:401), coder-escalated (:476) and analyzer-escalated (:491). A global find/replace on that string would silently move seven lanes. Any architector model swap must target the architector block only (and its own fallback).

## Auditor independence invariant

knowledge/model-registry.yaml:125 records: ai-auditor must stay on a DIFFERENT model family from ai-specialist. Moving ai-auditor onto `opencode-go/deepseek-v4.1-flash` (the ticket's original informal request "DeepSeek Flash V4.1 high") would have put it on the SAME family as ai-specialist (:401) and broken that invariant. Resolved by routing ai-auditor to kimi-k3 instead, which is a different family and therefore preserves the invariant.

## Live catalog (verified 2026-09-28)

Command: `opencode models | grep -iE 'kimi|deepseek'` (exit 0, first attempt).
Relevant output lines: `opencode/deepseek-v4-flash`, `opencode/deepseek-v4-pro`, `opencode/deepseek-v4.1-flash` (line 61 region: `opencode/kimi-k3`), `opencode-go/deepseek-v4-flash`, `opencode-go/deepseek-v4-pro`, `opencode-go/deepseek-v4.1-flash`, `opencode-go/kimi-k2.7-code`, `opencode-go/kimi-k3` (line 92).
Conclusions: `opencode-go/kimi-k3` EXISTS and resolves. There is no bare `deepseek-v4.1` model ID; the entries are the `-flash` variants. Therefore knowledge/model-registry.yaml:152, which marks kimi-k3 `active: false` / `role: retired (was coder-escalated)`, is STALE bookkeeping and should be corrected.
Also: "High" and "medium" are OMO `variant` values, not part of the model ID. No `kimi-k3-high` string exists anywhere.

## Lane invocation frequency (source of truth)

Source: `make session-analytics` (scripts/session-analytics.sh), backed by the native OpenCode SQLite DB. Grouped by the session `agent` field. Window 2026-08-12 11:03 UTC to 2026-09-28 13:49 UTC, 727 session rows total, 641 subagent sessions, 0 rows with a missing agent field.
Counts: coder 384, orchestrator 85, ai-specialist 49, memory-manager 43, reviewer 34, code-navigator 30, ai-auditor 23, analyzer 19, researcher 18, openspec-plan 14, conspecter 14, architector 10, analyzer-escalated 3, build 1.
Consequence: ai-auditor (23) is invoked LESS than ai-specialist (49); architector (10) is the least of the three. Note the tool's default agents view filters `WHERE parent_id IS NOT NULL`, which hides the orchestrator row.

## registry.jsonl is NOT usable for per-lane counts

Only 318 of 2583 rows carry an `agent` key at all, and 297 of those hold the literal string "subagent" (a role, not a lane name). `subagent_type` appears on 57 rows only. 2208 rows carry neither field. `session_spawn` rows (465) carry no lane. Use `make session-analytics` for lane frequency instead. Mixed row schema confirmed; event kinds seen include session_complete, task_success, session_spawn, empty_result_detected, session_boot.
