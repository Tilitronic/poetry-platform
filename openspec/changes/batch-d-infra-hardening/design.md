# Design: batch-d-infra-hardening

> **Proposal:** `openspec/changes/batch-d-infra-hardening/proposal.md`
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-174-batch-d-infra-hardening.md`
> **Predecessor change:** `openspec/changes/batch-d-parallel-coders/` (DIA-172)
> **Scope:** dev-infra + opencode-config. Six independent hardening items
> grouped into 4 disjoint slices (S1-S4), parallelizable across 4 coders
> under batch D (each coder in its OWN git worktree per
> `.sdd/opencode-config` ADR 1).
> **Governing SDDs:**
>
> - `.sdd/dev-infra/architecture.md` -- worktree lifecycle, parallel-dev
>   model, ADR 3 squash-merge, ADR 6 conflict escalation, ADR 7 worktree
>   location. S1 adds a new ADR (DD1 below) to this document.
> - `.sdd/opencode-config/architecture.md` -- batch D ADR 1 (parallel
>   coders) + ADR 2 (singleton-batch exemption). S4's directive text
>   references but does not alter these ADRs.
>   **Disjoint-ownership contract:** every file in the change has exactly one
>   owning slice across ALL slices. No other slice may edit it.

## Context

DIA-172 shipped and exposed 6 friction points. Each is self-contained;
none requires an architectural escalation (the existing `.sdd/` documents
cover the relevant module boundaries). The design below is file-by-file
and slice-by-slice. For motivation, see proposal.md.

The 4 slices map to 4 disjoint file sets (see Ownership table at the end
of this document). Each slice is independently demoable, independently
revertable, and independently testable. S4 owns BOTH AGENTS.md and
orchestrator_append.md -- no other slice touches either file, eliminating
the DIA-172 af6e019-class collision.

## Goals / Non-Goals

**Goals:**

- Close the worktree husky-shim gap so DIA-094 fires on worktree commits.
- Replace DIA-172's throwaway `/tmp/...` behavioral tests with a
  persistent, gitignored suite under `scripts/__tests__/`, wired into
  `make test-config`.
- Codify the branch-ownership model in `coder_append.md` so future batch
  D dispatches name owned files explicitly.
- Codify three orchestrator rules in AGENTS.md section 2.3 (+ mirror in
  `orchestrator_append.md`): ticket-ID token, architector design
  persistence, merge-gate container evidence.
- Record two ADR-worthy decisions (DD1: copy vs husky install; DD2: suite
  gitignored) in `.sdd/dev-infra/architecture.md`.
- Keep every slice independently revertable.

**Non-Goals:**

- Do NOT change `scripts/verify-pre-commit.sh` (it is the consumer of the
  husky shim, not the producer).
- Do NOT alter `.sdd/opencode-config/architecture.md` ADR 1 / ADR 2 (those
  are already merged by DIA-172 and remain governing).
- Do NOT implement orchestrator-side runtime enforcement of S4's rules
  (the directive text is the contract; enforcement is by adoption, not by
  plugin code in this change).
- Do NOT relax the DIA-063 ticket gate (DD3 below).
- Do NOT add end-to-end orchestrator tests (orchestrator runtime behavior
  is a workflow concern, not this change's unit-test surface).

## Decisions

### DD1: Husky shim materialization strategy (S1 -- ADR-worthy)

**Decision:** `scripts/worktrees.sh create` COPIES `.husky/_` from the
main tree into the new worktree (filesystem-only operation, no side
effects on global git config).

**Rationale:** `husky install` has side effects (mutates
`core.hooksPath`, requires the husky binary on PATH in the worktree
environment, may interact with the shared `.husky/_` runtime state in
unpredictable ways when run in parallel across worktrees). Copying the
already-materialized shim is pure filesystem work, deterministic, and
keeps the worktree isolated from the main tree's husky runtime.

**Alternatives considered:**

- **Run `husky install` inside the new worktree:** rejected because it
  mutates the worktree's `.git/config` and has cross-worktree side
  effects; fails if husky is not on PATH in the worktree's environment.
- **Symlink `.husky/_` from main tree into the worktree:** rejected
  because a symlink breaks the worktree-isolation invariant (a change
  in the main tree's `.husky/_` would silently propagate to all
  worktrees; removal of the main tree breaks every worktree).
- **Do nothing (leave the gap):** rejected because DIA-094 is silently
  bypassed on worktree commits -- the whole point of the hardening is
  to close this gap.

**Post-copy verification:** the create step asserts `.husky/_` exists
in the new worktree after the copy. If the source (main tree) does not
have `.husky/_`, the create step fails loudly with a clear error
("husky is not installed in the main tree; run `husky install` before
creating worktrees") -- no silent bypass.

**ADR placement:** recorded in `.sdd/dev-infra/architecture.md` as a
new ADR (ADR N "Worktree husky shim materialization (copy, not install)").

### DD2: S2 behavioral suite -- gitignored, not tracked (decision)

**Decision:** the new file `scripts/__tests__/batch-d-infra.test.mjs`
is gitignored. A `.gitignore` entry (appended to the existing root
`.gitignore` or placed at `scripts/__tests__/.gitignore`) excludes it.

**Rationale:** the suite is a session-local reconstruction of DIA-172's
throwaway tests. The invariants it asserts (plugin classification
outcomes, config grep checks) may evolve as other validators (S3/S4
grep checks) are added. Gitignoring it prevents accidental commit of
stale assertions. Once the assertions stabilize, the file can be
un-gitignored and promoted to tracked status.

**Alternatives considered:**

- **Track the file from day one:** rejected because the assertions
  are reconstructed per session; early versions will drift and the
  git history will accumulate churn.
- **Keep the suite in `/tmp/`:** rejected because that is the very
  problem DIA-172 exposed (throwaway tests vanish between sessions).
- **Use a different runtime (bats, pytest):** rejected because the
  existing assertions are JavaScript (node) and the DIA-172
  throwaway suite was node. Re-using the runtime avoids a rewrite;
  no new deps needed.

**Wiring:** `make test-config` adds a step that runs `node
scripts/__tests__/batch-d-infra.test.mjs` (node native, no new deps).
If the file is absent (first-time setup), the Makefile step creates a
stub on demand OR the suite is a required file that the developer
creates once per session. Decision: the suite is REQUIRED; absence
fails `make test-config` loudly. The file is gitignored but must be
created locally before running test-config. Documented in the test
file's header comment.

> **Amendment (DIA-176 F2, 2026-08-14):** DD2's gitignore decision is
> SUPERSEDED. The suite was un-gitignored and committed: its assertions
> target committed files only (no session-local content), so a fresh
> clone failed `make test-config` by design once the file was absent —
> a Major review finding. The suite is now tracked, wired into
> `make test-config`, and regenerated when the plugin/config invariants
> it asserts evolve. Recorded as ADR 10 in
> `.sdd/dev-infra/architecture.md`.

### DD3: DIA-063 ticket gate stays intact (decision)

**Decision:** S4 codifies that every dispatch AND resume prompt MUST
contain the literal ticket ID. The DIA-063 ticket gate is NOT relaxed
for resume prompts -- instead, every resume prompt is required to
carry the token, so the gate passes naturally.

**Rationale:** relaxing the gate risks losing the ticket-traceability
invariant that DIA-063 established. Ensuring the token is present is
the minimal fix that addresses the DIA-172 friction (two resumes
blocked) without weakening the gate.

**Alternatives considered:**

- **Relax DIA-063 for resume prompts:** rejected because it opens the
  door to resumes without ticket traceability, which DIA-063 was
  designed to prevent.
- **Add a new gate just for resumes:** rejected as redundant -- the
  existing DIA-063 gate, plus the new rule "every resume prompt MUST
  carry the ticket ID", is the minimal solution.

### DD4: S4 rule placement -- BOTH AGENTS.md and orchestrator_append.md

**Decision:** the three S4 rules (ticket-ID token, architector design
persistence, merge-gate evidence) are codified in BOTH AGENTS.md
section 2.3 (+ 2.3.1 where applicable) AND
`.opencode/oh-my-opencode-slim/orchestrator_append.md`.

**Rationale:** AGENTS.md is the project-level canonical source;
`orchestrator_append.md` is the orchestrator-local projection
explicitly marked "keep in sync with AGENTS.md §2.2/§2.3". Both must
carry the rules for the lockstep invariant to hold.

**Ownership:** S4 owns BOTH files; no other slice touches either file.
This eliminates the DIA-172 af6e019-class collision (a slice editing
a sibling-owned file).

### DD5: Test suite assertions (S2 -- scope lock)

**Decision:** the S2 `.test.mjs` suite asserts the following classes
of invariants (node native, no new deps):

- **Plugin/config grep checks:** presence of required phrases in
  `coder_append.md` (S3's branch-ownership model),
  `orchestrator_append.md` (S4's three rules), and AGENTS.md (S4's
  codification).
- **Structural checks:** `.sdd/dev-infra/architecture.md` contains
  the new DD1 ADR; `.sdd/opencode-config/architecture.md` ADR 1/2
  are intact.
- **Behavioral reconstruction:** the DIA-172 throwaway assertions
  (plugin classification outcomes for representative batch shapes)
  are reconstructed as node-native test cases.

**Rationale:** a single suite that covers grep + structure + behavior
gives the merge-phase coder a single entry point for verification.
Running `make test-config` exercises the whole surface.

## Seams

Tests live at these pre-agreed public boundaries (one seam per test
surface):

| Seam                                                 | Test location                                           | What is tested                                                                   |
| ---------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `scripts/worktrees.sh` create (post-`git worktree` ) | `scripts/__tests__/worktrees.bats` T17+ (bats, host)    | husky shim materialization: `.husky/_` exists after create; commit runs the hook |
| `make test-config` target                            | `scripts/__tests__/batch-d-infra.test.mjs` (node, host) | S2's full assertion surface (grep + structural + behavioral reconstruction)      |
| `coder_append.md` worktree-confinement bullet        | grep via S2's suite                                     | branch-ownership model wording present                                           |
| `orchestrator_append.md` S4 rules                    | grep via S2's suite                                     | ticket-ID token, architector design persistence, merge-gate evidence phrases     |
| `AGENTS.md` section 2.3 / 2.3.1 S4 codification      | grep via S2's suite                                     | same three rules codified at project level                                       |

No new seams are introduced -- the existing bats seam (worktrees.bats)
and the existing `make test-config` seam are both extended.

## Risks / Trade-offs

**Risk:** S1's husky shim copy assumes `.husky/_` exists in the main tree.
**Mitigation:** the script fails loudly with a clear error if the source
path is absent (no silent bypass -- see DD1).

**Risk:** S2's suite is gitignored, so its content could drift unnoticed.
**Mitigation:** the assertions are narrow (grep checks on committed text

- structural checks on committed files + behavioral reconstruction of
  known DIA-172 assertions). Drift is caught by the assertions themselves
  when they fail.

**Risk:** S4's AGENTS.md edits could conflict with other in-flight
changes to section 2.3. **Mitigation:** S4 owns BOTH AGENTS.md and
orchestrator_append.md exclusively; no other slice touches either file.
Other in-flight changes that need to touch section 2.3 must go through
S4's coder (batch-D disjoint-ownership contract).

**Risk:** S2's .test.mjs suite is node-native but the dev container
runs node via mise -- version skew across host/container could cause
false failures. **Mitigation:** the suite uses only node built-ins
(no deps), so version skew is bounded to basic JS semantics (stable
across node 18+).

**Risk:** parallel implementation (4 slices, 4 coders) requires the
batch D infrastructure (which this change partially hardens). **Mitigation:**
the pre-existing batch D infrastructure works; this change hardens
edge cases. If S1's husky shim is not in place at dispatch time, the
orchestrator simply dispatches serially (the existing batch-D path
still works; the husky shim is a post-create step, not a dispatch
prerequisite).

## Migration plan

No migration. Each slice is independently revertable (see proposal.md
Rollback plan). The order of application does not matter -- slices
are disjoint -- but the recommended order is S1 -> S2 -> S3 -> S4
(S2's suite depends on the S1 hook shim for full end-to-end coverage,
but its assertions do not require S1 to be in place to pass).

## Open Questions

None at this time. The three blocking questions in the proposal have
recommended answers that, if accepted, resolve all open design
uncertainty (DD1, DD2, DD3 above).

## Ownership table (final; per-slice file sets)

| Slice | Owner of these files (no other slice may edit)                                                                                                                                                   |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| S1    | `scripts/worktrees.sh` (create-step husky shim); `scripts/__tests__/worktrees.bats` (T17+ cases)                                                                                                 |
| S2    | `scripts/__tests__/batch-d-infra.test.mjs` (NEW, gitignored); `Makefile` (test-config wiring); `.gitignore` (entry for S2 suite)                                                                 |
| S3    | `.opencode/oh-my-opencode-slim/coder_append.md` (worktree-confinement bullet extension)                                                                                                          |
| S4    | `.opencode/oh-my-opencode-slim/orchestrator_append.md` (three new rules); `AGENTS.md` (section 2.3 / 2.3.1 codification)                                                                         |
| S5    | close-out: lockstep greps + full test-suite run + `validate-opencode-config.sh` + `validate-agent-names.sh` + DIA-174 README/CHANGELOG/learnings update (orchestrator-driven, not a coder slice) |

**No overlaps.** S1 owns worktrees.sh + worktrees.bats; S2 owns the new
.test.mjs + Makefile + .gitignore entry; S3 owns coder_append.md; S4
owns orchestrator_append.md + AGENTS.md. S5 is close-out (orchestrator-
driven, no coder slice).
