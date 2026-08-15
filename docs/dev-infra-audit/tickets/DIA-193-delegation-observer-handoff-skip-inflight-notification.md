# DIA-193 - delegation-observer handoff-writer skip for non-terminal in-flight: benign guard surfaced as alarming high-severity notification

<!-- FILED 2026-08-15 (orchestrator lane). NOTE: dispatch requested DIA-191,
     but that number was already taken by the parallel ticket
     DIA-191-context-usage-estimator-overestimates-tui.md (parallel request,
     committed 49cb3de). Per COORDINATION.md number-allocation protocol
     (allocator = max+1, same precedent as DIA-191's own header note), this
     ticket is filed as DIA-193, the next free number. -->

---

id: DIA-193
title: "delegation-observer handoff-writer skip for non-terminal in-flight: benign guard surfaced as alarming high-severity notification"
area: opencode-config
severity: Low
status: VERIFIED
blocked_by: [] # no blockers
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: session-observation (developer screenshot clipboard-e3be15ea.png 2026-08-15)
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffb7ba1daffemGh05K4YUPlQe2" # orchestrator session that observed the notification
lane_id: ""
agent: "orchestrator"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-193-delegation-observer-handoff-skip-inflight-notification.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: [.opencode/images/ses_ffb7ba1daffemGh05K4YUPlQe2/clipboard-e3be15ea.png]

---

## Description

Developer observed a TUI notification:
`[delegation-observer] handoff-writer skipped: non-terminal resolution_status
'in-flight'` (screenshot clipboard-e3be15ea.png, 2026-08-15). The skip is
intentional and benign, yet the notification reads as alarming.

Recon evidence (code-navigator lane, read-only):

- Skip branch at `.opencode/plugins/delegation-observer.ts:2464-2474`.
- `TERMINAL_HANDOFF_STATUSES = {done, escalated, pending-owner}` (lines
  2419-2423); `'in-flight'` is correctly non-terminal.

This is the DIA-120 fix working: the writer MUST NOT run for non-terminal
statuses or it would clobber a valid handoff file and cause a false checksum
mismatch (the DIA-120 trigger story).

Assessment: NOT a runtime bug - the writer was correctly prevented from
running. The problem is observability/severity loudness: `console.warn`
surfaces as a high-severity TUI notification for an intentionally benign skip.

Root cause: a `log_decision` invocation with `event_type=handoff` AND a
non-terminal `resolution_status` AND a non-empty prognosis string is a
contradictory tool-contract use (handoff implies a cycle end; a terminal
status is required per the tool description). Historical messages.jsonl rows
show many handoff+in-flight observations (e.g. boot-gate / batch-approval
detection rows).

Fix direction (for design):

- Demote the skip log from `console.warn` to `ctx.client.app.log` (info).
- Or strengthen the `log_decision` tool description to forbid handoff with a
  non-terminal status.
- Or have the skip emit only when a handoff FILE write was actually attempted.

Note: same OMO TUI-core card-layout observation as DIA-192.

## Verification

Invoke `log_decision(handoff, in-flight, prognosis)` and confirm:

1. The handoff file is NOT touched.
2. No high-severity TUI notification appears after the fix.
3. The skip is still observable in app.log at info level.

## Fix

Implemented 2026-08-15 (coder lane; combined with DIA-192 in one working-tree
diff; ai-auditor APPROVE-WITH-NITS, findings F6/F7 applied).

- .opencode/plugins/delegation-observer.ts skip-if-inflight branch
  (~L2642-2652): the DIA-120 non-terminal resolution_status guard's
  console.warn is now ctx.client.app.log (service delegation-observer, level
  info), same message text - a benign guard no longer surfaces as a
  high-severity TUI notification. Guard behavior UNCHANGED: non-terminal
  statuses still write NO slot and NO pointer (DIA-120 invariant).
- Tests: parallel-handoff.test.mjs S1 DIA-120 filter test now asserts the
  info-level app-log "handoff-writer skipped" message AND the absence of any
  slot/pointer write.

Validation: bun parallel-handoff harness 9/9 (incl. the modified S1 test);
make test-config exit 0 (56/56); make test-shell exit 0 (390); npx prettier
--check exit 0.

## Re-verify

PENDING-restart-verify (after next OpenCode restart; ai-auditor review):

- [ ] invoke log_decision(handoff, in-flight, prognosis) and confirm: the
      handoff file is NOT touched (no slot, no pointer); the skip is visible
      in app.log at info level; NO high-severity TUI notification appears
