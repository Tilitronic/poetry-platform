# DIA-260827-s4s1 - Replace weak substring meta-task whitelist with structured [META-TASK] marker

---

id: DIA-260827-s4s1
title: "Replace weak substring meta-task whitelist with structured [META-TASK] marker"
area: dev-infra
severity: High
status: OPEN
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
updated: 2026-08-27

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

Reaudit (DIA-260827-wfcx, 2026-08-31; W-H3) confirms .opencode/plugins/delegation-observer.ts:2974-2995 matches substrings 'create ticket', 'procedural authorization', 'meta-task', etc. Impact: a normal prompt such as 'do not create ticket' or injected text bypasses DIA-217 resolution. Correct fix: keep only the exact [META-TASK] marker, validate the target lane and the allowed operation, and remove the natural-language substring matches.

## Verification

Unit test: a prompt containing 'do not create ticket' does NOT bypass the ticket gate; only an exact [META-TASK] marker with a valid lane/operation does.

## Fix

Replace the substring whitelist with a single exact [META-TASK] marker check that validates target lane and allowed operation; remove natural-language substrings (DIA-217 meta-task carve-out uses the structural marker, not substrings).

## Re-verify

> To be filled at re-verify time.
