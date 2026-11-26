# Proposal: parallel-handoff-slots

> **Status:** proposed · **Scope:** dev-infra (delegation-observer plugin handoff writer + boot-gate protocol)
> **Ticket:** DIA-085 (OPEN, Medium, docs area; deferred-build since 2026-08-11, activated by 2026-08-15 incident)
> **Escalation:** none — change is within existing module boundaries (delegation-observer.ts plugin + NEXT-RUN.md operating manual). No @architector dispatch required.

## Why

On 2026-08-15, two parallel orchestrator sessions both wrote terminal handoffs into
the same single-slot file `.opencode/session/current-handoff.json` within ~65 seconds:

- `ses_ffd538953ffeHi5JxeN4RF1aAp` wrote `self-rerun-48pct` (ticket DIA-174) at 09:04:54Z
- `ses_ffb7ba1daffemGh05K4YUPlQe2` wrote `dia189-cycle` (ticket DIA-189) at 09:05:59Z

The second writer CLOBBERED the first. The DIA-174 full 5-subsection prognosis is LOST
from the file (only the one-line summary survives in `.opencode/session/messages.jsonl`
row 28605). Recovery was possible only via registry cross-refs and native session
recall (NEXT-RUN.md §7.8 lossless fallback).

The system is SINGLE-SLOT by design: only `current-handoff.json` exists, no per-session
variants, no history dirs. The `.opencode/session/claims/` and `claims/history/`
directories from the ana011 protocol are NOT yet built.

