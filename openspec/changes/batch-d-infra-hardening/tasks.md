# Tasks: batch-d-infra-hardening

> **Proposal:** `openspec/changes/batch-d-infra-hardening/proposal.md`
> **Design:** `openspec/changes/batch-d-infra-hardening/design.md`
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-174-batch-d-infra-hardening.md`
> **Predecessor change:** `openspec/changes/batch-d-parallel-coders/` (DIA-172)
> **Implementation commits:** none yet (spec phase).
> **Routing:** AGENTS.md section 2.4 (dev-infra, items 1-2) + section 2.5
> (opencode config, items 3-6). `@coder` implements; `make test-config` +
> `make test-shell` validate; `@reviewer` reviews dev-infra slices;
> `@ai-auditor` reviews opencode-config slices.
> **Parallel-implementation model:** 4 disjoint slices (S1-S4), one coder
> per slice, each in its OWN git worktree (batch D). S4 owns BOTH
> AGENTS.md and orchestrator_append.md. S5 is close-out (orchestrator-
> driven, not a coder slice).
> **ASCII-only protocol (DIA-079):** all changes use ASCII-only text.
> **DIA-094 Docker gate:** implementation work AND commits MUST NOT proceed
> without a running docker dev container.
> **DIA-063 Ticket gate:** no implementation work starts without the
> DIA-174 ticket.

## Dependency graph

```
S1 (worktree husky shim) ------+
                               |
S2 (persistent behavioral suite) -- depends on S1 for full end-to-end
                               |    coverage but S2's assertions pass
                               |    without S1 in place
                               v
S3 (coder_append branch model) -- independent
                               |
S4 (orchestrator_append +      |
    AGENTS.md 3 rules)         -- independent
                               |
                               v
S5 (close-out: lockstep greps, full test suite, DIA-174 close-out)
    depends on S1 + S2 + S3 + S4
```

**Critical path:** S1 + S2 (parallel) + S3 + S4 (parallel with S1/S2) -> S5.
S1 and S2 run in parallel (different owners, disjoint files, different
test seams). S3 and S4 run in parallel (different owners, disjoint
files). S5 runs last after all four slices are complete.

**Rationale for four slices (not fewer, not more):**

- **Not fewer:** each slice is a disjoint file set and a distinct
  hardening item. Merging slices would conflate different test seams
  (bats vs node .test.mjs vs grep) and make partial rollback harder.
- **Not more:** each slice is already the narrowest coherent unit.
  Splitting S2 further (e.g., .test.mjs vs Makefile wiring) would
  create a slice that cannot be verified independently (the suite
  needs the wiring to run). Splitting S4 (e.g., ticket-ID vs
  architector design vs merge-gate) would separate tightly-coupled
  orchestrator rules that share the same owning files.

---

## 1. S1: Worktree husky shim (item 1)

- [ ] **1.1 Extend `scripts/worktrees.sh` create to materialize the `.husky/_` shim.**
  - **Blockers:** none
  - **Owner:** S1 (disjoint; no other slice may edit `scripts/worktrees.sh`).
  - **Vertical slice:** in `scripts/worktrees.sh`, in the `cmd_create` function, after the existing `git worktree add` step (around line 185) and before the `.opencode/session/` materialization step (line 194), add a post-create step that copies `.husky/_` from the main tree (ROOT) into the new worktree (path). Use `cp -R` (not symlink, per DD1 in design.md). If the source path (ROOT/.husky/_) does not exist, fail loudly with a clear error message: "husky is not installed in the main tree; run `husky install` before creating worktrees". After the copy, assert that `$path/.husky/_` is a real directory (not a symlink, not missing); fail loudly if the assertion does not hold.
  - **Acceptance criteria:**
    - `scripts/worktrees.sh create feature/DIA-174-test` succeeds AND creates `$path/.husky/_` as a real directory.
    - If the main tree does not have `.husky/_`, the create step fails loudly with the documented error message.
    - The copy is a plain filesystem copy (not a symlink); `test -L $path/.husky/_` returns false.
    - The create step remains bash-3 compatible (no [[]], no associative arrays).
  - **Verification:** `make test-shell` exits 0; new bats cases T17+ (see task 1.2) pass.

- [ ] **1.2 Add T17+ cases to `scripts/__tests__/worktrees.bats` for the husky shim.**
  - **Blockers:** 1.1
  - **Owner:** S1 (disjoint; no other slice may edit `scripts/__tests__/worktrees.bats`).
  - **Vertical slice:** in `scripts/__tests__/worktrees.bats`, add new test cases after the existing T16 (around line 250): T17 `create materializes .husky/_ in the worktree`, T18 `create fails loudly when main tree has no .husky/_`, T19 `create's .husky/_ copy is a real directory, not a symlink`. Each test follows the existing `setup_worktree_repo` fixture pattern (fresh isolated git repo inside `$BATS_TEST_TMPDIR`, copy the script in). T17 pre-populates `.husky/_` in the fixture repo before running `create`, then asserts `.husky/_` exists in the resulting worktree. T18 omits `.husky/_` from the fixture and asserts the create step fails with the documented error message. T19 asserts the copy is a real directory (not a symlink) via `test -L` returning false.
  - **Acceptance criteria:**
    - T17 passes: after `create`, the worktree contains `.husky/_` as a directory.
    - T18 passes: without `.husky/_` in the main tree, `create` exits non-zero with the documented error message.
    - T19 passes: the copied `.husky/_` is not a symlink.
    - Existing T1-T16 continue to pass (no regression).
  - **Verification:** `make test-shell` exits 0; all bats cases T1-T19 pass.

