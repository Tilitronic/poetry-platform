# DIA-260929-wjir - model swap: architector and ai-auditor kimi-k3 to grok-4.7 (variants preserved), analyzer to deepseek-v4.1-flash variant high

---

id: DIA-260929-wjir
title: "model swap: architector and ai-auditor kimi-k3 to grok-4.7 (variants preserved), analyzer to deepseek-v4.1-flash variant high"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
updated: 2026-09-29

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

Lane-scoped model swaps in the ACTIVE preset only (`mimo-balanced`, active
preset pointer at .opencode/oh-my-opencode-slim.jsonc:3):

- architector lane: primary model becomes opencode-go/grok-4.7; preserve
  variant "high" (line 286); leave the fallback array element
  (opencode-go/mimo-v2.6-flash) unchanged.
- ai-auditor lane: primary model becomes opencode-go/grok-4.7; preserve
  variant "medium" (line 417); leave the fallback array element
  (opencode-go/deepseek-v4-flash) unchanged.
- analyzer lane: primary model becomes opencode-go/deepseek-v4.1-flash;
  variant "high" is already set at line 357; leave the fallback array
  element (opencode-go/deepseek-v4-flash) unchanged.

knowledge/model-registry.yaml:

- add a grok-4.7 entry (live OpenCode Go pricing $2.00/$6.00 per M tokens
  <=200K context, $4.00/$12.00 above 200K, 500K context, reasoning yes,
  about 845 requests/month);
- retire kimi-k3 from the architector and ai-auditor lanes;
- add the analyzer to deepseek-v4.1-flash and drop it from qwen3.8-flash;
- fix the affected routing_table rungs.

Correct the stale comments that the change invalidates:

- .opencode/oh-my-opencode-slim.jsonc:14
- knowledge/model-registry.yaml:23, :99, :152-162

SCOPE OUT (explicitly not part of this ticket):

- reviewer (line 342), designer (line 373), analyzer-escalated, and EVERY
  seat inside the promo-union-alpha preset are untouched.
- The openai-first-cost-balanced preset is untouched: it contains ZERO
  occurrences of the three models and ADR 2138 keeps it strict
  OpenAI-only.

Decision record:

- R6 resolved by the developer on 2026-09-29 as the LANE-SCOPED reading
  (active mimo-balanced preset only). The occurrence-scoped alternative
  was rejected because it silently reroutes reviewer, designer and
  analyzer-escalated seats that no ticket names, and churns
  promo-union-alpha which DIA-260929-5c6m deletes.
- Assumption on record (developer may override): fallback (second) array
  elements are left unchanged - minimal diff.

## Verification

- [ ] The three lane model arrays in mimo-balanced show the new primaries;
      variants stay high / medium / high.
- [ ] No other seat and no other preset differs (a diff limited to the
      intended lines).
- [ ] knowledge/model-registry.yaml carries a grok-4.7 entry and no longer
      lists kimi-k3 or qwen3.8-flash on the affected lanes.
- [ ] `make test-config` exits 0.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
