# Learnings: per-permission ticker rows (DIA-260827-gnsv)

Date: 2026-09-11
Ticket: DIA-260827-gnsv
Workflow: AGENTS.md section-2.5 step 1 (ai-specialist research registration)
Status: Developer APPROVED implement
File: .opencode/learnings/external-patterns/2026-09-11-gnsv-per-permission-ticker-rows.md

## Context

Campaign ticket DIA-260827-gnsv covers per-permission waiting rows in the
ticker/status surface. Prior behavior aggregated waiting state per session,
which hid which permission was blocking progress when multiple permission
requests were outstanding for one session.

Goal: one row per pending permission, with correct correlation from request
to reply/timeout, and scoped clearing that never drops sibling rows.

## Interview agreement (Q1-Q4)

Q1 - Row granularity: per-permission rows, not per-session rollup.
Each pending permission renders its own ticker row so the operator sees
exactly what is blocked and can act on each item independently.

Q2 - State shape: two maps.
- sessionWaiting: session-level waiting flag/summary (existing seam).
- permissionWaiting[sessionID:permissionID]: per-permission entries keyed by
  composite key. Composite key avoids cross-session permissionID collision.

Q3 - Clearing scope: scoped clearing only.
Resolving one permission clears exactly its own entry. Bulk clear is allowed
only for terminal bulk events (error/deleted session), never for a single
permission resolution.

Q4 - Tests: 6 tests with permission_id correlation.
Every waiting/reply/timeout/render path must assert on permission_id (and
the composite key where applicable), so a regression back to per-session
aggregation fails fast.

## ai-specialist specified seams

1. State: keep sessionWaiting; add
   permissionWaiting[sessionID:permissionID].
2. Waiting view: merged time-sorted waiting derived from both maps, so
   session-level and permission-level waits interleave chronologically.
3. Reply path: correlate reply by requestID on the happy path.
4. Timeout path: correlate timeout by permissionID, since timed-out requests
   may no longer carry a live requestID.
5. Render: C2 component plus ticker-render path both thread permission_id
   through, so rows stay stable across re-renders.
6. Bulk: error/deleted session events clear all entries scoped to that
   session (both maps), preserving other sessions.

## Evidence

- ai-specialist report: exact seams listed above (sessionWaiting +
  permissionWaiting composite key, merged time-sorted waiting, reply
  requestID vs timeout permissionID split, C2 + ticker-render
  permission_id threading, bulk error/deleted clear).
- Interview record: Q1-Q4 agreed as summarized above.
- Developer decision: APPROVED implement (section-2.5 step 1 -> step 2/3).

## Recommendation

Implement per plan with no scope expansion:

- Add permissionWaiting map with [sessionID:permissionID] keys; do not
  repurpose sessionWaiting.
- Build merged time-sorted waiting selector; keep sort key stable (request
  time) so rows do not jump.
- Thread permission_id through C2 and ticker-render; assert in all 6 tests.
- Clearing rule: single resolve clears single entry; error/deleted clears
  the whole session scope only.
- No new dependencies, no new abstraction layer; smallest diff that holds
  the 6-test gate.

## Next (section-2.5 flow)

- Step 2: user review of this learning (done - APPROVED).
- Step 3+: design if non-trivial, then @coder implements, then
  make test-config + functional smoke test, then @ai-auditor review, then
  CHANGELOG entry via scripts/changelog-add.

## Outcome (2026-09-11, section-2.5 step 7 closure)

- **status**: VERIFIED (ai-auditor CONFORMANT-WITH-NOTES; minors F7+F8
  fixed: cross-session test 7/7, renderer relabel, bats 6/6).
- **outcome**: per-permission ticker rows landed - one row per pending
  permission with permission_id correlation and scoped clearing (single
  resolve clears single entry; error/deleted clears session scope only).
  Evidence: harness 7 pass/41 expects; make test-shell 642 zero not-ok;
  make test-config EXIT 0; changelog entry registered via
  scripts/changelog-add.
