# Proposal: batch-d-infra-hardening

> **Status:** drafted
> **Scope:** dev-infra (6 independent retrospective hardening items from DIA-132)
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-134-batch-d-infra-hardening.md`
> **Predecessor change:** `openspec/changes/batch-d-parallel-coders/` (DIA-132 implementation)
> **Governing SDDs:**
>
> - `.sdd/dev-infra/architecture.md` (worktree lifecycle, parallel-dev model)
> - `.sdd/opencode-config/architecture.md` (batch D ADRs -- now merged by DIA-132)
>   **Routing:** AGENTS.md section 2.4 (dev-infra) for items 1-2 (scripts/, Makefile);
>   section 2.5 (opencode config) for items 3-6 (coder/orchestrator/AGENTS.md
>   directive text). `@coder` implements; `make test-config` + `make test-shell`
>   validate; `@reviewer` reviews dev-infra slices, `@ai-auditor` reviews
>   opencode-config slices.
>   **Parallel-implementation model:** 4 disjoint slices (S1-S4), one coder per
>   slice, each in its OWN git worktree (batch D, per `.sdd/opencode-config`
>   ADR 1). S4 owns both AGENTS.md and orchestrator_append.md (no collision).

## Why

DIA-132 (parallel coders, batch D) shipped 2026-08-14 and exposed 6 friction
points during its own execution: silent hook bypass in worktrees (DIA-094 not
enforced on worktree commits), throwaway tests that vanished across sessions
(same-test contract broken), a coder that edited sibling-branch-owned files
(revert commit af6e019 required), two agent resumes blocked by DIA-063 ticket
gate (missing literal ticket-ID token), an architector design that lived only
in the orchestrator session (false-positive FALSIFICATION-1 review cycle), and
a merge phase attempted against a DOWN container. These are independent,
self-contained hardening items. Fixing them in one change (parallelizable
across 4 slices) closes the DIA-132 retrospective loop without waiting for
6 separate tickets.

## What Changes

### Item 1: Worktree husky-shim gap (slice S1)

`scripts/worktrees.sh create` materializes the `.husky/_` shim in each new
worktree so husky pre-commit + `scripts/verify-pre-commit.sh` actually fire on
worktree commits. Without this, `core.hooksPath` points to runtime state that
is never copied into fresh worktrees, and DIA-094 is silently bypassed.

### Item 2: Persistent behavioral test suite for plugin/config tests (slice S2)

Replace the DIA-132 `/tmp/opencode/batch-d-tests/` throwaway suite with a
persistent, gitignored suite at `scripts/__tests__/batch-d-infra.test.mjs`
(node native, no new deps). Wire it into `make test-config` so RED/GREEN/
merge-verify always re-run the SAME files.

### Item 3: Branch-ownership in batch D payloads (slice S3)

Extend the `coder_append.md` worktree-confinement bullet with an explicit
branch model: "worktree base = <shared sha>; sibling branches own other
slices' files; edit ONLY your assigned files." Prevents the DIA-132 revert
(af6e019) from recurring.

### Item 4: Ticket-ID token in dispatch/resume prompts (slice S4)

Codify in AGENTS.md section 2.3 (and in `orchestrator_append.md`) that every
dispatch AND resume prompt MUST contain the literal ticket ID. Resolves the
DIA-063 ticket-gate friction that blocked two DIA-132 agent resumes.

### Item 5: Architector design persistence (slice S4)

Orchestrator persists the architector design text into the DIA ticket (or a
`.sdd` draft) BEFORE implementation dispatch, so reviewers can verify
"verbatim" ADR transcription claims. Eliminates the DIA-132 FALSIFICATION-1
false positive.

### Item 6: Merge-gate container evidence (slice S4)

Merge phase may only start with recorded `docker compose ps` evidence showing
the dev service running (commit the gate output into the merge report); the
session log MUST record container state before merge dispatch. Eliminates the
DIA-132 double-attempt-against-down-container failure mode.

## Capabilities

### New Capabilities

None. This is a pure dev-infra + opencode-config hardening change -- no
spec-level behavior of the Poetry Platform application changes.

### Modified Capabilities

None. No spec-level behavior changes.

> **Spec opt-out rationale (`skip_specs: true`):** the change modifies
> OpenCode's own configuration (orchestrator/coder directive text, AGENTS.md
> rules), scripts (`worktrees.sh` create step, test suite), and the Makefile
> (test-config wiring). None of this alters the Poetry Platform application's
> observable behavior, APIs, or data models. The change's test surface is
> `make test-config` + `make test-shell` + behavioral tests of the new
> persistent suite + grep-based AC checks on directive text -- all internal
> tooling concerns. Adding spec files to satisfy the validator would invent
> requirements that do not exist.

## Impact

### Affected files (implementation)

| File                                                         | Change                                                                           |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| `scripts/worktrees.sh`                                       | S1: `create` materializes `.husky/_` shim in the new worktree                    |
| `scripts/__tests__/worktrees.bats`                           | S1: add T17+ cases covering worktree-hook-shim behavior                          |
| `scripts/__tests__/batch-d-infra.test.mjs` (NEW, gitignored) | S2: persistent behavioral test suite for DIA-132-era plugin/config assertions    |
| `Makefile`                                                   | S2: `test-config` target runs the new .test.mjs suite                            |
| `.gitignore` (optional)                                      | S2: ignore `scripts/__tests__/batch-d-infra.test.mjs` if needed (decision below) |
| `.opencode/oh-my-opencode-slim/coder_append.md`              | S3: extend worktree-confinement bullet with branch-ownership model               |
| `.opencode/oh-my-opencode-slim/orchestrator_append.md`       | S4: add rules for ticket-ID token, architector design persistence, merge-gate    |
| `AGENTS.md` (section 2.3 + 2.3.1)                            | S4: same three rules codified at the project level                               |

### Affected systems

- **`scripts/worktrees.sh` create path:** post-`git worktree add` step now
  materializes `.husky/_` (copy from main tree). DIA-094 pre-commit gate now
  fires on worktree commits.
- **`make test-config` host gate:** picks up the new .test.mjs suite. No
  container required (host-runnable). Same RED/GREEN/merge-verify contract
  that DIA-132 intended but could not persist across sessions.
- **Coder dispatch payloads:** every batch D dispatch now names the owned
  files explicitly (no more sibling-branch collisions like DIA-132 af6e019).
- **Orchestrator dispatch/resume contract:** every prompt carries the ticket
  ID; architector design text is persisted into the DIA ticket before
  implementation; merge dispatch requires recorded container evidence.

### Not affected

- **Poetry Platform application code:** no TypeScript/Python/Rust application
  files touched.
- **`architecture.md` (root):** no system architecture changes.
- **`.sdd/opencode-config/architecture.md`:** ADR 1 / ADR 2 (batch D) remain
  as merged by DIA-132; this change does not alter them. (A new ADR for S1's
  shim approach is ADR-worthy; see design.md decision DD1.)
- **Docker/CI pipeline:** no container or CI changes.
- **`scripts/verify-pre-commit.sh`:** unchanged -- it is the consumer, not
  the producer, of the husky shim.

## Rollback plan

Every artifact added or modified by this change is independently revertable.

| Artifact                                               | Revert                          |
| ------------------------------------------------------ | ------------------------------- |
| `scripts/worktrees.sh` (husky shim step)               | `git checkout` to prior version |
| `scripts/__tests__/worktrees.bats` (T17+ cases)        | `git checkout` to prior version |
| `scripts/__tests__/batch-d-infra.test.mjs`             | Delete file (gitignored)        |
| `Makefile` (test-config wiring)                        | `git checkout` to prior version |
| `.opencode/oh-my-opencode-slim/coder_append.md`        | `git checkout` to prior version |
| `.opencode/oh-my-opencode-slim/orchestrator_append.md` | `git checkout` to prior version |
| `AGENTS.md` (section 2.3 / 2.3.1 edits)                | `git checkout` to prior version |

All rollbacks are `git checkout` to prior versions or file deletions. No
data migrations, no side effects on running services, no application-code
changes. Rollback restores the pre-change state: silent hook bypass in
worktrees, throwaway-only behavioral tests, bare worktree-confinement bullet,
and the pre-change orchestrator dispatch contract.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that
> states what makes a good test for this change, which modules will be
> tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra + opencode-config hardening -- the test verifies
**mechanical invariants and directive-text grep checks**, not application
logic. A good test is one that:

- fails loudly when the husky shim is NOT materialized in a fresh worktree
  (T17 in `worktrees.bats`: create a worktree, assert `.husky/_` exists,
  assert a commit triggers the hook)
- passes quietly when the behavioral assertions hold (plugin/config
  invariants under S2's .test.mjs)
- uses the SAME test files across sessions (the whole point of S2 -- no more
  `/tmp` drift)
- can be asserted by grep (S3/S4 directive text) or by test exit code (S1
  bats, S2 node)

### Test surface (per module)

| Module                                                  | What is tested                                                                | Test type                                                  |
| ------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `scripts/worktrees.sh` (husky shim)                     | `create` materializes `.husky/_`; a commit in the worktree runs the hook      | `scripts/__tests__/worktrees.bats` T17+ cases (host, bats) |
| `scripts/__tests__/batch-d-infra.test.mjs` (S2's suite) | Persistent behavioral assertions for DIA-132-era plugin/config invariants     | node native `.test.mjs`, wired into `make test-config`     |
| `.opencode/oh-my-opencode-slim/coder_append.md` (S3)    | worktree-confinement bullet carries branch-ownership wording                  | grep-based AC check (via S2's suite or separate grep)      |
| `.opencode/oh-my-opencode-slim/orchestrator_append.md`  | S4 rules present: ticket-ID token, architector design persistence, merge-gate | grep-based AC check (via S2's suite or separate grep)      |
| `AGENTS.md` (S4 codification)                           | same 3 rules codified in section 2.3 / 2.3.1                                  | grep-based AC check                                        |

### Integration verification

- `make test-shell` exits 0 (S1 bats cases pass).
- `make test-config` exits 0 (S2 .test.mjs pass + all existing test-config
  checks still pass).
- Lockstep grep across S3/S4 directive texts: all required phrases present
  in the right files.
- End-to-end: create a fresh worktree via `scripts/worktrees.sh create
feature/DIA-134-test`, make a trivial commit, confirm pre-commit runs
  (visible output, hard-fails when container is down per DIA-094).

### Prior art in the codebase

- **`scripts/__tests__/worktrees.bats`** T1-T16 (DIA-100): established the
  fixture-repo pattern (fresh `git init` inside `$BATS_TEST_TMPDIR`, copy
  the script in). T17+ follows the same pattern, adds husky-shim assertions.
- **Throwaway DIA-132 tests under `/tmp/opencode/batch-d-tests/`:** the
  prior-art behavioral assertions the S2 suite preserves (plugin
  classification outcomes, config invariants). S2 converts them to a
  persistent, gitignored file.
- **`make test-config` gate:** established by DIA-111/DIA-112 config
  validators campaign. Extended by S2 to include the new .test.mjs suite.
- **`make test-shell` gate:** established by DIA-100 worktree lifecycle. S1
  adds T17+ bats cases.

### Test risk and mitigation

**Risk:** S1's husky shim copy assumes `.husky/_` exists in the main tree.
**Mitigation:** the script checks for the source path and fails loudly with
a clear error if absent (no silent bypass -- if husky is not installed in
the main tree, the create step fails and tells the operator to run
`husky install`).

**Risk:** S2's persistent test file being committed accidentally when it
should be gitignored. **Mitigation:** `.gitignore` entry added explicitly;
the file is named so the gitignore pattern matches it. The test file is
gitignored because its assertions are session-local reconstructions of the
DIA-132 throwaway tests; once the plugin/config invariants they assert are
encoded as grep-based checks in other validators, the suite can be
un-gitignored. (Decision DT2 in design.md.)

**Risk:** S3/S4 directive text changes may drift from the grep patterns.
**Mitigation:** the S2 behavioral suite (or a dedicated grep check) asserts
the presence of the key phrases, so drift fails `make test-config`.

### What we explicitly do NOT test

- **End-to-end worktree commit with full pre-commit pipeline** (husky shim +
  `scripts/verify-pre-commit.sh` + docker gate + actual dev container up).
  Tested by developer operational workflow, not by this change's unit tests.
- **Full orchestrator dispatch with ticket-ID token + architector design
  persistence + merge-gate evidence.** Tested by adoption, not by this
  change's unit tests. The directive text is asserted by grep; the
  orchestrator's runtime compliance with the new rules is a workflow
  concern.
- **Plugin behavioral assertions beyond what DIA-132's throwaway suite
  already covered.** S2 preserves the existing assertions; it does not add
  new plugin test cases.

## Blocking questions (up to 3, with recommended answers)

> These are genuine unknowns that could change the spec. Recommended answers
> provided. If the developer does not override, the recommended answers stand
> and artifact creation proceeds.

1. **Q: Should S1's husky shim materialization COPY `.husky/_` from the main
   tree, or RUN `husky install` inside the new worktree?**
   Recommended answer: COPY (not `husky install`). Rationale: `husky install`
   has side effects on the global git config (`core.hooksPath`) and on the
   shared `.husky/_` runtime state; it also requires the husky binary on PATH
   in the worktree's environment. Copying the already-materialized shim is
   pure filesystem work, no side effects, deterministic. Recorded as ADR in
   `.sdd/dev-infra/architecture.md` (DD1).

2. **Q: Should the S2 behavioral test file be git-tracked or gitignored?**
   Recommended answer: gitIGNORED (under `scripts/__tests__/`). Rationale:
   the file is a session-local reconstruction of DIA-132's throwaway tests;
   once the invariants it asserts are encoded as grep-based checks in other
   validators (S3/S4), the suite's per-session content may vary. Gitignoring
   it prevents accidental commit of stale assertions. If the developer wants
   the assertions locked down, the file can be un-gitignored later and the
   assertions promoted to permanent fixtures. (Decision DT2 in design.md.)

3. **Q: Should S4's ticket-ID token rule RELAX the DIA-063 ticket gate for
   resume prompts (so resume prompts no longer need to pass the gate), or
   should it KEEP the gate and just ensure every resume prompt carries the
   token?**
   Recommended answer: KEEP the gate; codify that every resume prompt MUST
   carry the ticket ID (the gate stays intact, resumes just always have the
   token). Rationale: relaxing the gate risks losing the ticket-traceability
   invariant that DIA-063 established; ensuring the token is present is the
   minimal fix that addresses the DIA-132 friction without weakening the
   gate. (Decision DT3 in design.md.)
