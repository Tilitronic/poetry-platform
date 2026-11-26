---
title: "Empty-result predicate measured the wrong thing + dropped handoff-archive observability"
date: 2026-09-27
ticket: DIA-260926-ch1d
related_tickets: [DIA-260927-uevh, DIA-224, DIA-225, DIA-260826-zvu4, DIA-260902-eqgg]
source: ai-specialist (read-only, AGENTS.md 2.5 step 1)
verdict: "GO-with-conditions"
tags: [plugin, delegation-observer, observability, detector, predicate]
---

# Empty-result predicate and plugin observability

## Change 1 - DIA-224 D3 empty-result detector keys on the wrong signal

Finding: the `empty_result_detected` detector (delegation-observer.ts:3270-3278)
keys on `edits === 0` rather than ABSENCE OF TEXT. Measured false-positive rate
263/265 = 99.2% (263 flagged sessions returned >200 chars of assistant text;
zero were truly text-empty). Read-only lanes that returned full reports
(analyzer, ai-specialist, ai-auditor) were labelled SILENT_FAILURE, and the
label leaked into a later retry that re-armed a permission-timeout trap.

Aggravating detail: a READ_ONLY_LANES exemption already exists
(delegation-observer.ts:293-300) and covers researcher, ai-specialist,
ai-auditor, code-navigator, observer and architector - but NOT analyzer, so the
analyzer false positives had a one-line cause sitting in plain sight.

Correct predicate (OWNER DECISION RECORDED 2026-09-27: variant A, text-only):
capture the child's `<task_result>` BODY length in `tool.execute.after`
(delegation-observer.ts ~:2886/:2931) into a per-session map, then fire only
when `hasKnownResult && resultLen === 0 && !isReadOnly && !verificationOnly`.
Fails open when no result text was captured. The genuine empty case (a 98-char
`<task_result></task_result>` envelope) still fires. Accepted consequence: a
lane that EDITS files but returns no text now fires, where the old predicate
silently excluded it.

Label decision (recorded): keep the EVENT name `empty_result_detected`
(scripts/lane-resume:45 keys on it) but stop reusing the shared SILENT_FAILURE
status - emit a distinct, lower-severity status, because a SEPARATE genuine
silent-failure detector also sets SILENT_FAILURE (delegation-observer.ts:1587-1595)
and the two are conflated today.

Consumer map: scripts/lane-resume:45 (event name - behavioural); tests in
empty-result-detection.test.mjs, harness-scenarios/empty-result-silent-failure.scenario.mjs,
failure-cap.test.mjs, harness-scenario-replay.bats, lane-resume.bats. The
DIA-225 3-consecutive-failure cap contract must be RE-ANCHORED to the new
predicate, never deleted.

Rejected variant B was `text-empty AND zero-edits` (strictly narrower, cannot
introduce new firings, but leaves an edited-but-textless lane unflagged).
Rejected variant C was status-quo plus only adding analyzer to READ_ONLY_LANES
(removes the analyzer noise, leaves the 99.2% measurement defect everywhere else).

## Change 2 - DIA-260927-uevh dropped 'handoff archived' log line

Finding: the seam extraction (DIA-260902-eqgg) moved the archive behaviour into
the pure lib/handoff.ts helper (which has no ctx and by SRP cannot log) and
never re-added the log at the caller, so
`.opencode/plugins/__tests__/parallel-handoff.test.mjs:319-326` fails (it
expects an info app.log whose message contains BOTH "handoff archived: ses_A"
AND "archive/"). The archive FILESYSTEM behaviour is intact.

Fix: restore a guarded `ctx.client.app.log({ body: { service:
"delegation-observer", level: "info", message: `[delegation-observer] handoff
archived: ${handoffSessionId} -> ${writeResult.archived_prior}` } })` right
after `libAtomicWriteHandoff` at delegation-observer.ts:3627-3631. Additive and
guarded by `writeResult?.archived_prior`, so the negative case
(parallel-handoff.test.mjs:249-255, no log on a first write) still passes. No
test asserts a log COUNT - every assertion uses `.some(...)`.

## Reusable lesson

A detector predicate must measure the signal it names. "empty result" on a
zero-edit proxy is a type error: edits and text are independent quantities, and
a 99.2% false-positive rate is not noise, it is a wrong measurement that
manufactures retry churn. And when a refactor extracts a seam into a pure
helper, observability owned by the old site must be explicitly re-homed at the
caller: a passing filesystem test does not prove the log line survived.

## Outcome

- DONE (2026-09-27): implemented across commits 6bbbef28, 8e57fb2d, 9ff8bb48 and 0518c9e4 (campaign ticket DIA-260926-ch1d); section 2.5 step 6 independent audit verdict SOUND-with-conditions; its findings F1-F4 addressed in 0518c9e4; plugin suite green at 555 pass / 1 skip / 0 fail on bun 1.4.2; `make test-infra` host confirmation still pending.
