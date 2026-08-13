# DIA-123 - deterministic opencode restart detection for the orchestrator

<!-- Planning ticket filed 2026-08-13 from the DIA-122 restart-verify evidence
     lane (2026-08-13). During the DIA-122 restart-verify, the evidence lane
     detected the opencode restart only through the needs-input-observer ticker
     boot re-seed (ticker.json created at 2026-08-12T22:41:40Z with empty
     waiting/errors lists = fresh boot state). This detection was FRAGILE - it
     worked only because of directory-mtime proof of file creation. The
     developer requested a ticket for a deterministic restart-detection tool so
     the orchestrator can reliably detect opencode restarts in the future.
     This is an opencode-config feature request. Planning ticket - no
     implementation performed yet. -->

---

id: DIA-123
title: "deterministic opencode restart detection for the orchestrator"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
discovered: 2026-08-13
source: evidence-lane (DIA-122 restart-verify)
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Background (2026-08-13 DIA-122 restart-verify evidence lane):** the only
artifact that proved the opencode tool load after the DIA-122 restart was the
needs-input-observer ticker boot re-seed. Today's detection was FRAGILE and
non-deterministic - the orchestrator needs a deterministic restart-detection
mechanism for future restarts.

**(a) The observed detection:** ticker.json created 2026-08-12T22:41:40.490Z,
`updated_at` 22:41:40.492Z matching the file mtime, `version` 1, empty
`waiting` and `errors` lists, parent dir mtime 22:41:40.494Z proving file
CREATION at that instant - the only artifact proving the tool loaded after
restart.

**(b) The five weaknesses that make this non-deterministic:**

1. No `session.created` / boot / tool-load events exist in registry.jsonl
   (0 of 2934 rows) or messages.jsonl (0 rows) - ticker.json existence is the
   ONLY artifact proving tool load.
2. ticker.json `updated_at` is indistinguishable from a periodic rewrite
   without a dedicated boot marker (a `boot_id` / `process_started_at` field
   separate from `updated_at`); only the dir-mtime proof of file creation made
   today's detection a boot re-seed - a future rewrite would lose that
   evidence.
3. registry.jsonl sequence numbers are non-monotonic (35 out-of-order
   transitions observed, last 2898 -> 2866), indicating external
   rewriting/reordering that makes seq-based reasoning unreliable.
4. messages.jsonl writer is stale vs registry.jsonl writer (22:40:21Z vs
   22:42:42Z at detection time) - two divergent freshness domains.
5. current-handoff.json still references the PRIOR session
   (ses_0088b118...), so the handoff timestamp cannot serve as current-session
   restart evidence.

**(c) Proposed deterministic mechanism (to be designed at fix time, NOT
implemented now):**

- Emit an explicit boot/init event (`session.created` for the orchestrator
  session, or `tool.load` with process start time, opencode version, and
  registered tool list) written atomically to registry.jsonl.
- Add a `boot_id` / `process_started_at` field to ticker.json separate from
  `updated_at`.
- Enforce monotonic sequence numbers.
- Unify the event writer so boot evidence lands in the same stream as activity
  evidence.

**Workflow requirements:** if the fix touches `.opencode/` tooling it must
route through the AI Devtools Modernization Workflow (gate research ->
developer review -> design -> implement -> validate -> independent review ->
register). DIA-063 section-10 ticket gate satisfied by this ticket.

## Verification

> To be filled at fix time.

## Fix

> To be filled at fix time. Planning ticket - no implementation performed yet.

## Re-verify

> To be filled at re-verify time.
