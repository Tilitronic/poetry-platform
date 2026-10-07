# DIA-099 - Truncated/partial subagent responses: detect-preserve-resume-validate mechanism

<!-- CLOSURE UPDATE (closure lane, 2026-08-14):
     Phase 6 audit: ai--6 (ses_fff6c522dffeI4mdf4eRAF90Jt) verdict
     CONFORMANT-WITH-NOTES - 5 PASS + note 3 (Low, non-blocking: no
     exemption path for legitimately terse valid outputs), note 6 (Medium,
     closure blocker: restart/live functional verify deferred), note 7
     (Medium, closure blocker: reproduction-script deliverable open,
     verification criterion (a)).
     DEVELOPER DISPOSITION (binding) 2026-08-14: "Close w/ rebaseline" -
     all 7 notes accepted. Note 3 accepted as non-blocking (no code change
     needed). Note 7 REBASELINED: the reproduction-script deliverable
     (verification criterion (a)) is DEFERRED to the live restart-verify
     follow-up (documented in the Re-verify section, VERIFICATION REBASELINE
     note below). Status OPEN -> CLOSED 2026-08-14 with deferred live
     restart-verify placeholder per the DIA-123 second-boot pattern (same
     as DIA-078 / DIA-103 closures). README index row + rollup counts
     deferred to the DIA-153 lease commit (README is a protected
     concurrent-session file; not touched by this closure). -->

<!-- SESSION ATTRIBUTION UPDATE (completion lane, 2026-08-14):
     Phase 1 gate: ai--5 (ses_fff9d9720ffeVQGixVHFhyproY) recommended
     Variant A2 (orchestrator-side P1 preservation + verify-first resume;
     no plugin rewrite, no database; uses DIA-098 stall detection +
     cod-8/cod-9 verify-first precedent).
     Developer approved Variant A2 2026-08-14.
     Implementation: cod-11 (ses_fff785ec4ffeVg0XSpxlTF9f1k) landed 3/4:
     (1) learnings file
     .opencode/learnings/external-patterns/2026-08-14-truncated-subagent-responses.md,
     (2) skill .opencode/skills/resume-truncated-lane/SKILL.md, (3) protocol
     section in .opencode/oh-my-opencode-slim/orchestrator_append.md
     L271-308 "Truncated/Empty Subagent Result Protocol (DIA-099, Variant A2)".
     Verification: cod-12 (ses_fff7132cdffedt5LvsV3CSZ6Wk) confirmed the 3/4
     landing (read-only) and that make test-config passes.
     Completion lane (this edit) fills the ticket: blocked_by -> [], Fix
     summary, Re-verify summary. Status stays OPEN: closure after ai-auditor
     review + developer disposition. -->

---

id: DIA-099
title: "truncated/partial subagent responses: detect-preserve-resume-validate mechanism"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-098 (CLOSED 2026-08-14) SATISFIED: its stall-detection chain provides the D2/D5 detection signals used by this mechanism (see learnings file section 2); no longer blocking
discovered:
source: inventory
date: 2026-08-11
created: 2026-08-11
closed: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Design and implement a reliable mechanism for handling truncated or partial
structured responses from subagent lanes. Known incidents: ai--1 (session-6,
one intro sentence only, 3m38s), cod-5 (session-6, empty return after 11m09s,
longest lane), cod-7 (partial structured response). Current workaround: resume
via task_id in a new lane. Goal: detect truncation reliably, preserve partial
output, resume from preserved state, validate resumed output completes the
task. Investigate jointly with DIA-098 (cross-link findings on
complete-vs-interrupted).

### Investigation requirements

1. Reproduce truncation pattern (controlled task with known step-budget).
2. Identify registry/messages signals that distinguish truncation from
   legitimate short output.
3. Evaluate preservation strategy (write partial to persistence-pending.json?
   append to registry with truncation flag?).
4. Design resume prompt strategy (full remaining state + partial output as
   context).
5. Define validation: resumed lane must produce output that (a) covers the
   original task scope, (b) acknowledges the partial it extends.

