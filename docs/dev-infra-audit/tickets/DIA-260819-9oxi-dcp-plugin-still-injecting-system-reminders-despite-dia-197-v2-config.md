# DIA-260819-9oxi - DCP plugin still injecting system-reminders despite DIA-197 V2 config

<!-- UPDATE 2026-08-19 (CLOSED): Verified post-restart: DCP config enabled: false, zero system-reminders in session. Ticket CLOSED. -->

---

id: DIA-260819-9oxi
title: "DCP plugin still injecting system-reminders despite DIA-197 V2 config"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19 (CLOSED)

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

DIA-197 V2 decision (2026-08-16) disabled DCP autonomous pruning via config changes:

- `manualMode.enabled: true`
- `compress.permission: "deny"`
- `strategies.deduplication.enabled: false`
- `strategies.purgeErrors.enabled: false`

Ticket DIA-197 was marked OPEN with restart-verify pending. Observation: DCP
system-reminder about context compression still appearing in conversation
(image evidence: ses_fe5153f74ffekHJ1rvgIEdw4U4/clipboard-09caeff7.png).

Either (a) restart-verify never confirmed the config took effect, or
(b) DCP's manual mode still injects system-reminders even with pruning disabled.

Investigation needed:

1. Check if restart occurred after DIA-197 V2 config changes
2. Verify `.opencode/dcp.jsonc` config loaded correctly (registry.jsonl or logs)
3. Determine if manual mode injects system-reminders regardless of pruning settings
4. If config not applied: restart-verify
5. If manual mode still injects: evaluate whether to disable manual mode entirely or accept reminders

## Verification

- [ ] DIA-197 restart-verify status confirmed (restart occurred or documented as skipped)
- [ ] `.opencode/dcp.jsonc` config verified loaded on last restart (evidence from registry.jsonl or logs)
- [ ] DCP system-reminder behavior determined (manual mode injects reminders = expected, or config not applied)
- [ ] If config was not applied: restart-verify completed and system-reminders stopped
- [ ] If manual mode injects reminders: decision documented (disable manual mode or accept as expected behavior)
- [ ] Ticket CLOSED with verification evidence

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

<!-- UPDATE 2026-08-19: DCP disabled (enabled: false in global config). Restart-verify pending. -->