DIA-073 (CLOSED) adopted the worktrees-only ruling: parallel sessions in separate
worktrees have separate `.opencode/session/` dirs and no coordination is needed. But
the 2026-08-15 incident happened with sessions in the SAME working directory,
violating the NEXT-RUN.md §7.3 step 0.5 PARALLELISM-CONSTRAINT ("at most ONE session
owns the handoff file at any time"). That constraint was documented but never
enforced.

DIA-120 (CLOSED) fixed a DIFFERENT clobber bug: within a single session, the plugin's
handoff-writer fired on non-terminal (in-flight) events. The fix (commit e15a876)
added a `TERMINAL_HANDOFF_STATUSES` filter. The parallel-session clobber of two
legitimately-terminal writes is a distinct, unresolved bug.

This change closes that bug and makes the handoff system safe for parallel
orchestrator sessions: no last-writer-wins data loss.

## What Changes

1. **Per-session handoff slots.** Replace the single-slot
   `.opencode/session/current-handoff.json` with per-session slot files at
   `.opencode/session/handoffs/<session-id>.json`. Each slot carries its own
   checksum over its own prognosis. Multiple parallel sessions each have their
   own slot; no collision by construction.
2. **Pointer file.** Add `handoffs/active.json` as an optimization that points
   to the most recently written slot. Boot gate reads pointer first; falls
   back to mtime scan of `handoffs/` if pointer is missing/stale/mismatched.
   Pointer is dispensable; slots are the source of truth.
3. **Archive-on-overwrite.** When the same session rewrites its slot (HANDOFF-
   REFRESH G2 within a campaign), the prior slot is renamed to
   `handoffs/archive/<session-id>.<iso-timestamp>.json` before the new slot
   lands. No prognosis is ever silently lost from the filesystem.
4. **Reconciliation sidecar.** Add `handoffs/.reconciled` tracking which slots
   have been presented and approved in a batch. Boot gate filters out
   reconciled slots when scanning, preventing re-presentation of already-
   approved prognoses.
5. **Boot-gate selection chain.** Update NEXT-RUN.md §1 and §7.3 to use the
   resolution chain: pointer -> mtime scan -> legacy `current-handoff.json`
   fallback. Batch approval presents all unreconciled slots when multiple
   exist.
6. **Plugin writer changes.** Modify `delegation-observer.ts` `atomicWriteHandoff`
   (line 1088) and `handoffPath` constant (line 571) to write per-session
   slots + pointer + archive flow. `log_decision` handler (line 2369) passes
   session_id through.
7. **validate-handoff.sh extension.** Slot-aware mode (`-s <session-id>`),
   pointer auto-discovery, legacy fallback.
8. **Parallel-handoff smoke test.** New `scripts/test-parallel-handoff.sh`
   exercising the six acceptance scenarios.
9. **Docs.** NEXT-RUN.md §1, §2 (relevant subsections), §7.3 (steps 0, 1, 7,
   step 0.5 PARALLELISM-CONSTRAINT rewrite), §7.8 (note on archive); AGENTS.md
   §6 DIA-124 reference; DIA-085 ticket frontmatter + Fix section.

## Capabilities

### New Capabilities

(skip_specs: true — dev-infra within existing module boundaries, no Poetry
Platform spec-level behavior change.)

### Modified Capabilities

None at the Poetry Platform spec level. The change is entirely in the dev-
infra operating layer (delegation-observer plugin + orchestrator operating
manual + validation scripts).

## Impact

**Plugin code:** `.opencode/plugins/delegation-observer.ts` — modifies
`atomicWriteHandoff`, `handoffPath` constant, `log_decision` handoff-writer
branch. Preserves existing terminal-status filter (DIA-120).

**Boot-gate docs:** `docs/dev-infra-audit/NEXT-RUN.md` — §1 step 1, §7.3
steps 0/0.5/1/7, §7.8 note, §2 (relevant WRITE RESTRICTION / SELF-RERUN /
CRISIS-DETECTION / HANDOFF-REFRESH / PROGNOSIS-DISCIPLINE wording).

**Orchestrator operating rules:** `AGENTS.md` §6 session-end handoff (DIA-124)
reference update.

**Validation:** `scripts/validate-handoff.sh` extended; new
`scripts/test-parallel-handoff.sh`.

**Runtime state:** new directory `.opencode/session/handoffs/` with per-session
slots, `active.json` pointer, `.reconciled` sidecar, `archive/` subdir. All
gitignored via existing `.gitignore:82` rule (`.opencode/session/`).

**Migration:** none required. Existing `current-handoff.json` stays in place;
boot gate falls back to it if `handoffs/` is empty. First new terminal write
after upgrade creates `handoffs/` and the first slot; legacy file becomes
read-only.

**No application code changes. No Poetry Platform behavior change.**

## Success Criteria

1. **Two-session smoke.** Session A writes slot `ses_AAA.json` + pointer -> A.
   Session B writes slot `ses_BBB.json` + pointer -> B. Both slots exist;
   pointer points to B; archive/ empty; each slot's checksum matches its own
   prognosis. Boot gate reads pointer -> presents B.
2. **Forced race.** Two writers within 1 second. Both slots survive, no file
   lost, pointer points to one; boot-gate mtime fallback finds both.
3. **Same-session rewrite.** Session A writes slot A. Session A later rewrites
   slot A. `archive/ses_AAA.<ts>.json` created with prior content; new slot
   replaces old; pointer unchanged. Archived slot's checksum still matches
   its (old) prognosis.
4. **Legacy fallback.** Empty `handoffs/` dir. Legacy `current-handoff.json`
   (DIA-189 content, checksum c847654d) exists. Boot gate falls back,
   presents it. LANE-0 checksum verification passes on legacy file.
5. **Pointer stale recovery.** Delete `active.json`. Slots exist. Boot gate
   falls back to mtime scan, presents newest slot.
6. **Pointer mismatch recovery.** `active.json` points to deleted slot.
   Another slot exists. Boot gate falls back to mtime scan, presents
   surviving slot.
7. **make test-config passes.** `validate-handoff.sh` extended, new bats /
   smoke tests pass.
8. **Docs updated.** NEXT-RUN.md §1, §2 (relevant subsections), §7.3 (0, 0.5,
   1, 7), §7.8; AGENTS.md §6 DIA-124 reference.
9. **Plugin behavior post-upgrade.** Existing terminal `log_decision`
   invocations still work; new behavior (slot + pointer + archive) observable
   via registry `archived_prior` field when archive happens.

## Non-goals

- ana011 full claim+heartbeat protocol adoption (separate follow-up change,
  e.g., `parallel-session-claims`).
- Stale-claim detection, reclaim procedure, heartbeat scripts (ana011
  territory).
- Changes to registry.jsonl schema beyond the optional `archived_prior` field
  addition.
- Changes to messages.jsonl schema.
- Changes to `.gitignore` (already covers the new paths via line 82).

## Alternatives Considered (EBDV per DIA-115)

- **Option A (narrow, per-session slots only):** Eliminate data loss by giving
  each session its own slot file, but leave boot-gate selection implicit (the
  successor greps registry.jsonl to find its handoff). Rejected: forces the
  expensive §7.8 recovery path on every boot, defeating the whole point of
  the convenience handoff file. (Tier-1: interview Q1 analysis.)
- **Option B (per-session slots + pointer + archive) — CHOSEN:** Adds a
  deterministic pointer file that the boot gate reads first, plus archive-on-
  overwrite so same-session rewrites never lose the prior prognosis. The
  pointer preserves the "deterministic read()" property of the original
  single-slot design; archive gives a forensic safety net; slots are the
  source of truth so pointer is dispensable. Chosen because: eliminates data
  loss AND keeps boot deterministic AND matches §7.8 "handoff file is an
  optimization, not the source of truth" design principle. (Tier-1: ana011
  conflict table row "Handoff clobber = HARD", interview Q1-Q8 decisions.)
- **Option C (full ana011 protocol adoption):** Adopt the entire 10-item
  claim+heartbeat protocol (~14h) including slotting as a subset. Rejected:
  conflation of concerns. ana011 coordinates TASK ownership (who is doing
  what); the handoff file is CYCLE termination (what happened, what next).
  The immediate incident fix is slotting, not full task coordination. Task
  coordination is a separate change that can land after the clobber is fixed.
  (Tier-1: ana011 scope separation analysis.)
