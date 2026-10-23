# DIA-261023-d6b9 - dispatch guard: reject a task payload that carries more than one envelope block

---

id: DIA-261023-d6b9
title: "dispatch guard: reject a task payload that carries more than one envelope block"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-23
source: inventory
date: 2026-10-23
created: 2026-10-23
updated: 2026-10-23

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

The reviewer dispatch path has exactly one legitimate envelope: the one the
pre-spawn hook appends to the child prompt after resolving the marker. Any
SECOND block in the dispatch text is necessarily hand-written by the
orchestrator, and it competes with the injected one for the same marker
capture (the capture regex is `(\S+)`). In this campaign three dispatches
carried a fabricated second block with invented or placeholder OIDs; each
reviewer caught it only because it happened to cross-check the block against
the worktree. A reviewer that trusted it would review a diff that does not
exist and record the range as verified.

## Evidence

- The three occurrences, commits `0a4caf7a` (range review), the nine-commit
  range ending `0e83d1e8`, and the five-commit range ending `338c5578`.
- The durable record and its index row:
  `.opencode/learnings/external-patterns/2026-10-22-orchestrator-envelope-fabrication.md`.
- The pre-spawn hook that already validates the single-marker rule for
  reviewer dispatches is in `.opencode/plugins/delegation-observer.ts` (the
  `tool.execute.before` reviewer-envelope block).

## Proposed fix (scope)

Reject the dispatch before spawning the child when the `task` payload text
contains the envelope marker token more than once. Rationale: the legitimate
count is exactly one, and it is produced by the hook, so a second occurrence
is proof of hand authoring. Keep the existing single-marker and empty-range
checks untouched; do not change the envelope format; do not touch the
reviewer prompt contract.

## Acceptance criteria

- [ ] A reviewer dispatch carrying two envelope blocks fails before a child
      session is created, with an error naming the count.
- [ ] A dispatch carrying exactly one block (the normal case) still spawns a
      child and receives the injected envelope.
- [ ] A test covers both cases through the same seam the existing
      routing-gate suite uses (the cli/content is what the hook sees), including
      the negative case.
- [ ] `make test-config` exits 0 and the routing-gate suite still passes at
      its current count.
- [ ] Restart-verify confirms the guard is live in a fresh session (the
      plugin loads at boot).

## Routing note

OpenCode config surface: AGENTS.md section 2.5 chain applies - ai-specialist
gate, coder implementation, `make test-config` + restart-verify, ai-auditor
independent review, then the changelog entry.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