## 2. S2: Persistent behavioral test suite + Makefile wiring (item 2)

- [ ] **2.1 Create `scripts/__tests__/batch-d-infra.test.mjs` with the DIA-172-era assertions.**
  - **Blockers:** none (can run in parallel with S1, S3, S4)
  - **Owner:** S2 (disjoint; no other slice may edit this file or the Makefile).
  - **Vertical slice:** create a new node-native `.test.mjs` file at `scripts/__tests__/batch-d-infra.test.mjs`. No new dependencies (use node's built-in `node:test` and `node:assert`). The suite asserts the following classes of invariants:
    - **grep checks on committed text:** presence of required phrases in `.opencode/oh-my-opencode-slim/coder_append.md` (S3's branch-ownership model), `.opencode/oh-my-opencode-slim/orchestrator_append.md` (S4's three rules), and `AGENTS.md` (S4's codification). Phrase list defined in design.md DD5 and enumerated in S3/S4 acceptance criteria below.
    - **structural checks:** `.sdd/dev-infra/architecture.md` contains the new DD1 ADR (ADR "Worktree husky shim materialization"); `.sdd/opencode-config/architecture.md` ADR 1 + ADR 2 are intact (grep for their headers).
    - **behavioral reconstruction:** the DIA-172 throwaway assertions (plugin classification outcomes for representative batch shapes) reconstructed as node-native test cases (e.g., `isSafeTaskBatch` with synthetic payload arrays asserting SAFE/UNSAFE/silent outcomes; reference the 9 cases listed in `openspec/changes/batch-d-parallel-coders/tasks.md` section 5.1).
  - **Acceptance criteria:**
    - `node scripts/__tests__/batch-d-infra.test.mjs` runs on the host (no container needed) and exits 0 with all assertions passing.
    - The file uses only node built-ins (no `require()` of third-party modules).
    - The file is at least 1 test case per class (grep, structural, behavioral); the exact count is the coder's discretion but must be non-zero.
    - Header comment in the file documents: "gitignored per design.md DD2; recreate or regenerate when invariants evolve."
  - **Verification:** `node scripts/__tests__/batch-d-infra.test.mjs` exits 0.

- [ ] **2.2 Wire the S2 suite into `make test-config` + add `.gitignore` entry.**
  - **Blockers:** 2.1
  - **Owner:** S2 (disjoint; no other slice may edit `Makefile` or `.gitignore`).
  - **Vertical slice:** in `Makefile`, extend the `test-config` target (currently at line 178) to include a step that runs `node scripts/__tests__/batch-d-infra.test.mjs`. In the root `.gitignore`, add an entry that excludes `scripts/__tests__/batch-d-infra.test.mjs` (per design.md DD2). Add a comment in the Makefile step that documents the suite's role (DIA-174 item 2: persistent behavioral tests replacing the DIA-172 throwaway `/tmp` suite).
  - **Acceptance criteria:**
    - `make test-config` runs the S2 suite as part of its pipeline.
    - If the suite is absent (not yet created), `make test-config` fails loudly (not silently passes).
    - `.gitignore` contains the documented entry; `git status` does not list `scripts/__tests__/batch-d-infra.test.mjs` as a tracked or untracked file after creation.
  - **Verification:** `make test-config` exits 0 after 2.1 is in place; without 2.1 it fails with a clear message.

## 3. S3: Branch-ownership in `coder_append.md` (item 3)

- [ ] **3.1 Extend `coder_append.md` worktree-confinement bullet with branch-ownership model.**
  - **Blockers:** none (can run in parallel with S1, S2, S4)
  - **Owner:** S3 (disjoint; no other slice may edit `coder_append.md`).
  - **Vertical slice:** in `.opencode/oh-my-opencode-slim/coder_append.md`, extend the existing worktree-confinement bullet (line 7) with an explicit branch-ownership model. The extended bullet must include ALL of the following phrases (exact wording is the coder's discretion, but these phrases must be present for the grep checks to pass):
    - "worktree base"
    - "sibling branches own"
    - "edit ONLY your assigned files"
    - "disjoint file sets"
    - a clear statement that batch D dispatch payloads MUST name the owned files per slice
  - The existing worktree-confinement wording is preserved (APPEND, not replace).
  - **Acceptance criteria:**
    - The bullet contains all 5 required phrases.
    - The existing worktree-confinement wording is preserved verbatim (diff shows only ADD lines in the bullet).
    - The wording is ASCII-only (DIA-079).
  - **Verification:** `grep -c "worktree base" .opencode/oh-my-opencode-slim/coder_append.md` returns >= 1; same for each of the 4 other required phrases. S2's grep-based test asserts the same.

## 4. S4: Three orchestrator rules in AGENTS.md + orchestrator_append.md (items 4, 5, 6)

- [ ] **4.1 Add three orchestrator rules to `.opencode/oh-my-opencode-slim/orchestrator_append.md`.**
  - **Blockers:** none (can run in parallel with S1, S2, S3)
  - **Owner:** S4 (disjoint; no other slice may edit `orchestrator_append.md`).
  - **Vertical slice:** in `.opencode/oh-my-opencode-slim/orchestrator_append.md`, add three new rules in an appropriate location (near the existing Grounded Dispatch Discipline section, around A1-A6). Each rule is a short paragraph with clear trigger conditions:
    - **Rule R1 (Ticket-ID token in dispatch/resume prompts):** every `task()` dispatch AND every resume prompt MUST contain the literal ticket ID (e.g., "DIA-174"). Resumes without the ticket ID are BLOCKED by the DIA-063 gate; the rule ensures the token is always present so the gate passes naturally. Required phrases in the rule text: "every dispatch", "every resume prompt", "literal ticket ID", "DIA-063 gate".
    - **Rule R2 (Architector design persistence):** after each `@architector` design dispatch, the orchestrator MUST persist the design text into the DIA ticket (or a `.sdd` draft) BEFORE implementation dispatch. Required phrases: "persist the design text", "DIA ticket", "before implementation".
    - **Rule R3 (Merge-gate container evidence):** the merge phase may only start with recorded `docker compose ps` evidence showing the dev service running; the session log MUST record container state before merge dispatch. Required phrases: "docker compose ps", "dev service", "before merge dispatch", "session log".
  - **Acceptance criteria:**
    - All 3 rules are present in the file.
    - Each rule contains its required phrases (see above).
    - The rules are ASCII-only (DIA-079).
    - The rules are placed in an appropriate section (Grounded Dispatch Discipline or a new sibling section).
  - **Verification:** grep for each required phrase returns >= 1 match; S2's grep-based test asserts the same.

- [ ] **4.2 Codify the same 3 rules in `AGENTS.md` section 2.3 / 2.3.1.**
  - **Blockers:** 4.1
  - **Owner:** S4 (disjoint; no other slice may edit `AGENTS.md`).
  - **Vertical slice:** in `AGENTS.md`, extend section 2.3 (Implementation) and section 2.3.1 (Re-Review Loop) to codify the same 3 rules (R1, R2, R3) at the project level. The wording should reference but not necessarily duplicate the orchestrator_append.md wording (AGENTS.md is the canonical source; orchestrator_append.md is the orchestrator-local projection per its own "keep in sync" note). Required phrases in AGENTS.md: "ticket ID", "every dispatch", "every resume prompt", "persist the design text", "docker compose ps", "before merge dispatch".
  - **Acceptance criteria:**
    - AGENTS.md contains all 3 rules at the project level.
    - Each rule's required phrases are present (see above).
    - The rules are ASCII-only (DIA-079).
    - The rules are placed in section 2.3 or 2.3.1 (not in unrelated sections).
    - The existing content of sections 2.3 / 2.3.1 is preserved (diff shows only ADD lines).
  - **Verification:** grep for each required phrase returns >= 1 match; S2's grep-based test asserts the same.

## 5. S5: Close-out (orchestrator-driven, not a coder slice)

- [ ] **5.1 Lockstep greps across S3/S4 directive texts.**
  - **Blockers:** S3 + S4 (all directive text in place)
  - **Owner:** orchestrator (S5 is not a coder slice).
  - **Vertical slice:** run grep-based lockstep checks across the directive texts:
    - `coder_append.md`: all 5 S3 phrases present.
    - `orchestrator_append.md`: all 3 S4 rules' required phrases present.
    - `AGENTS.md`: all 3 S4 rules' required phrases present.
    - Cross-reference: AGENTS.md + orchestrator_append.md agree (lockstep invariant).
  - **Acceptance criteria:**
    - All grep checks return >= 1 match for each required phrase.
    - AGENTS.md and orchestrator_append.md agree on the 3 rules (lockstep).
  - **Verification:** grep commands exit 0 with the expected counts.

- [ ] **5.2 Full test-suite run.**
  - **Blockers:** 5.1
  - **Owner:** orchestrator.
  - **Vertical slice:** run the full dev-infra test suite on the host:
    - `make test-shell` (exits 0; S1 bats cases T1-T19 pass)
    - `make test-config` (exits 0; S2 .test.mjs pass + all existing test-config checks)
    - `bash .opencode/scripts/validate-opencode-config.sh` (exits 0)
    - `bash scripts/validate-agent-names.sh` (exits 0)
  - **Acceptance criteria:**
    - All 4 commands exit 0.
    - No regressions in existing test-config or test-shell checks.
  - **Verification:** exit codes + summary lines captured.

- [ ] **5.3 DIA-174 ticket close-out + CHANGELOG/learnings registration.**
  - **Blockers:** 5.2
  - **Owner:** orchestrator (delegates to `@memory-manager` for learnings registration).
  - **Vertical slice:**
    - Update `docs/dev-infra-audit/tickets/DIA-174-batch-d-infra-hardening.md`: change status from OPEN to DONE; fill in the Fix section with the change summary; fill in the Re-verify section with the test-suite evidence; update files_touched with the files actually modified.
    - Update `docs/dev-infra-audit/tickets/README.md`: change DIA-174 row (status OPEN -> DONE); update summary counts (Major unchanged, OPEN -1, DONE +1).
    - Update CHANGELOG (if the repo has one) with an entry for DIA-174.
    - Dispatch `@memory-manager` with the DIA-174 change summary + learnings (per AGENTS.md Mandatory Final Step) to register the change in `.opencode/memory-shelf.yaml`. The openspec-plan agent does NOT write `.opencode/memory-shelf.yaml` (memory-manager is sole shelf writer).
  - **Acceptance criteria:**
    - DIA-174 ticket status = DONE; Fix + Re-verify sections populated.
    - README row updated; summary counts consistent.
    - CHANGELOG entry present.
    - `@memory-manager` dispatched with the change summary.
  - **Verification:** ticket + README diff reviewed; memory-manager dispatch logged.

---

## Out of scope for these tasks

- **End-to-end orchestrator test** (orchestrator constructs payload ->
  plugin classifies -> coder runs in worktree -> reviewer reviews ->
  squash-merge). This is workflow-adoption testing, orthogonal to this
  change's unit-test surface.
- **`husky install` as the shim strategy** (DD1 rejects this in favor of
  copy).
- **Git-tracking the S2 suite** (DD2 rejects this in favor of gitignored).
- **Relaxing DIA-063 for resume prompts** (DD3 rejects this in favor of
  keeping the gate and ensuring the token is present).
- **Plugin behavioral test additions beyond the DIA-172 throwaway
  reconstruction.** S2 preserves the existing assertions; it does not add
  new plugin test cases.
- **`.sdd/opencode-config/architecture.md` ADR changes.** ADR 1 / ADR 2
  remain as merged by DIA-172.
- **T5.3 restart smoke** (carried over from DIA-172; not adopted by this
  change -- it is an integration-level check that the developer runs
  manually post-merge, not a unit test).
- **DIA-173 items** (out of scope entirely).

## Verification gate summary

| Gate                                                  | When | Required                                                                                                  |
| ----------------------------------------------------- | ---- | --------------------------------------------------------------------------------------------------------- |
| `scripts/worktrees.sh` create materializes `.husky/_` | S1.1 | post-create assertion passes                                                                              |
| bats cases T17+ pass                                  | S1.2 | `make test-shell` exits 0; T17-T19 pass; T1-T16 no regression                                             |
| S2 suite runs on the host with node native            | S2.1 | `node scripts/__tests__/batch-d-infra.test.mjs` exits 0                                                   |
| `make test-config` runs the S2 suite                  | S2.2 | `make test-config` exits 0 after S2.1; fails loudly without S2.1                                          |
| `coder_append.md` branch-ownership phrases            | S3.1 | 5 grep checks pass                                                                                        |
| `orchestrator_append.md` 3 rules                      | S4.1 | required phrases grep pass for each rule                                                                  |
| `AGENTS.md` 3 rules codified                          | S4.2 | required phrases grep pass for each rule; lockstep with orchestrator_append.md                            |
| Lockstep greps (S5.1)                                 | S5.1 | all directive-text grep checks pass                                                                       |
| Full test-suite run (S5.2)                            | S5.2 | `make test-shell` + `make test-config` + validate-opencode-config.sh + validate-agent-names.sh all exit 0 |
| DIA-174 ticket close-out + CHANGELOG + learnings      | S5.3 | ticket status = DONE; README counts consistent; CHANGELOG entry present; memory-manager dispatched        |

## Implementation notes for `@coder`

- **ASCII-only protocol (DIA-079):** all changes to JSONC/markdown/TypeScript/shell must use ASCII-only text (no em-dashes, no smart quotes, no non-ASCII punctuation) to prevent serialization failures.
- **DIA-094 Docker gate:** implementation work AND commits MUST NOT proceed without a running docker dev container.
- **DIA-063 Ticket gate:** no implementation work starts without the DIA-174 ticket.
- **Disjoint-ownership contract:** every file in the change has exactly one owning slice. No other slice may edit it. See the ownership table in design.md.
- **Practice-protected zone:** the OpenSpec artifacts themselves (this file) are practice-protected -- the developer writes the substance, @openspec-plan guides. Implementation of the artifacts (what this tasks.md describes) is not practice-protected; @coder implements freely within the acceptance criteria.
- **Batch D discipline:** every coder dispatched under this change works in its OWN worktree. S1, S2, S3, S4 are 4 independent slices that can be dispatched in parallel under batch D (each coder has a distinct worktree per `.sdd/opencode-config` ADR 1). S5 is orchestrator-driven (no coder).
