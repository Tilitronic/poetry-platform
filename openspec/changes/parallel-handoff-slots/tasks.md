# Tasks: parallel-handoff-slots

> **Proposal:** `openspec/changes/parallel-handoff-slots/proposal.md`
> **Design:** `openspec/changes/parallel-handoff-slots/design.md`
> **Interview:** `openspec/changes/parallel-handoff-slots/interview.md`
> **Ticket:** DIA-085
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice
> (tracer bullet). Each slice is independently testable.

## Dependency graph

```
T1 (plugin writer: per-session slots + archive + pointer)
 ├──▶ T3 (validate-handoff.sh slot-aware extension)
 │     │
 │     └──▶ T4 (parallel-handoff smoke test + plugin TS unit tests)
 │           │
 │           └──▶ T5 (DIA-085 ticket update + docs reconciliation)
 │
T2 (boot-gate docs: NEXT-RUN.md §1/§7.3 + AGENTS.md §6)
 └──▶ T5
```

**Critical path:** T1 -> T3 -> T4 -> T5
**Parallel track:** T2 runs in parallel with T1/T3 (docs-only, no code
dependencies). T5 requires both T2 and T4 complete.

**Rationale for ordering:** T1 produces the new file layout that T3's
validator extension needs to exercise. T3 produces the slot-aware validator
that T4's smoke test uses. T4 produces the test suite that validates T1
behavior end-to-end. T2 is pure docs and can run any time after T1 lands
(the doc text references the new layout). T5 is final reconciliation and
DIA-085 ticket update, which requires the full implementation to be done.

---

## 1. Plugin writer (core)

### T1.1 — Per-session slot writer + archive + pointer (core slice)

**Blockers:** none
**Vertical slice:** modify `atomicWriteHandoff` (line 1088 of
`.opencode/plugins/delegation-observer.ts`) and `handoffPath` constant
(line 571) to implement the new flow:

1. `handoffs/` directory created on first write (if missing).
2. Archive-on-overwrite: if `handoffs/<sessionId>.json` exists, rename
   to `handoffs/archive/<sessionId>.<iso-ts-hyphenated>.json`. Best-
   effort on error (console.warn, proceed).
3. Write new slot atomically: temp -> fsync -> rename -> fsync dir.
4. Write pointer atomically: temp -> fsync -> rename -> fsync dir.
5. Session ID derived from `parentSessionId ?? args.lane_id ??
"unknown"` (existing logic at line 2450).

The `log_decision` handler (line 2448) passes session_id as a new
parameter to `atomicWriteHandoff`. The terminal-status filter
(`TERMINAL_HANDOFF_STATUSES`, line 2419) is preserved unchanged.

**Acceptance criteria (user perspective):**

- Calling `log_decision(event_type='handoff', resolution_status='done',
prognosis=<JSON>, lane_id='ses_test')` creates
  `.opencode/session/handoffs/ses_test.json` with correct schema
  (status, session_id, cycle_id, timestamp, checksum, prognosis).
- If `handoffs/ses_test.json` already exists, the prior file is moved to
  `handoffs/archive/ses_test.<ts>.json` before the new write.
- `handoffs/active.json` is created/updated with `active_session_id`
  matching the just-written slot.
- Checksum in the slot matches the canonical jq serialization of the
  prognosis (same algorithm as current single-slot writer, DIA-061).
- Non-terminal events (e.g., `resolution_status='in-flight'`) do NOT
  touch the slot or pointer (DIA-120 filter preserved).
- `console.warn "[delegation-observer] handoff archived: ..."` emitted
  when archive happens.

**Verification:** `tsc --noEmit` passes; eslint passes; the smoke test in
T4.1 exercises this slice end-to-end.

---

## 2. Boot-gate docs (parallel with T1)

### T2.1 — NEXT-RUN.md §1 + §7.3 boot-gate updates

**Blockers:** none (can start any time, but should land after T1 so the
described behavior matches reality)
**Vertical slice:** update the operating manual to reflect the new file
layout and resolution chain.

Files touched:

