# DIA-228 — Boot gate reads stale current-handoff.json instead of active slot

---

id: DIA-228
title: "Boot gate reads stale current-handoff.json instead of active slot"
area: opencode-config
severity: Critical
status: CLOSED
blocked_by: []
parent_epic: ""

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18

session_id: "ses_feb515b0affeEPe3x8eIDJD9B3"
lane_id: "orchestrator"
agent: "orchestrator"
model: "mimo-v2.5"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

The orchestrator batch-approval boot gate (NEXT-RUN section 7.3) instructs reading
`.opencode/session/current-handoff.json` to detect a prior session's prognosis. However,
the DIA-085 parallel-handoff-slots system writes handoffs to
`.opencode/session/handoffs/ses_<id>.json` with an `active.json` pointer — the
`current-handoff.json` file is a legacy artifact that is NOT updated by the plugin's
`atomicWriteHandoff`.

**Impact:** On session start, the orchestrator read `current-handoff.json` and presented
a stale prognosis from session `ses_ffd538953ffeHi5JxeN4RF1aAp` (2026-08-15) instead of
the actual active handoff from `ses_feb515b0affeEPe3x8eIDJD9B3` (2026-08-18). This
means:

1. The developer was shown wrong session summary, wrong fixes applied, wrong open tickets
2. Verification requests pointed to stale work (DIA-184/185/177 instead of DIA-222-227)
3. Resume instructions referenced outdated context
4. If the developer had approved without noticing, work would have proceeded against the
   wrong state

**Root cause:** The boot gate protocol predates DIA-085's per-session slot system. The
`current-handoff.json` path was never updated to read from `active.json` ->
`handoffs/<active_session_id>.json`.

## Verification

1. `cat .opencode/session/current-handoff.json | jq .session_id` -- shows stale session
2. `cat .opencode/session/handoffs/active.json | jq .active_session_id` -- shows current
3. `cat .opencode/session/handoffs/<active_session_id>.json | jq .session_id` -- matches active.json
4. The diff between current-handoff.json and the active slot file is total (different session,
   different prognosis, different timestamp)

## Fix

Update the batch-approval boot gate protocol to:

1. Read `.opencode/session/handoffs/active.json` to get the active session ID
2. Read `.opencode/session/handoffs/<active_session_id>.json` for the actual prognosis
3. Fall back to `current-handoff.json` only if active.json is missing (backward compat)

Files to update:

- `docs/dev-infra-audit/NEXT-RUN.md` section 7.3 (boot gate protocol)
- Orchestrator system prompt (batch-approval boot gate section)
- Consider: should the plugin also write `current-handoff.json` as a symlink/copy for
  backward compat? Or is the read-side fix sufficient?

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
