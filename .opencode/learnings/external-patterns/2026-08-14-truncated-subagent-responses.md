---
date: 2026-08-14
topic: truncated/partial subagent responses (detect-preserve-resume-validate mechanism)
source: ai-specialist phase-1 gate (ai--5, ses_fff9d9720ffeVQGixVHFhyproY)
ticket: DIA-099-truncated-subagent-responses
status: active
---

# Truncated/partial subagent responses (DIA-099 Phase 1 gate findings)

## 1. Signal inventory (S1-S13)

Raw observable signals for an empty/truncated/partial lane result, distilled
from the ai--5 gate report (ses_fff9d9720ffeVQGixVHFhyproY) plus the live
registry.jsonl event inventory (2026-08-14). Signals are observable at either
the orchestrator task() return or the registry/messages layer:

| # | Signal | Evidence location | Notes |
|---|--------|-------------------|-------|
| S1 | task() result text empty (length 0) | orchestrator task() return | strongest raw trigger; seen in cod-5 (2026-08-08) |
| S2 | result text < 50 chars | orchestrator task() return | suspect_short bucket |
| S3 | mid-sentence stop (result ends mid-clause, no terminal punctuation) | orchestrator task() return | truncation pattern per ai--5 |
| S4 | "I was unable to complete" / explicit incompletion phrase | orchestrator task() return | truncation pattern per ai--5 |
| S5 | lone intro sentence with no body ("Let me...", "Here is my analysis:" etc.) | orchestrator task() return | seen in ai--1 (session-6, 3m38s) |
| S6 | session_complete event without task_success for the lane | registry.jsonl | D1 component |
| S7 | zero file-edit rows (format_applied/edit evidence) for the lane | registry.jsonl | D1 component |
| S8 | lane duration < 2x lane-class median | registry.jsonl | D1 component |
| S9 | session_failed with error containing MAXIMUM STEPS / "steps" | registry.jsonl | D2 component |
| S10 | stall_detected row with no terminal event after it | registry.jsonl | D5 component (DIA-098) |
| S11 | silent_failure_alert row for the lane | registry.jsonl | plugin A3 retroactive check |
| S12 | result fails the artifact gate (no artifacts[], no RESULT/FILES_TOUCHED/VERIFICATION_EVIDENCE structure) | orchestrator task() return | A4 artifact gate |
| S13 | anomaly_backward_transition row for the lane | registry.jsonl | state-machine anomaly, inferential supplement |

Note: S1-S5 are direct output-text signals; S6-S13 are derived registry
signals. None is sufficient alone (see section 2).

## 2. Discrimination matrix (D1-D5, with precision)

OpenCode has NO native truncation event (no truncation_detected /
steps_exceeded / finish_reason in any hook or session payload). All detection
is DERIVED from registry/messages signals:

| # | Rule | Precision | Class |
|---|------|-----------|-------|
| D1 | session_complete + no task_success + no file edits + duration < 2x median | ~80% | SILENT_FAILURE candidate |
| D2 | session_failed + error contains MAXIMUM STEPS / "steps" | ~95% | CRASH / STEP_CAP |
| D3 | anomaly_backward_transition present (state-machine anomaly) | inferential supplement | ANOMALY |
| D4 | silent_failure_alert row (plugin A3 retroactive) + corroborating S1/S2 | inferential supplement | SILENT_FAILURE |
| D5 | stall_detected + no terminal event | ~90% | STALLED (DIA-098) |

Discrimination is NOT possible from registry signatures alone. Verified cases:

- cod-8 empty result (2026-08-14) was a REPORTING ARTIFACT: the work fully
  landed (commit 442b17e), only the result text was empty.
- cod-4 (2026-08-10) was a genuine SILENT FAILURE: no work landed.
- Both have IDENTICAL registry signatures (session_complete, no task_success,
  no file edits, short duration). Telling them apart REQUIRES external
  ground-truth verification (verify-first read-only lane: git log, file
  existence, ticket status).

## 3. Preservation options (P1 recommended, P5 fallback)

