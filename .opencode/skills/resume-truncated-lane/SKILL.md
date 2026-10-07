---
name: resume-truncated-lane
description: Use when a subagent lane returned an empty/truncated/partial result and the orchestrator needs to resume the original task safely - verify-first read-only, extend partial output, return non-empty structured result.
compatibility: opencode
metadata:
  audience: agents
  workflow: resume
---

# Resume Truncated Lane (DIA-099, Variant A2)

Use when the orchestrator dispatches a resume lane after a subagent returned an
empty, truncated, or suspiciously short result (DIA-099 detection signals D1-D5;
see .opencode/learnings/external-patterns/2026-08-14-truncated-subagent-responses.md).
Your job is to determine whether the work actually landed, then either report
WORK_LANDED with evidence or complete the original task from the preserved
partial state.

## CONTEXT (always provided by the orchestrator)

Your dispatch brief contains three context blocks:

1. **Prior dispatch** - the original task reference (ticket ID + slug) and the
   agent/session that produced the suspect result.
2. **Partial output** - the preserved result text from
   `.opencode/session/partial-results/<task_id>.json` (fields: task_id,
   session_id, agent, timestamp, status, result_text, result_length,
   duration_seconds, detection_signal, original_task_ref, scope_hash).
3. **Detection signal** - which D1-D5 rule flagged the result (empty/short
   text, session_complete without task_success, session_failed with
   MAXIMUM STEPS, stall_detected with no terminal, etc.).

## VERIFY FIRST (read-only, mandatory, before ANY work)

The registry signature of a suspect result CANNOT discriminate a silent
failure from a reporting artifact (cod-8 empty result was a reporting
artifact, work fully landed in commit 442b17e; cod-4 was a genuine silent
failure - identical signatures, opposite outcomes). Ground-truth verification
is mandatory, never skip it. All checks are READ-ONLY - you make no edits
until verification completes:

1. `git log --oneline -5` - did a commit land since the original dispatch?
   Match commit messages/scope against the original task.
2. Check the target files - do the files the task was supposed to create or
   modify exist, and does their content reflect the task requirements?
3. Check the ticket status - `docs/dev-infra-audit/tickets/DIA-NNN-*.md`
   status field, and the registry row for the original lane if available.

**WORK_LANDED short-circuit:** if verification proves the work already landed,
report WORK_LANDED with evidence (commit hash, file paths, ticket status) and
STOP. Do NOT re-apply, do NOT redo, do NOT "improve" - report and return.

## FULL ORIGINAL TASK SPEC

The resume lane is a full re-dispatch, not a delta: the orchestrator provides
the COMPLETE original task spec, unabbreviated. Treat it as authoritative. The
partial output extends it - it never replaces it. If the spec and the partial
output conflict, the spec wins and you flag the conflict in your result.

## WRITE EARLY

If verification shows the work has NOT landed and you must do the work: write
skeletons first (file stubs, function signatures, section headings, TODO
markers) BEFORE deep analysis or implementation. This guarantees the lane
produces durable artifacts even if it is itself cut short - the preserved
state for a THIRD resume will contain the skeletons. Do not front-load
analysis at the expense of any on-disk artifact.

## NON-EMPTY RESULT CONTRACT

Your final result MUST be a non-empty structured report containing exactly:

- **RESULT** - what was found or done (at minimum: WORK_LANDED with evidence,
  or the completed task summary).
- **FILES_TOUCHED** - file paths created/modified (or "none" for WORK_LANDED
  - verified via read-only checks).
- **VERIFICATION_EVIDENCE** - commit hashes, git log excerpts, file existence
  checks, test/lint exit codes.

If you have genuinely nothing to report, say so EXPLICITLY with the reason
(the orchestrator escalates empty results per the 3-failures rule - do not
loop).

## Validation checklist

Before returning, confirm ALL:

- [ ] Original task scope covered - every requirement of the FULL task spec is
      addressed (or explicitly flagged as not applicable with reason).
- [ ] Partial output acknowledged - the result references the partial it
      extends and notes what was reused vs. redone.
- [ ] Verify-first completed - WORK_LANDED or not-landed determination was
      made with evidence BEFORE any write.
- [ ] Non-empty structured result - RESULT / FILES_TOUCHED /
      VERIFICATION_EVIDENCE all present.
- [ ] Read-only verification used only read tools (git log, file reads,
      grep) - no edits were made during the verification phase.
