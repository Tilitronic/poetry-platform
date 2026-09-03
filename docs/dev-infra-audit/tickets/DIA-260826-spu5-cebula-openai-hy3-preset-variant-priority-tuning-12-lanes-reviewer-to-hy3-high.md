# DIA-260826-spu5 - cebula-openai-hy3 preset variant-priority tuning (12 lanes; reviewer to hy3 high)

---

id: DIA-260826-spu5
title: "cebula-openai-hy3 preset variant-priority tuning (12 lanes; reviewer to hy3 high)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-08-26

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fc16ca273ffe3Qj67HX19uIwcM"
lane_id: "config-work"
agent: "coder"
model: "opencode-go/hy3"
parent_session_id: ""
attempts: 1
lease_expires_at: "2026-08-26T18:58:39Z" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Variant-priority tuning of the `cebula-openai-hy3` preset in
`.opencode/oh-my-opencode-slim.jsonc` (11 edits, all scoped to this preset
only; no other preset touched):

- variant high -> medium (7 lanes): orchestrator, openspec-plan, coder,
  conspecter, analyzer, ai-specialist, researcher
- variant medium -> low (3 lanes): resource-manager, memory-manager,
  code-navigator
- reviewer model `[opencode-go/qwen3.7-plus, opencode/big-pickle]` ->
  `[opencode-go/hy3, opencode/big-pickle]`; reviewer variant stays `high`
- analyzer-escalated intentionally unchanged at variant `high` (developer
  decision: lowering would contradict its hard-reasoning escalation purpose)

Review-diversity override rationale: coder and reviewer now share `hy3` as
primary model, which violates `ai-assist-sources.yaml:245` ("reviewer must be
different model family than coder"). The developer consciously overrode this:
same model + HIGHER reasoning effort (reviewer variant `high` vs coder
`medium`) is accepted as sufficient; `big-pickle` is retained as the fallback
for episodic family diversity (res029: fallbacks activate on error signals
only). The override is recorded in ticket DIA-260826-spu5 and in the
learnings file.

F1/F2 caveats: (F1) the `big-pickle` fallback provides family diversity only
on error signals, not in steady state; (F2) the variant-lowering evidence
(res021: medium beats high on code by 3-5pp) is coding-task evidence applied
to non-coding agents (orchestrator, openspec-plan, conspecter, analyzer,
ai-specialist, researcher) - applicability to non-coding reasoning tasks is
unverified and accepted as a conscious decision.

## Verification

- `make test-config` exits 0 (stable across x4 runs): JSONC valid, agent-name
  lockstep, changelog schema, EBDV validator all pass.
- The 11 config edits are scoped to the `cebula-openai-hy3` preset only
  (verified by per-preset variant/reviewer-model mapping; preset 1 and preset
  5 reverted after an initial cross-preset hit from short-anchored edits).
- `opencode-go/hy3` registry entry added to `knowledge/model-registry.yaml`
  (price $0.14/$0.58 per 1M, 21,500 req/mo, 256K ctx, fallback
  `[opencode-go/mimo-v2.5, opencode/big-pickle]`).
- Learnings file registered at
  `.opencode/learnings/external-patterns/2026-08-26-variant-priority-tuning.md`.

## Fix

- 11 config edits in `.opencode/oh-my-opencode-slim.jsonc` (`cebula-openai-hy3`
  preset): 7 lanes high->medium, 3 lanes medium->low, reviewer model
  qwen3.7-plus -> hy3 (variant high).
- `opencode-go/hy3` entry added to `knowledge/model-registry.yaml`.
- Learnings file `.opencode/learnings/external-patterns/2026-08-26-variant-priority-tuning.md`
  written (ai-specialist gate findings F1-F5 + gate verdict).
- Block-level comment added above the `cebula-openai-hy3` preset opening
  documenting the tuning.

## Re-verify

Independent review rev-1 returned APPROVE-WITH-FINDINGS. Developer disposition:
ALL findings ACCEPTED. Fixes applied: (S1/F3) ticket body populated; (S2)
registry role field shortened to `multi-lane-primary (cebula-openai-hy3)`;
(S3) block-level comment added above the preset; (F1/F2) explicit caveats
appended to the learnings file. `make test-config` re-run exits 0; the 11
config edits confirmed intact (no regression).
