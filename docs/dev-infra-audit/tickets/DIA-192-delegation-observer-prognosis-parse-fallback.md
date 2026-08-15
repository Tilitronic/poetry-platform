# DIA-192 - delegation-observer prognosis parse fallback firing: lossy handoff + spurious high-severity TUI notification

<!-- FILED 2026-08-15 (orchestrator lane). NOTE: dispatch requested DIA-190,
     but that number was already taken by the parallel ticket
     DIA-190-conspecter-shelf-edit-permission.md (parallel request, working
     tree). Per COORDINATION.md number-allocation protocol (allocator = max+1,
     same precedent as DIA-191's own header note), this ticket is filed as
     DIA-192, the next free number. -->

---

id: DIA-192
title: "delegation-observer prognosis parse fallback firing: lossy handoff + spurious high-severity TUI notification"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # no blockers
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: session-observation (developer screenshot clipboard-6107e1fa.png 2026-08-15)
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
files_touched: [docs/dev-infra-audit/tickets/DIA-192-delegation-observer-prognosis-parse-fallback.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: [.opencode/images/ses_ffb7ba1daffemGh05K4YUPlQe2/clipboard-6107e1fa.png]

---

## Description

Developer observed a TUI notification:
`[delegation-observer] prognosis parse failed -- falling back to plain-text
wrapper` (screenshot clipboard-6107e1fa.png, 2026-08-15). The notification is
reported at high severity even though the failure is a recovered error.

Recon evidence (code-navigator lane, read-only):

- `parsePrognosis` at `.opencode/plugins/delegation-observer.ts:2400-2414`:
  runs `JSON.parse` on the `log_decision` prognosis string; the catch branch
  falls back to a synthetic 5-key object with `session_summary.note = raw
string` and `fixes_applied` / `open_tickets` / `verification_request` /
  `resume_instructions` all empty.
- Single call site at line 2436, only reached by the terminal-status
  handoff-writer branch (guard lines 2429-2434: `event_type == handoff`,
  prognosis string non-empty, `TERMINAL_HANDOFF_STATUSES` contains
  `resolution_status`).

Live evidence: `.opencode/session/current-handoff.json` written
2026-08-15T09:05:59.706Z has `prognosis.session_summary.note` containing a
JSON-escaped (double-encoded) string, i.e. the caller passed a
JSON-string-of-a-JSON-string or malformed JSON.

DIA-079 relationship: DIA-079 (original uncaught `JSON.parse` crash aborting
the handoff write) is FIXED by this helper; this fallback branch firing is
the hardening working, NOT a regression.

Impact:

1. Handoff prognosis is lossy: structured fields empty, raw text dumped in
   `note`.
2. `console.warn` surfaces as a high-severity TUI notification for a
   recovered error, alarming the developer.

Root-cause hypothesis: the `log_decision` caller hand-assembles the prognosis
string and sometimes double-encodes or emits non-strict JSON.

Fix direction (for design):

- Enforce single-encode in the `log_decision` tool contract.
- Optionally retry `JSON.parse` on a double-encoded value.
- Demote the fallback log from `console.warn` to `ctx.client.app.log` (info)
  so a recovered error does not alarm.

Note: the notification-card layout itself (duplicated "Orchestrator / DeepSeek
V4 Flash (2x usage)" header and footer, truncated status-bar number) is OMO
TUI-core rendering (oh-my-opencode-slim panel), out of project control - low
priority upstream observation.

## Verification

Reproduce and confirm the fallback path:

1. Invoke `log_decision(handoff, done, prognosis=<double-encoded JSON string>)`
   and confirm the fallback fires without crashing.
2. Confirm `current-handoff.json` is still written with a valid checksum.
3. Confirm a non-double-encoded prognosis parses cleanly (no fallback).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
