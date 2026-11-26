# DIA-260927-ltum - openspec: reconcile dia-206 empty-return-recovery VP-2 and tasks with the shipped text-based empty-result predicate

---

id: DIA-260927-ltum
title: "openspec: reconcile dia-206 empty-return-recovery VP-2 and tasks with the shipped text-based empty-result predicate"
area: scripts
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: inventory
date: 2026-09-27
created: 2026-09-27
updated: 2026-09-27

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

Reconcile the `dia-206-empty-return-recovery` OpenSpec change (proposal, design,
tasks validation points) with the text-based empty-result predicate that actually
shipped in commit `9ff8bb48`.

## Problem

- Shipped predicate (ground truth):
  `.opencode/plugins/delegation-observer.ts:3246-3269` fires
  `empty_result_detected` only when `hasKnownResult && resultLen === 0`, and
  emits `dispatch_state: "EMPTY_RESULT"` / `status: "NO_TEXT_RESULT"`. It no
  longer measures file edits.
- The OpenSpec change still documents the old zero-edit predicate:
  - `openspec/changes/dia-206-empty-return-recovery/proposal.md:8` - "emits a
    crisis event ... when a child session completes with zero file edits".
  - `openspec/changes/dia-206-empty-return-recovery/proposal.md:46` - acceptance
    criterion 4 "Existing behavior preserved: zero-edit coder -> `SILENT_FAILURE`"
    is now wrong on both halves: the trigger is text-emptiness, and the shipped
    status is `NO_TEXT_RESULT`, not `SILENT_FAILURE` (label decision recorded in
    `.opencode/learnings/external-patterns/2026-09-27-empty-result-predicate-and-plugin-observability.md`,
    Change 1).
  - `openspec/changes/dia-206-empty-return-recovery/tasks.md:41` (VP-1) - "zero
    edits each"; `tasks.md:42` (VP-2) - "Drive 1 coder task with an edit then
    idle; assert NO `empty_result_detected` row (reset path intact)". VP-2 is
    the direct contradiction: under the shipped predicate a lane that EDITS but
    returns no text DOES fire (accepted consequence, learning file Change 1), so
    VP-2 as written asserts the opposite of current behaviour.
  - `openspec/changes/dia-206-empty-return-recovery/tasks.md:89-91` (Test A/B/C)
    and `design.md:82-92` (sequence diagram `session.idle (0 edits)`) carry the
    same zero-edit framing.
- Consequence: the change is unusable as written - an implementer or reviewer
  driving VP-2 gets a failing (or misleading) validation run against shipped
  code.

## Verification

- [ ] `grep -rn "zero file edits\|zero-edit\|0 edits" openspec/changes/dia-206-empty-return-recovery/`
      returns only text that is explicitly marked as the retired predicate (or
      nothing).
- [ ] VP-2 in `tasks.md` states the shipped expectation: an edit with EMPTY
      result text fires `empty_result_detected` with `status: NO_TEXT_RESULT`,
      and reset happens on a NON-EMPTY result text.
- [ ] proposal acceptance criterion 4 names `NO_TEXT_RESULT` (not
      `SILENT_FAILURE`) and keys on result text.
- [ ] The reconciled spec still preserves the two exemptions: `READ_ONLY_LANES`
      and verification-only lanes (DIA-260826-zvu4) emit no row.
- [ ] `make test-config` exit 0 (the spec files are prose only, so this is the
      guard that nothing structural was disturbed).

## Fix

Proposed fix, spec-only (no plugin change - the shipped code is the reference):

1. `openspec/changes/dia-206-empty-return-recovery/proposal.md` - rewrite the
   motivation sentence (line 8) and acceptance criterion 4 (line 46) to the
   text-based predicate and `NO_TEXT_RESULT`.
2. `openspec/changes/dia-206-empty-return-recovery/tasks.md` - restate VP-1,
   VP-2 and Test A/B/C so "empty" means `resultLen === 0` with a captured
   result, and VP-2's negative case becomes "edit + non-empty result text ->
   no row".
3. `openspec/changes/dia-206-empty-return-recovery/design.md` - correct the
   sequence-diagram labels (`session.idle (0 edits)` -> empty result text).

Acceptance: the change's validation points pass as written against HEAD.

## Re-verify

    grep -rn "zero file edits\|zero-edit\|0 edits" openspec/changes/dia-206-empty-return-recovery/
    grep -n "NO_TEXT_RESULT\|SILENT_FAILURE" openspec/changes/dia-206-empty-return-recovery/proposal.md
    grep -n "hasKnownResult && resultLen === 0" .opencode/plugins/delegation-observer.ts   # spec agrees with this line
    make test-config