- P1 (RECOMMENDED): dedicated plain-text file
  `.opencode/session/partial-results/<task_id>.json` - survives session
  boundaries, committable, discoverable by task_id.
- P5 (practical mechanism): the ORCHESTRATOR is the writer. The plugin cannot
  see the subagent's final result text directly (it observes session events,
  not the agent's reply content), so the orchestrator-side writer is the
  mechanism that actually populates P1.

P1 file format (JSON):

```json
{
  "task_id": "<lane task_id>",
  "session_id": "<subagent session id>",
  "agent": "<agent name>",
  "timestamp": "<ISO-8601>",
  "status": "partial|empty|suspect_short",
  "result_text": "<the partial/empty result text>",
  "result_length": 0,
  "duration_seconds": 0,
  "detection_signal": "D1|D2|D3|D4|D5",
  "original_task_ref": "<original dispatch ref/ticket>",
  "scope_hash": "<hash of the original task spec>"
}
```

## 4. Resume-prompt template (ai--5 sketch, verbatim)

CONTEXT (prior dispatch + partial output + detection signal) / VERIFY FIRST
(git log, file existence, ticket status; if landed report WORK_LANDED with
evidence, do NOT re-apply) / ORIGINAL TASK SPEC (full, unabbreviated) /
WRITE EARLY (skeletons before deep analysis) / NON-EMPTY RESULT CONTRACT
(RESULT/FILES_TOUCHED/VERIFICATION_EVIDENCE).

## 5. EBDV variants (decision-variant record)

- Variant A (RECOMMENDED, A2 approved): orchestrator saves partial output to
  plain-text `.opencode/session/partial-results/<task_id>.json` (committable),
  then re-dispatches with a resume template that FIRST verifies read-only
  whether the work already landed (git log, file check) before redoing
  anything. No database, no plugin rewrite; uses the existing DIA-098 stall
  detection. The cod-8/cod-9 pattern made systematic.
- Variant B: plugin-embedded truncation detection + persistence (rejected:
  the plugin cannot see the subagent's final result text, G2; and a plugin
  rewrite is high-risk for a detection problem that is fundamentally
  orchestrator-observable).
- Variant C: status quo / manual resume only (rejected: repeated silent
  failures and reporting artifacts justify a systematic mechanism).

## 6. Gaps (open items)

- G1: no native truncation event in OpenCode - all detection derived (no
  truncation_detected / steps_exceeded / finish_reason). Monitor for future
  OpenCode versions.
- G2: the plugin cannot see the subagent's final result text directly - P5
  orchestrator-side writer is the practical preservation mechanism.
- G3: verify-first discrimination is manual today (no scripted
  WORK_LANDED checker); the resume lane performs it read-only per dispatch.
- G4: D1 false positives - the cod-8 reporting-artifact case proves registry
  signatures alone cannot discriminate; ground-truth verification is
  mandatory, never skip it.
- G5: no reproduction script for controlled truncation (ticket deliverable
  (a) remains open; reproduce with a steps-capped lane).
- G6: compaction - long partial outputs need summarization before they are
  embedded in the resume prompt to protect subagent context budgets.

## 7. Sources

- ai--5 Phase 1 gate report, session ses_fff9d9720ffeVQGixVHFhyproY (2026-08-14, Tier-3)
- DIA-099 ticket: docs/dev-infra-audit/tickets/DIA-099-truncated-subagent-responses.md (Tier-3)
- DIA-098 ticket: docs/dev-infra-audit/tickets/DIA-098-spontaneous-session-stops.md (Tier-3, CLOSED 2026-08-14)
- DIA-130 learning: .opencode/learnings/external-patterns/2026-08-13-dia130-escalation-silent-failure.md (Tier-1)
- registry.jsonl event inventory (2026-08-14, Tier-3)
- Incidents: cod-4 (2026-08-10, SILENT FAILURE), cod-5 (2026-08-08, empty after 11m09s),
  cod-8 (2026-08-14, REPORTING ARTIFACT, commit 442b17e), ai--1 (session-6, lone intro sentence) (Tier-3)
