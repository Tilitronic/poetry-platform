# DIA-260926-n49u - muse-balanced preset: swap mimo-v2.5 -> mimo-v2.6-flash

---

id: DIA-260926-n49u
title: "muse-balanced preset: swap mimo-v2.5 -> mimo-v2.6-flash"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-26
source: inventory
date: 2026-09-26
created: 2026-09-26
updated: 2026-09-28

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

Fast-path config change in the active `muse-balanced` preset of .opencode/oh-my-opencode-slim.jsonc.

Developer opt-in (recorded): skip the @ai-specialist gate and @ai-auditor review. Reason: MiMo-V2.6-Flash dominates MiMo-V2.5 on every metric at identical price (reasoning 17->33, coding 53->62, tool use 50->68; cost/context/multimodal equal).

Scope: replace all 12 occurrences of `opencode-go/mimo-v2.5` with `opencode-go/mimo-v2.6-flash` inside the `muse-balanced` preset only.

- PRIMARY lanes: coder, conspecter, observer, resource-manager, memory-manager, code-navigator, researcher
- FALLBACK lanes: orchestrator, architector, openspec-plan, designer, ai-specialist
- DO NOT touch the `free` preset (`opencode/mimo-v2.5-free` is a different model) or any other preset.

Also: update the stale composition comment in the preset header, and update knowledge/model-registry.yaml (DIA-133 routing source of truth) so it does not drift.

Hard prerequisite: the exact OpenCode Go model ID must be verified before the swap; if `opencode-go/mimo-v2.6-flash` does not resolve, STOP and report.

## Verification

- `make test-config` exit 0.
- Zero remaining `opencode-go/mimo-v2.5` occurrences inside the `muse-balanced` preset.
- `free` preset untouched.
- OpenCode restart + functional smoke test (developer).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
