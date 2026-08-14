# Tasks: batch-d-parallel-coders

> **Proposal:** `openspec/changes/batch-d-parallel-coders/proposal.md`
> **Design:** `openspec/changes/batch-d-parallel-coders/design.md`
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-172-parallel-coders-batch-d-expansion.md`
> **Predecessor tickets:** DIA-162/DIA-163 (BATCH-DISPATCH + plugin A1, commits 0697a08 + 7b08e90)
> **Implementation commits:** none yet (spec phase).
> **Routing:** AGENTS.md section 2.5 (OpenCode Configuration Changes). `@coder` implements; `make test-config` validates; `@ai-auditor` independent review.
> **Developer approval gate:** implementation MUST NOT start until the developer reviews and approves this plan (per the developer's operational requirement #6 for this change).
> **Worktree discipline (per developer requirements #1-#5):** every coder works in its OWN git worktree; ONE worktree per task; per-worktree reviewer on committed fixed points; orchestrator owns worktree naming; serialized squash-merges.

## Dependency graph

```
T1 (foundation: .sdd ADRs) -----> T3 (plugin: F4 + F5 + batch D)
                                   |
                                   v
T2 (drift closures: F1/F2/F3) -> T4 (lockstep surface: preset texts + orchestrator_append + coder instructions)
                                   |
                                   v
                                 T5 (verification sweep: behavioral tests + make test-config + lockstep grep + restart smoke)
