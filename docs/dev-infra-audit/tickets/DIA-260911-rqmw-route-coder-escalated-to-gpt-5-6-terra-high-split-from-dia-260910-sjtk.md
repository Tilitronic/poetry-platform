# DIA-260911-rqmw - Route coder-escalated to GPT-5.6 Terra High (split from DIA-260910-sjtk)

---

id: DIA-260911-rqmw
title: "Route coder-escalated to GPT-5.6 Terra High (split from DIA-260910-sjtk)"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-11
source: inventory
date: 2026-09-11
created: 2026-09-11
updated: 2026-09-11

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Route the coder-escalated lane from opencode-go/kimi-k3 to openai/gpt-5.6-terra
at high reasoning (one-shot no-retry rule retained). Split from DIA-260910-sjtk,
which landed architector-only. Terra 5-surface scope (currently uncommitted in
worktree, owned by this ticket):

- .opencode/opencode.jsonc (coder-escalated direct route)
- .opencode/agents/coder-escalated.md (agent contract)
- AGENTS.md (agent-name table row)
- .opencode/oh-my-opencode-slim.jsonc (muse-qwen-balanced coder-escalated hunk plus preset prompt)
- knowledge/model-registry.yaml (Rung3 route plus Terra price correction)

## Verification

- [x] Terra 5-surface changes committed under this ticket (nothing under sjtk) (2026-09-11, commit cdd5f04)
- [x] make test-config exit 0, git diff --check exit 0 (2026-09-11; test-config rqmw gates pass, full run blocked only by foreign j5k6 shelf entry)
- [x] Restart OpenCode plus post-restart resolver shows coder-escalated to openai/gpt-5.6-terra high (2026-09-11, RESOLVER-OK)
- [x] Non-empty Terra High smoke green (2026-09-11, TERRA_HIGH_SMOKE_OK exit 0)
- [x] Independent ai-auditor review plus changelog registration per section-2.5 (2026-09-11; audit ai--4 all PASS except one verification-key blocker, fixed this commit; changelog entry validated plus rendered)

## Fix

Coder-escalated Kimi K3 to GPT-5.6 Terra High, 5-surface atomic set
(developer-approved, ai-specialist findings registered in
.opencode/learnings/external-patterns/2026-09-11-dia-260911-rqmw-terra-routing.md):

- .opencode/opencode.jsonc: coder-escalated direct route
  opencode-go/kimi-k3 -> openai/gpt-5.6-terra, one-shot no-retry kept
  (developer direction after failure, no auto fallback chain).
- .opencode/agents/coder-escalated.md: description + Role model line +
  ONE-SHOT rule rewritten to paid developer-gated wording (3 hunks).
- AGENTS.md: agent-name table coder-escalated row Kimi K3 -> GPT-5.6
  Terra High (semantic row only; table rewrap churn excluded).
- .opencode/oh-my-opencode-slim.jsonc (muse-qwen-balanced ONLY):
  coder-escalated hunk kimi-k3/max + deepseek-v4-pro/max -> terra/high
  (variant max -> high) plus agents.coder-escalated orchestratorPrompt
  line ONLY. All other preset hunks (Muse Free / Luna Medium utility
  lanes) excluded per owner rule (DIA-260909-csds and neighbors).
- knowledge/model-registry.yaml: routing_table Rung3 kimi-k3 ->
  openai/gpt-5.6-terra (one-shot comment kept); Terra quota_notes
  long-context price corrected (short <=272K $2.00/$12.00, long >272K
  $4.00/$18.00 per res013); kimi-k3 entry retired (active false);
  coder-escalated added to Terra lanes; Rung3-fallback signal gated on
  developer approval.

Validation evidence: (pending Step 6, appended below)

Validation evidence 2026-09-11:

- make test-config: all gates PASS except validate-memory-shelf.sh, which
  fails ONLY on the foreign DIA-260831-j5k6 shelf entry (shelf.specs.31
  'artifacts' property, committed in 21904d1 by its owning lane, never
  touched by this ticket). Rqmw-relevant gates all exit 0:
  validate-opencode-config.sh (opencode.jsonc + slim jsonc valid JSONC,
  coder/coder-escalated permission lockstep ok), validate-agent-names.sh
  (27 passed 0 failed 0 warnings), check-orchestrator-prompt-drift.sh
  (3 presets 9 markers 0 gaps byte-identical), validate-changelog.sh
  (1 passed 0 failed), ticket gate_state check (rqmw skipped valid).
- git diff --check: exit 0 (worktree and staged).
- Restart: isolated headless OpenCode server on 127.0.0.1:4099, startup
  log "opencode server listening on http://127.0.0.1:4099" (port 4096
  held by a stale listener; 4099 used instead). Catalog lists
  openai/gpt-5.6-terra.
- Post-restart resolver: opencode.jsonc coder-escalated model =
  openai/gpt-5.6-terra; muse-qwen-balanced coder-escalated model =
  [{"id": "openai/gpt-5.6-terra", "variant": "high"}] variant high;
  orchestratorPrompt carries GPT-5.6 Terra High one-shot wording.
  RESOLVER-OK.
- Fresh Terra High non-empty smoke: opencode run -m
  openai/gpt-5.6-terra --variant high returned exactly
  TERRA_HIGH_SMOKE_OK (19 chars, non-empty), exit 0.

## Re-verify

Re-verify 2026-09-11 (blocker-fix commit): ai--4 BLOCKED on exactly one
blocker (CHANGELOG.yaml rqmw entry missing required verification key);
all else PASS (route/variant, no over-grant with task deny, one-shot
gate, registry fidelity, agent-name lockstep 27/0/0). Fix adds
verification: manual plus area: opencode-config to the rqmw entry
(index tail), matching sibling-entry convention; validated with
scripts/validate-changelog.sh exit 0. Owner-rule exclusivity confirmed
on commit cdd5f04: AGENTS.md hunk is the semantic coder-escalated row
(Kimi K3 -> GPT-5.6 Terra High) plus prettier-canonical table rewrap
only; slim jsonc hunk is coder-escalated model plus orchestratorPrompt
line only (utility-lane preset churn excluded). Description 4-vs-5
drift fixed (registry listed as 5th surface).
