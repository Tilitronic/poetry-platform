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

Implemented 2026-08-15 (coder lane; combined with DIA-193 in one working-tree
diff; ai-auditor APPROVE-WITH-NITS, findings F6/F7 applied).

- .opencode/plugins/delegation-observer.ts parsePrognosis (~L2520-2562):
  double-decode retry - JSON.parse(raw); when the result is a STRING (caller
  double-encoded), JSON.parse(inner) recovers the structured object; the inner
  catch preserves pre-DIA-192 behavior for bare plain-string prognoses; the
  plain-text fallback wrapper shape is unchanged. WHY comment documents that a
  catch-only retry would be unreachable (JSON.parse is deterministic).
- Parse-failure reporting: console.warn -> ctx.client.app.log (service
  delegation-observer, level info), firing ONLY when both parses genuinely
  fail - a recovered error no longer surfaces as a high-severity TUI
  notification.
- Gate-driven extension: the log_decision execute-path zero-console.warn grep
  gate also converted the pre-existing "handoff atomic write failed" catch
  (~L2618-2630) to error-level ctx.client.app.log (severity preserved).
- Tests: .opencode/plugins/**tests**/parallel-handoff.test.mjs - harness
  captures ctx.client.app.log; the slot-collision test asserts the
  error-level app-log channel.

Validation: node --experimental-strip-types --check delegation-observer.ts
exit 0; bun parallel-handoff harness 9/9 (63 expect calls) in the dev
container; DIA-192 real probe (container, real plugin execute path):
double-encoded prognosis recovered as a structured object (open_tickets
["DIA-192"], session_summary note recovered) and logs captured [] (info log
correctly silent on success); make test-config exit 0 (56/56); make test-shell
exit 0 (390); npx prettier --check exit 0.

## Re-verify

PENDING-restart-verify (after next OpenCode restart; ai-auditor review):

**Smoke A (double-encoded prognosis):**

- [ ] Invoke log_decision(handoff, done, prognosis=<double-encoded JSON string>) and confirm the handoff slot carries the RECOVERED structured prognosis (open_tickets etc.), the slot checksum is valid, and NO high-severity TUI notification appears.

**Smoke B (single-encoded prognosis):**

- [ ] Invoke log_decision(handoff, done, prognosis=<single-encoded JSON>) and confirm it parses cleanly with no fallback wrapper and no info-level parse-failed log.
