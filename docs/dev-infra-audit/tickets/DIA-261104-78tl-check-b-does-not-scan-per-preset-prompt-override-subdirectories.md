# DIA-261104-78tl - check B does not scan per-preset prompt-override subdirectories

---

id: DIA-261104-78tl
title: "check B does not scan per-preset prompt-override subdirectories"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-04
source: inventory
date: 2026-11-04
created: 2026-11-04
updated: 2026-11-04

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

Problem: the Check B doc-drift gate in .opencode/scripts/lib/jsonc-parse.js
scans .opencode/oh-my-opencode-slim/<agent>.md and <agent>\_append.md, but not
the per-preset variants <preset>/<agent>.md and <preset>/<agent>\_append.md.
The prompt loader puts the preset directory first in its search order, so a
preset-scoped override wins at runtime and passes the gate unscanned.

Scope: extend the Check B candidate set to the per-preset subdirectories while
keeping deny-first scoping and the existing message shape (agent, file, line,
phrase). Add bats coverage: forbidden phrase in a per-preset <agent>.md, in a
per-preset <agent>\_append.md, and an extended clean fixture.

Acceptance: after extension, run the gate against the current repo. If it
fails, report the drift - do NOT narrow the gate to make it green.

Relation: this is a narrower, newer gap than the one DIA-261104-xw9y closed
(that closure stands; its original defect is fixed).

## Verification

- [ ] Check B candidate set covers <preset>/<agent>.md and
      <preset>/<agent>\_append.md, deny-first scoping preserved, message shape
      (agent, file, line, phrase) unchanged.
- [ ] bats coverage added: forbidden phrase in a per-preset <agent>.md, in a
      per-preset <agent>\_append.md, and an extended clean fixture.
- [ ] Gate run against the current repo; any drift reported, gate not
      narrowed to force green.

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
