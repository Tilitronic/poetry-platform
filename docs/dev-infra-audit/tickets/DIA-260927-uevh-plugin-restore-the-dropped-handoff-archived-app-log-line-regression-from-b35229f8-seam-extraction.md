# DIA-260927-uevh - plugin: restore the dropped handoff-archived app.log line (regression from b35229f8 seam extraction)

---

id: DIA-260927-uevh
title: "plugin: restore the dropped handoff-archived app.log line (regression from b35229f8 seam extraction)"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: fix-lane
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

Restore the `[delegation-observer] handoff archived: <sid> ...` info line in
app.log that the b35229f8 seam extraction dropped (fix already landed in
`9ff8bb48`; this ticket records the defect and the proof).

## Problem

- Regression origin: the DIA-260902-eqgg seam extraction moved archive behaviour
  into the pure `lib/handoff.ts` helper, which has no `ctx` and by single
  responsibility cannot log, and the log line was never re-homed at the caller
  (recorded in `.opencode/learnings/external-patterns/2026-09-27-empty-result-predicate-and-plugin-observability.md`,
  "Change 2").
- Concrete failure: `.opencode/plugins/__tests__/parallel-handoff.test.mjs:323`
  expects an info app.log whose message contains BOTH `handoff archived: ses_A`
  AND `archive/`; before the fix that assertion failed, while the archive
  filesystem behaviour stayed intact (a passing filesystem test does not prove
  the log line survived).
- Affected surface: `.opencode/plugins/delegation-observer.ts` handoff write path
  (now at :3648); consumer of the line is any audit/observability read of
  app.log for handoff archival, plus the test above.

## Verification

- [ ] `grep -n "handoff archived" .opencode/plugins/delegation-observer.ts`
      returns the log call (present at :3648 as of HEAD).
- [ ] `parallel-handoff.test.mjs` passes, including the BOTH-substrings
      assertion at :323 and the negative no-log-on-first-write case at :253.
- [ ] Plugin suite green (recorded for the shipping commit: 555 pass / 1 skip /
      0 fail, bun 1.4.2).

## Fix

Fixed in `9ff8bb48` ("fix(plugins): empty-result predicate measures result
text; restore handoff archive log (DIA-260926-ch1d, DIA-260927-uevh)", commit
date 2026-09-27). Shape: a guarded
`ctx.client.app.log({ ... message: "[delegation-observer] handoff archived: ${handoffSessionId} prior slot -> ${writeResult.archived_prior}" })`
emitted right after the atomic handoff write, guarded by
`writeResult?.archived_prior` so the first-write case still logs nothing; no
test asserts a log COUNT (all assertions use `.some(...)`), so the addition is
non-breaking for the suite.

## Re-verify

    grep -n "handoff archived" .opencode/plugins/delegation-observer.ts
    grep -n "handoff archived: ses_A" .opencode/plugins/__tests__/parallel-handoff.test.mjs
    cd .opencode/plugins/__tests__ && bun test    # or: make test-harness (Makefile:381-384)
    grep -n "DIA-260927-uevh" .opencode/CHANGELOG.yaml    # cited in the DIA-260926-ch1d entry summary