```

- **T1** has no blockers (foundation: ADRs are pure text).
- **T2** has no blockers (drift closures are independent of the plugin work).
- **T3** depends on T1 (ADRs document the decisions that the plugin implements).
- **T4** depends on T2 + T3 (preset texts must agree with plugin's READ_ONLY_LANES + batch D predicate; coder instructions must match the batch D wording; orchestrator_append A1 must match the 5-surface lockstep).
- **T5** depends on T1-T4 (verification sweep validates all surfaces).

**Critical path:** T1 -> T3 -> T4 -> T5 (T2 runs in parallel with T1/T3, but T4 needs both).

**Rationale for five slices (not fewer, not more):**

- **Not fewer:** T1 (ADRs) is pure text and independently verifiable -- merging it with T3 (plugin) would conflate different file types and make partial rollback harder. T2 (drift closures) is independent of the plugin work. T4 (lockstep surface) is logically coupled to T3 but touches different files (JSONC + markdown vs TypeScript) and is verifiable independently via grep. T5 (verification) is cross-cutting and must run last.
- **Not more:** each slice is already the narrowest coherent unit. Splitting T3 further (e.g., F4 separate from F5 + batch D) would create a slice that is not demoable on its own (the signature change must be consistent with the predicate change). Splitting T4 (e.g., preset texts separate from orchestrator_append) would separate tightly-coupled lockstep surfaces.

---

## 1. Foundation

- [ ] **1.1 Author `.sdd/opencode-config/architecture.md` + update `.sdd/README.md` index row.**
  - **Blockers:** none
  - **Vertical slice:** create the new `.sdd/opencode-config/architecture.md` file with the two ADRs transcribed verbatim from the architector design (ADR 1 "Batch Pattern D (Parallel Coders)" + ADR 2 "Singleton-Batch Semantic Exemption", both Status Accepted). Update `.sdd/README.md` index table to include a row pointing to the new file with a one-line summary.
  - **Acceptance criteria:**
    - `.sdd/opencode-config/architecture.md` exists and contains two ADRs with Status Accepted.
    - ADR 1 Context references DIA-172 and the parallel-throughput motivation.
    - ADR 2 Context references the singleton-batch false-positive motivation.
    - `.sdd/README.md` index table has a row `opencode-config/architecture.md` with a summary.
  - **Verification:** `cat .sdd/opencode-config/architecture.md` readable; grep for "ADR 1" and "ADR 2" both match; `grep -c "opencode-config" .sdd/README.md` returns >= 1.

## 2. Config drift closures (F1 + F2 + F3)

- [ ] **2.1 Close analyzer-escalated sole-writer drift (F1).**
  - **Blockers:** none
  - **Vertical slice:** in `.opencode/opencode.jsonc`, remove `".opencode/memory-shelf.yaml": "allow"` from the analyzer-escalated edit block (~line 257) and fix the adjacent comment (~lines 244-245) to reflect the corrected invariant. In `.opencode/agents/analyzer-escalated.md` (~lines 41-42), replace the self-registration instruction with "do NOT write .opencode/memory-shelf.yaml; report artifact paths (memory-manager registers)".
  - **Acceptance criteria:**
    - analyzer-escalated edit block in `opencode.jsonc` does NOT contain `memory-shelf.yaml`.
    - Adjacent comment reflects the DIA-162 sole-writer invariant.
    - analyzer-escalated agent markdown does NOT instruct self-registration; instead instructs reporting artifact paths to memory-manager.
  - **Verification:** `grep -c "memory-shelf.yaml" .opencode/agents/analyzer-escalated.md` returns 0 OR only appears in the negative-instruction sentence ("do NOT write ..."); analyzer-escalated edit block in opencode.jsonc does not list memory-shelf.yaml.

- [ ] **2.2 Close strict read-only drift for code-navigator + observer (F2).**
  - **Blockers:** none
  - **Vertical slice:** in `.opencode/opencode.jsonc`, add `"bash": "deny"` to the permission blocks of code-navigator (~line 320) and observer (~line 340).
  - **Acceptance criteria:**
    - code-navigator permission block contains `"bash": "deny"`.
    - observer permission block contains `"bash": "deny"`.
    - Both agents remain classified as read-only (still in READ_ONLY_LANES; this slice does not change the plugin, only the config).
  - **Verification:** `make test-config` (JSONC validity) exit 0; grep shows both permission blocks include bash deny.

- [ ] **2.3 Close conspecter doc drift (F3).**
  - **Blockers:** none
  - **Vertical slice:** in `.opencode/agents/conspecter.md` (line 18 and ~lines 82-83), change the edit allow list to `knowledge/*` only. Remove any mention of memory-shelf.yaml.
  - **Acceptance criteria:**
    - conspecter agent markdown edit allow list is `knowledge/*` only.
    - No mention of memory-shelf.yaml as an editable target (negative mentions like "do NOT write" are permitted).
  - **Verification:** grep for `memory-shelf.yaml` in conspecter.md returns only negative-instruction occurrences (or zero).

## 3. Plugin behavioral core (F4 + F5 + batch D)

- [ ] **3.1 Add `architector` to READ_ONLY_LANES (F5).**
  - **Blockers:** T1 (ADRs document the decision; this slice implements it)
  - **Vertical slice:** in `.opencode/plugins/delegation-observer.ts` (~line 277), add `"architector"` to the `READ_ONLY_LANES` Set.
  - **Acceptance criteria:**
    - `READ_ONLY_LANES` Set contains `"architector"`.
    - Comment above the Set (line 268-270) is updated to mention the DIA-172 addition.
  - **Verification:** `grep -A 6 "READ_ONLY_LANES = new Set" .opencode/plugins/delegation-observer.ts` shows `"architector"` in the Set.

- [ ] **3.2 Extend `isSafeTaskBatch` signature + extract worktree assertion (D1 + D2).**
  - **Blockers:** T1, 3.1
  - **Vertical slice:** change the signature of `isSafeTaskBatch` from `(agents: string[])` to `(tasks: Array<{agent: string, worktree?: string}>)`. Extend the per-turn capture (currently `{tool, subagent_type}` at ~lines 411-414) to also capture the worktree assertion extracted via regex `/WORKTREE:\s*(\S+)/i` against the task description+prompt. Update the single call site (~line 807) to construct the new array shape. Update A/B/C predicates to destructure `task.agent` instead of using the bare string.
  - **Acceptance criteria:**
    - `isSafeTaskBatch` signature is `Array<{agent, worktree?}>`.
    - Per-turn capture includes `worktree?: string` extracted via the documented regex.
    - Single call site at line 807 passes the new shape.
    - A/B/C predicates continue to work (regression-free) after destructuring.
  - **Verification:** TypeScript compiles (no type errors); existing A/B/C classification behavior unchanged (verified via behavioral test in T5).

- [ ] **3.3 Add batch D predicate + F4 singleton exemption (D3 + D4).**
  - **Blockers:** 3.2
  - **Vertical slice:** in `isSafeTaskBatch`, after A/B/C predicates, add predicate D: multiple coders with distinct worktree paths + all non-coders read-only. In the call-site guard (~line 800), implement the F4 singleton exemption: when the turn contains exactly one task() call (regardless of other semantic tools like log_decision), skip the A1 classification entirely (silent).
  - **Acceptance criteria:**
    - Predicate D returns true iff (a) every non-coder lane is in READ_ONLY_LANES, (b) every coder lane has a defined worktree assertion, (c) the Set of worktree paths has size equal to the number of coder lanes.
    - Singleton exemption: turns with exactly one task() call do NOT trigger A1, regardless of other semantic tools in the turn.
    - Malformed worktree assertions (multiple markers in one payload) are treated as `worktree = undefined`, causing batch D to fail for that coder (fail-loud).
  - **Verification:** behavioral test cases (T5): (a) 2 coders WITHOUT worktree assertion -> UNSAFE; (b) 2 coders WITH distinct worktrees -> SAFE; (c) 2 coders WITH same worktree -> UNSAFE; (d) 2 coders + 1 analyzer -> UNSAFE (writer in batch D); (e) 2 coders + 1 researcher -> SAFE (non-coder read-only); (f) 1 task() + log_decision -> silent (F4); (g) 1 task() + 1 read -> silent or classified as per A/B/C (not a batch D case).

## 4. Lockstep surface (preset texts + orchestrator_append + coder instructions)

- [ ] **4.1 Extend BATCH-DISPATCH rule text in 3 presets (D9 + D5 mirror).**
  - **Blockers:** T1, 3.1, 3.3
  - **Vertical slice:** in `.opencode/oh-my-opencode-slim.jsonc` at lines 26/207/429 (3 identical presets), replace the BATCH-DISPATCH RULE text with the extended version from design.md D9, which preserves A/B/C wording verbatim and appends the batch D clause. `architector` must appear in batch A's lane list.
  - **Acceptance criteria:**
    - All 3 preset locations contain identical BATCH-DISPATCH RULE text.
    - Batch A lane list includes `architector`.
    - Batch D clause includes "multiple @coder lanes ONLY IF each uses a separate git worktree and the dispatch payload asserts WORKTREE: <path> per coder, with disjoint file sets".
    - "When in doubt, serialize" tail is present.
  - **Verification:** lockstep grep across the 3 preset locations returns identical text; grep for "architector" and "WORKTREE" both match in all 3 locations.

- [ ] **4.2 Extend orchestrator_append.md A1 + A6 (D11).**
  - **Blockers:** 4.1
  - **Vertical slice:** in `.opencode/oh-my-opencode-slim/orchestrator_append.md`, A1 section (~156-167): extend to include `architector` in batch A + the batch D wording (must agree with 4.1 preset texts). A6 Serialization Points: add item 6 encoding the developer's operational contract for parallel coders (per-worktree review on committed fixed points + serialized squash-merges).
  - **Acceptance criteria:**
    - A1 section includes `architector` in batch A lane list + batch D wording.
    - A6 item 6 is present and encodes "per-worktree reviews MUST operate on committed fixed points inside that worktree; squash-merges to the main branch MUST be serialized (one at a time)".
    - 5-surface lockstep invariant holds: plugin READ_ONLY_LANES (3.1) + 3 preset texts (4.1) + A1 section (4.2) all agree.
  - **Verification:** lockstep grep across all 5 surfaces returns consistent strings for architector-in-A and batch-D wording.

- [ ] **4.3 APPEND coder inline instructions for batch D (D10).**
  - **Blockers:** 4.1
  - **Vertical slice:** in the presets where `coder` has existing inline prompts (per DIA-128: coder and analyzer have inline prompts in `oh-my-opencode-slim.jsonc`), APPEND (do not replace) the worktree confinement directive: "If dispatched as part of a parallel batch (batch D), strictly confine your work to the git worktree path specified in your task payload; do not touch the main tree or other worktrees; commit to your assigned branch only." Plus the standard verification-evidence duty reference.
  - **Acceptance criteria:**
    - Existing coder inline instructions are preserved verbatim (APPEND, not replace).
    - New confinement directive is present and conditional on "batch D".
    - Verification-evidence duty is referenced (or already present and reinforced).
  - **Verification:** diff shows only ADD lines (no DELETE/CHANGE lines) in the coder inline instruction block; grep for "batch D" and "worktree path specified" both match in the coder instruction section.

## 5. Verification sweep

- [ ] **5.1 Behavioral tests for plugin classification.**
  - **Blockers:** 3.3, 4.1
  - **Vertical slice:** author a small standalone behavioral test (either as a new bats case, a new standalone script under `scripts/__tests__/`, or inline in an existing plugin test harness if one exists) that invokes the plugin's classification logic with synthetic payload arrays and asserts SAFE/UNSAFE outcomes for: (a) read-only batch incl. architector -> SAFE (A); (b) single-writer -> SAFE (B); (c) reviewer + ai-auditor -> SAFE (C); (d) 2 coders without worktrees -> UNSAFE; (e) 2 coders with distinct worktrees -> SAFE (D); (f) 2 coders with same worktree -> UNSAFE; (g) 2 coders + 1 writer -> UNSAFE; (h) 2 coders + 1 read-only -> SAFE (D + non-coder read-only); (i) 1 task() + log_decision -> silent (F4 singleton exemption).
  - **Acceptance criteria:**
    - Test script exists and runs.
    - All 9 cases pass with expected SAFE/UNSAFE/silent outcomes.
    - Test invokes the actual classification logic (not a reconstructed copy).
  - **Verification:** test script exits 0; case count = 9; all cases pass.

- [ ] **5.2 `make test-config` + lockstep grep.**
  - **Blockers:** T2, T4 (all changes must be in place)
  - **Vertical slice:** run `make test-config` and verify exit 0. Run the lockstep grep across 5 surfaces: (a) `architector` in `READ_ONLY_LANES` (plugin), (b) `architector` in batch A lane list in each of the 3 preset BATCH-DISPATCH rule texts, (c) `architector` in A1 section of orchestrator_append.md, (d) batch D wording in each of the 3 preset BATCH-DISPATCH rule texts, (e) batch D wording in A1 section of orchestrator_append.md, (f) A6 item 6 in orchestrator_append.md.
  - **Acceptance criteria:**
    - `make test-config` exits 0.
    - Lockstep grep returns matches for all 6 checks (a-f).
    - No PURE-DISPATCH remnants (regression check).
  - **Verification:** exit 0; grep counts match expected (1 for plugin READ_ONLY_LANES + 3 for preset texts + 1 for orchestrator_append A1 = 5 matches for architector-in-A; same count for batch D wording; 1 match for A6 item 6).

- [ ] **5.3 Restart smoke (integration).**
  - **Blockers:** 5.1, 5.2
  - **Vertical slice:** restart OpenCode inside the dev container (with the new plugin loaded). Dispatch representative batches via the orchestrator and observe plugin behavior: (a) batch A with researcher + architector -> silent (no A1 warning); (b) batch D without worktree assertions (2 coders) -> A1 VIOLATION warning + `a1_violation` row in registry.jsonl; (c) batch D with distinct worktree assertions (2 coders) -> silent.
  - **Acceptance criteria:**
    - OpenCode restarts cleanly (no plugin load errors).
    - Batch A (researcher + architector) produces no A1 warning in logs.
    - Batch D without worktrees produces A1 warning + `a1_violation` row.
    - Batch D with distinct worktrees produces no A1 warning.
  - **Verification:** logs grepped for A1 VIOLATION patterns match expected outcomes; registry.jsonl contains (or does not contain) `a1_violation` rows per the expected outcomes.

---

## Out of scope for these tasks

- **Orchestrator dispatch logic implementation** (constructing worktree-bearing payloads, creating worktrees via `scripts/worktrees.sh`, dispatching per-worktree reviewers, performing serialized squash-merges). This is orchestrator behavioral work, consumed by this change's contract but not implemented here.
- **Worktree lifecycle CLI extension** (`scripts/worktrees.sh`). DIA-100 territory; this change consumes the CLI, does not extend it.
- **Full end-to-end orchestrator test** (orchestrator -> plugin -> coder in worktree -> reviewer -> squash-merge). This is workflow-adoption testing, orthogonal to the config change.
- **`.slim/worktrees.json` state file**. Not adopted by the project (DIA-100 scope).
- **DIA-085 / ana011 parallel-session protocol**. Not yet implemented; orthogonal to this change.

## Verification gate summary

| Gate                                                      | When | Required                                     |
| --------------------------------------------------------- | ---- | -------------------------------------------- |
| `.sdd/opencode-config/architecture.md` exists with 2 ADRs | T1.1 | File readable, ADR 1 + ADR 2 present         |
| `.sdd/README.md` index row                                | T1.1 | grep `opencode-config` matches               |
| analyzer-escalated memory-shelf.yaml removed              | T2.1 | Negative grep in edit block + agent markdown |
| code-navigator + observer bash deny                       | T2.2 | `make test-config` exit 0 + grep matches     |
| conspecter knowledge/\* only                              | T2.3 | grep matches                                 |
| architector in READ_ONLY_LANES                            | T3.1 | grep matches                                 |
| isSafeTaskBatch signature change                          | T3.2 | TypeScript compiles, no type errors          |
| batch D predicate + F4 singleton exemption                | T3.3 | Behavioral test cases pass                   |
| 3 preset BATCH-DISPATCH rule texts extended               | T4.1 | Lockstep grep matches across all 3           |
| orchestrator_append A1 + A6                               | T4.2 | Lockstep grep matches                        |
| Coder inline instructions APPEND                          | T4.3 | Diff shows only ADD lines                    |
| Behavioral plugin tests (9 cases)                         | T5.1 | Test script exits 0, 9/9 pass                |
| `make test-config` + lockstep grep                        | T5.2 | Exit 0; 6 lockstep checks pass               |
| Restart smoke                                             | T5.3 | 3 representative batches behave as expected  |

## Implementation notes for `@coder`

- **ASCII-only protocol (DIA-079):** all changes to JSONC/markdown/TypeScript must use ASCII-only text (no em-dashes, no smart quotes, no non-ASCII punctuation) to prevent serialization failures.
- **DIA-094 Docker gate:** implementation work AND commits MUST NOT proceed without a running docker dev container.
- **DIA-063 Ticket gate:** no implementation work starts without the DIA-172 ticket (already in place).
- **Practice-protected zone:** the OpenSpec artifacts themselves (this file) are practice-protected -- the developer writes the substance, @openspec-plan guides. Implementation of the artifacts (what this tasks.md describes) is not practice-protected; @coder implements freely within the acceptance criteria.
- **Developer approval gate:** per the developer's operational requirement #6 for this change, @orchestrator MUST present the final plan (these tasks) to the developer for explicit approval BEFORE dispatching @coder to implement.
- **Worktree discipline:** every coder dispatched under this change works in its OWN worktree. Since this change's slices are sequential and tightly coupled, the recommendation is a SINGLE coder worktree for the whole change (not parallel coders across slices). If the developer chooses to parallelize slices, each coder must have a distinct worktree per the developer's operational requirements.
