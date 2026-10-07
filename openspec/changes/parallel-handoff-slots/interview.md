# Interview: parallel-handoff-slots

> **Change:** `openspec/changes/parallel-handoff-slots/`
> **Ticket:** DIA-085
> **Interviewer:** @openspec-plan (ope-1 lane)
> **Date:** 2026-08-15
> **Depth mode:** Full
> **Gate check (DIA-104):** full-interview
>
> - triggers: new-module, schema-state, cross-cutting
> - waivers: none
> - override: none
>   **Practice-protected rule applied:** the developer wrote substance through
>   interview decisions; @openspec-plan structured and captured.

---

## Context (incident summary)

On 2026-08-15, two parallel orchestrator sessions both wrote terminal
handoffs into the single-slot `.opencode/session/current-handoff.json`
within ~65 seconds. The second writer clobbered the first, losing the
DIA-174 full 5-subsection prognosis. Recoverable only via registry
cross-refs + native session recall (NEXT-RUN.md §7.8).

DIA-085 was OPEN (deferred-build) since 2026-08-11 with ana011 research
already complete. The incident triggered activation.

---

## Q1 — Scope

**Question:** What exactly changes?

**Options presented:**

- (A) Minimal: per-session slots + archive-on-overwrite
- (B) Medium: per-session slots + pointer + boot-gate selection + archive
- (C) Full: adopt entire ana011 protocol (14h)

**Recommendation:** (B) Medium.

**Developer decision:** **Option B — per-session slots + pointer/index +
boot-gate selection + archive-on-overwrite.**

**Rationale:** eliminates data loss AND keeps boot deterministic AND
matches §7.8 "handoff file is an optimization, not the source of truth"
design principle.

---

## Q2 — Boundary conditions

### Q2.1 Boot-gate selection (pointer session_id != booting session)

**Recommendation:** pointer + slot mtime + registry cross-ref = "latest
terminal handoff for THIS directory"; boot gate presents ALL unreconciled
slots' prognoses if >1 pending, or the single active one.

**Developer decision:** **Confirm.** Add explicit `.reconciled` sidecar
to track approved slots and prevent re-presentation.

### Q2.2 Atomicity of slot+pointer pair

**Recommendation:** pointer is a JSON file (not symlink) written AFTER
slot rename; on mismatch, boot falls back to mtime scan. Pointer is
optimization; slots are source of truth.

**Developer decision:** **Confirm.** Plain JSON pointer, not symlink.

### Q2.3 Backward compat (existing current-handoff.json)

**Recommendation:** boot reads slots FIRST, falls back to legacy
`current-handoff.json` only if `handoffs/` empty. New writer writes
ONLY to slots. Legacy file stays in place as read-only fallback.

**Developer decision:** **Confirm.**

### Q2.4 Session-id in filename

**Recommendation:** `<session-id>.json` only, no human-readable slug.

**Developer decision:** **Confirm.**

### Q2.5 Archive retention

**Recommendation:** deferred self-clean (ana011 §SCOPE-GUARD item 3
pattern).

**Developer decision:** **Confirm.**

### Q2.6 Reconciliation sidecar

**Recommendation:** add `.reconciled` file tracking approved slots.

**Developer decision:** **Confirm.**

---

## Q3 — Performance

**Question:** Is perf a concern?

**Answer:** **Non-issue.** Handoff writes are rare (cycle termination);
reads are once per boot. O(1) atomic rename for writes; O(n) mtime scan
over small dir for fallback reads. No optimization needed.

---

## Q4 — Integration

**Integration points enumerated:**

1. Plugin writer: `atomicWriteHandoff` flow = archive -> write slot ->
   write pointer.
2. Boot gate (NEXT-RUN.md §1 + §7.3): update to new resolution chain.
3. validate-handoff.sh: extend for slot-aware mode.
4. New test script: `scripts/test-parallel-handoff.sh` with 6 scenarios.
5. Docs: NEXT-RUN.md + AGENTS.md updates.

