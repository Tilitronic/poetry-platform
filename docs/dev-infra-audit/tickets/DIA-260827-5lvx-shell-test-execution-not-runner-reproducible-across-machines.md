# DIA-260827-5lvx - Shell test execution not runner-reproducible across machines

---

id: DIA-260827-5lvx
title: "Shell test execution not runner-reproducible across machines"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: baseline
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

scripts/**tests**/bats-wrapper.sh:81-90 warns and continues on vendored runner mismatch. Current tree uses Bats 1.11.0 while the wrapper pins 1.14.0. Impact: different machines run the same 587 tests under different runner semantics.

Reaudit (DIA-260827-wfcx, 2026-08-31) confirms: scripts/**tests**/bats-wrapper.sh:81-90,138-153; vendored 1.11.0 vs pinned 1.14.0, mismatch only warns, and an arbitrary system bats takes priority without a version check. Impact: 585 green tests can have different semantics on two machines. Correct fix: enforce the exact version or always use the immutable vendored/container runner.

## Verification

Fail with a precise bootstrap command, or execute an immutable vendored/containerized runner version.

## Fix

Enforce the exact Bats version (or always use the immutable vendored/container runner); fail when the system bats does not match the pin.

## Re-verify

> To be filled at re-verify time.
