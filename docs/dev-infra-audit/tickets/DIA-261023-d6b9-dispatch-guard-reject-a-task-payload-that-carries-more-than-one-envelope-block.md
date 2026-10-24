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

## Chosen variant (EBDV DIA-115)

- **Variant A chosen** over B (post-injection count at >1) and C (status quo / intent rule only).
- **Because** the authored dispatch text carries ZERO envelope text - the hook writes the token only into the outbound child prompt at `delegation-observer.ts:1927` - so any authored fence is hand-written by definition. Counting the AUTHORED text before injection is the only form immune to envelope diff/log contamination, and it detects all three recorded occurrences.
- **Threshold correction (off-by-one in the original wording):** "more than one" counts the POST-injection prompt (authored 1 + injected 1 = 2). Counted over the AUTHORED text each of the three occurrences had exactly ONE hand-written block, so the implemented threshold is `count >= 1`, not `> 1`.
- **Scope:** reviewer-only, matching the existing reviewer-only block at `:1826`; a non-reviewer payload never legitimately carries the token.
- **Dropped:** a `count == 1` advisory warn (under pre-injection counting that state IS the defect; under post-injection counting it is the normal state and would fire on every reviewer dispatch).
- The filename retains the original title; the threshold above supersedes it.

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

1. A reviewer dispatch whose authored description+prompt contains a line-anchored envelope fence opener throws via the existing `failEnvelope` closure - `REVIEWER ENVELOPE:` prefix, the count in the message, the prompt left unchanged, rollback still fired, `reviewer_envelope_blocked` row still written.
2. The pattern is line-anchored, not a bare-substring search, so a review range whose diff or log quotes the token does not trip the guard.
3. A non-reviewer dispatch carrying envelope text is untouched (existing inert behaviour preserved).
4. A new `node:test` suite in the routing-order-gate style covers the pure helper, and one new scenario in `.opencode/plugins/__tests__/reviewer-immutable-git-envelope.test.mjs` covers the hook path.
5. `make test-config` exit 0.
6. Restart-verify confirms the guard is live in a fresh session (the plugin loads at boot).

## Routing note

OpenCode config surface: AGENTS.md section 2.5 chain applies - ai-specialist
gate, coder implementation, `make test-config` + restart-verify, ai-auditor
independent review, then the changelog entry.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
