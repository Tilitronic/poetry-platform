# DIA-260825-fjnc - auto-clear stale pending-flag gate files in delegation-observer

---

id: DIA-260825-fjnc
title: "auto-clear stale pending-flag gate files in delegation-observer"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-211
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
updated: 2026-08-26

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

- re-review cycle 2/2: all 4 delta findings verified-closed
- pending-gate-clear.bats 14/14 ok; make test-shell exit 0 (563 ok); make test-config exit 0

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Fix (review cycle 2/2): named conspect check ($res-conspect.md or
_conspect_.md fallback) replaces any-.md; grep -P -> grep -E POSIX-safe
traversal guard; path-traversal bats case added; learnings outcome flipped to
applied. Candidate A standalone script per ai-specialist gate (no plugin hook;
.opencode/plugins/\* untouched).

## Re-verify

Re-verify cycle 2/2: all 4 delta findings verified-closed. Evidence:
pending-gate-clear.bats 14/14 ok; make test-shell exit 0 (563 ok / 0 not ok);
make test-config exit 0; ASCII clean; real .opencode/session flags untouched.
