# DIA-260916-z5pf - Optimize archive-aware jsonl cross-check for bounded interactive latency

---

id: DIA-260916-z5pf
title: "Optimize archive-aware jsonl cross-check for bounded interactive latency"
area: dev-infra
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-16
source: inventory
date: 2026-09-16
created: 2026-09-16
updated: 2026-09-16

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

The archive-aware path in `.opencode/scripts/jsonl-cross-check.sh` is
functionally correct but its jq reduction remains CPU-bound for more than one
minute against the verified 44,861,601-byte / 128,373-row registry archive plus
the approximately 53 MB messages journal. This is an explicit historical audit
command, not a periodic or hot-path regression, but interactive operators need
bounded progress and a practical completion time. Preserve the source-aware
identity contract established by DIA-260914-tqor while removing avoidable
whole-history materialization or quadratic state updates.

## Verification

- [ ] The live verified archive cross-check completes with the same result as
      the current implementation and reports elapsed time and rows processed.
- [ ] Same-source legacy sequence collisions remain distinct; identical
      cross-source rows deduplicate; genuine cross-source conflicts fail closed.
- [ ] Peak work is bounded or streamed without changing periodic sweep or
      append paths.
- [ ] Focused Bats, `make test-shell`, and `git diff --check` pass.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
