# DIA-260827-4q3h - [HIGH] Reviewer cannot acquire its required diff (bash denied)

---

id: DIA-260827-4q3h
title: "[HIGH] Reviewer cannot acquire its required diff (bash denied)"
area: opencode-config
severity: High
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-09-11

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

- .opencode/oh-my-opencode-slim/reviewer.md:7-9; .opencode/opencode.jsonc:292-298

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-H4) confirms opencode.jsonc:292-298 forbids reviewer bash, while the prompt (oh-my-opencode-slim.jsonc:1634-1635) requires git diff, git log, and ref resolution. Impact: reviewer may inspect current files instead of the fixed-point delta and miss a regression. Correct fix: a narrow read-only git-diff/log tool, or a mandatory immutable diff artifact in the dispatch.

## Verification

Reviewer obtains the exact fixed-point diff without bash; assertion that diff matches the dispatched ref.

## Fix

Landed in 1dbc41e: reviewer immutable git envelope via hook pre-dispatch. Delegation-observer builds diff/log/ref artifact before reviewer dispatch so the reviewer reads the fixed-point delta without bash. Reviewer prompt updated to consume the envelope. Test harness 12/81 suite (reviewer-immutable-git-envelope.test.mjs) covers F4+F5. ai-auditor: F4+F5 verified-closed, F3 intentional contract (read-only envelope by design, no bash grant). Code plus changelog already landed; this lane is bookkeeping only.

## Re-verify

Re-verify 4q3h: envelope commit 1dbc41e present; harness 12/81 pass per evidence lane; ai-auditor F4+F5 verified-closed, F3 intentional. This close-out lane: make test-config EXIT 0, git diff --check EXIT 0 (evidence in .scratch/test-config.log). No code change in this lane; status may go CLOSED.
