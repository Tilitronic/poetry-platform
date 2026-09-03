# DIA-260826-pjm - fix datetime ticket ID parsing in observer gates (C1)

---

id: DIA-260826-pjm
title: "fix datetime ticket ID parsing in observer gates (C1)"
area: delegation-observer
severity: Critical
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260825-wprb
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-09-01

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
evidence:

- .opencode/plugins/**tests**/dia-ticket-id-parser.test.mjs
- .opencode/plugins/**tests**/dia217-ticket-gate.test.mjs
- re-review cycle 1/2 APPROVE 5/5 verified-closed; restart-verify pending

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

Re-verify VALIDATE -> CLOSED (2026-09-01): fix commit a18d4f0 "fix(observer): datetime-first ticket ID parsing via shared const regexes (DIA-260826-pjm)" verified.

- Commit exists: git show --stat a18d4f0 shows .opencode/plugins/delegation-observer.ts replacing six inline DIA-id regex literals with shared datetime-first consts TICKET_ID_RE / TICKET_ID_FIND_RE / TICKET_ID_FILENAME_RE; free-text scan gains word boundaries.
- Datetime ids (DIA-YYMMDD-xxxx) now parse as FULL id at every site instead of truncating to DIA-YYMMDD; ScannedTicket.id uppercased at construction; suffix grammar pinned as [a-z0-9]+.
- Tests: .opencode/plugins/**tests**/dia-ticket-id-parser.test.mjs + dia217-ticket-gate.test.mjs; re-review cycle 1/2 APPROVE 5/5 verified-closed per evidence field.
- Developer-approved procedural closure.