- `docs/dev-infra-audit/NEXT-RUN.md`:
  - §1 step 1: replace "read current-handoff.json" with the resolution
    chain (pointer -> mtime scan -> legacy fallback).
  - §7.3 step 0 (DETECTION): same resolution chain; log detection event
    with the slot's session_id.
  - §7.3 step 0.5 PARALLELISM-CONSTRAINT: rewrite to reflect that
    multiple sessions can now each have their own slot; the constraint
    is "at most one slot per session, but multiple sessions can coexist";
    reconciliation via `.reconciled` sidecar.
  - §7.3 step 1 (VERIFY INTEGRITY): lane-0 computes canonical checksum
    of the RESOLVED slot (not legacy file unless fallback path used).
  - §7.3 step 7 (LANE-0 CHECKSUM DELEGATION): same canonical pipeline,
    new path (`handoffs/<session-id>.json` or via pointer).
  - §7.3 new step after batch approval: mark slot reconciled (append
    session_id to `.reconciled`).
  - §7.8 note: archive-on-overwrite preserves prior slot content,
    reducing §7.8 invocation frequency. §7.8 remains the lossless
    fallback for catastrophic cases.
  - §2 (WRITE RESTRICTION, SELF-RERUN, CRISIS-DETECTION,
    HANDOFF-REFRESH, PROGNOSIS-DISCIPLINE): wording update from
    "writes current-handoff.json atomically" to "writes per-session
    slot atomically + updates pointer".
- `AGENTS.md`:
  - §6 (session-end handoff, DIA-124): reference update — same
    semantics (handoff BEFORE final summary), new path.

**Acceptance criteria (user perspective):**

- NEXT-RUN.md §1 step 1 describes the resolution chain completely.
- NEXT-RUN.md §7.3 steps 0, 0.5, 1, 7 reflect new behavior.
- §7.3 includes a reconciliation step after batch approval.
- §7.8 notes the archive-on-overwrite behavior.
- §2 relevant subsections say "per-session slot" not "current-handoff.json".
- AGENTS.md §6 references the new path.

**Verification:** @reviewer reads the updated NEXT-RUN.md on the Spec-
fidelity axis and confirms the text matches the implemented behavior.

---

## 3. Validator extension

### T3.1 — validate-handoff.sh slot-aware mode

**Blockers:** T1.1 (needs new file layout)
**Vertical slice:** extend `scripts/validate-handoff.sh` to accept:

- No flag: read `handoffs/active.json` -> resolve slot -> validate.
  If pointer missing/mismatched, fall back to mtime scan of `handoffs/`.
  If `handoffs/` empty, fall back to legacy `current-handoff.json`.
- `-s <session-id>`: validate specific slot at
  `handoffs/<session-id>.json`.

Checksum verification works the same (canonical jq serialization of
prognosis). The script's exit-code contract (0 pass / 1 fail / 2 infra)
is preserved.

**Acceptance criteria (user perspective):**

- `bash scripts/validate-handoff.sh` (no args) works end-to-end against
  the new file layout.
- `bash scripts/validate-handoff.sh -s ses_test` validates a specific
  slot.
- Legacy fallback: with empty `handoffs/` dir and existing legacy
  `current-handoff.json`, script validates the legacy file.
- Checksum verification matches existing behavior for the same
  prognosis.
- Exit codes preserved (0/1/2).
- Output contract preserved (ok: to stdout, FAIL:/WARN: to stderr,
  summary line).

**Verification:** bats tests in T4.2 exercise all three modes.

---

## 4. Test suite

### T4.1 — Parallel-handoff smoke test (shell / end-to-end)

**Blockers:** T1.1, T3.1 (needs plugin writer + validator extension)
**Vertical slice:** new `scripts/test-parallel-handoff.sh` exercising the
six acceptance scenarios from proposal.md:

1. **Two-session smoke.** Session A writes slot A + pointer -> A.
   Session B writes slot B + pointer -> B. Verify: both slots exist;
   pointer -> B; archive/ empty; each slot's checksum matches its
   prognosis. `validate-handoff.sh` passes on pointer-resolved slot.
2. **Forced race.** Two writers within 1 second. Verify: both slots
   survive; no file lost; pointer points to one; boot-gate mtime
   fallback finds both.
3. **Same-session rewrite.** Session A writes slot A. Session A later
   rewrites slot A. Verify: `archive/ses_A.<ts>.json` created; new
   slot replaces old; pointer unchanged. Archived slot's checksum
   still matches its (old) prognosis.
4. **Legacy fallback.** Empty `handoffs/` dir. Legacy
   `current-handoff.json` exists. Verify: `validate-handoff.sh`
   falls back and passes on legacy file.