**.gitignore:** no change needed (line 82 covers `.opencode/session/`).

---

## Q5 — Error states

**Error table (11 modes):**

| Failure                            | Behavior                                                 |
| ---------------------------------- | -------------------------------------------------------- |
| Slot rename fails                  | log warn, prior slot intact, log row still emitted       |
| Pointer write fails                | slot valid, pointer stale, boot falls back               |
| Archive rename fails               | log warn, proceed (best-effort)                          |
| Two writers SAME session           | archive preserves prior, new wins                        |
| Two writers DIFFERENT sessions     | both slots exist, pointer to one, boot presents both     |
| Pointer missing                    | boot falls back to mtime scan                            |
| Pointer points to nonexistent slot | boot falls back to mtime scan                            |
| Slot JSON corrupt                  | log error, present raw, human disposes                   |
| Legacy file read fails             | slots authoritative, non-fatal                           |
| .reconciled missing/corrupt        | treat as empty set                                       |
| handoffs/ missing                  | boot falls back to legacy; writer creates on first write |

**Policy:** pointer is dispensable, slots are source of truth, archive is
forensic net, log row is non-negotiable audit trail.

---

## Q6 — Observability

**Observability channels:**

- `console.warn` on archive events.
- Registry row enrichment: optional `archived_prior` field.
- Boot gate report: slot info + reconciled state.
- session-log render: unchanged event types.

---

## Q7 — Acceptance criteria

**9 criteria enumerated** (see proposal.md).

**Test artifacts:**

- `scripts/test-parallel-handoff.sh` (6 scenarios)
- `.opencode/plugins/__tests__/parallel-handoff.test.mjs` (bun harness)
- `scripts/__tests__/validate-handoff.bats` extension

---

## Q8 — Data persistence

- **Slot file format:** identical JSON schema to current-handoff.json.
- **Pointer format:** `{ active_session_id, timestamp, pointer_version: 1 }`.
- **Reconciled sidecar:** `{ reconciled_sessions: [], last_updated }`.
- **Archive filename:** `<session-id>.<iso-ts-hyphenated>.json`.
- **Migration:** none. Legacy file stays; new code ignores it if slots/
  has content.
- **.gitignore:** no change (line 82 covers all).

---

## Phase 3 — Structured Interview Summary

**Confirmed by developer on 2026-08-15.**

See proposal.md for the full summary. Key decisions:

- **Scope:** per-session slots + pointer + archive + reconciliation
  sidecar + boot-gate selection chain + plugin writer changes +
  validator extension + test suite + docs updates.
- **Scope out:** ana011 full claim+heartbeat protocol (separate change).
- **Architecture compliance:** no .sdd/ module doc for delegation-
  observer; operates within .sdd/dev-infra/ boundaries (DIA-073/100
  worktree model) and extends .sdd/dia-redispatch-cycle/ protocol.
- **Error handling:** all failures degrade gracefully.
- **Open questions (deferred):** archive retention, .reconciled pruning,
  pointer_version insurance, TS unit test strategy.

---

## Phase 4 — Completion self-check

- **Depth mode:** Full.
- **All applicable questions answered:**
  - Q1 Scope: answered (Option B + archive)
  - Q2 Boundary: answered (6 sub-questions)
  - Q3 Performance: answered (non-issue)
  - Q4 Integration: answered (5 points)
  - Q5 Error states: answered (11 modes)
  - Q6 Observability: answered (4 channels)
  - Q7 Acceptance: answered (9 criteria)
  - Q8 Data persistence: answered (formats, migration, gitignore)
  - Q9 Boundary contract: N/A (in-process, no FFI)
  - Q10 Visual output: N/A
  - Q11 Numerical: N/A

---

<!--
ownership:
  substance: developer (via interview decisions)
  structure: AI (@openspec-plan)
  interview_depth: full
-->
