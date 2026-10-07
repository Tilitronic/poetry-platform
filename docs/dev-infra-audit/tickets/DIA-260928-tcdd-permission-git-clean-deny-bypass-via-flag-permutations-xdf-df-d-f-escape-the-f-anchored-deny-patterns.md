# DIA-260928-tcdd - permission: git clean deny bypass via flag permutations (-xdf, -df, -d -f escape the -f-anchored deny patterns)

---

id: DIA-260928-tcdd
title: "permission: git clean deny bypass via flag permutations (-xdf, -df, -d -f escape the -f-anchored deny patterns)"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-28
source: inventory
date: 2026-09-28
created: 2026-09-28
updated: 2026-09-28

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Found during the DIA-260926-5vin scratch-permission deliberation.

The git clean deny patterns anchor on the -f flag. Flag permutations such as `git clean -xdf`, `git clean -df` and `git clean -d -f` do not match those anchors and fall through to the global catch-all allow.

Needs a probe to confirm the bypass, then a pattern fix (or a flag-normalising guard). Independent of the .scratch work.

Why a literal-spelling deny is structurally fragile: the deny patterns are anchored to one literal spelling of the destructive flag, but the shell accepts many equivalent spellings of the same semantics (clustered short flags, separated flags, reordered flags). Any complete-enumeration approach over spellings is therefore defeated by the next equivalent form. The guard must normalize or expand the flag set before matching, or deny on the verb combined with any destructive flag set rather than on one literal string.

## Re-verify

> To be filled at re-verify time.