5. **Pointer stale recovery.** Delete `active.json`. Slots exist.
   Verify: `validate-handoff.sh` falls back to mtime scan and passes.
6. **Pointer mismatch recovery.** `active.json` points to deleted
   slot. Another slot exists. Verify: falls back and passes.

The test creates a temporary `.opencode/session/` fixture, exercises
each scenario, reports pass/fail per scenario, cleans up.

**Acceptance criteria:**

- All six scenarios pass (exit 0 per scenario).
- Test is reproducible (hermetic fixture, no external state).
- Test is wired into `make test-config` or similar gate.

### T4.2 — Plugin TS unit tests (bun harness extension)

**Blockers:** T1.1 (needs new writer API)
**Vertical slice:** extend `.opencode/plugins/__tests__/` with a new
`parallel-handoff.test.mjs` (or similar) using the DIA-189 bun harness
pattern.

Unit tests cover the S1 seam scenarios from design.md §6:

- slot write creates `<session-id>.json` with correct schema
- pointer write creates `active.json` with correct session_id
- archive-on-overwrite creates archive/<session-id>.<ts>.json
- archive skipped when no prior slot exists
- checksum in slot matches canonical serialization of prognosis
- terminal-status filter still works (in-flight events skip writer)

**Acceptance criteria:**

- All S1 scenarios pass (bun test, 0 failures).
- Harness integrates with existing `make test-config` / bun test
  invocation.

### T4.3 — validate-handoff.sh bats tests

**Blockers:** T3.1 (needs slot-aware script)
**Vertical slice:** extend (or create)
`scripts/__tests__/validate-handoff.bats` covering the S3 seam:

- default mode (no args) reads pointer, validates pointed slot
- `-s <session-id>` validates specific slot
- missing pointer -> mtime fallback
- legacy fallback
- checksum verification per mode

**Acceptance criteria:**

- All bats cases pass.
- Wired into `make test-shell`.

---

## 5. Final reconciliation

### T5.1 — DIA-085 ticket update + docs reconciliation

**Blockers:** T2.1, T4.1, T4.2, T4.3 (needs full implementation + tests)
**Vertical slice:** update the DIA-085 ticket with the gate metadata
and the populated Fix section, plus any remaining docs reconciliation.

Updates:

- `docs/dev-infra-audit/tickets/DIA-085-handoff-parallel-orchestrator-sessions.md`:
  - Frontmatter: add `gate_state: full-interview`,
    `gate_triggers: [new-module, schema-state, cross-cutting]`,
    `gate_waivers: []`, `gate_override: none`.
  - Status: keep OPEN (will be CLOSED after implementation).
  - Fix section: populated with a reference to the OpenSpec change
    (`openspec/changes/parallel-handoff-slots/`) and a brief summary of
    the design (per-session slots + pointer + archive + reconciliation).
  - Verification section: checklist of the 9 acceptance criteria from
    proposal.md.
- `.opencode/CHANGELOG.md`: entry noting the change (under "dev-infra"
  section, dated).
- `.opencode/memory-shelf.yaml`: register the new OpenSpec change
  under `shelf.specs` (entry added by @openspec-plan as part of this
  task).

**Acceptance criteria:**

- DIA-085 ticket frontmatter updated with gate metadata.
- DIA-085 Fix section populated with change reference + design summary.
- DIA-085 Verification section has the 9 criteria checklist.
- CHANGELOG entry added.
- shelf.specs entry added (see SHELF_REGISTRATION below).

---

## Task sizing (one-context-window check)

| Task | Estimated scope         | Fits one context window? |
| ---- | ----------------------- | ------------------------ |
| T1.1 | ~80-120 lines plugin TS | YES                      |
| T2.1 | ~50-80 lines docs       | YES                      |
| T3.1 | ~60-80 lines bash       | YES                      |
| T4.1 | ~120-160 lines bash     | YES                      |
| T4.2 | ~100-140 lines TS tests | YES                      |
| T4.3 | ~80-120 lines bats      | YES                      |
| T5.1 | ~30-50 lines docs/meta  | YES                      |

All slices sized to fit a single fresh context window per the
`openspec/config.yaml` rule.

---

<!--
ownership:
  substance: developer (via interview decisions; captured in interview.md)
  structure: AI (@openspec-plan)
  interview_depth: full
-->
