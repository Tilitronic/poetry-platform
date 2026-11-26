# DIA-260821-bqy7 - audit repository risks and prioritize unresolved remediation

---

id: DIA-260821-bqy7
title: "audit repository risks and prioritize unresolved remediation"
area: dev-infra
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-21

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

Record a disposition for every item in the ranked repository-risk remediation
list (ana031/ana033/z1g8) and reconcile the linked OpenSpec reconciliation
change with the audit evidence already delivered.

## Problem

- The audit deliverables exist and are shelf-registered under this ticket:
  `.opencode/memory-shelf.yaml:846` (ana031 ranked top-10),
  `:851` (ana032 August reconciliation), `:856` (ana033 next-10), and
  `knowledge/ana-260921-z1g8-repo-risk-triage/ana-260921-z1g8-repo-risk-triage-report.md:14`
  ("Ticket DIA-260821-bqy7").
- The change filed under this ticket reports 0% completion although ana032
  delivered exactly that work: `openspec/changes/dia-260821-bqy7-ticket-reconciliation/tasks.md`
  has zero checked boxes (`grep -c '^\- \[x\]'` returns 0; sections 1-7 all
  `[ ]`).
- The ranking itself shows no execution progress: ana031's top-ranked items
  are still OPEN in the ledger (e.g. `scripts/tickets show DIA-206`,
  `DIA-213`), and this ticket's own body carried the creation template.

## Verification

- [ ] Every `tasks.md` box is checked with an evidence pointer, or the change
      is archived as superseded by ana032
- [ ] This ticket's Fix section carries a one-line disposition (closed /
      tracked by DIA-x / accepted risk) for each ana031 Top-10 item
- [ ] `make test-config` exit 0 (changelog/shelf validators unaffected)

## Fix

Mark `openspec/changes/dia-260821-bqy7-ticket-reconciliation/tasks.md`
complete with citations to ana032's tables (or archive the change if the
developer rules it superseded), and append a disposition table for the
ana031 Top-10 items to this ticket. Touch:
`openspec/changes/dia-260821-bqy7-ticket-reconciliation/tasks.md` and this
ticket. No implementation code.

## Re-verify

```bash
grep -c '^\- \[x\]' openspec/changes/dia-260821-bqy7-ticket-reconciliation/tasks.md
# > 0, or the change is gone: ls openspec/changes/archive/ | grep bqy7
grep -n "Disposition" docs/dev-infra-audit/tickets/DIA-260821-bqy7-*.md
scripts/tickets show DIA-260821-bqy7     # populated Description/Fix/Re-verify
make test-config                         # exit 0
```

## References

- `.opencode/memory-shelf.yaml:846,851,856` (ana031/ana032/ana033, task_ref DIA-260821-bqy7)
- `knowledge/ana031-repository-risk-prioritization/ana031-repository-risk-prioritization-report.md` (ranked list)
- `openspec/changes/dia-260821-bqy7-ticket-reconciliation/{proposal.md,tasks.md}`
