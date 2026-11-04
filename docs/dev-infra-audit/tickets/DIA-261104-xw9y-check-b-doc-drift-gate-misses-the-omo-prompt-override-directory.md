# DIA-261104-xw9y - Check B doc-drift gate misses the OMO prompt-override directory

---

id: DIA-261104-xw9y
title: "Check B doc-drift gate misses the OMO prompt-override directory"
area: opencode-config
severity: Major
status: CLOSED
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

Filed 2026-11-04 out of the coder-lane investigation recorded in
.opencode/learnings/external-patterns/2026-11-04-coder-lane-investigation-budget-and-prompt-surface-findings.md
(observation source DIA-260827-ft3z; sibling ticket DIA-261104-dexw).

Defect as observed: the deny-first doc-drift gate (check B) was reported to
scan .opencode/agents/<name>.md and the preset orchestratorPrompt field only,
and to never scan .opencode/oh-my-opencode-slim/<name>.md or
<name>\_append.md - the prompt-override files the OMO loader actually reads at
runtime. If that held, a "bash: allow" claim written into an override file
would pass the gate while the lane that reads it obeyed it, leaving the doc
contract unenforceable on exactly the files that win at runtime (the append
layer arrives last and survives a base-prompt replacement). The coder pair
would be a total blind spot.

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Resolution (2026-11-04)

Closed as already implemented - no new work needed. The defect was real when
filed and became false at commit 9cfe295e ("test(config): make the analyzer
permission gates non-vacuous and semantic"), which added the missing scan:

- .opencode/scripts/lib/jsonc-parse.js:377 loops over ['.md', '_append.md']
  inside the oh-my-opencode-slim directory and scans each file that exists.
- Pinned by scripts/**tests**/test-config-wiring.bats:418 ("validator: a live
  prompt-override \_append.md file claiming an allow is caught
  (DIA-260827-ft3z)").
- Scope at HEAD: .opencode/agents/<name>.md,
  .opencode/oh-my-opencode-slim/<name>.md and <name>\_append.md, both .prompt
  and .orchestratorPrompt fields, flat-deny agents included - 13 in-scope
  agents.

Bookkeeping under DIA-260827-ft3z: the committed README rollup row for this
ticket and the stale learnings claim were corrected to match HEAD in the same
commit that closes this ticket.