- **Status-quo (do nothing):** Reject. The 2026-08-15 incident already
  demonstrated data loss; DIA-174 prognosis was recovered only via the
  §7.8 lossless fallback. Status-quo means every future parallel-session
  clobber requires the same expensive recovery. (Tier-1: incident evidence
  in DIA-085 ticket.)

**Chosen option:** Option B — because it eliminates data loss, preserves
deterministic boot, and layers cleanly on top of §7.8 without requiring the
full ana011 protocol.

## Design Authority (.sdd/) Reference

**No `.sdd/` module doc governs this change directly.** The project's design
authority layer (`architecture.md` + `.sdd/`) does not yet have a module doc
for the delegation-observer plugin. The existing `.sdd/dev-infra/
architecture.md` governs the worktree parallel dev model (DIA-100); this
change operates within its boundaries (no new module boundary, no
technology choice change).

**Closest existing design references:**

- `.sdd/dev-infra/architecture.md` — worktrees-only parallel model (DIA-073/100)
- `.sdd/dia-redispatch-cycle/architecture.md` — the handoff / prognosis /
  cycle termination protocol that this change extends with multi-session safety
- NEXT-RUN.md §7.3 — the boot-gate protocol being modified
- DIA-073 / DIA-120 / DIA-189 — the line of handoff-writer fixes this change
  continues

**No @architector dispatch required** — the change operates within the
existing delegation-observer.ts module boundary and extends the already-
documented handoff protocol.

## Rollback Plan

| Artifact                                    | Revert                                                |
| ------------------------------------------- | ----------------------------------------------------- |
| `.opencode/plugins/delegation-observer.ts`  | git revert (preserves DIA-120 terminal-status filter) |
| `docs/dev-infra-audit/NEXT-RUN.md`          | git revert                                            |
| `AGENTS.md`                                 | git revert                                            |
| `scripts/validate-handoff.sh`               | git revert                                            |
| `scripts/test-parallel-handoff.sh`          | delete file                                           |
| `.opencode/session/handoffs/` (runtime dir) | delete directory (gitignored, no committed state)     |
| `.opencode/session/current-handoff.json`    | untouched (still readable by legacy fallback path)    |

**No data migration.** Legacy `current-handoff.json` stays in place during
rollback. New code path never wrote to it, so rollback restores the prior
single-slot behavior with no residual state.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that
> states what makes a good test for this change, which modules will be
> tested, and the prior art in the codebase."

### What makes a good test here

This change has two testable surfaces:

1. **Plugin behavior** (TypeScript, in-process): `atomicWriteHandoff` flow,
   archive-on-overwrite, pointer write order, `log_decision` session_id
   pass-through. Good test = unit test calling the writer function directly
   and asserting filesystem state after.
2. **Boot-gate protocol + validation** (shell / bash): boot-gate resolution
   chain, validate-handoff.sh slot-aware mode, archive file naming. Good
   test = bats suite setting up filesystem fixtures (slots, pointer, archive,
   legacy file) and asserting the resolution output.

### Modules tested

- `.opencode/plugins/delegation-observer.ts` — writer flow + archive +
  pointer. Prior art: `.opencode/plugins/__tests__/needs-input-observer.dia189.test.mjs`
  (14 tests, bun 1.3.14, 26 expect) — extend with new `parallel-handoff.test.mjs`.
- `scripts/validate-handoff.sh` — slot-aware mode, pointer discovery,
  legacy fallback. Prior art: existing `scripts/__tests__/validate-handoff.bats`
  (if present) or new bats file.
- `scripts/test-parallel-handoff.sh` — new end-to-end smoke test
  exercising the six acceptance scenarios.
- `docs/dev-infra-audit/NEXT-RUN.md` — doc review (manual; @reviewer
  two-axis covers this).

### What we explicitly do NOT test

- Live parallel orchestrator sessions (the incident scenario). The smoke
  test simulates via direct plugin function calls and filesystem fixtures.
- ana011 claim+heartbeat protocol (out of scope, separate change).
- Application code (no Poetry Platform change).

### Test risk and mitigation

**Risk:** Plugin unit tests run in bun; the atomic rename semantics are
POSIX-specific. On Windows / non-POSIX, the test may not reflect production
behavior. **Mitigation:** the dev container is POSIX (Linux); the existing
DIA-189 bun harness runs inside the dev container and is authoritative.
Document the POSIX assumption in the test header.

**Risk:** Boot-gate behavior is protocol-level, hard to automate. **Mitigation:**
NEXT-RUN.md updates are reviewed by @reviewer on the Spec-fidelity axis;
the smoke test covers the filesystem-level resolution logic that the boot
gate depends on.

---

<!--
ownership:
  substance: developer (via interview decisions; captured in interview.md)
  structure: AI (@openspec-plan)
  interview_depth: full
  gate_state: full-interview
-->