### Deliverables

- Reproduction script (controlled truncation test).
- Detection signals documented (fields + thresholds).
- Preservation mechanism (file format + location).
- Resume-prompt template.
- Validation checklist.

## Verification

- (a) Reproduction: truncation triggered on demand in test.
- (b) Detection: signal identifies truncation with >=80% precision.
- (c) Preservation: partial output survives session boundary.
- (d) Resume: resumed lane completes original task scope.
- (e) Cross-linked with DIA-098 (joint investigation findings).

## Fix

Variant A2 (approved 2026-08-14 after the ai--5 Phase 1 gate): an
orchestrator-side detect-preserve-resume-validate mechanism. NO plugin
changes, NO database - it rides the existing DIA-098 stall-detection chain
(D2/D5 signals) and the cod-8/cod-9 verify-first precedent. Landed 3/4
(implementation cod-11, verification cod-12):

(a) Learnings file:
`.opencode/learnings/external-patterns/2026-08-14-truncated-subagent-responses.md` - signal inventory S1-S13, discrimination matrix D1-D5, P1 preservation
schema, resume-prompt template, EBDV variant record (A2 chosen; B and C
rejected), gaps G1-G6.

(b) Skill: `.opencode/skills/resume-truncated-lane/SKILL.md` - the resume lane
contract: VERIFY FIRST (read-only: git log, target file existence/content,
ticket status), WORK_LANDED short-circuit (report with evidence, do NOT
re-apply), FULL ORIGINAL TASK SPEC (unabbreviated; spec wins on conflict),
WRITE EARLY (skeletons before deep analysis), NON-EMPTY RESULT CONTRACT
(RESULT / FILES_TOUCHED / VERIFICATION_EVIDENCE), validation checklist.

(c) Orchestrator protocol: `.opencode/oh-my-opencode-slim/orchestrator_append.md`
L271-308 "Truncated/Empty Subagent Result Protocol (DIA-099, Variant A2)":
DETECT (empty result / <50 chars / truncation patterns: mid-sentence stop,
"I was unable to complete", lone intro sentence; registry signals D1/D2/D5,
D3/D4 supplements), PRESERVE (`.opencode/session/partial-results/<task_id>.json`
P1 schema: task_id, session_id, agent, timestamp, status, result_text,
result_length, duration_seconds, detection_signal, original_task_ref,
scope_hash; orchestrator is the writer - gap G2), RESUME (dispatch a lane
with the resume-truncated-lane skill, full spec + partial output +
detection signal), VALIDATE (non-empty structured result; on repeated
empty, escalate per the 3-failures rule - do NOT loop).

(d) Explicitly NOT done: no plugin changes (the plugin cannot see the
subagent's final result text, G2), no database - plain-text committable
P1 files only.

## Re-verify

Positive test (reporting artifact): an empty-result lane triggers the
protocol end-to-end - the orchestrator flags the result, writes the partial
to `.opencode/session/partial-results/<task_id>.json` (P1 schema), and
dispatches a resume lane that VERIFY-FIRST read-only finds the work already
landed; the lane reports WORK_LANDED with evidence (commit hash, file paths,
ticket status) and does NOT re-apply.

Negative test (genuine step-cap): a steps-capped lane (session_failed with
MAXIMUM STEPS, D2 detection) is preserved and resumed; the resume lane
completes the original task scope, acknowledges the partial it extends, and
returns a non-empty RESULT / FILES_TOUCHED / VERIFICATION_EVIDENCE report.

### VERIFICATION REBASELINE (2026-08-14)

VERIFICATION (a) REBASELINED 2026-08-14 (developer disposition 'Close w/
rebaseline'): the on-demand reproduction script (steps:2 capped lane) is
DEFERRED to the live restart-verify follow-up below.

DEFERRED live restart-verify (DIA-099 follow-up): in a POST-change OpenCode
session, trigger a truncated lane result (empty result lane + steps:2 capped
lane) and confirm the protocol fires end-to-end (detect -> preserve -> resume
-> validate) per the DIA-123 second-boot pattern.
