# DIA-260926-40bb - context/handoff thresholds: stale design.md + dead resource-pressure code + the 15/25 vs 60/75 policy question

---

id: DIA-260926-40bb
title: "context/handoff thresholds: stale design.md + dead resource-pressure code + the 15/25 vs 60/75 policy question"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-26
source: fix-lane
date: 2026-09-26
created: 2026-09-26
updated: 2026-09-26

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

### Problem

- Canonical self-rerun thresholds live in NEXT-RUN.md:80-82 (15 percent primary / 25 percent safety-net). All LIVE surfaces agree: the four OMO presets, delegation-observer.ts:4034-4035 (constants 0.15 / 0.25), scripts/check-orchestrator-prompt-drift.sh:75 (THRESHOLD_MARKER), and the context_usage tool description.
- STALE DOC: openspec/changes/dia-redispatch-cycle/design.md:44 states >=50 percent and :270 states a 30 percent primary with a >=50 percent safety-net - DIA-097-era tuning never updated when DIA-191 retuned to 15/25. DIA-198 reconciled the prompts and the drift checker but MISSED this file. No OPEN ticket covers it.
- DEAD CODE: the resource-pressure thresholds 0.5 / 0.8 / 0.95 at delegation-observer.ts:1432-1437 are documented but NONFUNCTIONAL - getContextPressure returns 0, so they never fire.
- POLICY: DIA-260903-oj59 (OPEN) proposes raising to 60 percent primary / 75 percent safety-net. The 60/85 pair belongs to a SEPARATE mechanism (adaptive compaction: delegation-observer.ts:1765 >0.6 warning, :1786 >0.85 compaction) and is not a conflict.
- BLIND SPOT: scripts/check-orchestrator-prompt-drift.sh reads only the preset orchestrator prompts; it never reads .opencode/oh-my-opencode-slim/orchestrator_append.md, so the R3 merge-gate rule and the other append rules have ZERO drift enforcement.

### Fix

1. Replace the stale hardcoded numbers in openspec/changes/dia-redispatch-cycle/design.md with a pointer to NEXT-RUN.md as the single source of truth - or fold this into the OPEN DIA-260822-medh.
2. Decide DIA-260903-oj59. If adopted, change FOUR places consistently or drift is guaranteed: NEXT-RUN.md, the OMO presets, the delegation-observer constants, and THRESHOLD_MARKER in the drift checker.
3. Extend the drift checker (or add a doc lint) to catch stale threshold numbers in docs/ and openspec/, and to cover orchestrator_append.md.
4. Remove or implement the dead resource-pressure thresholds.

### Acceptance criteria

- No two documents state different self-rerun thresholds.
- The drift checker (or doc lint) covers docs/, openspec/ and orchestrator_append.md.
- The dead resource-pressure code is functional or deleted.
- The 15/25 vs 60/75 decision is recorded.

### Relations

- Related OPEN: DIA-260903-oj59 and DIA-260822-medh. Found by a read-only threshold audit on 2026-09-26, in the same session as the container-rules work under DIA-260922-cp0m.

## Verification

- [ ] No two documents state different self-rerun thresholds.
- [ ] The drift checker (or doc lint) covers docs/, openspec/ and orchestrator_append.md.
- [ ] The dead resource-pressure code is functional or deleted.
- [ ] The 15/25 vs 60/75 decision is recorded.

## Fix

> To be completed when the fix is implemented.

## Re-verify

> To be filled at re-verify time.
