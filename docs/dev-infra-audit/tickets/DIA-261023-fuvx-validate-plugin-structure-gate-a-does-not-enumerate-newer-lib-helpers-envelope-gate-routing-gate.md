# DIA-261023-fuvx - validate-plugin-structure Gate A does not enumerate newer lib helpers (envelope-gate, routing-gate)

---

id: DIA-261023-fuvx
title: "validate-plugin-structure Gate A does not enumerate newer lib helpers (envelope-gate, routing-gate)"
area: scripts
severity: Minor
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-261023-d6b9
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-23
source: fix-lane
date: 2026-10-23
created: 2026-10-23
updated: 2026-10-23

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

`scripts/validate-plugin-structure.sh:30-40` hardcodes the `gateA_symbols`
association array and the `retained` array. Neither `envelope-gate` nor
`routing-gate` appears in either manifest (the enumerated libs are
capability, ticket-gate, handoff, registry, stall-sweep, formatter,
circuit-breaker, errors).

Consequence: Gate A's "retained symbol referenced outside its import"
property is not enforced for `evaluateEnvelopeDuplication`. A future edit
that keeps the import but drops the call site at
`.opencode/plugins/delegation-observer.ts:1862-1867` still passes the
structural gate. The behaviour test would catch it, but the structural
invariant would silently rot.

Fix shape: add both libs to the manifests and update the clean-plugin
fixture in `scripts/__tests__/validate-plugin-structure.bats:52-70`, which
hardcodes the imports required to pass Gate A in Gate C negative tests.

Origin: ai-auditor condition 3 of DIA-261023-d6b9 (Suggestion severity).
Routing: `scripts/` is section 2.4 dev-infra, not section 2.5 config.

## Verification

- [ ] `scripts/validate-plugin-structure.sh:30-40` manifests list
      `envelope-gate` and `routing-gate` in both `gateA_symbols` and
      `retained`.
- [ ] `scripts/__tests__/validate-plugin-structure.bats:52-70`
      clean-plugin fixture imports the new libs' symbols so Gate C
      negative tests still pass.
- [ ] `make test-shell` (or the validate-plugin-structure bats target)
      exits 0.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
