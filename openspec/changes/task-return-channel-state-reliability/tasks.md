# Tasks: Reliable task return-channel lifecycle states

**Governing ticket:** DIA-260827-95fv "bug-task-returns-task-cancelled-while-background-session-is-live-or-stopped-without-result-return-channel-false-state"

**Ownership:** substance: AI; structure: AI; interview_depth: full; interview_reason: Developer confirmed the complete 10-question transcript and explicitly approved synthesis.

## 1. Define the failing lifecycle contract (RED)

- [x] 1.1 **Blockers: none.** A dedicated RED coder instance writes focused seam tests for Board-confirmed cancellation, live-or-unconfirmed pending output, stopped-without-result metadata and tombstoning, oldest-first eviction at the dedicated 500-tombstone cap without touching `MAX_PROCESSED_INJECTED_COMPLETIONS` or `maxReusablePerAgent=6`, missing-ID rejection with its exact wire diagnostic and no Board mutation, failed exact-session resume, and unchanged legacy parsing. Acceptance: the two false-state fixed points were committed as RED; additional reviewer-requested tombstone and missing-ID regressions were added by a test-only lane before the final GREEN fix.

## 2. Project authoritative lifecycle state (GREEN)

- [x] 2.1 **Blockers: 1.1.** A different GREEN coder instance implements the minimum identifier validation, Board-backed projection, dedicated tombstone cap, and state persistence that passes the approved RED tests. Acceptance: `cancelled` requires both confirmation fields; only the two approved persisted new states are added; missing task ID returns the exact non-persisted unverifiable diagnostic; legacy states are unchanged; terminal state is never inferred; tombstone eviction is oldest-first and independent of the two named counters.

## 3. Make recovery non-duplicating

- [x] 3.1 **Blockers: 2.1.** Implement the recovery procedure at the existing recovery seam. Acceptance: pending work waits/rechecks; stopped work resumes the exact task session with tombstone evidence; confirmed cancellation alone permits replacement; failed or result-less resume keeps the work non-terminal without automatic replacement; missing task ID requires manual correlation and permits no replacement dispatch.

## 4. Verify lifecycle evidence and rollback readiness

- [ ] 4.1 **Blockers: 2.1, 3.1.** Focused lifecycle tests, the full reference-package suite, typecheck, and static gates pass. Runtime lifecycle smoke remains pending on the rebuilt npm OMO 2.2.19 path. Acceptance: evidence records each state and its required metadata or fixed diagnostic; no duplicate or missing-ID replacement dispatch occurs; rollback restores the prior implementation and dedicated cap as one unit while operators continue identifier and Board verification before replacement dispatch.
